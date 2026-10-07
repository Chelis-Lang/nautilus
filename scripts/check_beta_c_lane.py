#!/usr/bin/env python3
"""Build the beta-family exports through the C lane and check both lanes agree.

`chelis reef build` type-checks the package and does NOT enter host lowering, so
it is not weak evidence about a C consumer -- it is no evidence. nautilus#125
records that class in this repo (`Nautilus.Optim` and `Nautilus.Roots` cannot be
built by a C consumer while every package gate is green), and nautilus#70 states
the rule: package-level green is not evidence for a consumer. The rolling
harness beside this one exists for the same reason.

This module earned its own oracle when the regularised incomplete beta moved to
f64 internals: f64 arithmetic, f64 tuple members and f64->f32 casts are all new
to this module's host-lowered path, and nothing else in CI compiles them.

Three legs, and the third is the one that catches a package boundary.

**Eval leg:** evaluate the probe with `chelis eval --file` to get each value in
the interpreter lane.

**In-package leg:** `chelis build` the same probe from inside `src/`, require an
executable, run it, and require every value to match the eval lane bit for bit.
That covers host lowering, C compilation and linking rather than stopping at
code generation.

**Cross-package leg:** rebuild this package from the CURRENT source, install it
into a throwaway Reef store, then build a *separate* package against it and run
that. An in-package module shares the package's own compilation context, so it
cannot see a package-boundary failure. The rebuild is not optional: the rolling
harness records a review round that probed STALE `dist/` artifacts built from a
mutated source and drew a conclusion that was a property of the artifact rather
than of the module.

Cross-lane agreement alone would not catch both lanes being wrong the same way,
so the probe also carries absolute anchors that need no reference library:
`beta_cdf(0.5, a, a)` and `f_cdf(1, d, d)` are **0.5 exactly** for every `a` and
`d`, by the symmetry of those distributions.

The cross-package leg sets `CHELIS_REEF_HOME` to a temporary directory, so it
never writes the shared `~/.chelis/reef/`; the run asserts that store's digest
is unchanged.

    python3 scripts/check_beta_c_lane.py

Success is exit 0 with a final `BETA C LANE: PASS` line. Set `CHELIS_BIN` to
validate an explicit toolchain binary. `--in-package-only` skips the leg that
builds and installs the package. `--keep` leaves the generated artifacts.

The probe is written into `src/` because chelis resolves package imports from the
source root, and it is always removed again. Its module name and `lane_` prefix
have to agree: §7.1 rejects a shared prefix that is not the module's own domain
shorthand, and the style gate runs before the build.
"""
from __future__ import annotations

import argparse
import hashlib
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
PROBE = REPO / "src" / "lanebeta.ch"
MODULE = "Nautilus.LaneBeta"
NAME = "nautilus"
SHARED_STORE = Path.home() / ".chelis" / "reef"
VALUE_RE = re.compile(r"^\s*(lane_\w+)\s*=\s*(\S+)\s*$", re.M)

# Each case is (name, expression). The two `_sym` cases are the absolute
# anchors: both are 0.5 exactly, by symmetry, with no reference needed.
CASES = [
    ("lane_sym_beta", "beta_cdf(cast(0.5, f32), cast(1e7, f32), cast(1e7, f32))"),
    ("lane_sym_f", "f_cdf(cast(1.0, f32), cast(1e5, f32), cast(1e5, f32))"),
    ("lane_beta", "beta_cdf(cast(0.3, f32), cast(2.0, f32), cast(5.0, f32))"),
    ("lane_f", "f_cdf(cast(3.0, f32), cast(5.0, f32), cast(10.0, f32))"),
    ("lane_t", "student_t_cdf(cast(1.0, f32), cast(5.0, f32))"),
    ("lane_binom", "binomial_cdf(cast(3.0, f32), cast(10.0, f32), cast(0.3, f32))"),
    # the three argument-saturation cases nautilus#143 repaired
    ("lane_t_sat", "student_t_cdf(cast(1.0, f32), cast(1e8, f32))"),
    ("lane_f_sat", "f_cdf(cast(1.0, f32), cast(1e8, f32), cast(1.0, f32))"),
    ("lane_binom_sat", "binomial_cdf(cast(0.0, f32), cast(1000000.0, f32), cast(1e-8, f32))"),
    # the [0, 1] range guard
    ("lane_nan", "beta_cdf(cast(0.5, f32), cast(1e12, f32), cast(1e12, f32))"),
]
SYMMETRIC = {"lane_sym_beta", "lane_sym_f"}
EXPECT_NAN = {"lane_nan"}
# f32 holds about 7 digits; the symmetry anchors are measured well inside this.
SYM_TOL = 1e-5


class LaneError(Exception):
    pass


def probe_source(module: str) -> str:
    lines = [
        f"module {module}",
        "import Nautilus.Distributions (beta_cdf, f_cdf, student_t_cdf, binomial_cdf)",
        f"export ({', '.join(name for name, _ in CASES)})",
    ]
    lines += [f"def {name}() -> f32 = {expr}" for name, expr in CASES]
    return "\n".join(lines) + "\n"


def run(command: list[str], cwd: Path, env: dict | None = None,
        timeout: int = 1800) -> subprocess.CompletedProcess:
    return subprocess.run(command, cwd=str(cwd), capture_output=True, text=True,
                          timeout=timeout, env=env)


def values(stdout: str) -> dict[str, str]:
    return {m.group(1): m.group(2) for m in VALUE_RE.finditer(stdout)}


def field(pattern: str) -> str:
    match = re.search(pattern, (REPO / "reef.toml").read_text(), re.M)
    if match is None:
        raise LaneError(f"cannot read {pattern} from reef.toml")
    return match.group(1)


def store_digest(root: Path) -> str:
    if not root.exists():
        return "absent"
    h = hashlib.sha256()
    for path in sorted(p for p in root.rglob("*") if p.is_file()):
        h.update(str(path.relative_to(root)).encode())
        h.update(str(path.stat().st_size).encode())
    return h.hexdigest()[:16]


def check_anchors(got: dict[str, str], lane: str) -> None:
    """The symmetry anchors and the NaN guard, which need no reference."""
    for name in SYMMETRIC:
        raw = got.get(name)
        if raw is None:
            raise LaneError(f"{lane}: {name} missing from output")
        if abs(float(raw) - 0.5) > SYM_TOL:
            raise LaneError(
                f"{lane}: {name} = {raw}, but it is 0.5 exactly by symmetry "
                f"(tolerance {SYM_TOL})"
            )
    raw = got.get("lane_nan")
    if raw is None or raw.lower() != "nan":
        raise LaneError(
            f"{lane}: lane_nan = {raw}, expected NaN from the [0, 1] range guard"
        )


def compare(a: dict[str, str], b: dict[str, str], a_name: str, b_name: str) -> None:
    missing = [name for name, _ in CASES if name not in a or name not in b]
    if missing:
        raise LaneError(f"missing from one lane: {', '.join(missing)}")
    bad = [(name, a[name], b[name]) for name, _ in CASES if a[name] != b[name]]
    if bad:
        detail = "\n".join(f"    {n}: {a_name} {x} vs {b_name} {y}" for n, x, y in bad)
        raise LaneError(f"{a_name} and {b_name} disagree:\n{detail}")


def cross_package(chelis: str, keep: bool) -> dict[str, str]:
    version, pin = field(r'^version\s*=\s*"([^"]+)"'), field(r'^compiler\s*=\s*"=?([^"]+)"')
    built = run([chelis, "reef", "build"], REPO)
    if built.returncode != 0:
        raise LaneError(
            "chelis reef build failed, so there is no artifact to install "
            f"(rc={built.returncode}):\n{(built.stderr or built.stdout).strip()[-600:]}"
        )
    sandbox = Path(tempfile.mkdtemp(prefix="beta-c-lane-"))
    try:
        mono = sandbox / "mono" / "packages" / NAME
        (mono / "dist").mkdir(parents=True)
        shutil.copy(REPO / "reef.toml", mono / "reef.toml")
        for suffix in (".chb", ".tar.zst"):
            artifact = REPO / "dist" / f"{NAME}-{version}{suffix}"
            if not artifact.exists():
                raise LaneError(f"missing build artifact {artifact}")
            shutil.copy(artifact, mono / "dist" / artifact.name)

        store = sandbox / "store"
        store.mkdir()
        env = dict(os.environ, CHELIS_REEF_HOME=str(store))
        installed = run(
            [chelis, "reef", "install", "--from-monorepo", str(sandbox / "mono"), NAME],
            REPO, env=env)
        if installed.returncode != 0:
            raise LaneError(
                "reef install into the isolated store failed "
                f"(rc={installed.returncode}):\n"
                f"{(installed.stderr or installed.stdout).strip()[-600:]}")

        consumer = sandbox / "consumer"
        (consumer / "src").mkdir(parents=True)
        (consumer / "reef.toml").write_text(
            "[package]\n"
            'name = "betaconsumer"\n'
            'version = "0.0.0"\n'
            f'compiler = "={pin}"\n'
            'module_prefix = "Downstream"\n'
            "\n[dependencies]\n"
            'chelis-std = { version = "0.4.0" }\n'
            f'{NAME} = {{ version = "{version}" }}\n')
        (consumer / "src" / "lanebeta.ch").write_text(probe_source("Downstream.LaneBeta"))
        formatted = run([chelis, "fmt", "--inplace", "src/lanebeta.ch"], consumer, env=env)
        if formatted.returncode != 0:
            raise LaneError(f"chelis fmt failed on the consumer probe: "
                            f"{formatted.stderr.strip()[-400:]}")

        out = sandbox / "out"
        consumed = run([chelis, "build", "-o", str(out), "src/lanebeta.ch"], consumer, env=env)
        if consumed.returncode != 0:
            raise LaneError(
                "a SEPARATE package could not build against this one "
                f"(rc={consumed.returncode}). The in-package leg passed, so this is a "
                f"package-boundary failure:\n"
                f"{(consumed.stderr or consumed.stdout).strip()[-1200:]}")
        executable = out / "lanebeta"
        if not executable.exists():
            raise LaneError(f"cross-package build produced no executable at {executable}")
        ran = run([str(executable)], consumer, env=env, timeout=600)
        if ran.returncode != 0:
            raise LaneError(f"the cross-package executable exited {ran.returncode}:\n"
                            f"{(ran.stderr or ran.stdout).strip()[-600:]}")
        return values(ran.stdout)
    finally:
        if not keep:
            shutil.rmtree(sandbox, ignore_errors=True)


def main() -> int:
    parser = argparse.ArgumentParser(description="Beta-family C-lane oracle.")
    parser.add_argument("--keep", action="store_true",
                        help="keep the generated artifacts for inspection")
    parser.add_argument("--in-package-only", action="store_true",
                        help="skip the cross-package leg (it builds and installs the package)")
    args = parser.parse_args()

    chelis = os.environ.get("CHELIS_BIN", "chelis")
    before = store_digest(SHARED_STORE)
    out = Path(tempfile.mkdtemp(prefix="beta-c-lane-inpkg-"))
    try:
        PROBE.write_text(probe_source(MODULE))
        relative = str(PROBE.relative_to(REPO))
        formatted = run([chelis, "fmt", "--inplace", relative], REPO)
        if formatted.returncode != 0:
            raise LaneError(f"chelis fmt on the generated probe failed: "
                            f"{formatted.stderr.strip()[-500:]}")

        evaluated = run([chelis, "eval", "--file", relative], REPO)
        if evaluated.returncode != 0:
            raise LaneError(f"chelis eval --file on the probe failed "
                            f"(rc={evaluated.returncode}):\n"
                            f"{(evaluated.stderr or evaluated.stdout).strip()[-800:]}")
        eval_values = values(evaluated.stdout)
        check_anchors(eval_values, "eval lane")
        print(f"eval lane: {len(eval_values)} values, anchors hold")

        built = run([chelis, "build", "-o", str(out), relative], REPO)
        if built.returncode != 0:
            raise LaneError(
                "chelis build rejected an in-package consumer of the beta family "
                f"(rc={built.returncode}):\n{(built.stderr or built.stdout).strip()[-1200:]}")
        executable = out / PROBE.stem
        if not executable.exists():
            raise LaneError(f"in-package build produced no executable at {executable}")
        ran = run([str(executable)], REPO, timeout=600)
        if ran.returncode != 0:
            raise LaneError(f"the in-package executable exited {ran.returncode}:\n"
                            f"{(ran.stderr or ran.stdout).strip()[-600:]}")
        in_package = values(ran.stdout)
        check_anchors(in_package, "in-package C lane")
        compare(eval_values, in_package, "eval lane", "in-package C lane")
        print(f"in-package C lane: built, ran, and agrees with the eval lane on "
              f"all {len(CASES)} values")
    except LaneError as error:
        print(f"BETA C LANE: FAIL\n{error}", file=sys.stderr)
        return 1
    finally:
        if not args.keep:
            PROBE.unlink(missing_ok=True)
            shutil.rmtree(out, ignore_errors=True)

    if not args.in_package_only:
        try:
            cross = cross_package(chelis, args.keep)
            check_anchors(cross, "cross-package C lane")
            compare(eval_values, cross, "eval lane", "cross-package C lane")
            print(f"cross-package C lane: a separate package built, ran, and agrees "
                  f"with the eval lane on all {len(CASES)} values")
        except LaneError as error:
            print(f"BETA C LANE: FAIL\n{error}", file=sys.stderr)
            return 1

    after = store_digest(SHARED_STORE)
    if before != after:
        print(f"BETA C LANE: FAIL\nthe shared Reef store at {SHARED_STORE} changed "
              f"({before} -> {after}); the isolated store leaked", file=sys.stderr)
        return 1
    print(f"shared Reef store unchanged ({before})")
    print("BETA C LANE: PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
