#!/usr/bin/env python3
"""Execute the registered gate oracle once and record the canonical receipts.

The oracle command mirrors the declared `NAUT-GATE-CHELIS-TEST` record: the
reef-pinned `chelis test` run over the committed positive corpus. The
canonical execution report is written to
`provenance/receipts/latest-execution.json`; the raw logs stay noncanonical
and are not retained. The static identity is an input and the check fails
if execution changed it.
"""

from __future__ import annotations

import argparse
import json
import os
import pathlib
import subprocess
import sys
import tempfile


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", default=".", type=pathlib.Path)
    parser.add_argument("--command", default="nautilus-provenance")
    arguments = parser.parse_args()
    repo = arguments.repo.resolve()
    config = repo / "provenance" / "chelis-adapter-config.toml"

    chelis_home = pathlib.Path(os.environ.get("CHELIS_HOME", pathlib.Path.home() / ".chelis"))
    chelis = chelis_home / "bin" / "chelis"
    if not chelis.is_file():
        print(f"corpus-execute: chelis shim absent at {chelis}", file=sys.stderr)
        raise SystemExit(1)

    static = subprocess.run(
        [arguments.command, "static", "--root", str(repo), "--config", str(config)],
        capture_output=True,
        text=True,
        check=False,
    )
    if static.returncode != 0:
        print("corpus-execute: static check must pass before execution", file=sys.stderr)
        raise SystemExit(static.returncode)

    oracle_toml = "\n".join(
        [
            "[[oracle]]",
            'id = "NAUT-GATE-CHELIS-TEST"',
            'program = "/bin/bash"',
            f'args = ["{repo / "scripts" / "provenance_oracle.sh"}"]',
            "timeout_ms = 1200000",
            "[oracle.environment]",
            f'HOME = "{pathlib.Path.home()}"',
            f'CHELIS_HOME = "{chelis_home}"',
            f'PATH = "{chelis_home / "bin"}:/usr/bin:/bin"',
        ]
    )
    with tempfile.NamedTemporaryFile("w", suffix=".toml", delete=False) as handle:
        handle.write(oracle_toml + "\n")
        oracles_path = handle.name

    execution = subprocess.run(
        [
            arguments.command,
            "execute",
            "--root",
            str(repo),
            "--config",
            str(config),
            "--oracles",
            oracles_path,
        ],
        capture_output=True,
        text=True,
        check=False,
    )
    os.unlink(oracles_path)
    if not execution.stdout.strip():
        print(f"corpus-execute: no canonical report (exit {execution.returncode})", file=sys.stderr)
        raise SystemExit(1)
    report = json.loads(execution.stdout)

    static_after = subprocess.run(
        [arguments.command, "static", "--root", str(repo), "--config", str(config)],
        capture_output=True,
        text=True,
        check=False,
    )
    if static_after.stdout != static.stdout:
        print("corpus-execute: execution mutated the static report bytes", file=sys.stderr)
        raise SystemExit(1)

    receipts = repo / "provenance" / "receipts" / "latest-execution.json"
    receipts.parent.mkdir(parents=True, exist_ok=True)
    receipts.write_text(execution.stdout.strip() + "\n")
    print(f"corpus-execute: exit={execution.returncode} verdicts={report['verdicts']}")
    raise SystemExit(0 if execution.returncode in (0, 4) else 1)


if __name__ == "__main__":
    main()
