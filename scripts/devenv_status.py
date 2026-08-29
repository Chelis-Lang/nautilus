#!/usr/bin/env python3
"""Report and check the reef-pinned Chelis toolchain for this repository.

Shell entry runs this without `--check` to print status; it never installs
or downloads anything. The gate runs `--check`, which fails loudly when the
chelisup shims are absent or the resolved compiler does not satisfy the
exact pin in `reef.toml`.
"""

from __future__ import annotations

import argparse
import os
import pathlib
import re
import subprocess
import sys
import tomllib


def resolve_pin(repo: pathlib.Path) -> str:
    reef = tomllib.loads((repo / "reef.toml").read_text())
    compiler = reef.get("package", {}).get("compiler", "")
    match = re.fullmatch(r"=([0-9]+\.[0-9]+\.[0-9]+)", compiler)
    if not match:
        print(f"devenv-status: reef.toml compiler pin must be exact, got {compiler!r}", file=sys.stderr)
        raise SystemExit(1)
    return match.group(1)


def shim_path() -> pathlib.Path:
    home = pathlib.Path(os.environ.get("CHELIS_HOME", pathlib.Path.home() / ".chelis"))
    return home / "bin" / "chelis"


def resolved_version(repo: pathlib.Path, shim: pathlib.Path) -> str | None:
    try:
        result = subprocess.run(
            [str(shim), "--version"],
            cwd=repo,
            capture_output=True,
            text=True,
            timeout=60,
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired):
        return None
    if result.returncode != 0:
        return None
    match = re.search(r"chelis ([0-9]+\.[0-9]+\.[0-9]+)", result.stdout)
    return match.group(1) if match else None


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", default=".", type=pathlib.Path)
    parser.add_argument("--check", action="store_true")
    arguments = parser.parse_args()
    repo = arguments.repo.resolve()
    pin = resolve_pin(repo)
    shim = shim_path()

    if not shim.is_file():
        message = f"devenv-status: chelisup shim absent at {shim}; run chelisup to install it"
        if arguments.check:
            print(message, file=sys.stderr)
            raise SystemExit(1)
        print(message)
        return

    version = resolved_version(repo, shim)
    if version != pin:
        message = (
            f"devenv-status: reef pin ={pin} does not resolve"
            f" (shim reported {version!r}); run: chelisup install {pin}"
        )
        if arguments.check:
            print(message, file=sys.stderr)
            raise SystemExit(1)
        print(message)
        return

    print(f"devenv-status: chelis {version} resolves the reef pin ={pin}")


if __name__ == "__main__":
    main()
