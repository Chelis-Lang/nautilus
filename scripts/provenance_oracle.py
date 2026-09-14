#!/usr/bin/env python3
"""Normalize the declared native test selection into the provenance protocol."""
import os
from pathlib import Path
import subprocess
import sys


def main():
    home = Path(os.environ.get("CHELIS_HOME", Path.home() / ".chelis"))
    try:
        status = subprocess.run(
            [str(home / "bin/chelis"), "test", "tests/", "--timeout", "600", "--jobs", "auto"],
            stdout=sys.stderr,
            stderr=sys.stderr,
            check=False,
        ).returncode
    except OSError as error:
        print(error, file=sys.stderr)
        status = 127
    print("spec-provenance-result/v1\t" + ("pass" if status == 0 else "fail"))


if __name__ == "__main__":
    main()
