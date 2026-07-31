#!/usr/bin/env python3
"""Executable regressions for Nautilus's release-artifact contract."""

from __future__ import annotations

import ctypes
import io
import json
import subprocess
import tarfile
import tempfile
import unittest
from pathlib import Path
from unittest import mock

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
    def test_compiler_verifier_is_the_canonical_pair_oracle(self) -> None:
        success = subprocess.CompletedProcess(
            args=[],
            returncode=0,
            stdout=json.dumps(
                {
                    "valid": True,
                    "package": {"name": "nautilus", "version": "1.0.0"},
                    "compiler": "0.17.4",
                    "shell_sha256": "a" * 64,
                    "archive_sha256": "b" * 64,
                    "errors": [],
                }
            ),
            stderr="",
        )
        with mock.patch.object(
            artifacts.subprocess, "run", return_value=success
        ) as run:
            report = artifacts.verify_canonical_pair(
                "/candidate/chelis",
                Path("/tmp/nautilus.tar.zst"),
                Path("/tmp/nautilus.chb"),
            )

        self.assertTrue(report["valid"])
        run.assert_called_once_with(
            [
                "/candidate/chelis",
                "reef",
                "verify-artifact",
                "--archive",
                "/tmp/nautilus.tar.zst",
                "--shell",
                "/tmp/nautilus.chb",
                "--json",
            ],
            capture_output=True,
            text=True,
        )

    def test_compiler_verifier_rejects_invalid_machine_contracts(self) -> None:
        cases = (
            (
                "zero exit with errors",
                subprocess.CompletedProcess(
                    args=[],
                    returncode=0,
                    stdout='{"valid":true,"errors":["bad"]}',
                    stderr="",
                ),
            ),
            (
                "nonzero exit with valid report",
                subprocess.CompletedProcess(
                    args=[],
                    returncode=1,
                    stdout='{"valid":true,"errors":[]}',
                    stderr="",
                ),
            ),
            (
                "stderr pollution",
                subprocess.CompletedProcess(
                    args=[],
                    returncode=1,
                    stdout='{"valid":false,"errors":["trailing bytes"]}',
                    stderr="warning",
                ),
            ),
        )
        for label, result in cases:
            with self.subTest(label=label):
                with mock.patch.object(
                    artifacts.subprocess, "run", return_value=result
                ):
                    with self.assertRaises(RuntimeError):
                        artifacts.verify_canonical_pair(
                            "/candidate/chelis",
                            Path("/tmp/nautilus.tar.zst"),
                            Path("/tmp/nautilus.chb"),
                        )

    def test_release_gate_requires_compiler_rejection_of_chb_trailing_bytes(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory(
            prefix="nautilus-canonical-shell-test-"
        ) as raw_tmp:
            root = Path(raw_tmp)
            archive = root / "nautilus-1.0.0.tar.zst"
            shell = root / "nautilus-1.0.0.chb"
            archive.write_bytes(b"archive")
            shell.write_bytes(b"canonical shell")

            def fake_verify(
                *args: object, **kwargs: object
            ) -> subprocess.CompletedProcess[str]:
                command = args[0]
                candidate = Path(command[command.index("--shell") + 1])
                self.assertTrue(candidate.read_bytes().endswith(b"\x00"))
                return subprocess.CompletedProcess(
                    args=command,
                    returncode=1,
                    stdout='{"valid":false,"errors":["CHB contains trailing bytes"]}',
                    stderr="",
                )

            with mock.patch.object(
                artifacts.subprocess, "run", side_effect=fake_verify
            ):
                artifacts.require_trailing_shell_rejection(
                    "/candidate/chelis", archive, shell
                )
            self.assertEqual(shell.read_bytes(), b"canonical shell")

    def test_checksum_seal_rejects_shell_byte_flip_and_appended_junk(self) -> None:
        for label, mutate in (
            ("byte flip", lambda payload: bytes([payload[0] ^ 1]) + payload[1:]),
            ("appended junk", lambda payload: payload + b"junk"),
        ):
            with self.subTest(label=label):
                with tempfile.TemporaryDirectory(
                    prefix="nautilus-checksum-test-"
                ) as raw_tmp:
                    root = Path(raw_tmp)
                    archive = root / "nautilus-1.0.0.tar.zst"
                    shell = root / "nautilus-1.0.0.chb"
                    checksums = root / "nautilus-1.0.0.sha256"
                    archive.write_bytes(b"archive payload")
                    shell.write_bytes(b"shell payload")
                    payloads = (archive, shell)
                    artifacts.write_checksum_manifest(checksums, payloads)
                    artifacts.validate_checksum_manifest(checksums, payloads)

                    shell.write_bytes(mutate(shell.read_bytes()))
                    with self.assertRaisesRegex(
                        RuntimeError, "SHA-256 mismatch.*\\.chb"
                    ):
                        artifacts.validate_checksum_manifest(checksums, payloads)

    def test_resealing_replacement_marks_release_authority_boundary(self) -> None:
        with tempfile.TemporaryDirectory(
            prefix="nautilus-checksum-boundary-"
        ) as raw_tmp:
            root = Path(raw_tmp)
            archive = root / "nautilus-1.0.0.tar.zst"
            shell = root / "nautilus-1.0.0.chb"
            checksums = root / "nautilus-1.0.0.sha256"
            archive.write_bytes(b"archive payload")
            shell.write_bytes(b"original shell payload")
            payloads = (archive, shell)
            artifacts.write_checksum_manifest(checksums, payloads)

            shell.write_bytes(b"replacement shell payload")
            artifacts.write_checksum_manifest(checksums, payloads)
            artifacts.validate_checksum_manifest(checksums, payloads)

    def test_checksum_manifest_rejects_noncanonical_or_extra_records(self) -> None:
        with tempfile.TemporaryDirectory(prefix="nautilus-checksum-shape-") as raw_tmp:
            root = Path(raw_tmp)
            archive = root / "nautilus-1.0.0.tar.zst"
            shell = root / "nautilus-1.0.0.chb"
            checksums = root / "nautilus-1.0.0.sha256"
            archive.write_bytes(b"archive payload")
            shell.write_bytes(b"shell payload")
            payloads = (archive, shell)
            artifacts.write_checksum_manifest(checksums, payloads)
            checksums.write_text(
                checksums.read_text() + f"{'0' * 64}  unexpected-payload\n"
            )
            with self.assertRaisesRegex(RuntimeError, "filenames/order"):
                artifacts.validate_checksum_manifest(checksums, payloads)

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

    def test_release_workflow_seals_and_validates_payloads_before_overwrite(
        self,
    ) -> None:
        release = (ROOT / ".github" / "workflows" / "release.yml").read_text()
        build = release.index("run: chelis reef build")
        seal = release.index(
            "python3 scripts/check_release_artifacts.py --write-checksums"
        )
        rebuild = release.index("chelis reef build", seal)
        validate = release.index("python3 scripts/check_release_artifacts.py", seal + 1)
        publish = release.index("uses: softprops/action-gh-release@v2")
        self.assertLess(build, seal)
        self.assertLess(seal, rebuild)
        self.assertLess(rebuild, validate)
        self.assertLess(validate, publish)
        self.assertIn(
            "dist/${{ env.PACKAGE_NAME }}-${{ env.PACKAGE_VERSION }}.sha256",
            release[publish:],
        )
        self.assertIn("overwrite_files: true", release[publish:])

        docs = (ROOT / "docs" / "releases.md").read_text()
        self.assertIn("rerun performs the same deterministic rebuild", docs)
        self.assertIn("seals both payloads", docs)
        self.assertIn("byte-identical", docs)
        self.assertIn("release authority", docs)

        ci = (ROOT / ".github" / "workflows" / "ci.yml").read_text()
        self.assertGreaterEqual(
            ci.count("python3 scripts/check_release_artifacts.py --write-checksums"),
            2,
        )
        self.assertGreaterEqual(
            ci.count("python3 scripts/check_release_artifacts.py\n"), 2
        )
        self.assertGreaterEqual(
            ci.count(
                "python3 scripts/check_release_artifacts.py --write-checksums\n"
                "          chelis reef build\n"
                "          python3 scripts/check_release_artifacts.py"
            ),
            2,
        )


if __name__ == "__main__":
    unittest.main()
