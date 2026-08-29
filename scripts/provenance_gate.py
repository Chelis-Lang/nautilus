#!/usr/bin/env python3
"""Advisory provenance gate lane.

The lane runs the pin check, the frozen fixture pack, and the deterministic
static check; any failure there is loud and blocks the lane. It then prints
the advisory summary derived from the same saved records: carrier verdicts
from the latest committed execution receipts (`not-run` when none exist),
uncovered atoms, and the README module table as a visible untracked copy.
Advisory findings never change the exit status.
"""

from __future__ import annotations

import argparse
import json
import pathlib
import subprocess
import sys

RECORD_MARKER = "-- chelis:provenance/v1 "


def parse_records(repo: pathlib.Path) -> list[dict[str, str]]:
    records: list[dict[str, str]] = []
    for root in ("src", "tests", "tests_neg"):
        base = repo / root
        if not base.exists():
            continue
        for path in sorted(base.rglob("*.ch")):
            lines = path.read_text().splitlines()
            index = 0
            while index < len(lines):
                line = lines[index]
                if line.startswith(RECORD_MARKER):
                    record = {"kind": line[len(RECORD_MARKER) :].strip()}
                    index += 1
                    while index < len(lines) and lines[index].startswith("-- "):
                        body = lines[index][3:]
                        if " = " in body:
                            key, value = body.split(" = ", 1)
                            record[key.strip()] = value.strip()
                        index += 1
                    records.append(record)
                else:
                    index += 1
    return records


def run_step(command: list[str]) -> None:
    result = subprocess.run(command, check=False)
    if result.returncode != 0:
        raise SystemExit(result.returncode)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", default=".", type=pathlib.Path)
    parser.add_argument("--command", default="nautilus-provenance")
    arguments = parser.parse_args()
    repo = arguments.repo.resolve()

    run_step([sys.executable, str(repo / "scripts" / "check_buoy_pin.py"), "--repo", str(repo)])
    run_step(
        [
            sys.executable,
            str(repo / "scripts" / "check_provenance_fixtures.py"),
            "--repo",
            str(repo),
            "--command",
            arguments.command,
        ]
    )

    static = subprocess.run(
        [
            arguments.command,
            "static",
            "--root",
            str(repo),
            "--config",
            str(repo / "provenance" / "chelis-adapter-config.toml"),
        ],
        capture_output=True,
        text=True,
        check=False,
    )
    if static.returncode != 0:
        print(static.stdout, file=sys.stderr)
        print(f"provenance-gate: static check failed with exit {static.returncode}", file=sys.stderr)
        raise SystemExit(static.returncode)
    report = json.loads(static.stdout)

    records = parse_records(repo)
    atoms = {record["id"] for record in records if record["kind"] == "authority"}
    carriers = [record for record in records if record["kind"] == "carrier"]
    covered = set()
    for carrier in carriers:
        for reference in carrier.get("atoms", "").split(";"):
            covered.add(reference.split("@", 1)[0])

    verdicts: dict[str, str] = {}
    receipts = repo / "provenance" / "receipts" / "latest-execution.json"
    oracle_verdicts: dict[str, str] = {}
    if receipts.is_file():
        payload = json.loads(receipts.read_text())
        oracle_verdicts = {oracle: verdict for oracle, verdict in payload.get("verdicts", [])}
    for carrier in carriers:
        verdicts[carrier["id"]] = oracle_verdicts.get(carrier.get("oracle-id", ""), "not-run")

    print("provenance-advisory: begin (advisory findings never block)")
    print(f"  static verdict: {report['verdict']} atoms={len(report['objects']['atoms'])}")
    for identifier in sorted(verdicts):
        print(f"  carrier {identifier}: verdict={verdicts[identifier]}")
    for atom in sorted(atoms - covered):
        print(f"  uncovered atom: {atom}")
    print("  untracked copy: README.md module table stays hand-maintained; the surface record is authoritative")
    print("provenance-advisory: end")


if __name__ == "__main__":
    main()
