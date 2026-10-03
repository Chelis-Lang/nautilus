#!/usr/bin/env python3
"""Build every `Nautilus.Rolling` export through the C lane.

`chelis reef build` type-checks the package and does NOT enter host lowering,
so it cannot see chelis#730: an `Option` return reached through a lambda used
to fail a consumer's `chelis build` with an unresolved host inference variable
while every package-level gate stayed green. nautilus#70 records that class and
says package-level green is not evidence for a consumer. No other job in this
repository runs `chelis build` at all.

This script is that oracle for this module. It generates one consumer module
calling all 34 exports, runs `chelis build`, and then runs the clang line
`chelis build` printed, so the check covers host lowering AND the C compile
rather than stopping at code generation.

    uv run --no-project --python 3.12 python scripts/check_rolling_c_lane.py

Success is exit 0 with a final `ROLLING C LANE: PASS` line. Set `CHELIS_BIN` to
validate an explicit toolchain binary. `--keep` leaves the generated artifacts
for inspection.

The probe is written into `src/` because chelis resolves package imports from
the source root, and it is always removed again.
"""

from __future__ import annotations

import argparse
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
SOURCE = REPO / "src" / "rolling.ch"
# The module name and the `lane_` prefix have to agree: chelis's §7.1
# prefix-namespace rule rejects a shared prefix that is not the module's
# own domain shorthand, and the style gate runs before the build.
PROBE = REPO / "src" / "lanecheck.ch"
MODULE = "Nautilus.LaneCheck"
COMPILE_RE = re.compile(r"^Compile:\s*(.+)$", re.M)

# Exports whose result has no absent position, so they return a plain list or
# a tensor rather than an `Option`. Everything else returns `List[Option[f64]]`.
DENSE = {"shift_fill", "shift_clamped"}
# Exports carrying a ddof argument.
DDOF = {"rolling_var", "rolling_std", "expanding_var", "expanding_std"}


class LaneError(Exception):
    pass


def exports() -> list[str]:
    text = SOURCE.read_text()
    match = re.search(r"export\s*\(([^)]*)\)", text, re.S)
    if match is None:
        raise LaneError(f"{SOURCE}: no export(...) clause")
    return [token.strip() for token in match.group(1).split(",") if token.strip()]


def arguments(name: str, tensor: bool) -> str:
    base = name[len("tensor_"):] if tensor else name
    series = "ts()" if tensor else "xs()"
    if base.startswith("rolling_"):
        args = "cast(2, i64), cast(2, i64)"
    elif base.startswith("expanding_"):
        args = "cast(2, i64)"
    elif base == "shift_fill":
        args = "cast(1, i64), cast(0.0, f64)"
    else:
        args = "cast(1, i64)"
    if base in DDOF:
        args += ", cast(1, i64)"
    return f"{series}, {args}"


def probe_source(names: list[str]) -> str:
    lines = [
        f"module {MODULE}",
        f"import Nautilus.Rolling ({', '.join(names)})",
        "def xs() -> List[f64] = [cast(5.0, f64), cast(2.0, f64), cast(7.0, f64), cast(3.0, f64)]",
        "def ts() -> tensor[4, f64] = to_tensor(xs())",
    ]
    for name in names:
        tensor = name.startswith("tensor_")
        base = name[len("tensor_"):] if tensor else name
        if base in DENSE:
            ret = "tensor[4, f64]" if tensor else "List[f64]"
        else:
            ret = "List[Option[f64]]"
        lines.append(f"def lane_{name}() -> {ret} = {name}({arguments(name, tensor)})")
    return "\n".join(lines) + "\n"


def run(command: list[str], cwd: Path) -> subprocess.CompletedProcess:
    return subprocess.run(command, cwd=str(cwd), capture_output=True, text=True, timeout=1200)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--keep", action="store_true", help="keep the generated artifacts")
    args = parser.parse_args()

    chelis = os.environ.get("CHELIS_BIN", "chelis")
    out = Path(tempfile.mkdtemp(prefix="rolling-c-lane-"))
    try:
        names = exports()
        if not names:
            raise LaneError("no exports to build")
        PROBE.write_text(probe_source(names))

        formatted = run([chelis, "fmt", "--inplace", str(PROBE.relative_to(REPO))], REPO)
        if formatted.returncode != 0:
            raise LaneError(f"chelis fmt on the generated probe failed: {formatted.stderr.strip()[-500:]}")

        built = run([chelis, "build", "-o", str(out), str(PROBE.relative_to(REPO))], REPO)
        if built.returncode != 0:
            raise LaneError(
                "chelis build rejected a consumer of Nautilus.Rolling "
                f"(rc={built.returncode}):\n{(built.stderr or built.stdout).strip()[-1200:]}"
            )

        compile_line = COMPILE_RE.search(built.stdout)
        if compile_line is None:
            # Without the compile line this script would silently degrade to a
            # code-generation-only check, which is the weaker claim the module
            # already made and that this script exists to replace.
            raise LaneError(
                "chelis build printed no `Compile:` line, so the C compile was "
                f"never exercised:\n{built.stdout.strip()[-800:]}"
            )
        compiled = run(["/bin/sh", "-c", compile_line.group(1)], REPO)
        if compiled.returncode != 0:
            raise LaneError(
                "the clang line chelis build emitted failed "
                f"(rc={compiled.returncode}):\n{(compiled.stderr or compiled.stdout).strip()[-1200:]}"
            )

        print(f"{len(names)} exports lowered to C and compiled by the emitted clang line")
        print(f"  {compile_line.group(1)[:140]}")
        print("ROLLING C LANE: PASS")
        return 0
    except (LaneError, subprocess.TimeoutExpired, OSError) as exc:
        print(f"ROLLING C LANE: FAIL -- {exc}", file=sys.stderr)
        return 1
    finally:
        if not args.keep:
            PROBE.unlink(missing_ok=True)
            shutil.rmtree(out, ignore_errors=True)
        else:
            print(f"kept: {PROBE} and {out}", file=sys.stderr)


if __name__ == "__main__":
    sys.exit(main())
