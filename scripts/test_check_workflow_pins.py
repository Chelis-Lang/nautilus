#!/usr/bin/env python3
"""Tests for the workflow pin guard."""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path
from unittest import mock

from scripts import check_workflow_pins as guard


VERSION = "1.2.3"  # A parser fixture, deliberately unrelated to the live pin.
WORKFLOW_SHA = "1" * 40
DIGEST = "sha256:" + "a" * 64


class WorkflowPinGuardTests(unittest.TestCase):
    def setUp(self) -> None:
        tmp = tempfile.TemporaryDirectory(prefix="workflow-pin-test-")
        self.addCleanup(tmp.cleanup)
        self.root = Path(tmp.name)
        self.workflows = self.root / "workflows"
        self.workflows.mkdir()

    def write(self, name: str, text: str) -> Path:
        path = self.workflows / name
        path.write_text(text, encoding="utf-8")
        return path

    def installing_workflow(
        self, *, tag: str | None = f"v{VERSION}", version: str | None = VERSION
    ) -> str:
        declarations = []
        if tag is not None:
            declarations.append(f"  CHELIS_TAG: {tag}")
        if version is not None:
            declarations.append(f"  CHELIS_VERSION: {version}")
        return "\n".join(
            [
                "name: fixture",
                "env:",
                *declarations,
                "jobs:",
                "  test:",
                "    steps:",
                "      - uses: ./.github/actions/install-chelis",
                "",
            ]
        )

    def direct_download_workflow(
        self, *, tag: str | None = f"v{VERSION}", version: str | None = VERSION
    ) -> str:
        return self.installing_workflow(tag=tag, version=version).replace(
            "      - uses: ./.github/actions/install-chelis",
            "      - run: gh release download --repo Chelis-Lang/chelis",
        )

    def central_wrapper(
        self,
        *,
        version: str = VERSION,
        profile: str = "nautilus-ci",
        revision: str = WORKFLOW_SHA,
        extra_job_key: str = "",
    ) -> str:
        lines = [
            "name: fixture",
            "on: workflow_dispatch",
            "permissions:",
            "  contents: read",
            "jobs:",
            "  call-central:",
            "    name: Call central profile",
            f"    uses: Chelis-Lang/ci/.github/workflows/consumer.yml@{revision}",
            *(f"    {extra_job_key}".splitlines() if extra_job_key else []),
            "    with:",
            f"      profile: {profile}",
        ]
        if profile in {"nautilus-ci", "coral-ci"}:
            lines.extend(
                [
                    f"      chelis-tag: v{version}",
                    f"      chelis-version: {version}",
                    f"      chelis-linux-sha256: {DIGEST}",
                    f"      chelis-darwin-sha256: {DIGEST}",
                ]
            )
        elif profile == "nautilus-nightly":
            lines.extend(
                [
                    f"      chelis-tag: v{version}",
                    f"      chelis-version: {version}",
                    f"      chelis-linux-sha256: {DIGEST}",
                ]
            )
        else:
            lines.append(f"      chelis-linux-sha256: {DIGEST}")
        lines.extend(
            [
                "    secrets:",
                "      CHELIS_RELEASE_TOKEN: ${{ secrets.CHELIS_RELEASE_TOKEN }}",
                "",
            ]
        )
        return "\n".join(lines)

    def errors(self) -> list[str]:
        with mock.patch.object(guard, "APPROVED_CENTRAL_WORKFLOW_SHA", WORKFLOW_SHA):
            return guard.check_workflow_pins(VERSION, self.workflows)

    def test_matching_quoted_pair_passes(self) -> None:
        self.write(
            "ci.yml",
            self.installing_workflow(
                tag=f"'v{VERSION}' # tag", version=f'"{VERSION}" # version'
            ),
        )
        self.assertEqual(self.errors(), [])

    def test_drift_and_missing_values_fail(self) -> None:
        cases = (
            ("CHELIS_TAG", "v1.2.2", VERSION),
            ("CHELIS_VERSION", f"v{VERSION}", "1.2.2"),
            ("CHELIS_TAG", None, VERSION),
            ("CHELIS_VERSION", f"v{VERSION}", None),
        )
        for key, tag, version in cases:
            with self.subTest(key=key, tag=tag, version=version):
                for path in self.workflows.iterdir():
                    path.unlink()
                self.write("ci.yml", self.installing_workflow(tag=tag, version=version))
                self.assertTrue(any(key in error for error in self.errors()))

    def test_discovers_yaml_and_rejects_conflicting_literals(self) -> None:
        text = self.installing_workflow() + "  CHELIS_VERSION: 1.2.2\n"
        self.write("future.yaml", text)
        errors = self.errors()
        self.assertTrue(any("future.yaml" in error for error in errors))
        self.assertTrue(any("CHELIS_VERSION" in error for error in errors))

    def test_direct_chelis_release_download_requires_matching_mirrors(self) -> None:
        self.write("release.yml", self.direct_download_workflow())
        self.assertEqual(self.errors(), [])

        self.write(
            "release.yml",
            self.direct_download_workflow(tag=None, version=None),
        )
        errors = self.errors()
        self.assertTrue(any("release.yml" in error for error in errors))
        self.assertTrue(any("CHELIS_TAG=missing" in error for error in errors))
        self.assertTrue(any("CHELIS_VERSION=missing" in error for error in errors))

    def test_immutable_central_wrappers_use_manifest_matching_input(self) -> None:
        self.write("ci.yml", self.central_wrapper())
        self.write("nightly.yml", self.central_wrapper(profile="nautilus-nightly"))
        self.write("release.yml", self.central_wrapper(profile="nautilus-release"))
        self.assertEqual(self.errors(), [])

        self.write("release.yml", self.central_wrapper(version="1.2.2"))
        self.assertTrue(any("chelis-version=1.2.2" in error for error in self.errors()))

        self.write(
            "release.yml",
            self.central_wrapper().replace(
                f"chelis-tag: v{VERSION}", "chelis-tag: v1.2.2"
            ),
        )
        self.assertTrue(any("chelis-tag=v1.2.2" in error for error in self.errors()))

    def test_central_wrapper_must_be_bound_and_non_skippable(self) -> None:
        cases = (
            self.central_wrapper(revision="main"),
            self.central_wrapper(revision="0" * 40),
            self.central_wrapper(revision="2" * 40),
            self.central_wrapper(profile="coral-ci"),
            self.central_wrapper(extra_job_key="if: false"),
            self.central_wrapper().replace(DIGEST, "sha256:wrong", 1),
            self.central_wrapper().replace(
                "${{ secrets.CHELIS_RELEASE_TOKEN }}", "${{ github.token }}"
            ),
        )
        for index, text in enumerate(cases):
            with self.subTest(index=index):
                for path in self.workflows.iterdir():
                    path.unlink()
                self.write("ci.yml", text)
                self.assertTrue(
                    any("malformed or unapproved" in error for error in self.errors())
                )

    def test_inert_central_or_installer_strings_do_not_pass(self) -> None:
        self.write(
            "ci.yml",
            "name: inert\njobs:\n  test:\n    runs-on: ubuntu-latest\n    steps:\n"
            f"      # uses: Chelis-Lang/ci/.github/workflows/consumer.yml@{WORKFLOW_SHA}\n"
            "      - run: |\n"
            "          echo 'uses: ./.github/actions/install-chelis'\n"
            "          echo 'gh release download --repo Chelis-Lang/chelis'\n",
        )
        errors = self.errors()
        self.assertTrue(any("malformed or unapproved" in error for error in errors))

        self.write(
            "ci.yml",
            "name: inert\nenv:\n"
            f"  CHELIS_TAG: v{VERSION}\n  CHELIS_VERSION: {VERSION}\n"
            "jobs:\n  test:\n    runs-on: ubuntu-latest\n    steps:\n"
            "      - run: |\n"
            "          uses: ./.github/actions/install-chelis\n",
        )
        self.assertTrue(
            any("no toolchain-installing workflow" in error for error in self.errors())
        )

        self.write(
            "ci.yml",
            "name: inert\nenv:\n"
            f"  CHELIS_TAG: v{VERSION}\n  CHELIS_VERSION: {VERSION}\n"
            "jobs:\n  test:\n    fake:\n"
            "      - uses: ./.github/actions/install-chelis\n"
            "      - run: chelisup install 1.2.3\n",
        )
        self.assertTrue(
            any("no toolchain-installing workflow" in error for error in self.errors())
        )

    def test_noninstalling_release_workflow_is_ignored(self) -> None:
        self.write("ci.yml", self.installing_workflow())
        self.write(
            "release.yml",
            "name: release\njobs:\n  build:\n    steps:\n"
            "      - run: echo CHELIS_VERSION=$(read-version reef.toml)\n",
        )
        self.assertEqual(self.errors(), [])

    def test_no_installing_workflow_fails_closed(self) -> None:
        self.write("release.yml", "name: release\n")
        self.assertTrue(
            any("no toolchain-installing workflow" in error for error in self.errors())
        )

    def test_reef_pin_must_be_exact(self) -> None:
        reef = self.root / "reef.toml"
        reef.write_text('[package]\ncompiler = "=1.2.3"\n', encoding="utf-8")
        self.assertEqual(guard.read_reef_pin(reef), VERSION)

        reef.write_text('[package]\ncompiler = "^1.2.3"\n', encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "expected package.compiler"):
            guard.read_reef_pin(reef)


if __name__ == "__main__":
    unittest.main()
