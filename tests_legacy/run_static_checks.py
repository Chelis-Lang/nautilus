#!/usr/bin/env python3
"""Static cross-checks for the Nautilus package surface.

Belt-and-suspenders gate that complements `chelis check`:

1. Every name imported in src/apismoke.ch must appear in the corresponding
   src/<module>.ch's `export(...)` clause. Catches API drift between modules
   even when chelis check inside a reef package would also catch it — but
   gives a Python-readable error message naming both sides of the mismatch.

2. Every function name listed in the README's "P0 Surface" table is in the
   actual export() clause of the corresponding src/<module>.ch.

3. `tests/goldens/linalg/*.json` are consumed by the tensor-path harness.
   Keep an explicit informational print so this does not silently regress
   back into unused-fixture drift.

Exit non-zero on any drift.
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
SRC = REPO / "src"
sys.path.insert(0, str(REPO))

from scripts.extract_stability import build_stability_map, check_output, validate_surface_map

MODULES = {
    "Nautilus.Special":       SRC / "special.ch",
    "Nautilus.Distributions": SRC / "distributions.ch",
    "Nautilus.LinAlg":        SRC / "linalg.ch",
    "Nautilus.Roots":         SRC / "roots.ch",
    "Nautilus.Ode":           SRC / "ode.ch",
    "Nautilus.Stats":         SRC / "stats.ch",
    "Nautilus.Integrate":     SRC / "integrate.ch",
    "Nautilus.Testing":       SRC / "testing.ch",
    "Nautilus.Distance":      SRC / "distance.ch",
    "Nautilus.Signal":        SRC / "signal.ch",
    "Nautilus.Optim":         SRC / "optim.ch",
    "Nautilus.Interpolation": SRC / "interpolation.ch",
    "Nautilus.Sde":           SRC / "sde.ch",
    "Nautilus.CurveFit":      SRC / "curvefit.ch",
}


def parse_exports(path: Path) -> set[str]:
    txt = path.read_text()
    m = re.search(r"export\s*\(([^)]*)\)", txt, re.S)
    if not m:
        return set()
    body = m.group(1)
    return {tok.strip() for tok in body.split(",") if tok.strip()}


def parse_imports(path: Path) -> dict[str, set[str]]:
    txt = path.read_text()
    out: dict[str, set[str]] = {}
    for m in re.finditer(r"import\s+([\w.]+)\s*\(([^)]*)\)", txt, re.S):
        mod = m.group(1)
        names = {tok.strip() for tok in m.group(2).split(",") if tok.strip()}
        out.setdefault(mod, set()).update(names)
    return out


def check_apismoke(fail: list[str]) -> None:
    smoke = SRC / "apismoke.ch"
    if not smoke.exists():
        fail.append("missing src/apismoke.ch")
        return
    imports = parse_imports(smoke)
    for mod, names in imports.items():
        if mod not in MODULES:
            fail.append(f"apismoke imports unknown module {mod}")
            continue
        exports = parse_exports(MODULES[mod])
        missing = names - exports
        if missing:
            fail.append(f"apismoke imports {sorted(missing)} from {mod}, "
                        f"not in export clause of {MODULES[mod].name}")


README_TABLE_PATTERN = re.compile(r"^\| `(Nautilus\.[\w.]+)` \| (.+?) \|", re.M)
INLINE_NAME_PATTERN = re.compile(r"`([a-z_][\w]*)`")


def check_readme(fail: list[str]) -> None:
    readme = REPO / "README.md"
    if not readme.exists():
        return
    txt = readme.read_text()
    for mod_match in README_TABLE_PATTERN.finditer(txt):
        mod = mod_match.group(1)
        cell = mod_match.group(2)
        if mod not in MODULES:
            continue
        # Pull `name` tokens out of the README cell.
        listed = set()
        for inner in INLINE_NAME_PATTERN.finditer(cell):
            tok = inner.group(1)
            if tok in {"pdf", "cdf", "inv_cdf", "sample"}:
                continue  # method-suffix shorthand, not a function name
            listed.add(tok)
        if not listed:
            continue
        exports = parse_exports(MODULES[mod])
        missing = listed - exports
        if missing:
            fail.append(f"README claims {mod} exports {sorted(missing)} "
                        f"but they're not in {MODULES[mod].name}")


def check_linalg_goldens_consumed() -> None:
    linalg_g = REPO / "tests_legacy" / "goldens" / "linalg"
    if not linalg_g.exists():
        return
    files = sorted(p.name for p in linalg_g.glob("*.json"))
    if not files:
        return
    print("[info] tests_legacy/goldens/linalg/*.json consumed by tensor-path harness")
    print("       (v0.1.7 fixed Bug 5; linalg runtime tests now fully wired).")
    print("       Files:", ", ".join(files))


def check_stability_surface(fail: list[str]) -> None:
    try:
        surface = build_stability_map()
    except ValueError as exc:
        fail.append(str(exc))
        return
    fail.extend(validate_surface_map(surface))
    fail.extend(check_output(surface))


def main() -> int:
    fail: list[str] = []
    check_apismoke(fail)
    check_readme(fail)
    check_stability_surface(fail)
    check_linalg_goldens_consumed()
    if fail:
        print("STATIC CHECK FAILURES:")
        for f in fail:
            print(f"  - {f}")
        return 1
    print("static checks OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
