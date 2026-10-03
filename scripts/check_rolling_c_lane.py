#!/usr/bin/env python3
"""Build every `Nautilus.Rolling` export through the C lane.

`chelis reef build` type-checks the package and does NOT enter host lowering,
so it cannot see chelis#730: an `Option` return reached through a lambda used
to fail a consumer's `chelis build` with an unresolved host inference variable
while every package-level gate stayed green. nautilus#70 records that class and
says package-level green is not evidence for a consumer. No other job in this
repository runs `chelis build` at all.

This script is that oracle for this module, in two legs.

**In-package leg:** generate one module under `src/` calling all 34 exports,
run `chelis build`, then run the clang line it printed, so the check covers
host lowering AND the C compile rather than stopping at code generation.

**Cross-package leg:** rebuild this package from the CURRENT source, install it
into a throwaway Reef store, then build a *separate* package that depends on
it. Two reasons, and the second is the one that earned it.

An in-package module shares the package's own compilation context, so it cannot
see a package-boundary failure. And `dist/` is a build output that nobody
rebuilds before reading: a review round left artifacts there built from a
mutated source, a cross-package probe was run against those stale artifacts,
and the resulting "32 of 34 exports build" finding was an artifact of the stale
`.chb`, not a property of the module. This leg rebuilds first, so that cannot
recur here. The failure mode it reproduces is real -- a function-value kernel
does fail a consumer with `[05-UNS-1]` -- which is what makes the leg worth its
runtime.

The cross-package leg sets `CHELIS_REEF_HOME` to a temporary directory, so it
never writes the shared `~/.chelis/reef/` and never makes a branch build
resolvable as a release for another checkout. Verified: the shared store's
digest is unchanged across a run.

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
NAME = "nautilus"
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


def package_version() -> str:
    text = (REPO / "reef.toml").read_text()
    match = re.search(r'^version\s*=\s*"([^"]+)"', text, re.M)
    if match is None:
        raise LaneError("cannot read version from reef.toml")
    return match.group(1)


def cross_package(chelis: str, names: list[str]) -> None:
    """Build a separate package against this one, in a throwaway Reef store.

    The in-package leg compiles a module inside `src/`, which shares the
    package's own compilation context. A consumer in a different package does
    not, and the difference has already hidden a real failure, so this leg is
    not redundant with it.
    """
    version = package_version()
    built = run([chelis, "reef", "build"], REPO)
    if built.returncode != 0:
        raise LaneError(
            f"chelis reef build failed, so no artifact to install "
            f"(rc={built.returncode}):\n{(built.stderr or built.stdout).strip()[-600:]}"
        )

    sandbox = Path(tempfile.mkdtemp(prefix="rolling-cross-"))
    try:
        mono = sandbox / "mono" / "packages" / NAME
        (mono / "dist").mkdir(parents=True)
        shutil.copy(REPO / "reef.toml", mono / "reef.toml")
        for suffix in (".chb", ".tar.zst"):
            artifact = REPO / "dist" / f"{NAME}-{version}{suffix}"
            if not artifact.exists():
                raise LaneError(f"missing build artifact {artifact}")
            shutil.copy(artifact, mono / "dist" / artifact.name)

        # The isolated store. Nothing here touches ~/.chelis/reef.
        store = sandbox / "store"
        store.mkdir()
        env = dict(os.environ, CHELIS_REEF_HOME=str(store))
        installed = subprocess.run(
            [chelis, "reef", "install", "--from-monorepo", str(sandbox / "mono"), NAME],
            cwd=str(REPO), capture_output=True, text=True, timeout=1200, env=env,
        )
        if installed.returncode != 0:
            raise LaneError(
                f"reef install into the isolated store failed "
                f"(rc={installed.returncode}):\n"
                f"{(installed.stderr or installed.stdout).strip()[-600:]}"
            )

        consumer = sandbox / "consumer"
        (consumer / "src").mkdir(parents=True)
        (consumer / "reef.toml").write_text(
            "[package]\n"
            'name = "rollingconsumer"\n'
            'version = "0.0.0"\n'
            f'compiler = "={compiler_pin()}"\n'
            'module_prefix = "Downstream"\n'
            "\n[dependencies]\n"
            'chelis-std = { version = "0.4.0" }\n'
            f'{NAME} = {{ version = "{version}" }}\n'
        )
        source = probe_source(names).replace(f"module {MODULE}", "module Downstream.Lane", 1)
        (consumer / "src" / "lane.ch").write_text(source)

        formatted = subprocess.run(
            [chelis, "fmt", "--inplace", "src/lane.ch"],
            cwd=str(consumer), capture_output=True, text=True, timeout=600, env=env,
        )
        if formatted.returncode != 0:
            raise LaneError(
                f"chelis fmt failed on the consumer probe: "
                f"{formatted.stderr.strip()[-400:]}"
            )
        out = sandbox / "out"
        consumed = subprocess.run(
            [chelis, "build", "-o", str(out), "src/lane.ch"],
            cwd=str(consumer), capture_output=True, text=True, timeout=1800, env=env,
        )
        if consumed.returncode != 0:
            raise LaneError(
                "a SEPARATE package could not build against this one "
                f"(rc={consumed.returncode}). The in-package leg passed, so this "
                f"is a package-boundary failure:\n"
                f"{(consumed.stderr or consumed.stdout).strip()[-1200:]}"
            )
    finally:
        shutil.rmtree(sandbox, ignore_errors=True)


def compiler_pin() -> str:
    text = (REPO / "reef.toml").read_text()
    match = re.search(r'^compiler\s*=\s*"=?([^"]+)"', text, re.M)
    if match is None:
        raise LaneError("cannot read the compiler pin from reef.toml")
    return match.group(1)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--keep", action="store_true", help="keep the generated artifacts")
    parser.add_argument(
        "--in-package-only",
        action="store_true",
        help="skip the cross-package leg (it builds and installs the package)",
    )
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

        print(f"in-package: {len(names)} exports lowered to C and compiled by the "
              f"emitted clang line")

        if args.in_package_only:
            print("cross-package: SKIPPED (--in-package-only)")
        else:
            cross_package(chelis, names)
            print(f"cross-package: {len(names)} exports built from a separate "
                  f"package in an isolated Reef store")
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
