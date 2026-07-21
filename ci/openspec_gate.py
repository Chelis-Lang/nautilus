#!@python@
from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

PYTHON = "@python@"
GIT = "@git@"
OPENSPEC = "@openspec@"


def repository_root() -> Path:
    completed = subprocess.run(
        [GIT, "rev-parse", "--show-toplevel"],
        check=False,
        capture_output=True,
        text=True,
    )
    if completed.returncode != 0:
        diagnostic = completed.stderr.strip() or "not inside a Git worktree"
        raise RuntimeError(f"cannot locate Nautilus repository root: {diagnostic}")
    return Path(completed.stdout.strip()).resolve()


def gate_arguments(arguments: list[str]) -> list[str]:
    result = ["--self-test"]
    if "--merge-bound" not in arguments and "--pre-archive" not in arguments:
        result.append("--merge-bound")
    if "--base" not in arguments:
        result.extend(("--base", "origin/main"))
    result.extend(arguments)
    return result


def main() -> int:
    try:
        root = repository_root()
        checker = root / "scripts" / "check_openspec.py"
        if not checker.is_file():
            raise RuntimeError(f"missing Nautilus governance checker: {checker}")
        environment = os.environ.copy()
        environment["GIT_BIN"] = GIT
        environment["OPENSPEC_BIN"] = OPENSPEC
        os.execve(
            PYTHON,
            [PYTHON, str(checker), *gate_arguments(sys.argv[1:])],
            environment,
        )
    except (OSError, RuntimeError) as error:
        print(f"openspec-gate launcher: {error}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
