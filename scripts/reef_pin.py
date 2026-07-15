#!/usr/bin/env python3
"""Resolve the exact Chelis compiler pin from ``reef.toml``.

The CLI emits GitHub Actions step outputs so toolchain installers can use
``reef.toml`` as their runtime source of truth without duplicating TOML parsing.
"""
from __future__ import annotations

import re
import sys
import tomllib
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parent.parent
EXACT_REEF_PIN_RE = re.compile(r"=(\d+\.\d+\.\d+)")


def read_exact_reef_pin(path: Path = REPO_ROOT / "reef.toml") -> str:
    """Return ``X.Y.Z`` from an exact ``package.compiler = "=X.Y.Z"`` pin."""
    try:
        with path.open("rb") as handle:
            compiler = tomllib.load(handle)["package"]["compiler"]
    except (OSError, KeyError, tomllib.TOMLDecodeError) as exc:
        raise ValueError(f"cannot read compiler pin from {path}: {exc}") from exc

    match = EXACT_REEF_PIN_RE.fullmatch(compiler) if isinstance(compiler, str) else None
    if match is None:
        raise ValueError(f"{path}: expected package.compiler = '=X.Y.Z', got {compiler!r}")
    return match.group(1)


def github_outputs(version: str) -> str:
    """Render the tag and bare version as GitHub Actions step outputs."""
    return f"chelis-tag=v{version}\nchelis-version={version}\n"


def main() -> int:
    try:
        version = read_exact_reef_pin()
    except ValueError as exc:
        print(f"reef pin error: {exc}", file=sys.stderr)
        return 1

    print(github_outputs(version), end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
