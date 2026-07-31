#!/usr/bin/env python3
"""Executable regressions for Nautilus's release-artifact contract."""

from __future__ import annotations

import ctypes
import io
import subprocess
import tarfile
import tempfile
import unittest
from pathlib import Path

from scripts import check_release_artifacts as artifacts


ROOT = Path(__file__).resolve().parents[1]


def raw_tar(extra: list[tarfile.TarInfo]) -> bytes:
    output = io.BytesIO()
    with tarfile.open(fileobj=output, mode="w") as bundle:
        for name, payload in (
            ("reef.toml", b'[package]\nname = "fixture"\nversion = "1.0.0"\n'),
            ("reef.lock", b"version = 1\n"),
        ):
            member = tarfile.TarInfo(name)
            member.size = len(payload)
            bundle.addfile(member, io.BytesIO(payload))
        for member in extra:
            payload = b"module Fixture\n" if member.isreg() else None
            if payload is not None:
                member.size = len(payload)
                bundle.addfile(member, io.BytesIO(payload))
            else:
                bundle.addfile(member)
    return output.getvalue()


def zstd_compress(raw: bytes) -> bytes:
    lib = artifacts._load_zstd()
    lib.ZSTD_compressBound.argtypes = [ctypes.c_size_t]
    lib.ZSTD_compressBound.restype = ctypes.c_size_t
    lib.ZSTD_compress.argtypes = [
        ctypes.c_void_p,
        ctypes.c_size_t,
        ctypes.c_void_p,
        ctypes.c_size_t,
        ctypes.c_int,
    ]
    lib.ZSTD_compress.restype = ctypes.c_size_t
    lib.ZSTD_isError.argtypes = [ctypes.c_size_t]
    lib.ZSTD_isError.restype = ctypes.c_uint

    source = ctypes.create_string_buffer(raw)
    capacity = lib.ZSTD_compressBound(len(raw))
    output = ctypes.create_string_buffer(capacity)
    written = lib.ZSTD_compress(
        ctypes.cast(output, ctypes.c_void_p),
        capacity,
        ctypes.cast(source, ctypes.c_void_p),
        len(raw),
        3,
    )
    if lib.ZSTD_isError(written):
        raise RuntimeError("test fixture zstd compression failed")
    return output.raw[:written]


class ReleaseArtifactContractTests(unittest.TestCase):
    def test_structured_tar_contract_accepts_regular_language_sources(self) -> None:
        core = tarfile.TarInfo("src/core.ch")
        stats = tarfile.TarInfo("src/stats.ch")
        self.assertEqual(
            artifacts.validate_tar_bytes(raw_tar([core, stats])),
            ["reef.toml", "reef.lock", "src/core.ch", "src/stats.ch"],
        )

    def test_structured_tar_contract_rejects_non_regular_source_members(self) -> None:
        cases = [
            ("symlink", tarfile.SYMTYPE, "/etc/passwd"),
            ("hardlink", tarfile.LNKTYPE, "reef.toml"),
            ("fifo", tarfile.FIFOTYPE, ""),
            ("character-device", tarfile.CHRTYPE, ""),
        ]
        for label, member_type, linkname in cases:
            with self.subTest(label=label):
                member = tarfile.TarInfo("src/core.ch")
                member.type = member_type
                member.linkname = linkname
                with self.assertRaisesRegex(RuntimeError, "non-regular member"):
                    artifacts.validate_tar_bytes(raw_tar([member]))

    def test_python312_compatible_zstd_path_rejects_symlink(self) -> None:
        member = tarfile.TarInfo("src/core.ch")
        member.type = tarfile.SYMTYPE
        member.linkname = "/etc/passwd"
        compressed = zstd_compress(raw_tar([member]))
        with tempfile.TemporaryDirectory(prefix="nautilus-zstd-test-") as raw_tmp:
            archive = Path(raw_tmp) / "fixture.tar.zst"
            archive.write_bytes(compressed)
            with self.assertRaisesRegex(RuntimeError, "non-regular member"):
                artifacts.archive_members(archive)

    def test_regular_native_traversal_and_duplicate_members_are_rejected(self) -> None:
        native = tarfile.TarInfo("lib/native.so")
        with self.assertRaisesRegex(RuntimeError, "native-code member"):
            artifacts.validate_tar_bytes(raw_tar([native]))

        traversal = tarfile.TarInfo("../escape.ch")
        with self.assertRaisesRegex(RuntimeError, "unsafe source-archive member"):
            artifacts.validate_tar_bytes(raw_tar([traversal]))

        first = tarfile.TarInfo("src/core.ch")
        second = tarfile.TarInfo("src/core.ch")
        with self.assertRaisesRegex(RuntimeError, "duplicate member"):
            artifacts.validate_tar_bytes(raw_tar([first, second]))

    def test_docs_account_for_actual_tracked_artifacts_and_ignore_current_outputs(
        self,
    ) -> None:
        release_docs = (ROOT / "docs" / "releases.md").read_text()
        tracked = subprocess.check_output(
            ["git", "ls-files", "--", "dist"], cwd=ROOT, text=True
        ).splitlines()
        tracked_packages = {
            path for path in tracked if path.endswith((".chb", ".tar.zst"))
        }
        self.assertEqual(
            tracked_packages,
            {
                "dist/nautilus-0.1.4.chb",
                "dist/nautilus-0.1.4.tar.zst",
            },
        )
        for path in tracked_packages:
            self.assertIn(path, release_docs)

        name, version = artifacts.package_identity(ROOT / "reef.toml")
        for suffix in ("chb", "tar.zst"):
            current = f"dist/{name}-{version}.{suffix}"
            self.assertNotIn(current, tracked)
            subprocess.run(
                ["git", "check-ignore", "--quiet", current],
                cwd=ROOT,
                check=True,
            )

    def test_release_workflow_enforces_matching_pair_validation_before_overwrite(
        self,
    ) -> None:
        release = (ROOT / ".github" / "workflows" / "release.yml").read_text()
        build = release.index("run: chelis reef build")
        validate = release.index("python3 scripts/check_release_artifacts.py")
        publish = release.index("uses: softprops/action-gh-release@v2")
        self.assertLess(build, validate)
        self.assertLess(validate, publish)
        self.assertIn("overwrite_files: true", release[publish:])

        docs = (ROOT / "docs" / "releases.md").read_text()
        self.assertIn("successful rerun", docs)
        self.assertIn("currently attached matching pair", docs)

        ci = (ROOT / ".github" / "workflows" / "ci.yml").read_text()
        self.assertGreaterEqual(
            ci.count("python3 scripts/check_release_artifacts.py"), 2
        )


if __name__ == "__main__":
    unittest.main()
