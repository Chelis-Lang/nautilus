#!/usr/bin/env python3
"""Measure `chelis eval` startup cost for Nautilus imports."""
from __future__ import annotations

import argparse
import statistics
import subprocess
import sys
import tempfile
import time
from dataclasses import dataclass
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
REPORT = REPO / "docs" / "EVAL_STARTUP_FINDINGS.md"
sys.path.insert(0, str(REPO))

from scripts.chelis_toolchain import resolve_chelis_bin

CHELIS = resolve_chelis_bin()
BASELINE_EXPR = "add(cast(1, f32), cast(2, f32))"
BASELINE_FILE = "bench = add(cast(1, f32), cast(2, f32))\n"

IMPORT_SNIPPETS: dict[str, str] = {
    "Nautilus.Special": "import Nautilus.Special (erf)\nbench = cast(0, f32)\n",
    "Nautilus.Distributions": "import Nautilus.Distributions (normal_cdf)\nbench = cast(0, f32)\n",
    "Nautilus.LinAlg": "import Nautilus.LinAlg (l2_norm_vec)\nbench = cast(0, f32)\n",
    "Nautilus.Stats": "import Nautilus.Stats (mean_vec)\nbench = cast(0, f32)\n",
    "Nautilus.Distance": "import Nautilus.Distance (squared_euclidean)\nbench = cast(0, f32)\n",
    "Nautilus.Roots": "import Nautilus.Roots (brent)\nbench = cast(0, f32)\n",
    "Nautilus.Ode": "import Nautilus.Ode (rk4_solve)\nbench = cast(0, f32)\n",
    "Nautilus.Integrate": "import Nautilus.Integrate (gauss_legendre_10)\nbench = cast(0, f32)\n",
    "Nautilus.Testing": "import Nautilus.Testing (z_statistic)\nbench = cast(0, f32)\n",
    "Nautilus.Optim": "import Nautilus.Optim (golden_section_search)\nbench = cast(0, f32)\n",
    "Nautilus.Interpolation": "import Nautilus.Interpolation (linear_interp_uniform)\nbench = cast(0, f32)\n",
    "Nautilus.Sde": "import Nautilus.Sde (euler_maruyama_fixed)\nbench = cast(0, f32)\n",
    "Nautilus.CurveFit": "import Nautilus.CurveFit (lm_scalar_1param)\nbench = cast(0, f32)\n",
    "Nautilus.Signal": "import Nautilus.Signal (fftfreq)\nbench = cast(0, f32)\n",
}
IMPORT_SNIPPETS["all_modules"] = "".join(
    snippet.splitlines()[0] + "\n"
    for snippet in IMPORT_SNIPPETS.values()
) + "bench = cast(0, f32)\n"


@dataclass
class TrialResult:
    duration_ms: float


@dataclass
class ScenarioResult:
    label: str
    stats: dict[str, object] | None
    status: str
    detail: str


def make_eval_file(temp_dir: Path, stem: str, source: str) -> Path:
    path = temp_dir / stem
    path.write_text(source)
    return path


def snapshot_descendants(root_pid: int) -> set[str]:
    try:
        proc = subprocess.run(
            ["ps", "-axo", "pid=,ppid=,comm="],
            capture_output=True,
            check=True,
            text=True,
        )
    except (FileNotFoundError, subprocess.CalledProcessError):
        return set()

    children_by_parent: dict[int, list[tuple[int, str]]] = {}
    for line in proc.stdout.splitlines():
        line = line.strip()
        if not line:
            continue
        pid_str, ppid_str, comm = line.split(None, 2)
        children_by_parent.setdefault(int(ppid_str), []).append((int(pid_str), comm.strip()))

    seen: set[int] = set()
    queue = [root_pid]
    commands: set[str] = set()
    while queue:
        parent = queue.pop()
        if parent in seen:
            continue
        seen.add(parent)
        for child_pid, comm in children_by_parent.get(parent, []):
            commands.add(Path(comm).name)
            queue.append(child_pid)
    return commands


_PROBE_TIMEOUT_S = 5    # if chelis eval doesn't respond in 5s it's hung
_TIMED_TIMEOUT_S = 30  # generous for actual measurement trials


def run_timed(cmd: list[str]) -> TrialResult:
    start = time.perf_counter()
    proc = subprocess.run(
        cmd,
        cwd=REPO,
        capture_output=True,
        text=True,
        timeout=_TIMED_TIMEOUT_S,
    )
    duration_ms = (time.perf_counter() - start) * 1000.0
    if proc.returncode != 0:
        raise RuntimeError(proc.stderr.strip() or proc.stdout.strip() or "unknown error")
    return TrialResult(duration_ms=duration_ms)


def inspect_child_processes(cmd: list[str]) -> set[str]:
    proc = subprocess.Popen(
        cmd,
        cwd=REPO,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    descendants: set[str] = set()
    deadline = time.perf_counter() + _TIMED_TIMEOUT_S
    while proc.poll() is None:
        if time.perf_counter() > deadline:
            proc.kill()
            proc.wait()
            raise RuntimeError(f"command timed out after {_SUBPROCESS_TIMEOUT_S}s")
        descendants |= snapshot_descendants(proc.pid)
        time.sleep(0.05)
    stdout, stderr = proc.communicate()
    if proc.returncode != 0:
        raise RuntimeError(stderr.strip() or stdout.strip() or "unknown error")
    return descendants


def summarize(results: list[TrialResult], child_commands: set[str]) -> dict[str, object]:
    durations = [r.duration_ms for r in results]
    p95_index = max(0, round(0.95 * len(durations)) - 1)
    return {
        "median_ms": statistics.median(durations),
        "mean_ms": statistics.mean(durations),
        "min_ms": min(durations),
        "max_ms": max(durations),
        "p95_ms": sorted(durations)[p95_index],
        "child_commands": sorted(child_commands),
    }


def format_timing_table(rows: list[tuple[str, dict[str, object]]]) -> str:
    lines = [
        "| Scenario | Median ms | Mean ms | P95 ms | Min ms | Max ms | Child processes |",
        "|---|---:|---:|---:|---:|---:|---|",
    ]
    for label, stats in rows:
        children = ", ".join(stats["child_commands"]) if stats["child_commands"] else "none observed"
        lines.append(
            f"| {label} | {stats['median_ms']:.1f} | {stats['mean_ms']:.1f} | "
            f"{stats['p95_ms']:.1f} | {stats['min_ms']:.1f} | {stats['max_ms']:.1f} | {children} |"
        )
    return "\n".join(lines)


def format_probe_table(results: list[ScenarioResult]) -> str:
    lines = ["| Scenario | Status | Detail |", "|---|---|---|"]
    for result in results:
        detail = result.detail.replace("\n", " ").strip()
        lines.append(f"| {result.label} | {result.status} | {detail} |")
    return "\n".join(lines)


def probe_and_measure(trials: int, label: str, cmd: list[str]) -> ScenarioResult:
    try:
        probe = subprocess.run(
            cmd,
            cwd=REPO,
            capture_output=True,
            text=True,
            timeout=_PROBE_TIMEOUT_S,
        )
    except FileNotFoundError as exc:
        return ScenarioResult(label=label, stats=None, status="blocked", detail=str(exc))
    except subprocess.TimeoutExpired:
        return ScenarioResult(label=label, stats=None, status="blocked",
                              detail=f"command timed out after {_PROBE_TIMEOUT_S}s (chelis eval --file may hang on this toolchain)")

    if probe.returncode != 0:
        detail = probe.stderr.strip() or probe.stdout.strip() or "unknown error"
        return ScenarioResult(label=label, stats=None, status="blocked", detail=detail)

    try:
        results = [run_timed(cmd) for _ in range(trials)]
        children = inspect_child_processes(cmd)
    except (RuntimeError, subprocess.TimeoutExpired) as exc:
        return ScenarioResult(label=label, stats=None, status="blocked", detail=str(exc))
    return ScenarioResult(
        label=label,
        stats=summarize(results, children),
        status="timed",
        detail="measured successfully",
    )


def recommended_changes(
    baseline_inline: ScenarioResult,
    baseline_file: ScenarioResult,
    import_results: list[ScenarioResult],
) -> list[str]:
    recs: list[str] = []
    import_failures = [result for result in import_results if result.status != "timed"]
    successful_imports = [result for result in import_results if result.status == "timed"]

    if import_failures:
        first = import_failures[0]
        if "panicked at" in first.detail:
            recs.append(
                "`chelis eval --file` currently crashes when the file contains Nautilus reef imports. "
                "The first upstream fix is to stabilize package-aware file eval lowering before any import-startup target can be measured credibly."
            )
        else:
            recs.append(
                "`chelis eval --file` does not currently accept the Nautilus import surface exercised here. "
                "The compiler team should first make file-backed eval support reef-package imports as a supported CLI path."
            )

    for baseline in (baseline_inline, baseline_file):
        if baseline.stats is None:
            continue
        median_ms = float(baseline.stats["median_ms"])
        child_commands = {cmd.lower() for cmd in baseline.stats["child_commands"]}
        if {"gcc", "clang", "cc", "ld"} & child_commands and median_ms > 200.0:
            recs.append(
                "Even the working eval baseline shells out to a native toolchain, so process startup is part of the latency floor. "
                "If the 200 ms target matters, the likely upstream fix is a persistent eval server or library mode rather than a fresh compiler/toolchain subprocess per call."
            )
            break

    if baseline_file.stats is not None and float(baseline_file.stats["median_ms"]) > 200.0:
        recs.append(
            "The file-backed baseline already exceeds the 200 ms target before Nautilus imports are added. "
            "Upstream should reduce fixed startup cost first, then revisit package import caching."
        )

    if successful_imports:
        slowest = max(successful_imports, key=lambda result: float(result.stats["median_ms"]))
        recs.append(
            f"If import-backed eval is fixed, start optimization work with `{slowest.label}` because it is the slowest successfully measured import scenario in this run."
        )

    if not recs:
        recs.append(
            "The working eval baselines are already below target and the benchmark surface did not expose a single dominant import cost in this run."
        )

    recs.append(
        "Warm-cache measurement is still skipped because this CLI does not expose a documented persistent eval/session mode to benchmark."
    )
    return recs


def write_report(
    trials: int,
    baseline_rows: list[tuple[str, dict[str, object]]],
    import_results: list[ScenarioResult],
    recommendations: list[str],
) -> None:
    baseline_table = format_timing_table(baseline_rows)
    probe_table = format_probe_table(import_results)
    report = "\n".join(
        [
            "# Eval Startup Findings",
            "",
            "Generated by `python scripts/bench_eval_startup.py`.",
            "",
            f"- Toolchain: `{Path(CHELIS).name}`",
            f"- Trials per timed scenario: {trials}",
            "- Working directory: repo root",
            "- Measurement: wall-clock subprocess duration for successful `chelis eval` invocations",
            "- CLI surface observed on this build: `chelis eval --file <FILE> <EXPR>`; the old `--expr` flag is rejected",
            "",
            "## Cold-start baselines",
            "",
            baseline_table,
            "",
            "## Warm-cache results",
            "",
            "Skipped. No documented persistent eval/session surface is exposed here.",
            "",
            "## Nautilus import-surface probe",
            "",
            probe_table,
            "",
            "## Recommended upstream changes",
        ]
    )
    bullets = "\n".join(f"- {item}" for item in recommendations)
    REPORT.write_text(report + "\n\n" + bullets + "\n")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--trials", type=int, default=20)
    args = parser.parse_args()

    with tempfile.TemporaryDirectory(prefix="nautilus-eval-bench-") as tmp:
        temp_dir = Path(tmp)
        baseline_file = make_eval_file(temp_dir, "baseline_file", BASELINE_FILE)
        inline_cmd = [CHELIS, "eval", BASELINE_EXPR]
        file_cmd = [CHELIS, "eval", "--file", str(baseline_file), "bench"]

        baseline_inline = probe_and_measure(args.trials, "inline_expr", inline_cmd)
        baseline_file_result = probe_and_measure(args.trials, "file_baseline", file_cmd)

        import_results: list[ScenarioResult] = []
        for index, (label, source) in enumerate(IMPORT_SNIPPETS.items()):
            path = make_eval_file(temp_dir, f"import_case_{index}", source)
            cmd = [CHELIS, "eval", "--file", str(path), "bench"]
            import_results.append(probe_and_measure(args.trials, label, cmd))

    baseline_rows: list[tuple[str, dict[str, object]]] = []
    for result in (baseline_inline, baseline_file_result):
        if result.stats is not None:
            baseline_rows.append((result.label, result.stats))

    recommendations = recommended_changes(baseline_inline, baseline_file_result, import_results)
    write_report(args.trials, baseline_rows, import_results, recommendations)

    print(format_timing_table(baseline_rows))
    print()
    print("Warm-cache: skipped (no documented persistent eval/session surface detected).")
    print()
    print(format_probe_table(import_results))
    print()
    print(f"wrote {REPORT.relative_to(REPO)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
