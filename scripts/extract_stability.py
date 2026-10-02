#!/usr/bin/env python3
"""Extract the row-level stability map from SKILL.md Section 6."""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
SKILL_MD = REPO / "SKILL.md"
DIST = REPO / "dist"
OUTPUT = DIST / "stability.json"
SRC = REPO / "src"

API_START = "## 6. API Surface"
MODULE_RE = re.compile(r"^### (Nautilus\.[\w.]+)(?: \(([^)]*)\))?$")
ROW_RE = re.compile(r"^\| (`[^`]+`) \| (.*?) \| `?(stable|alpha)`? \| (.*) \|$")


def parse_exports(path: Path) -> list[str]:
    text = path.read_text()
    match = re.search(r"export\s*\(([^)]*)\)", text, re.S)
    if not match:
        raise ValueError(f"missing export(...) clause in {path}")
    return [token.strip() for token in match.group(1).split(",") if token.strip()]


def exported_surface() -> dict[str, list[str]]:
    mapping = {
        "Nautilus.Special": SRC / "special.ch",
        "Nautilus.Distributions": SRC / "distributions.ch",
        "Nautilus.LinAlg": SRC / "linalg.ch",
        "Nautilus.Stats": SRC / "stats.ch",
        "Nautilus.Distance": SRC / "distance.ch",
        "Nautilus.Roots": SRC / "roots.ch",
        "Nautilus.Ode": SRC / "ode.ch",
        "Nautilus.Integrate": SRC / "integrate.ch",
        "Nautilus.Testing": SRC / "testing.ch",
        "Nautilus.Optim": SRC / "optim.ch",
        "Nautilus.Interpolation": SRC / "interpolation.ch",
        "Nautilus.Sde": SRC / "sde.ch",
        "Nautilus.CurveFit": SRC / "curvefit.ch",
        "Nautilus.Signal": SRC / "signal.ch",
        "Nautilus.Info": SRC / "info.ch",
        "Nautilus.Optimize": SRC / "optimize.ch",
        "Nautilus.StateSpace": SRC / "statespace.ch",
        "Nautilus.TimeSeries": SRC / "timeseries.ch",
        "Nautilus.Rolling": SRC / "rolling.ch",
    }
    return {module: parse_exports(path) for module, path in mapping.items()}


def parse_skill_api_tables(skill_text: str) -> dict[str, dict[str, str]]:
    if API_START not in skill_text:
        raise ValueError(f"{SKILL_MD} is missing {API_START!r}")

    lines = skill_text.splitlines()
    start_idx = lines.index(API_START) + 1
    current_module: str | None = None
    header_seen = False
    data: dict[str, dict[str, str]] = {}

    for line in lines[start_idx:]:
        module_match = MODULE_RE.match(line)
        if module_match:
            current_module = module_match.group(1)
            data[current_module] = {}
            header_seen = False
            continue

        if current_module is None:
            continue

        if line.startswith("## "):
            break

        if not line.startswith("|"):
            continue

        if line.startswith("| Function | Signature | Stability | Notes |"):
            header_seen = True
            continue

        if line.startswith("|---|---|---|---|"):
            continue

        if not header_seen:
            continue

        row_match = ROW_RE.match(line)
        if not row_match:
            raise ValueError(f"{current_module}: malformed API row: {line}")
        fn_cell, _signature, stability, _notes = row_match.groups()
        data[current_module][fn_cell.strip("`")] = stability

    return data


def build_stability_map() -> dict[str, dict[str, str]]:
    return parse_skill_api_tables(SKILL_MD.read_text())


def validate_surface_map(surface: dict[str, dict[str, str]]) -> list[str]:
    failures: list[str] = []
    exports = exported_surface()

    missing_modules = set(exports) - set(surface)
    extra_modules = set(surface) - set(exports)
    if missing_modules:
        failures.append(f"SKILL.md is missing API tables for: {sorted(missing_modules)}")
    if extra_modules:
        failures.append(f"SKILL.md has unexpected API tables for: {sorted(extra_modules)}")

    for module, expected_exports in exports.items():
        documented = surface.get(module, {})
        for fn, stability in documented.items():
            if stability not in {"stable", "alpha"}:
                failures.append(
                    f"{module}.{fn}: invalid Stability value {stability!r}; expected 'stable' or 'alpha'"
                )
        missing = sorted(set(expected_exports) - set(documented))
        extra = sorted(set(documented) - set(expected_exports))
        if missing:
            failures.append(f"{module}: missing documented exports {missing}")
        if extra:
            failures.append(f"{module}: documented names not exported from source {extra}")

    return failures


def write_output(surface: dict[str, dict[str, str]]) -> None:
    DIST.mkdir(exist_ok=True)
    OUTPUT.write_text(json.dumps(surface, indent=2, sort_keys=True) + "\n")


def check_output(surface: dict[str, dict[str, str]]) -> list[str]:
    if not OUTPUT.exists():
        return [f"missing {OUTPUT.relative_to(REPO)}; run scripts/extract_stability.py"]
    current = json.loads(OUTPUT.read_text())
    if current != surface:
        return [f"{OUTPUT.relative_to(REPO)} is stale; run scripts/extract_stability.py"]
    return []


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true", help="Verify the committed artifact is current.")
    args = parser.parse_args()

    surface = build_stability_map()
    failures = validate_surface_map(surface)
    if args.check:
        failures.extend(check_output(surface))
    if failures:
        print("stability extraction failed:")
        for failure in failures:
            print(f"  - {failure}")
        return 1

    if args.check:
        print("stability artifact OK")
        return 0

    write_output(surface)
    print(f"wrote {OUTPUT.relative_to(REPO)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
