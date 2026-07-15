#!/usr/bin/env python3
"""Install chelis-std into the local Reef registry from the Chelis monorepo.

Why this exists: chelis-std is not shipped as a release artifact of
Chelis-Lang/chelis (only the toolchain tarball is). The prebuilt
`chelis-std-0.1.0.{chb,tar.zst}` ships inside the chelis monorepo at
every release tag under `packages/chelis-std/dist/`. This script clones
that tag and hands it to `chelis reef install --from-monorepo`, which
(as of chelis v0.3.0) is the sanctioned way to populate the local
registry without source-rebuilding chelis-std.

Pre-v0.3.0 history: this script used to hand-roll the install by
copying files into ~/.chelis/reef/packages/<name>/<version>/ and
writing the index.json by hand, because chelis v0.2.x had no
`reef install` subcommand. v0.3.0 shipped the proper command — see
`chelis reef install --help` and `docs/UPSTREAM_BUGS.md`
("v0.2.4 chelis-std bootstrap" — now resolved).

Usage:
    GH_TOKEN=...  python3 scripts/install_chelis_std.py
    GH_TOKEN=...  CHELIS_TAG=v0.16.1  python3 scripts/install_chelis_std.py

Env:
    GH_TOKEN    PAT with `contents: read` on Chelis-Lang/chelis. Read
                by `gh repo clone`; this script does not read it
                directly.
    CHELIS_TAG  Optional explicit tag of the Chelis monorepo to fetch.
                When absent, resolves the exact compiler pin from reef.toml.
    CHELIS_BIN  Chelis binary to use for `reef install`. Defaults to the
                pin-resolving `chelis` shim on PATH.
    WORK_DIR    Scratch directory for the monorepo clone (defaults to
                /tmp/chelis-monorepo-for-std).
"""
from __future__ import annotations

import os
import re
import shutil
import subprocess
import sys
import tomllib
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_CHELIS_BIN = "chelis"
DEFAULT_WORK_DIR = "/tmp/chelis-monorepo-for-std"
EXACT_PIN_RE = re.compile(r"=(\d+\.\d+\.\d+)")


def reef_chelis_tag(reef_path: Path = REPO_ROOT / "reef.toml") -> str:
    try:
        with reef_path.open("rb") as handle:
            compiler = tomllib.load(handle)["package"]["compiler"]
    except (OSError, KeyError, tomllib.TOMLDecodeError) as exc:
        raise RuntimeError(f"cannot resolve Chelis pin from {reef_path}: {exc}") from exc
    if not isinstance(compiler, str):
        raise RuntimeError(
            f"cannot resolve Chelis pin from {reef_path}: package.compiler is not a string"
        )
    match = EXACT_PIN_RE.fullmatch(compiler)
    if match is None:
        raise RuntimeError(
            f"cannot resolve exact Chelis pin from {reef_path}: expected '=X.Y.Z', got {compiler!r}"
        )
    return f"v{match.group(1)}"


def selected_chelis_tag(reef_path: Path = REPO_ROOT / "reef.toml") -> str:
    return os.environ.get("CHELIS_TAG") or reef_chelis_tag(reef_path)


def main() -> int:
    chelis_tag = selected_chelis_tag()
    chelis_bin = os.environ.get("CHELIS_BIN", DEFAULT_CHELIS_BIN)
    work_dir = Path(os.environ.get("WORK_DIR", DEFAULT_WORK_DIR))

    print(
        f"[chelis-std-install] cloning Chelis-Lang/chelis at {chelis_tag} "
        f"into {work_dir}"
    )
    if work_dir.exists():
        shutil.rmtree(work_dir)
    subprocess.run(
        [
            "gh",
            "repo",
            "clone",
            "Chelis-Lang/chelis",
            str(work_dir),
            "--",
            "--depth",
            "1",
            "--branch",
            chelis_tag,
            "--quiet",
        ],
        check=True,
    )

    print("[chelis-std-install] running chelis reef install --from-monorepo")
    subprocess.run(
        [chelis_bin, "reef", "install", "--from-monorepo", str(work_dir), "chelis-std"],
        check=True,
    )

    print("[chelis-std-install] done")
    return 0


if __name__ == "__main__":
    sys.exit(main())
