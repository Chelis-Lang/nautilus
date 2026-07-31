#!/usr/bin/env python3
"""Validate the Reef artifact pair produced by ``chelis reef build``.

This is an integrity and platform-content gate, not a reproducible-build claim.
Chelis#970 tracks byte instability between otherwise identical builds.
"""

from __future__ import annotations

import os
import re
import shutil
import subprocess
import sys
import tarfile
import tempfile
from pathlib import Path, PurePosixPath


REPO_ROOT = Path(__file__).resolve().parents[1]
NATIVE_SUFFIXES = {
    ".a",
    ".dylib",
    ".dll",
    ".exe",
    ".lib",
    ".macho",
    ".o",
    ".obj",
    ".so",
}


def package_identity(manifest: Path) -> tuple[str, str]:
    text = manifest.read_text()
    name = re.search(r'(?m)^name\s*=\s*"([^"]+)"', text)
    version = re.search(r'(?m)^version\s*=\s*"([^"]+)"', text)
    if not name or not version:
        raise RuntimeError(f"cannot read package name/version from {manifest}")
    return name.group(1), version.group(1)


def validate_member_names(names: list[str]) -> None:
    required = {"reef.toml", "reef.lock"}
    found = set(names)
    missing = required - found
    if missing:
        raise RuntimeError(f"source archive misses required member(s): {sorted(missing)}")

    source_count = 0
    for raw in names:
        path = PurePosixPath(raw)
        if path.is_absolute() or ".." in path.parts:
            raise RuntimeError(f"unsafe source-archive member: {raw}")
        if raw in required:
            continue
        if len(path.parts) == 2 and path.parts[0] == "src" and path.suffix == ".ch":
            source_count += 1
            continue
        if path.suffix.lower() in NATIVE_SUFFIXES:
            raise RuntimeError(f"native-code member in platform-neutral source archive: {raw}")
        raise RuntimeError(f"unexpected source-archive member: {raw}")
    if source_count == 0:
        raise RuntimeError("source archive contains no src/*.ch modules")


def archive_members(archive: Path) -> list[str]:
    try:
        with tarfile.open(archive, "r:*") as bundle:
            members = bundle.getmembers()
            non_files = [member.name for member in members if not member.isfile()]
            if non_files:
                raise RuntimeError(
                    f"source archive contains non-regular member(s): {non_files}"
                )
            return [member.name for member in members]
    except tarfile.ReadError:
        # Python before 3.14 cannot decode zstd tarballs itself. GNU tar uses
        # --zstd; macOS bsdtar auto-detects the compression.
        failures: list[str] = []
        for command in (
            ["tar", "--zstd", "-tf", archive],
            ["tar", "-tf", archive],
        ):
            result = subprocess.run(command, capture_output=True, text=True)
            if result.returncode == 0:
                return [line for line in result.stdout.splitlines() if line]
            failures.append(result.stderr.strip())
        raise RuntimeError(
            "cannot inventory zstd source archive with Python or system tar: "
            + " | ".join(failures)
        )


def resolve_chelis() -> str:
    configured = os.environ.get("CHELIS_BIN")
    if configured:
        return configured
    found = shutil.which("chelis")
    if found:
        return found
    raise RuntimeError("chelis not found; set CHELIS_BIN")


def validate_pair_with_chelis(
    chelis: str, manifest: Path, archive: Path, shell: Path, name: str, version: str
) -> None:
    with tempfile.TemporaryDirectory(prefix="nautilus-artifact-check-") as raw_tmp:
        root = Path(raw_tmp)
        package = root / "input" / "packages" / name
        dist = package / "dist"
        dist.mkdir(parents=True)
        shutil.copy2(manifest, package / "reef.toml")
        shutil.copy2(archive, dist / archive.name)
        shutil.copy2(shell, dist / shell.name)

        env = os.environ.copy()
        reef_home = root / "reef-home"
        env["CHELIS_REEF_HOME"] = str(reef_home)
        result = subprocess.run(
            [
                chelis,
                "reef",
                "install",
                "--from-monorepo",
                str(root / "input"),
                f"{name}={version}",
            ],
            env=env,
            capture_output=True,
            text=True,
        )
        if result.returncode != 0:
            raise RuntimeError(
                "artifact pair failed Reef validation:\n"
                f"{result.stdout}{result.stderr}"
            )

        installed = reef_home / "packages" / name / version
        for source in (archive, shell):
            target = installed / source.name
            if not target.is_file() or source.read_bytes() != target.read_bytes():
                raise RuntimeError(f"installed artifact is not byte-identical to {source}")


def main() -> int:
    manifest = REPO_ROOT / "reef.toml"
    name, version = package_identity(manifest)
    archive = REPO_ROOT / "dist" / f"{name}-{version}.tar.zst"
    shell = REPO_ROOT / "dist" / f"{name}-{version}.chb"
    for artifact in (archive, shell):
        if not artifact.is_file() or artifact.stat().st_size == 0:
            raise RuntimeError(f"missing or empty release artifact: {artifact}")

    names = archive_members(archive)
    validate_member_names(names)
    validate_pair_with_chelis(
        resolve_chelis(), manifest, archive, shell, name, version
    )
    print(
        f"release artifacts OK: {archive.name} + {shell.name}; "
        f"{len(names) - 2} source modules; Reef pair validation passed"
    )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, RuntimeError, subprocess.CalledProcessError) as error:
        raise SystemExit(f"release artifact check failed: {error}") from error
