"""Contract tests for the devenv definition.

Every script the devenv definition references must exist, the toolchain
check must run the status script with `--check`, and the advisory
provenance lane must run the gate script before `devenv:enterTest`.
"""

from __future__ import annotations

import pathlib
import re
import unittest

REPO = pathlib.Path(__file__).resolve().parents[1]
DEVENV_PATH = REPO / "devenv.nix"
DEVENV = DEVENV_PATH.read_text() if DEVENV_PATH.is_file() else ""


@unittest.skipIf(
    not DEVENV,
    "devenv.nix absent; the pin-consistency guard runs from a sparse checkout",
)
class DevenvContractTests(unittest.TestCase):
    # Pre-existing gap outside the provenance adoption: the manual
    # `nautilus-goldens` utility references a generator that was never
    # committed. The entry stays listed here as visible debt until the
    # generator lands or the wrapper retires.
    KNOWN_MISSING = frozenset({"scripts/gen_goldens.py"})

    def test_every_referenced_script_file_exists(self) -> None:
        for reference in sorted(set(re.findall(r"scripts/[A-Za-z0-9_]+\.(?:py|sh)", DEVENV))):
            if reference in self.KNOWN_MISSING:
                continue
            self.assertTrue((REPO / reference).is_file(), reference)

    def test_known_missing_entries_stay_current(self) -> None:
        for reference in self.KNOWN_MISSING:
            self.assertFalse(
                (REPO / reference).is_file(),
                f"{reference} exists; remove it from KNOWN_MISSING",
            )

    def test_toolchain_check_runs_status_with_check(self) -> None:
        self.assertIn('tasks."nautilus:toolchain-check"', DEVENV)
        self.assertIn("devenv_status.py", DEVENV)
        self.assertIn("--check", DEVENV)

    def test_provenance_lane_runs_before_enter_test(self) -> None:
        self.assertIn('tasks."nautilus:provenance-advisory"', DEVENV)
        self.assertIn("provenance_gate.py", DEVENV)
        lane = DEVENV.split('tasks."nautilus:provenance-advisory"', 1)[1]
        self.assertIn('before = [ "devenv:enterTest" ];', lane.split("};", 1)[0])

    def test_pinned_provenance_scripts_exist(self) -> None:
        for name in (
            "check_buoy_pin.py",
            "check_provenance_fixtures.py",
            "provenance_gate.py",
            "run_provenance_corpus.py",
            "provenance_oracle.sh",
            "devenv_status.py",
        ):
            self.assertTrue((REPO / "scripts" / name).is_file(), name)

    def test_pin_record_and_consumer_expressions_exist(self) -> None:
        for reference in (
            "provenance/buoy-pin.toml",
            "provenance/chelis-adapter-config.toml",
            "nix/buoy-consumer.nix",
            "nix/chelis-provenance.nix",
        ):
            self.assertTrue((REPO / reference).is_file(), reference)


if __name__ == "__main__":
    unittest.main()
