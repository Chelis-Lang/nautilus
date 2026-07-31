#!/usr/bin/env python3
"""Validate the Reef artifact pair produced by ``chelis reef build``.

The compiler owns canonical CHB/archive validation. This shell gate adds
transport sealing, platform-content checks, installation, dependent
compilation, and unchanged-build byte comparison around that oracle.
"""

from __future__ import annotations

import argparse
import ctypes
import ctypes.util
import hashlib
import io
import json
import os
import re
import shutil
import subprocess
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
MAX_ARCHIVE_BYTES = 64 * 1024 * 1024
ZSTD_CONTENTSIZE_ERROR = (1 << 64) - 2
ZSTD_CONTENTSIZE_UNKNOWN = (1 << 64) - 1
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")


def package_identity(manifest: Path) -> tuple[str, str]:
    text = manifest.read_text()
    name = re.search(r'(?m)^name\s*=\s*"([^"]+)"', text)
    version = re.search(r'(?m)^version\s*=\s*"([^"]+)"', text)
    if not name or not version:
        raise RuntimeError(f"cannot read package name/version from {manifest}")
    return name.group(1), version.group(1)


def validate_member_names(names: list[str]) -> None:
    if len(names) != len(set(names)):
        raise RuntimeError("source archive contains duplicate member names")
    required = {"reef.toml", "reef.lock"}
    found = set(names)
    missing = required - found
    if missing:
        raise RuntimeError(
            f"source archive misses required member(s): {sorted(missing)}"
        )

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
            raise RuntimeError(
                f"native-code member in platform-neutral source archive: {raw}"
            )
        raise RuntimeError(f"unexpected source-archive member: {raw}")
    if source_count == 0:
        raise RuntimeError("source archive contains no src/*.ch modules")


def _load_zstd() -> ctypes.CDLL:
    candidates = [
        ctypes.util.find_library("zstd"),
        "libzstd.so.1",
        "libzstd.dylib",
        "/opt/homebrew/lib/libzstd.dylib",
        "/usr/local/lib/libzstd.dylib",
        "zstd.dll",
    ]
    failures: list[str] = []
    for candidate in candidates:
        if not candidate:
            continue
        try:
            return ctypes.CDLL(candidate)
        except OSError as error:
            failures.append(f"{candidate}: {error}")
    raise RuntimeError(
        "libzstd is required for structured archive validation; "
        "refusing the lossy filename-only tar fallback"
        + (f" ({'; '.join(failures)})" if failures else "")
    )


def decompress_zstd(compressed: bytes) -> bytes:
    lib = _load_zstd()
    lib.ZSTD_getFrameContentSize.argtypes = [ctypes.c_void_p, ctypes.c_size_t]
    lib.ZSTD_getFrameContentSize.restype = ctypes.c_ulonglong
    lib.ZSTD_findFrameCompressedSize.argtypes = [ctypes.c_void_p, ctypes.c_size_t]
    lib.ZSTD_findFrameCompressedSize.restype = ctypes.c_size_t
    lib.ZSTD_decompressBound.argtypes = [ctypes.c_void_p, ctypes.c_size_t]
    lib.ZSTD_decompressBound.restype = ctypes.c_ulonglong
    lib.ZSTD_decompress.argtypes = [
        ctypes.c_void_p,
        ctypes.c_size_t,
        ctypes.c_void_p,
        ctypes.c_size_t,
    ]
    lib.ZSTD_decompress.restype = ctypes.c_size_t
    lib.ZSTD_isError.argtypes = [ctypes.c_size_t]
    lib.ZSTD_isError.restype = ctypes.c_uint
    lib.ZSTD_getErrorName.argtypes = [ctypes.c_size_t]
    lib.ZSTD_getErrorName.restype = ctypes.c_char_p

    source = ctypes.create_string_buffer(compressed)
    source_ptr = ctypes.cast(source, ctypes.c_void_p)
    frame_size = lib.ZSTD_findFrameCompressedSize(source_ptr, len(compressed))
    if lib.ZSTD_isError(frame_size):
        detail = lib.ZSTD_getErrorName(frame_size).decode()
        raise RuntimeError(f"invalid zstd frame: {detail}")
    if frame_size != len(compressed):
        raise RuntimeError(
            "source archive must contain exactly one zstd frame with no trailing bytes"
        )

    content_size = lib.ZSTD_getFrameContentSize(source_ptr, len(compressed))
    if content_size == ZSTD_CONTENTSIZE_ERROR:
        raise RuntimeError("invalid zstd frame content size")
    if content_size == ZSTD_CONTENTSIZE_UNKNOWN:
        output_size = lib.ZSTD_decompressBound(source_ptr, len(compressed))
        if output_size == 0 or output_size > MAX_ARCHIVE_BYTES:
            raise RuntimeError(
                f"zstd frame has unsafe decompression bound {output_size}; "
                f"limit is {MAX_ARCHIVE_BYTES}"
            )
    else:
        output_size = content_size
    if output_size > MAX_ARCHIVE_BYTES:
        raise RuntimeError(
            f"source archive expands to {output_size} bytes; "
            f"limit is {MAX_ARCHIVE_BYTES}"
        )

    output = ctypes.create_string_buffer(output_size)
    written = lib.ZSTD_decompress(
        ctypes.cast(output, ctypes.c_void_p),
        output_size,
        source_ptr,
        len(compressed),
    )
    if lib.ZSTD_isError(written):
        detail = lib.ZSTD_getErrorName(written).decode()
        raise RuntimeError(f"zstd decompression failed: {detail}")
    if content_size != ZSTD_CONTENTSIZE_UNKNOWN and written != content_size:
        raise RuntimeError(
            f"zstd content-size mismatch: frame declared {content_size}, wrote {written}"
        )
    return output.raw[:written]


def validate_tar_bytes(raw_tar: bytes) -> list[str]:
    try:
        with tarfile.open(fileobj=io.BytesIO(raw_tar), mode="r:") as bundle:
            members = bundle.getmembers()
    except tarfile.TarError as error:
        raise RuntimeError(f"invalid source tar stream: {error}") from error
    non_files = [
        f"{member.name} ({member.type!r})" for member in members if not member.isfile()
    ]
    if non_files:
        raise RuntimeError(
            f"source archive contains non-regular member(s): {non_files}"
        )
    names = [member.name for member in members]
    validate_member_names(names)
    return names


def archive_members(archive: Path) -> list[str]:
    return validate_tar_bytes(decompress_zstd(archive.read_bytes()))


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for block in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def checksum_manifest_bytes(artifacts: tuple[Path, ...]) -> bytes:
    ordered = sorted(artifacts, key=lambda path: path.name)
    return "".join(
        f"{sha256_file(artifact)}  {artifact.name}\n" for artifact in ordered
    ).encode()


def write_checksum_manifest(checksums: Path, artifacts: tuple[Path, ...]) -> None:
    payload = checksum_manifest_bytes(artifacts)
    checksums.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(
        dir=checksums.parent, prefix=f".{checksums.name}.", delete=False
    ) as output:
        temporary = Path(output.name)
        output.write(payload)
        output.flush()
        os.fsync(output.fileno())
    try:
        temporary.replace(checksums)
    except BaseException:
        temporary.unlink(missing_ok=True)
        raise


def validate_checksum_manifest(checksums: Path, artifacts: tuple[Path, ...]) -> None:
    if not checksums.is_file():
        raise RuntimeError(f"missing checksum manifest: {checksums}")
    try:
        payload = checksums.read_bytes()
        text = payload.decode("ascii")
    except UnicodeDecodeError as error:
        raise RuntimeError("checksum manifest must be ASCII") from error

    expected_names = sorted(artifact.name for artifact in artifacts)
    lines = text.splitlines(keepends=True)
    if not lines or any(not line.endswith("\n") for line in lines):
        raise RuntimeError("checksum manifest must end every record with LF")
    records: dict[str, str] = {}
    for line in lines:
        match = re.fullmatch(r"([0-9a-f]{64})  ([^\r\n/]+)\n", line)
        if not match:
            raise RuntimeError(f"malformed checksum record: {line!r}")
        digest, filename = match.groups()
        if not SHA256_RE.fullmatch(digest):
            raise RuntimeError(f"invalid SHA-256 digest for {filename}")
        if filename in records:
            raise RuntimeError(f"duplicate checksum record for {filename}")
        records[filename] = digest

    if list(records) != expected_names:
        raise RuntimeError(
            "checksum manifest filenames/order disagree with release payloads: "
            f"expected {expected_names}, found {list(records)}"
        )
    for artifact in artifacts:
        actual = sha256_file(artifact)
        if records[artifact.name] != actual:
            raise RuntimeError(f"SHA-256 mismatch for {artifact.name}")
    if payload != checksum_manifest_bytes(artifacts):
        raise RuntimeError("checksum manifest is not in canonical form")


def resolve_chelis() -> str:
    configured = os.environ.get("CHELIS_BIN")
    if configured:
        return configured
    found = shutil.which("chelis")
    if found:
        return found
    raise RuntimeError("chelis not found; set CHELIS_BIN")


def verify_canonical_pair(chelis: str, archive: Path, shell: Path) -> dict[str, object]:
    result = subprocess.run(
        [
            chelis,
            "reef",
            "verify-artifact",
            "--archive",
            str(archive),
            "--shell",
            str(shell),
            "--json",
        ],
        capture_output=True,
        text=True,
    )
    if result.stderr:
        raise RuntimeError(
            f"chelis reef verify-artifact --json polluted stderr: {result.stderr!r}"
        )
    try:
        report = json.loads(result.stdout)
    except json.JSONDecodeError as error:
        raise RuntimeError(
            "chelis reef verify-artifact --json emitted invalid JSON: "
            f"{result.stdout!r}"
        ) from error
    if not isinstance(report, dict):
        raise RuntimeError("artifact verifier JSON must be an object")
    valid = report.get("valid")
    errors = report.get("errors")
    if (
        not isinstance(valid, bool)
        or not isinstance(errors, list)
        or any(not isinstance(error, str) for error in errors)
    ):
        raise RuntimeError(
            "artifact verifier JSON must contain boolean valid and string-list errors"
        )
    if valid != (not errors):
        raise RuntimeError("artifact verifier violated valid == errors.is_empty()")
    if (result.returncode == 0) != valid:
        raise RuntimeError(
            "artifact verifier exit status disagrees with its valid field"
        )
    return report


def require_valid_canonical_pair(chelis: str, archive: Path, shell: Path) -> None:
    report = verify_canonical_pair(chelis, archive, shell)
    if not report["valid"]:
        raise RuntimeError(
            "compiler rejected generated artifact pair: " + "; ".join(report["errors"])
        )


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
                f"artifact pair failed Reef validation:\n{result.stdout}{result.stderr}"
            )

        installed = reef_home / "packages" / name / version
        for source in (archive, shell):
            target = installed / source.name
            if not target.is_file() or source.read_bytes() != target.read_bytes():
                raise RuntimeError(
                    f"installed artifact is not byte-identical to {source}"
                )

        consumer = root / "consumer"
        consumer_src = consumer / "src"
        consumer_src.mkdir(parents=True)
        (consumer / "reef.toml").write_text(
            "[package]\n"
            'name = "nautilus-artifact-consumer"\n'
            'version = "0.0.0"\n'
            f'compiler = "={_compiler_pin(manifest)}"\n'
            'module_prefix = "ArtifactConsumer"\n'
            "\n"
            "[dependencies]\n"
            f'{name} = {{ version = "{version}" }}\n'
        )
        (consumer_src / "main.ch").write_text(
            "module ArtifactConsumer.Main\n"
            "import Nautilus.Special (erf)\n"
            "export (artifact_smoke)\n"
            "def artifact_smoke(x: f32) -> f32 = erf(x)\n"
        )
        result = subprocess.run(
            [chelis, "reef", "build"],
            cwd=consumer,
            env=env,
            capture_output=True,
            text=True,
        )
        if result.returncode != 0:
            raise RuntimeError(
                "installed artifact failed dependent package compilation:\n"
                f"{result.stdout}{result.stderr}"
            )


def _compiler_pin(manifest: Path) -> str:
    match = re.search(r'(?m)^compiler\s*=\s*"=?([^"]+)"', manifest.read_text())
    if not match:
        raise RuntimeError(f"cannot read compiler pin from {manifest}")
    return match.group(1)


def require_tampered_archive_rejection(chelis: str, archive: Path, shell: Path) -> None:
    with tempfile.TemporaryDirectory(prefix="nautilus-artifact-tamper-") as raw_tmp:
        tampered = Path(raw_tmp) / archive.name
        payload = bytearray(archive.read_bytes())
        payload[-1] ^= 1
        tampered.write_bytes(payload)
        report = verify_canonical_pair(chelis, tampered, shell)
        if report["valid"]:
            raise RuntimeError(
                "compiler accepted an archive with a mismatched shell hash"
            )
        if not any("archive" in error.lower() for error in report["errors"]):
            raise RuntimeError(
                "tampered archive failed for the wrong reason: "
                + "; ".join(report["errors"])
            )


def require_trailing_shell_rejection(chelis: str, archive: Path, shell: Path) -> None:
    with tempfile.TemporaryDirectory(
        prefix="nautilus-artifact-trailing-shell-"
    ) as raw_tmp:
        tampered = Path(raw_tmp) / shell.name
        tampered.write_bytes(shell.read_bytes() + b"\x00")
        report = verify_canonical_pair(chelis, archive, tampered)
        if report["valid"]:
            raise RuntimeError("compiler accepted a CHB with a trailing byte")
        if not any("trailing" in error.lower() for error in report["errors"]):
            raise RuntimeError(
                "CHB trailing-byte mutation failed for the wrong reason: "
                + "; ".join(report["errors"])
            )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="validate and seal Nautilus release artifacts"
    )
    parser.add_argument(
        "--write-checksums",
        action="store_true",
        help="atomically seal the validated payload pair with a SHA-256 manifest",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    manifest = REPO_ROOT / "reef.toml"
    name, version = package_identity(manifest)
    archive = REPO_ROOT / "dist" / f"{name}-{version}.tar.zst"
    shell = REPO_ROOT / "dist" / f"{name}-{version}.chb"
    artifacts = (archive, shell)
    checksums = REPO_ROOT / "dist" / f"{name}-{version}.sha256"
    for artifact in artifacts:
        if not artifact.is_file() or artifact.stat().st_size == 0:
            raise RuntimeError(f"missing or empty release artifact: {artifact}")
    if not args.write_checksums:
        validate_checksum_manifest(checksums, artifacts)

    names = archive_members(archive)
    chelis = resolve_chelis()
    require_valid_canonical_pair(chelis, archive, shell)
    validate_pair_with_chelis(chelis, manifest, archive, shell, name, version)
    require_tampered_archive_rejection(chelis, archive, shell)
    require_trailing_shell_rejection(chelis, archive, shell)
    if args.write_checksums:
        write_checksum_manifest(checksums, artifacts)
        validate_checksum_manifest(checksums, artifacts)
    print(
        f"release artifacts OK: {archive.name} + {shell.name} + {checksums.name}; "
        f"{len(names) - 2} source modules; canonical compiler verification + "
        "SHA-256 seal + Reef install + dependent compile + archive mismatch + "
        "CHB trailing-byte rejection passed"
    )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, RuntimeError, subprocess.CalledProcessError) as error:
        raise SystemExit(f"release artifact check failed: {error}") from error
