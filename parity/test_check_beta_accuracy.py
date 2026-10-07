#!/usr/bin/env python3
"""Unit tests for the beta-family accuracy oracle's bookkeeping.

The measurement itself is the gate and needs the compiler, so it is not
duplicated here. These cover the parts that silently decide what the gate sees:
the generated identifiers, the governing-parameter choice, and the coverage of
the documented table.

The identifier test is not hypothetical. The first version of this script named
each case after its parameters, which produced `acc_1e+06_0p01` -- and `chelis`
rejected the file with "unrecognized literal suffix `p01`", because `06_0` was
lexed as a number. Names are positional now, and this pins that.
"""

from __future__ import annotations

import math
import re
import unittest

from parity.check_beta_accuracy import BOUND, CEILING, DOCUMENTED, FLOOR, PHI1, cases, f32

IDENTIFIER = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")

# No scipy guard here on purpose. This file lives under `parity/`, where SciPy is
# a declared, locked dependency, so an ImportError is a broken environment and
# should fail loudly. A `skipUnless` would turn that into a silent pass, and a
# test skipped everywhere is indistinguishable from a passing one.


class Names(unittest.TestCase):
    def setUp(self) -> None:
        self.spec = cases()

    def test_every_generated_name_is_a_valid_identifier(self) -> None:
        for name, *_ in self.spec:
            self.assertRegex(name, IDENTIFIER, f"{name!r} is not a usable def name")

    def test_no_name_contains_a_character_the_lexer_reads_as_a_literal(self) -> None:
        for name, *_ in self.spec:
            for bad in "+-.e":
                if bad == "e":
                    continue        # 'e' is fine in a name, just not beside digits
                self.assertNotIn(bad, name, f"{name!r} would not lex")

    def test_names_are_unique(self) -> None:
        names = [name for name, *_ in self.spec]
        self.assertEqual(len(names), len(set(names)))

    def test_every_name_shares_the_module_domain_prefix(self) -> None:
        # chelis §7.1 rejects a shared prefix that is not the module's own
        # shorthand, and the style gate runs before the build.
        for name, *_ in self.spec:
            self.assertTrue(name.startswith("acc_"), name)


class GoverningParameter(unittest.TestCase):
    """The range is indexed on the LARGE parameter. Indexing it on the small one
    is the defect a red-team round found: for `student_t_cdf` the small parameter
    is always 0.5, so such a range would describe nothing."""

    def test_beta_cases_carry_both_the_large_and_the_small_parameter(self) -> None:
        spec = [s for s in cases() if s[1] == "beta_cdf"]
        self.assertTrue(spec)
        for name, _, expr, large, _, small in spec:
            numbers = [float(v) for v in re.findall(r"cast\(([-\d.e+]+), f32\)", expr)]
            _, a, b = numbers                      # beta_cdf(x, a, b)
            self.assertEqual(large, max(a, b), f"{name}: {expr}")
            if small != float("inf"):
                self.assertEqual(small, min(a, b), f"{name}: {expr}")
            if a != b:
                self.assertNotEqual(large, min(a, b), f"{name} indexed on the small one")

    def test_student_t_is_indexed_on_df_not_on_the_constant_half(self) -> None:
        spec = [s for s in cases() if s[1] == "student_t_cdf"]
        self.assertTrue(spec)
        for name, _, expr, large, _, _ in spec:
            self.assertNotEqual(large, 0.5, f"{name}: df, not b")
            self.assertGreaterEqual(large, 1.0)


class Coverage(unittest.TestCase):
    def test_documented_covers_every_export_measured(self) -> None:
        measured = {export for _, export, _, _, _, _ in cases()}
        self.assertEqual(measured, set(DOCUMENTED))

    def test_every_export_has_a_case_inside_its_documented_range(self) -> None:
        inside = {export for _, export, _, large, _, small in cases()
                  if large <= DOCUMENTED[export][0] and small >= DOCUMENTED[export][1]}
        self.assertEqual(inside, set(DOCUMENTED),
                         "an export with no in-range case cannot fail the gate")

    def test_every_export_is_exercised_AT_its_ceiling(self) -> None:
        # Not "within a decade of". The previous version of this test accepted
        # `large >= limit / 10`, so it passed on grids that stopped at 1e8 while
        # the documented ceiling was 3e8 -- and the ceiling was false at 3e8 for
        # two exports. A guard that cannot fail at its own boundary is the defect.
        for export, (ceiling, _, _) in DOCUMENTED.items():
            at = [large for _, e, _, large, _, _ in cases()
                  if e == export and large == ceiling]
            self.assertTrue(at, f"{export} is never evaluated AT {ceiling:g}")

    # `student_t_cdf` and `binomial_cdf` have no user-facing small parameter: the
    # former's beta `b` is structurally 0.5 and the latter's are `n - k` and
    # `k + 1`, both at least 1 for any legal `k`. Exempted by name, with the
    # next test covering what they do have instead.
    NO_USER_FACING_FLOOR = {"student_t_cdf", "binomial_cdf"}

    def test_every_export_is_exercised_AT_its_floor(self) -> None:
        for export, (_, floor, _) in DOCUMENTED.items():
            if export in self.NO_USER_FACING_FLOOR:
                continue
            at = [small for _, e, _, _, _, small in cases()
                  if e == export and small == floor]
            self.assertTrue(at, f"{export} is never evaluated AT the floor {floor:g}")

    def test_binomial_is_exercised_at_its_own_smallest_beta_parameter(self) -> None:
        # k = n - 1 makes the beta parameter `n - k` exactly 1.
        spec = [s for s in cases() if s[1] == "binomial_cdf"]
        self.assertTrue(spec)
        extremes = []
        for _, _, expr, _, _, _ in spec:
            numbers = [float(v) for v in re.findall(r"cast\(([-\d.e+]+), f32\)", expr)]
            k, n, _ = numbers
            if n - k == 1.0:
                extremes.append(expr)
        self.assertTrue(extremes, "no binomial case has n - k == 1")

    def test_the_range_is_not_silently_widened(self) -> None:
        # A future edit that relaxes either edge has to change docs/book and
        # SKILL.md too; this pins what those documents currently state.
        for export, (ceiling, floor, bound) in DOCUMENTED.items():
            self.assertEqual(ceiling, 1e8, export)
            self.assertEqual(floor, 1.0, export)
            self.assertEqual(bound, 2e-6, export)
        self.assertEqual((CEILING, FLOOR, BOUND), (1e8, 1.0, 2e-6))


class ThresholdLocusCoverage(unittest.TestCase):
    """The branch threshold `x = (a+1)/(a+b+2)` is where the continued fraction
    converges slowest and the error peaks. Leaving it out of the grid is what
    made the documented range false in review round 3, and the ceiling and floor
    each got an "AT its own value" guard for the same reason — this is that guard
    for the locus.

    These assert the *output* rather than calling the derivation helpers. A
    silently broken `f_x_at_threshold` or `t_at_boundary` would still produce
    cases, just not on the locus, and only an output check catches that. The
    thresholds below are recomputed here independently of the script.
    """

    ULPS = 8

    @staticmethod
    def _near(a: float, b: float, tol_ulps: int = 8) -> float:
        import struct as _s
        bits = _s.unpack("<I", _s.pack("<f", a))[0]
        other = _s.unpack("<I", _s.pack("<f", b))[0]
        return abs(bits - other) <= tol_ulps

    def setUp(self) -> None:
        self.spec = cases()

    def _numbers(self, expr: str) -> list[float]:
        return [float(v) for v in re.findall(r"cast\(([-\d.e+]+), f32\)", expr)]

    def test_beta_cases_reach_the_branch_threshold(self) -> None:
        by_params: dict[tuple[float, float], list[float]] = {}
        for _, export, expr, _, _, _ in self.spec:
            if export != "beta_cdf":
                continue
            x, a, b = self._numbers(expr)
            by_params.setdefault((a, b), []).append(x)
        self.assertTrue(by_params)
        # Not every pair needs a threshold case -- the mid-range locus adds pairs
        # for a different purpose. What matters is that the locus is exercised,
        # and that it is exercised at the hard corner: the ceiling.
        on_locus = {(a, b) for (a, b), xs in by_params.items()
                    if any(self._near(x, f32((a + 1.0) / (a + b + 2.0)), self.ULPS)
                           for x in xs)}
        self.assertGreater(len(on_locus), 10,
                           f"only {len(on_locus)} (a,b) pairs sit on the threshold")
        corners = [(CEILING, CEILING), (CEILING, FLOOR), (FLOOR, CEILING)]
        for corner in corners:
            self.assertIn(corner, on_locus,
                          f"the threshold is never evaluated at {corner}")

    def test_f_cases_reach_the_branch_threshold_in_u(self) -> None:
        by_params: dict[tuple[float, float], list[float]] = {}
        for _, export, expr, _, _, _ in self.spec:
            if export != "f_cdf":
                continue
            x, d1, d2 = self._numbers(expr)
            by_params.setdefault((d1, d2), []).append(x)
        self.assertTrue(by_params)
        on_locus = set()
        for (d1, d2), xs in by_params.items():
            a, b = d1 / 2.0, d2 / 2.0
            thr = (a + 1.0) / (a + b + 2.0)
            us = [d1 * x / (d1 * x + d2) for x in xs]
            if any(abs(u - thr) <= 1e-6 * max(thr, 1e-12) for u in us):
                on_locus.add((d1, d2))
        self.assertGreater(len(on_locus), 10,
                           f"only {len(on_locus)} (d1,d2) pairs sit on the threshold")
        # d2 = 2 makes the beta parameter exactly 1.0 -- the beta-space floor,
        # and where round 4 found f_cdf's peak. The previous lists skipped it.
        self.assertTrue(any(d2 == 2.0 for _, d2 in on_locus),
                        "f_cdf never evaluates the threshold at d2 = 2")
        self.assertTrue(any(d1 == CEILING for d1, _ in on_locus),
                        "f_cdf never evaluates the threshold at the ceiling")

    def test_student_t_cases_reach_the_branch_boundary(self) -> None:
        by_df: dict[float, list[float]] = {}
        for _, export, expr, large, _, _ in self.spec:
            if export != "student_t_cdf":
                continue
            t, df = self._numbers(expr)
            by_df.setdefault(df, []).append(abs(t))
        self.assertTrue(by_df)
        hit = 0
        for df, ts in by_df.items():
            boundary = f32(math.sqrt(3.0 * df / (df + 2.0)))
            if any(self._near(t, boundary, self.ULPS) for t in ts):
                hit += 1
        # the three normal-limit df values carry no boundary case by design
        self.assertGreaterEqual(hit, len(by_df) - 3,
                                f"only {hit} of {len(by_df)} df values are evaluated "
                                f"ON the branch boundary")

    def test_binomial_cases_reach_its_own_threshold(self) -> None:
        # binomial's beta call is I_{1-p}(n-k, k+1), so its threshold is
        # p* = (k+1)/(n+2).
        hits = 0
        for _, export, expr, _, _, _ in self.spec:
            if export != "binomial_cdf":
                continue
            k, n, p = self._numbers(expr)
            star = (k + 1.0) / (n + 2.0)
            if abs(p - star) <= 1e-5 * max(star, 1e-12):
                hits += 1
        self.assertGreater(hits, 0, "no binomial case sits on p* = (k+1)/(n+2)")

    def test_every_export_has_a_mid_range_case(self) -> None:
        """Relative error is only meaningful where the value is neither saturated
        nor tiny, and round 4 found the true peak in that region rather than on
        the branch switch."""
        for export in DOCUMENTED:
            mid = [r for _, e, _, _, r, _ in self.spec
                   if e == export and 0.02 < r < 0.98]
            self.assertTrue(mid, f"{export} has no case with a mid-range value")


class ReferenceFreeAnchors(unittest.TestCase):
    def test_symmetric_beta_and_f_cases_use_the_exact_half(self) -> None:
        anchors = [s for s in cases()
                   if s[1] in {"beta_cdf", "f_cdf"} and s[4] == 0.5
                   and re.search(r"cast\(([-\d.e+]+), f32\), cast\(\1, f32\)", s[2])]
        self.assertTrue(anchors, "the symmetry anchors are gone")

    def test_the_largest_df_cases_use_the_normal_limit(self) -> None:
        normals = [s for s in cases() if s[1] == "student_t_cdf" and s[4] == PHI1]
        self.assertTrue(normals, "no case checks student_t against the normal limit")
        # and they are the ones past where scipy's own betainc saturates
        for _, _, _, large, _, _ in normals:
            self.assertGreaterEqual(large, 1e9)


class F32(unittest.TestCase):
    def test_f32_rounds_like_the_compiler(self) -> None:
        self.assertEqual(f32(0.99999994), 0.9999999403953552)
        self.assertEqual(f32(1e8) + 1.0, 100000001.0)   # the f64 sum is exact


if __name__ == "__main__":
    unittest.main()
