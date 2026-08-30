#!/usr/bin/env python3
"""Execute the frozen provenance fixture pack against the pinned command.

Every fixture freezes one expected outcome: the accept tree must produce the
golden canonical report bytes under two distinct absolute roots, each reject
tree must fail with its stable diagnostic, the floating-pin fixture must fail
the pin check, and the builtin oracle files must produce the five-state
execution behavior without mutating the static identity.

Golden regeneration policy: delete one golden file, run this check twice, and
review the recorded diff before commit. A missing golden fails the run.
"""

from __future__ import annotations

import argparse
import json
import pathlib
import shutil
import subprocess
import sys
import tempfile

REJECT_CASES = (
    ("reject-omitted-row", "SPG-SURFACE-INCOMPLETE"),
    ("reject-unattached", "CHELIS-PROV-UNATTACHED-METADATA"),
    ("reject-unsupported", "CHELIS-PROV-UNSUPPORTED-SCHEMA"),
    ("reject-malformed", "CHELIS-PROV-MALFORMED-RECORD"),
    ("reject-parse", "CHELIS-PROV-PARSE-ERROR"),
    ("reject-runner", "CHELIS-PROV-ORACLE-RUNNER-STALE"),
)


def fail(code: str, detail: str) -> None:
    print(f"{code}: {detail}", file=sys.stderr)
    raise SystemExit(1)


def run_static(command: str, root: pathlib.Path, config: pathlib.Path) -> tuple[int, str]:
    result = subprocess.run(
        [command, "static", "--root", str(root), "--config", str(config)],
        capture_output=True,
        text=True,
        check=False,
    )
    return result.returncode, result.stdout.strip()


def check_golden(golden: pathlib.Path, current: str, name: str) -> None:
    if not golden.exists():
        golden.write_text(current + "\n")
        fail("NAUT-FIX-GOLDEN-RECORDED", f"{name} was absent; recorded current bytes, review and rerun")
    frozen = golden.read_text().strip()
    if frozen != current:
        fail("NAUT-FIX-GOLDEN-DRIFT", name)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", default=".", type=pathlib.Path)
    parser.add_argument("--command", default="nautilus-provenance")
    arguments = parser.parse_args()
    repo = arguments.repo.resolve()
    command = arguments.command
    fixtures = repo / "provenance" / "fixtures"
    config = repo / "provenance" / "chelis-adapter-config.toml"

    exit_code, report = run_static(command, fixtures / "accept", config)
    if exit_code != 0 or '"verdict":"accept"' not in report:
        fail("NAUT-FIX-ACCEPT", f"exit={exit_code}")
    check_golden(fixtures / "goldens" / "static-report.json", report, "static-report.json")

    with tempfile.TemporaryDirectory() as first, tempfile.TemporaryDirectory() as second:
        for scratch in (first, second):
            shutil.copytree(fixtures / "accept", pathlib.Path(scratch) / "tree")
        _, report_a = run_static(command, pathlib.Path(first) / "tree", config)
        _, report_b = run_static(command, pathlib.Path(second) / "tree", config)
    if report_a != report_b or report_a != report:
        fail("NAUT-FIX-DETERMINISM", "report bytes differ across absolute roots")

    for name, code in REJECT_CASES:
        exit_code, report_text = run_static(command, fixtures / name, config)
        if exit_code != 2:
            fail("NAUT-FIX-EXIT", f"{name}: expected static exit class 2, got {exit_code}")
        if code not in report_text:
            fail("NAUT-FIX-DIAGNOSTIC", f"{name}: missing {code}")

    pin_check = subprocess.run(
        [sys.executable, str(repo / "scripts" / "check_buoy_pin.py"), "--repo", str(fixtures / "pin-floating")],
        capture_output=True,
        text=True,
        check=False,
    )
    if pin_check.returncode == 0 or "NAUT-PIN-FLOATING" not in pin_check.stderr:
        fail("NAUT-FIX-PIN", "floating pin fixture must fail the pin check")

    def run_execute(oracles: str) -> tuple[int, dict]:
        result = subprocess.run(
            [
                command,
                "execute",
                "--root",
                str(fixtures / "accept"),
                "--config",
                str(config),
                "--oracles",
                str(fixtures / oracles),
            ],
            capture_output=True,
            text=True,
            check=False,
        )
        return result.returncode, json.loads(result.stdout)

    fail_exit, fail_report = run_execute("oracles-builtin.toml")
    pass_exit, pass_report = run_execute("oracles-builtin-pass.toml")
    if fail_exit != 4 or pass_exit != 0:
        fail("NAUT-FIX-EXECUTE-EXIT", f"fail={fail_exit} pass={pass_exit}")
    if fail_report["static_identity"] != pass_report["static_identity"]:
        fail("NAUT-FIX-IDENTITY", "execution mutated the static identity")
    if ["FIX-FAIL", "fail"] not in fail_report["verdicts"]:
        fail("NAUT-FIX-VERDICT", "failing builtin oracle must record verdict fail")
    check_golden(
        fixtures / "goldens" / "execute-report.json",
        json.dumps(pass_report, separators=(",", ":"), sort_keys=False),
        "execute-report.json",
    )

    print("provenance-fixtures: ok cases=10 goldens=2 determinism=cross-root")


if __name__ == "__main__":
    main()
