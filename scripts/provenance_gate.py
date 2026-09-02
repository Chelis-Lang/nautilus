#!/usr/bin/env python3
"""Run the advisory provenance gate lane.

The lane runs the pin check, fixture pack, static check, and rebind dry run.
The dry run must report an empty plan.
The lane also traces each compact relation through its bound atom.
A deterministic failure blocks the lane.

The final summary uses the saved records and latest execution receipts.
It reports carrier verdicts, uncovered atoms, and the untracked README module table.
Advisory findings never change the exit status.
"""

from __future__ import annotations

import argparse
import json
import pathlib
import subprocess
import sys

RECORD_MARKER = "-- chelis:provenance/v1 "
COMPACT_TRACES = (
    ("NAUT-MOD-LINALG", "NAUT-LINK-LINALG-MATMUL"),
    ("NAUT-MOD-SIGNAL", "NAUT-LINK-SIGNAL-STUBS"),
    ("NAUT-MOD-STATS", "NAUT-LINK-STATS-HELPERS"),
)


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
    receipts_dir = repo / "provenance" / "receipts"
    receipts = receipts_dir / "latest-execution.json"
    receipt_static = receipts_dir / "latest-static-report.json"
    if receipts.is_file() and not receipt_static.is_file():
        print("provenance-gate: receipt static report is absent; run the corpus again", file=sys.stderr)
        raise SystemExit(2)
    if receipt_static.is_file() and receipt_static.read_text() != static.stdout:
        print("provenance-gate: execution receipt binds a stale static report", file=sys.stderr)
        print("provenance-gate: run the corpus again and review both receipt files", file=sys.stderr)
        raise SystemExit(2)

    config = str(repo / "provenance" / "chelis-adapter-config.toml")
    rebind = subprocess.run(
        [arguments.command, "rebind", "--root", str(repo), "--config", config],
        capture_output=True,
        text=True,
        check=False,
    )
    if rebind.returncode != 0:
        print(rebind.stderr, file=sys.stderr)
        print(f"provenance-gate: rebind dry run failed with exit {rebind.returncode}", file=sys.stderr)
        raise SystemExit(rebind.returncode)
    plan = json.loads(rebind.stdout)
    if plan["entries"]:
        for entry in plan["entries"]:
            print(
                f"provenance-gate: stale binding {entry['path']} {entry['record']} "
                f"{entry['field']} bound={entry['bound']} current={entry['current']}",
                file=sys.stderr,
            )
        print(
            "provenance-gate: run `nautilus-provenance rebind --write`, review the diff, "
            "re-execute the corpus, and commit",
            file=sys.stderr,
        )
        raise SystemExit(2)

    for atom_id, binding_id in COMPACT_TRACES:
        trace = subprocess.run(
            [
                arguments.command,
                "trace",
                "--root",
                str(repo),
                "--config",
                config,
                "--id",
                atom_id,
            ],
            capture_output=True,
            text=True,
            check=False,
        )
        if trace.returncode != 0:
            print(trace.stdout, file=sys.stderr)
            print(
                f"provenance-gate: trace failed for {atom_id} with exit {trace.returncode}",
                file=sys.stderr,
            )
            raise SystemExit(trace.returncode)
        projection = json.loads(trace.stdout)
        binding = next(
            (entry for entry in projection["bindings"] if entry["id"] == binding_id),
            None,
        )
        if binding is None or not binding["verified"]:
            print(f"provenance-gate: compact binding absent or unverified: {binding_id}", file=sys.stderr)
            raise SystemExit(2)
        if any(not hop["matches"] for hop in binding["hops"]):
            print(f"provenance-gate: compact binding trace mismatch: {binding_id}", file=sys.stderr)
            raise SystemExit(2)

    records = parse_records(repo)
    atoms = {record["id"] for record in records if record["kind"] == "authority"}
    carriers = [record for record in records if record["kind"] == "carrier"]
    covered = set()
    for carrier in carriers:
        for reference in carrier.get("atoms", "").split(";"):
            covered.add(reference.split("@", 1)[0])

    verdicts: dict[str, str] = {}
    oracle_verdicts: dict[str, str] = {}
    if receipts.is_file():
        payload = json.loads(receipts.read_text())
        oracle_verdicts = {oracle: verdict for oracle, verdict in payload.get("verdicts", [])}
    for carrier in carriers:
        verdicts[carrier["id"]] = oracle_verdicts.get(carrier.get("oracle-id", ""), "not-run")

    print("provenance-advisory: begin (advisory findings never block)")
    print(f"  static verdict: {report['verdict']} atoms={len(report['objects']['atoms'])}")
    traced = ", ".join(binding for _, binding in COMPACT_TRACES)
    print(f"  rebind plan: empty; compact traces accept: {traced}")
    for identifier in sorted(verdicts):
        print(f"  carrier {identifier}: verdict={verdicts[identifier]}")
    for atom in sorted(atoms - covered):
        print(f"  uncovered atom: {atom}")
    print("  untracked copy: README.md module table stays hand-maintained; the surface record is authoritative")
    print("provenance-advisory: end")


if __name__ == "__main__":
    main()
