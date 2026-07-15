#!/usr/bin/env python3
"""Fail when a toolchain-installing workflow drifts from reef.toml."""
from __future__ import annotations

import re
import sys
from pathlib import Path

try:
    from . import reef_pin
except ImportError:  # Direct execution: ``python3 scripts/check_workflow_pins.py``.
    import reef_pin


REPO_ROOT = Path(__file__).resolve().parent.parent
INSTALL_MARKERS = (
    "uses: ./.github/actions/install-chelis",
    "chelisup install",
    "--repo Chelis-Lang/chelis",
)
PIN_RE = re.compile(
    r"^\s*(CHELIS_TAG|CHELIS_VERSION)\s*:\s*(['\"]?)(v?\d+\.\d+\.\d+)\2\s*(?:#.*)?$",
    re.MULTILINE,
)


def read_reef_pin(path: Path) -> str:
    """Compatibility wrapper around the shared exact-pin reader."""
    return reef_pin.read_exact_reef_pin(path)


def static_pins(text: str) -> dict[str, set[str]]:
    """Collect literal workflow pin declarations, including duplicates."""
    pins: dict[str, set[str]] = {}
    for key, _quote, value in PIN_RE.findall(text):
        pins.setdefault(key, set()).add(value)
    return pins


def check_workflow_pins(version: str, workflow_dir: Path) -> list[str]:
    """Return errors for installing workflows without exactly one pin value."""
    expected = {"CHELIS_TAG": f"v{version}", "CHELIS_VERSION": version}
    paths = sorted([*workflow_dir.glob("*.yml"), *workflow_dir.glob("*.yaml")])
    errors: list[str] = []
    checked = 0

    for path in paths:
        try:
            text = path.read_text(encoding="utf-8")
        except OSError as exc:
            errors.append(f"cannot read {path}: {exc}")
            continue
        if not any(marker in text for marker in INSTALL_MARKERS):
            continue

        checked += 1
        pins = static_pins(text)
        for key, wanted in expected.items():
            found = pins.get(key, set())
            if found != {wanted}:
                actual = ", ".join(sorted(found)) or "missing"
                errors.append(f"{path}: {key}={actual}; expected {wanted}")

    if checked == 0:
        errors.append(f"{workflow_dir}: no toolchain-installing workflow found")
    return errors


def main() -> int:
    try:
        version = read_reef_pin(REPO_ROOT / "reef.toml")
    except ValueError as exc:
        print(f"workflow pin error: {exc}", file=sys.stderr)
        return 1

    errors = check_workflow_pins(version, REPO_ROOT / ".github" / "workflows")
    for error in errors:
        print(f"workflow pin error: {error}", file=sys.stderr)
    if errors:
        return 1

    print("workflow pins match the exact compiler pin in reef.toml")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
