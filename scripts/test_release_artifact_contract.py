#!/usr/bin/env python3
"""Regression tests for Nautilus's release-artifact honesty boundary."""

from __future__ import annotations

import unittest
from pathlib import Path

from scripts import check_release_artifacts as artifacts


ROOT = Path(__file__).resolve().parents[1]


class ReleaseArtifactContractTests(unittest.TestCase):
    def test_source_archive_member_contract_accepts_language_sources(self) -> None:
        artifacts.validate_member_names(
            ["reef.toml", "reef.lock", "src/core.ch", "src/stats.ch"]
        )

    def test_source_archive_member_contract_rejects_native_code(self) -> None:
        with self.assertRaisesRegex(RuntimeError, "native-code member"):
            artifacts.validate_member_names(
                ["reef.toml", "reef.lock", "src/core.ch", "lib/native.so"]
            )

    def test_docs_match_tag_built_untracked_artifact_policy(self) -> None:
        release_docs = (ROOT / "docs" / "releases.md").read_text()
        gitignore = (ROOT / ".gitignore").read_text()
        self.assertNotIn("committed under `dist/`", release_docs)
        self.assertNotIn("Identical bytes regardless of build host", release_docs)
        self.assertIn("chelis#970", release_docs)
        self.assertIn("dist/*", gitignore)
        self.assertIn("!dist/stability.json", gitignore)

    def test_ci_and_release_validate_the_built_pair(self) -> None:
        for workflow in (
            ROOT / ".github" / "workflows" / "ci.yml",
            ROOT / ".github" / "workflows" / "release.yml",
        ):
            self.assertIn(
                "python3 scripts/check_release_artifacts.py",
                workflow.read_text(),
                workflow,
            )


if __name__ == "__main__":
    unittest.main()
