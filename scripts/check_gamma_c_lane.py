#!/usr/bin/env python3
"""Build the gamma-family exports through the C lane and check both lanes agree.

`chelis reef build` type-checks the package and does NOT enter host lowering, so
it is not weak evidence about a C consumer -- it is no evidence. nautilus#125
records that class in this repo (`Nautilus.Optim` and `Nautilus.Roots` cannot be
built by a C consumer while every package gate is green), and nautilus#70 states
the rule: package-level green is not evidence for a consumer.

This family earned its own oracle when the regularised incomplete gamma moved to
f64 internals (nautilus#152). The beta sibling beside this file already proves
that f64 arithmetic, f64 tuple members and f64->f32 casts lower through the C
lane, so no *primitive* here is new. What is new is this module's own path:
`check_gamma_sampling_c_lane.py` covers keyed gamma-family *sampling* and
nothing covered `gamma_cdf`, `gamma_sf`, `gamma_pdf`, `poisson_cdf`, the two
chi-squared CDFs or either quantile, which is the whole surface #152 moves. It
also reaches four recursion levels and an 80-step Newton loop that the beta
lane's three levels do not.

Three legs, and the third is the one that catches a package boundary.

**Eval leg:** evaluate the probe with `chelis eval --file` to get each value in
the interpreter lane.

**In-package leg:** `chelis build` the same probe from inside `src/`, require an
executable, run it, and require every value to match the eval lane bit for bit.
That covers host lowering, C compilation and linking rather than stopping at
code generation.

**Cross-package leg:** rebuild this package from the CURRENT source, install it
into a throwaway Reef store, then build a *separate* package against it and run
that. An in-package module shares the package's own compilation context, so it
cannot see a package-boundary failure. The rebuild is not optional: the rolling
harness records a review round that probed STALE `dist/` artifacts built from a
mutated source and drew a conclusion that was a property of the artifact rather
than of the module.

**Cross-lane agreement alone would not catch both lanes being wrong the same
way, so every case also carries an anchor that needs no reference library.**
Three kinds, and all three reject the f32 lane this change replaces:

1. *Closed forms.* At `shape = 1` and `shape = 2` the incomplete gamma is
   elementary: `gamma_cdf(2, 2, 1)` is `1 - 3/e^2`, `gamma_sf(2, 2, 1)` is
   `3/e^2`, `gamma_pdf(2, 2, 1)` is `2/e^2`, `poisson_cdf(0, 5)` is `1/e^5`,
   `chi_squared_cdf(4, 4)` is `1 - 3/e^2`, and `gamma_inv_cdf(0.5, 1, 1)` is
   `ln 2`. Each is computed here from `math.exp` and `math.log`, which are not
   an oracle for this family in any sense -- they are the definition.

   These do **not** reject the f32 lane this change replaces, and that is not
   a weakness in them. At shape 2 the f32 front factor had nothing to cancel:
   `gamma_pdf(2, 2, 1)` was 0.27067044 against a true 0.270670566, which is
   4.7e-7 relative and inside the tolerance below. They are a guard against
   gross breakage and against both lanes agreeing on it. The two anchor kinds
   that do reject the f32 lane are the next two, and a reader should not take
   the elementary ones for the ones with teeth.

2. *An order anchor at a large shape, from the median.* A Gamma distribution is
   positively skewed, so its median is below its mean: `gamma_cdf(a, a, 1) >
   0.5` for every `a > 0`. The Chen-Rubin inequality, proved by Berg and
   Pedersen, gives the other side, `median > a - 1/3`, so `gamma_cdf(a - d, a,
   1) < 0.5` for any `d >= 1`. Both hold for all `a` and neither needs a
   reference value. The f32 lane violated both: it returned 0.0296 for
   `gamma_cdf(1e6, 1e6, 1)`, where the first anchor requires a value above
   0.5, and 0.9993 for `gamma_cdf(5e7 - 4, 5e7, 1)`, where the second requires
   one below it.

3. *A strict-gap anchor for the `k + 1` that f32 lost.* `poisson_cdf(k, lam)`
   is `Q(k + 1, lam)` and `gamma_sf(lam, k, 1)` is `Q(k, lam)`, so the first
   exceeds the second by exactly `poisson_pmf(k, lam)` -- strictly, for every
   `k` and `lam`. At `k = lam = 5e7` that gap is about `1/sqrt(2*pi*lam)` =
   5.64e-5, which f32 resolves comfortably beside a value near 0.5. When the
   f32 `k + 1` rounded back to `k`, the two expressions returned the identical
   value and the gap was exactly zero.

The cross-package leg sets `CHELIS_REEF_HOME` to a temporary directory, so it
never writes the shared `~/.chelis/reef/`; the run asserts that store's digest
is unchanged.

    python3 scripts/check_gamma_c_lane.py

Success is exit 0 with a final `GAMMA C LANE: PASS` line. Set `CHELIS_BIN` to
validate an explicit toolchain binary. `--in-package-only` skips the leg that
builds and installs the package. `--keep` leaves the generated artifacts.

This file is stdlib-only and therefore lives in `scripts/`:
`scripts/check_oracle_isolation.py` confines SciPy and NumPy to `parity/`,
where the accuracy gate `parity/check_gamma_accuracy.py` lives.

The probe is written into `src/` because chelis resolves package imports from the
source root, and it is always removed again. Its module name and `lane_` prefix
have to agree: §7.1 rejects a shared prefix that is not the module's own domain
shorthand, and the style gate runs before the build.
"""
from __future__ import annotations

import argparse
import hashlib
import math
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
PROBE = REPO / "src" / "lanegamma.ch"
MODULE = "Nautilus.LaneGamma"
NAME = "nautilus"
SHARED_STORE = Path.home() / ".chelis" / "reef"
VALUE_RE = re.compile(r"^\s*(lane_\w+)\s*=\s*(\S+)\s*$", re.M)

IMPORTS = ("gamma_cdf, gamma_sf, gamma_pdf, gamma_inv_cdf, chi_squared_cdf, "
           "chi_squared_sf, chi_squared_inv_cdf, poisson_cdf")

# Each case is (name, expression). Ordinary rows exist to be compared ACROSS
# lanes; the anchored rows below are additionally checked against a value this
# file derives itself.
CASES = [
    # --- closed forms, elementary at shape 1 and 2 --------------------------
    ("lane_cdf_two", "gamma_cdf(cast(2.0, f32), cast(2.0, f32), cast(1.0, f32))"),
    ("lane_sf_two", "gamma_sf(cast(2.0, f32), cast(2.0, f32), cast(1.0, f32))"),
    ("lane_pdf_two", "gamma_pdf(cast(2.0, f32), cast(2.0, f32), cast(1.0, f32))"),
    ("lane_pois_zero", "poisson_cdf(cast(0.0, f32), cast(5.0, f32))"),
    ("lane_chi_four", "chi_squared_cdf(cast(4.0, f32), cast(4.0, f32))"),
    ("lane_inv_ln2", "gamma_inv_cdf(cast(0.5, f32), cast(1.0, f32), cast(1.0, f32))"),
    # --- the median order anchors, at a shape the f32 lane got wrong --------
    ("lane_median_hi_6", "gamma_cdf(cast(1e6, f32), cast(1e6, f32), cast(1.0, f32))"),
    ("lane_median_lo_6", "gamma_cdf(cast(999999.0, f32), cast(1e6, f32), cast(1.0, f32))"),
    ("lane_median_hi_7", "gamma_cdf(cast(5e7, f32), cast(5e7, f32), cast(1.0, f32))"),
    ("lane_median_lo_7", "gamma_cdf(cast(49999996.0, f32), cast(5e7, f32), cast(1.0, f32))"),
    # --- the k + 1 gap anchor ----------------------------------------------
    ("lane_pois_big", "poisson_cdf(cast(5e7, f32), cast(5e7, f32))"),
    ("lane_sf_big", "gamma_sf(cast(5e7, f32), cast(5e7, f32), cast(1.0, f32))"),
    # --- ordinary cross-lane rows, including both quantiles and both tails --
    ("lane_cdf_small", "gamma_cdf(cast(0.5, f32), cast(0.5, f32), cast(2.5, f32))"),
    ("lane_sf_tail", "gamma_sf(cast(120000.0, f32), cast(100000.0, f32), cast(1.0, f32))"),
    ("lane_chi_sf", "chi_squared_sf(cast(200000.0, f32), cast(200000.0, f32))"),
    ("lane_inv_big", "gamma_inv_cdf(cast(0.999, f32), cast(1e6, f32), cast(1.0, f32))"),
    ("lane_chi_inv", "chi_squared_inv_cdf(cast(0.5, f32), cast(2e7, f32))"),
    ("lane_pois_left", "poisson_cdf(cast(10.0, f32), cast(50.0, f32))"),
]

# name -> (value this file derives, relative tolerance).
# f32 carries about 7 decimal digits, so 1e-6 is a little over ten ulps: tight
# enough to reject the f32 lane's errors (2.9e-4 at shape 1e3 and upward) and
# loose enough not to be a near-tie on the last bit.
CLOSED_TOL = 1e-6
CLOSED_FORMS = {
    "lane_cdf_two": 1.0 - 3.0 * math.exp(-2.0),
    "lane_sf_two": 3.0 * math.exp(-2.0),
    "lane_pdf_two": 2.0 * math.exp(-2.0),
    "lane_pois_zero": math.exp(-5.0),
    "lane_chi_four": 1.0 - 3.0 * math.exp(-2.0),
    "lane_inv_ln2": math.log(2.0),
}
# (name above the median, name below it). Both are inequalities, not values.
MEDIAN_PAIRS = (("lane_median_hi_6", "lane_median_lo_6"),
                ("lane_median_hi_7", "lane_median_lo_7"))
# poisson_cdf(k, lam) - gamma_sf(lam, k, 1) = poisson_pmf(k, lam) > 0.
GAP_LAMBDA = 5e7
GAP_TOL = 0.1


class LaneError(Exception):
    pass


def probe_source(module: str) -> str:
    lines = [
        f"module {module}",
        f"import Nautilus.Distributions ({IMPORTS})",
        f"export ({', '.join(name for name, _ in CASES)})",
    ]
    lines += [f"def {name}() -> f32 = {expr}" for name, expr in CASES]
    return "\n".join(lines) + "\n"


def run(command: list[str], cwd: Path, env: dict | None = None,
        timeout: int = 1800) -> subprocess.CompletedProcess:
    return subprocess.run(command, cwd=str(cwd), capture_output=True, text=True,
                          timeout=timeout, env=env)


def values(stdout: str) -> dict[str, str]:
    return {m.group(1): m.group(2) for m in VALUE_RE.finditer(stdout)}


def field(pattern: str) -> str:
    match = re.search(pattern, (REPO / "reef.toml").read_text(), re.M)
    if match is None:
        raise LaneError(f"cannot read {pattern} from reef.toml")
    return match.group(1)


def store_digest(root: Path) -> str:
    """Content hash of the shared Reef store, to prove the run did not write it.

    Hashes file *contents*, not sizes: a same-size overwrite would read as
    unchanged otherwise, which is the whole property this is asserting.
    """
    if not root.exists():
        return "absent"
    h = hashlib.sha256()
    for path in sorted(p for p in root.rglob("*") if p.is_file()):
        h.update(str(path.relative_to(root)).encode())
        h.update(b"\0")
        with path.open("rb") as handle:
            for block in iter(lambda: handle.read(1 << 20), b""):
                h.update(block)
    return h.hexdigest()[:16]


def value(got: dict[str, str], name: str, lane: str) -> float:
    """The row's value, or a LaneError. Non-finite is not a number here.

    The explicit finiteness check is not belt and braces. `float("NaN")`
    parses, and every comparison against the result is False, so a NaN reached
    `abs(seen - expected) / expected > CLOSED_TOL` and answered False -- it
    passed every closed-form anchor and both sides of the gap check in
    silence. A unit test flipping one row to NaN is what found that, which is
    the argument for unit-testing a gate's detection logic rather than only
    running it.
    """
    raw = got.get(name)
    if raw is None:
        raise LaneError(f"{lane}: {name} missing from output")
    try:
        parsed = float(raw)
    except ValueError as error:
        raise LaneError(f"{lane}: {name} = {raw}, which is not a number") from error
    if parsed != parsed or parsed in (float("inf"), float("-inf")):
        raise LaneError(
            f"{lane}: {name} = {raw}. Every row here has a finite value, so a "
            f"NaN or an infinity is a failure and never an exclusion")
    return parsed


def check_anchors(got: dict[str, str], lane: str) -> None:
    """Every anchor this file can evaluate without a reference library."""
    for name, expected in CLOSED_FORMS.items():
        seen = value(got, name, lane)
        error = abs(seen - expected) / abs(expected)
        if error > CLOSED_TOL:
            raise LaneError(
                f"{lane}: {name} = {seen!r}, but its closed form is "
                f"{expected!r} (relative error {error:.2e} > {CLOSED_TOL:.0e})")
    for high, low in MEDIAN_PAIRS:
        above = value(got, high, lane)
        below = value(got, low, lane)
        if not above > 0.5:
            raise LaneError(
                f"{lane}: {high} = {above!r}, but a Gamma median is below its "
                f"mean, so P(a, a) > 0.5 for every a")
        if not below < 0.5:
            raise LaneError(
                f"{lane}: {low} = {below!r}, but the Chen-Rubin inequality puts "
                f"the median above a - 1/3, so P(a, a - d) < 0.5 for d >= 1")
    gap = value(got, "lane_pois_big", lane) - value(got, "lane_sf_big", lane)
    expected_gap = 1.0 / math.sqrt(2.0 * math.pi * GAP_LAMBDA)
    if gap <= 0.0:
        raise LaneError(
            f"{lane}: poisson_cdf(k, lam) - gamma_sf(lam, k, 1) = {gap!r}, but "
            f"it is poisson_pmf(k, lam) and strictly positive. A gap of exactly "
            f"zero is the f32 `k + 1` rounding back to `k`")
    if abs(gap - expected_gap) / expected_gap > GAP_TOL:
        raise LaneError(
            f"{lane}: the poisson_cdf / gamma_sf gap is {gap:.6e}, against "
            f"1/sqrt(2*pi*lam) = {expected_gap:.6e} "
            f"(outside {GAP_TOL:.0%})")


def compare(a: dict[str, str], b: dict[str, str], a_name: str, b_name: str) -> None:
    missing = [name for name, _ in CASES if name not in a or name not in b]
    if missing:
        raise LaneError(f"missing from one lane: {', '.join(missing)}")
    bad = [(name, a[name], b[name]) for name, _ in CASES if a[name] != b[name]]
    if bad:
        detail = "\n".join(f"    {n}: {a_name} {x} vs {b_name} {y}" for n, x, y in bad)
        raise LaneError(f"{a_name} and {b_name} disagree:\n{detail}")


def cross_package(chelis: str, keep: bool) -> dict[str, str]:
    version, pin = field(r'^version\s*=\s*"([^"]+)"'), field(r'^compiler\s*=\s*"=?([^"]+)"')
    built = run([chelis, "reef", "build"], REPO)
    if built.returncode != 0:
        raise LaneError(
            "chelis reef build failed, so there is no artifact to install "
            f"(rc={built.returncode}):\n{(built.stderr or built.stdout).strip()[-600:]}"
        )
    sandbox = Path(tempfile.mkdtemp(prefix="gamma-c-lane-"))
    try:
        mono = sandbox / "mono" / "packages" / NAME
        (mono / "dist").mkdir(parents=True)
        shutil.copy(REPO / "reef.toml", mono / "reef.toml")
        for suffix in (".chb", ".tar.zst"):
            artifact = REPO / "dist" / f"{NAME}-{version}{suffix}"
            if not artifact.exists():
                raise LaneError(f"missing build artifact {artifact}")
            shutil.copy(artifact, mono / "dist" / artifact.name)

        store = sandbox / "store"
        store.mkdir()
        env = dict(os.environ, CHELIS_REEF_HOME=str(store))
        installed = run(
            [chelis, "reef", "install", "--from-monorepo", str(sandbox / "mono"), NAME],
            REPO, env=env)
        if installed.returncode != 0:
            raise LaneError(
                "reef install into the isolated store failed "
                f"(rc={installed.returncode}):\n"
                f"{(installed.stderr or installed.stdout).strip()[-600:]}")

        consumer = sandbox / "consumer"
        (consumer / "src").mkdir(parents=True)
        (consumer / "reef.toml").write_text(
            "[package]\n"
            'name = "gammaconsumer"\n'
            'version = "0.0.0"\n'
            f'compiler = "={pin}"\n'
            'module_prefix = "Downstream"\n'
            "\n[dependencies]\n"
            'chelis-std = { version = "0.4.0" }\n'
            f'{NAME} = {{ version = "{version}" }}\n')
        (consumer / "src" / "lanegamma.ch").write_text(probe_source("Downstream.LaneGamma"))
        formatted = run([chelis, "fmt", "--inplace", "src/lanegamma.ch"], consumer, env=env)
        if formatted.returncode != 0:
            raise LaneError(f"chelis fmt failed on the consumer probe: "
                            f"{formatted.stderr.strip()[-400:]}")

        out = sandbox / "out"
        consumed = run([chelis, "build", "-o", str(out), "src/lanegamma.ch"], consumer, env=env)
        if consumed.returncode != 0:
            raise LaneError(
                "a SEPARATE package could not build against this one "
                f"(rc={consumed.returncode}). The in-package leg passed, so this is a "
                f"package-boundary failure:\n"
                f"{(consumed.stderr or consumed.stdout).strip()[-1200:]}")
        executable = out / "lanegamma"
        if not executable.exists():
            raise LaneError(f"cross-package build produced no executable at {executable}")
        ran = run([str(executable)], consumer, env=env, timeout=600)
        if ran.returncode != 0:
            raise LaneError(f"the cross-package executable exited {ran.returncode}:\n"
                            f"{(ran.stderr or ran.stdout).strip()[-600:]}")
        return values(ran.stdout)
    finally:
        if not keep:
            shutil.rmtree(sandbox, ignore_errors=True)


def main() -> int:
    parser = argparse.ArgumentParser(description="Gamma-family C-lane oracle.")
    parser.add_argument("--keep", action="store_true",
                        help="keep the generated artifacts for inspection")
    parser.add_argument("--in-package-only", action="store_true",
                        help="skip the cross-package leg (it builds and installs the package)")
    args = parser.parse_args()

    chelis = os.environ.get("CHELIS_BIN", "chelis")
    before = store_digest(SHARED_STORE)
    out = Path(tempfile.mkdtemp(prefix="gamma-c-lane-inpkg-"))
    try:
        PROBE.write_text(probe_source(MODULE))
        relative = str(PROBE.relative_to(REPO))
        formatted = run([chelis, "fmt", "--inplace", relative], REPO)
        if formatted.returncode != 0:
            raise LaneError(f"chelis fmt on the generated probe failed: "
                            f"{formatted.stderr.strip()[-500:]}")

        evaluated = run([chelis, "eval", "--file", relative], REPO)
        if evaluated.returncode != 0:
            raise LaneError(f"chelis eval --file on the probe failed "
                            f"(rc={evaluated.returncode}):\n"
                            f"{(evaluated.stderr or evaluated.stdout).strip()[-800:]}")
        eval_values = values(evaluated.stdout)
        check_anchors(eval_values, "eval lane")
        print(f"eval lane: {len(eval_values)} values, anchors hold")

        built = run([chelis, "build", "-o", str(out), relative], REPO)
        if built.returncode != 0:
            raise LaneError(
                "chelis build rejected an in-package consumer of the gamma family "
                f"(rc={built.returncode}):\n{(built.stderr or built.stdout).strip()[-1200:]}")
        executable = out / PROBE.stem
        if not executable.exists():
            raise LaneError(f"in-package build produced no executable at {executable}")
        ran = run([str(executable)], REPO, timeout=600)
        if ran.returncode != 0:
            raise LaneError(f"the in-package executable exited {ran.returncode}:\n"
                            f"{(ran.stderr or ran.stdout).strip()[-600:]}")
        in_package = values(ran.stdout)
        check_anchors(in_package, "in-package C lane")
        compare(eval_values, in_package, "eval lane", "in-package C lane")
        print(f"in-package C lane: built, ran, and agrees with the eval lane on "
              f"all {len(CASES)} values")
    except LaneError as error:
        print(f"GAMMA C LANE: FAIL\n{error}", file=sys.stderr)
        return 1
    finally:
        if not args.keep:
            PROBE.unlink(missing_ok=True)
            shutil.rmtree(out, ignore_errors=True)

    if not args.in_package_only:
        try:
            cross = cross_package(chelis, args.keep)
            check_anchors(cross, "cross-package C lane")
            compare(eval_values, cross, "eval lane", "cross-package C lane")
            print(f"cross-package C lane: a separate package built, ran, and agrees "
                  f"with the eval lane on all {len(CASES)} values")
        except LaneError as error:
            print(f"GAMMA C LANE: FAIL\n{error}", file=sys.stderr)
            return 1

    after = store_digest(SHARED_STORE)
    if before != after:
        print(f"GAMMA C LANE: FAIL\nthe shared Reef store at {SHARED_STORE} changed "
              f"({before} -> {after}); the isolated store leaked", file=sys.stderr)
        return 1
    print(f"shared Reef store unchanged ({before})")
    print("GAMMA C LANE: PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
