#!/usr/bin/env python3
"""Unit tests for the incomplete-gamma accuracy oracle's bookkeeping.

The measurement itself is the gate and needs the compiler, so it is not
duplicated here. These cover the parts that silently decide what the gate sees:
the generated identifiers, the argument spellings, and the coverage of the
documented table.

Several pin a defect that happened while the sibling oracles were written, and
which would have been just as easy to make here.
`test_every_export_is_exercised_AT_its_ceiling` exists because a bound indexed
on a parameter the grid never reaches at its stated value cannot fail at its own
boundary -- the sibling beta range was false at its own edge for exactly that
reason. `test_the_branch_point_is_probed_for_every_shape` exists because this
defect lives at `x ~ shape` and nowhere else: the broken f32 lane was 2.8e-8
relative at `x = 1.05*shape` while being 4.4e-2 at `x = shape`, so a grid that
drifted off the branch point would have measured a healthy lane.
`test_the_walk_is_not_silently_narrowed` and
`test_the_scale_set_is_not_silently_narrowed` exist because every coverage test
below is indexed on the tuple it is checking, so shrinking the tuple shrinks the
expectation and they all stay green -- a review round proved that on the PMF
gate by reducing its probability set to one element and watching seventeen tests
pass.
"""

from __future__ import annotations

import re
import unittest

from parity.check_gamma_accuracy import (
    BEYOND,
    MP_DPS,
    QUANTILE_FLOOR,
    QUANTILE_FLOOR_SHAPES,
    DOCUMENTED,
    F32_MIN_NORMAL,
    QUANTILES,
    SCALES,
    THIN_ABOVE,
    Z_THIN,
    Z_WALK,
    cases,
    f32,
    lit,
    references,
    shape_ladder,
)

IDENTIFIER = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")
CALL = re.compile(r"^(\w+)\((.*)\)$")

# `cases()` builds every reference at arbitrary precision, which costs about
# twelve seconds for the whole grid. Building it once per test method instead of
# once per run turned this file from under two seconds into over five minutes,
# so the grid is built once and shared. Nothing here mutates it.
_SPEC: list | None = None


# Tolerances for the oracle checks below, derived from the reference's own
# working precision rather than written as literals, so they cannot go stale if
# that precision moves. At MP_DPS = 30 they are 1e-22, 1e-18 and 1e-13 against
# the 2e-6 the gate measures -- sixteen, twelve and seven orders of magnitude
# below it. Seven is the smallest margin and it belongs to the root finder,
# whose residual is bounded by its own step; none of the three is ever the
# binding term in a gate result.
#
# They differ from each other because the routes differ. Two recursions that
# both converge to MP_TOL agree to a few digits short of the working precision.
# `mpmath.quad` is numerical integration and is looser than either. And the
# root finder stops once a Newton step moves its estimate by less than
# 10**-(MP_DPS - 12) of itself, so the residual it leaves in `P` is that step
# multiplied by `P`'s slope -- bounding the residual tighter than the step that
# produced it is not a stricter test, it is an impossible one, and asserting
# 1e-25 against a 1e-18 step is the mistake these three tests caught on their
# first run.
REF_AGREE = 10.0 ** -(MP_DPS - 8)
REF_QUAD = 10.0 ** -(MP_DPS - 12)
REF_ROOT = 10.0 ** -(MP_DPS - 17)


def spec_once() -> list:
    global _SPEC
    if _SPEC is None:
        _SPEC = cases()
    return _SPEC

# No scipy guard here on purpose. This file lives under `parity/`, where SciPy is
# a declared, locked dependency, so an ImportError is a broken environment and
# should fail loudly. A `skipUnless` would turn that into a silent pass, and a
# test skipped everywhere is indistinguishable from a passing one.

GAMMA_OF_X = ("gamma_cdf", "gamma_sf", "gamma_pdf")
CHI_OF_X = ("chi_squared_cdf", "chi_squared_sf", "chi_squared_pdf")
QUANTILE_EXPORTS = ("gamma_inv_cdf", "chi_squared_inv_cdf")


def arguments(expression: str) -> list[float]:
    """The f32 values the probe will hold, not the decimals that spell them.

    `lit` emits the shortest decimal that round-trips, so `1e-07` reads back as
    the f64 1e-07 while the probe holds f32(1e-7). Comparing the decimal is how
    the sibling gate's parameter-coverage test first failed against its own grid.
    """
    body = CALL.match(expression).group(2)
    return [f32(float(part)) for part in body.split(", ")]


class Names(unittest.TestCase):
    def setUp(self) -> None:
        self.spec = spec_once()

    def test_every_generated_name_is_a_valid_identifier(self) -> None:
        for name, *_ in self.spec:
            self.assertRegex(name, IDENTIFIER, f"{name!r} is not a usable def name")

    def test_no_name_contains_a_character_the_lexer_reads_as_a_literal(self) -> None:
        for name, *_ in self.spec:
            for bad in "+-.":
                self.assertNotIn(bad, name, f"{name!r} would not lex")

    def test_names_are_unique(self) -> None:
        names = [case[0] for case in self.spec]
        self.assertEqual(len(names), len(set(names)))

    def test_every_name_shares_the_module_domain_prefix(self) -> None:
        for name, *_ in self.spec:
            self.assertTrue(name.startswith("acc_"), name)


class Spelling(unittest.TestCase):
    def test_every_literal_round_trips_to_the_f32_it_names(self) -> None:
        for value in (0.5, 2.5, 0.0078125, 0.001, 0.999, 1e-7, 5e7, 1e9,
                      2.0 ** 24, 1.0, 0.0):
            self.assertEqual(f32(float(lit(value))), f32(value), repr(value))

    def test_an_integral_value_is_spelled_as_a_float(self) -> None:
        # A digit string with no "." or "e" lexes as an integer literal, which
        # is an i32 at these call sites and fails to type-check.
        for value in (0.0, 1.0, 10.0, 100.0, 5e7, 2.0 ** 24):
            text = lit(value)
            self.assertTrue("." in text or "e" in text, f"{value!r} -> {text!r}")

    def test_every_generated_expression_parses_as_a_call(self) -> None:
        for _, export, expression, *_ in spec_once():
            matched = CALL.match(expression)
            self.assertIsNotNone(matched, expression)
            self.assertEqual(matched.group(1), export, expression)


class Coverage(unittest.TestCase):
    def setUp(self) -> None:
        self.spec = spec_once()

    def test_documented_covers_every_export_measured(self) -> None:
        self.assertEqual({case[1] for case in self.spec}, set(DOCUMENTED))

    def test_every_export_named_in_the_issue_is_measured(self) -> None:
        # nautilus#152's "Affected exports" list, plus `gamma_pdf`, which has
        # the same front factor and which the issue body did not name.
        measured = {case[1] for case in self.spec}
        for export in ("gamma_cdf", "gamma_sf", "chi_squared_cdf",
                       "chi_squared_sf", "poisson_cdf", "gamma_inv_cdf",
                       "chi_squared_inv_cdf", "gamma_pdf", "chi_squared_pdf"):
            self.assertIn(export, measured, export)

    def test_every_export_has_a_case_inside_its_documented_range(self) -> None:
        for export, (ceiling, _) in DOCUMENTED.items():
            inside = [case for case in self.spec
                      if case[1] == export and case[3] <= ceiling]
            self.assertTrue(inside, f"{export} has no in-range case to fail on")

    def test_every_export_is_exercised_AT_its_ceiling(self) -> None:
        for export, (ceiling, _) in DOCUMENTED.items():
            at = [case for case in self.spec
                  if case[1] == export and case[3] == ceiling]
            self.assertTrue(at, f"{export} is never probed at {ceiling:.0e}")

    def test_every_export_is_exercised_BEYOND_its_ceiling(self) -> None:
        # The documents claim the error grows past the ceiling. That claim is
        # measured, not asserted, so the run has to carry out-of-range rows.
        for export, (ceiling, _) in DOCUMENTED.items():
            beyond = [case for case in self.spec
                      if case[1] == export and case[3] > ceiling]
            self.assertTrue(beyond, f"{export} is never probed above {ceiling:.0e}")
            self.assertGreater(BEYOND[export], ceiling, export)

    def test_the_branch_point_is_probed_for_every_shape(self) -> None:
        # `x = shape*scale` is where the three terms of the front factor cancel
        # and where both recursions are slowest. It is the whole defect: off it
        # the broken lane measured 2.8e-8 and on it 4.4e-2.
        for export in GAMMA_OF_X:
            ceiling, _ = DOCUMENTED[export]
            for shape in shape_ladder(ceiling, BEYOND[export]):
                rows = [arguments(case[2]) for case in self.spec
                        if case[1] == export and case[3] == shape]
                if not rows:
                    continue  # every reference at this shape was out of f32 range
                self.assertTrue(
                    any(x == f32(f32(k) * f32(s)) for x, k, s in rows),
                    f"{export} at shape {shape:.3g} never reaches x = shape*scale")

    def test_both_sides_of_the_branch_are_probed(self) -> None:
        # The implementation runs a series below `shape*scale + scale` and a
        # continued fraction at or above it. A grid on one side only would
        # leave one of the two recursions unmeasured.
        for export in GAMMA_OF_X:
            rows = [arguments(case[2]) for case in self.spec if case[1] == export]
            below = any(x < f32(k) * f32(s) for x, k, s in rows)
            above = any(x > f32(k) * f32(s) for x, k, s in rows)
            self.assertTrue(below, f"{export} never probes below the branch point")
            self.assertTrue(above, f"{export} never probes above the branch point")

    def test_every_scale_is_actually_probed(self) -> None:
        probed = {arguments(case[2])[2] for case in self.spec
                  if case[1] in GAMMA_OF_X}
        for scale in SCALES:
            self.assertIn(f32(scale), probed,
                          f"scale = {scale!r} is in SCALES but reaches no case")

    def test_every_quantile_is_actually_probed(self) -> None:
        probed = {arguments(case[2])[0] for case in self.spec
                  if case[1] in QUANTILE_EXPORTS}
        for q in QUANTILES:
            self.assertIn(f32(q), probed,
                          f"q = {q!r} is in QUANTILES but reaches no case")

    def test_both_quantile_tails_are_probed(self) -> None:
        # The Wilson-Hilferty start is weakest in the far tails, which is where
        # the Newton refinement had the most to undo.
        for export in QUANTILE_EXPORTS:
            probed = {arguments(case[2])[0] for case in self.spec
                      if case[1] == export}
            self.assertTrue(any(q <= f32(0.001) for q in probed), export)
            self.assertTrue(any(q >= f32(0.999) for q in probed), export)

    def test_the_two_to_the_24_neighbourhood_is_probed_for_poisson(self) -> None:
        # Above k = 2^24 the f32 `k + 1` lost its increment, so `poisson_cdf`
        # evaluated the wrong gamma shape.
        counts = {arguments(case[2])[0] for case in self.spec
                  if case[1] == "poisson_cdf"}
        self.assertIn(f32(2.0 ** 24), counts)
        self.assertTrue(any(count > 2.0 ** 24 for count in counts))

    def test_no_case_carries_a_reference_f32_cannot_hold(self) -> None:
        for _, export, expression, _, reference in self.spec:
            self.assertGreaterEqual(reference, F32_MIN_NORMAL, expression)
            if export in ("gamma_cdf", "gamma_sf", "chi_squared_cdf",
                          "chi_squared_sf", "poisson_cdf"):
                # A probability of exactly 1.0 has no relative resolution. A
                # density and a quantile are not probabilities and are exempt.
                self.assertLess(reference, 1.0, expression)

    def test_the_grid_is_large_enough_to_be_a_grid(self) -> None:
        # A guard against a filter silently emptying an export's rows, which is
        # how the sibling gate lost every skewed probability.
        for export in DOCUMENTED:
            rows = [case for case in self.spec if case[1] == export]
            self.assertGreaterEqual(len(rows), 12, f"{export} has {len(rows)} cases")

    def test_the_walk_is_not_silently_narrowed(self) -> None:
        self.assertEqual(Z_WALK, (-20.0, -8.0, -5.0, -3.0, -1.0, 0.0, 1.0, 3.0,
                                  5.0, 8.0, 20.0))
        self.assertEqual(Z_THIN, (-3.0, -1.0, 0.0, 1.0, 5.0))
        self.assertIn(0.0, Z_WALK)
        self.assertIn(0.0, Z_THIN)
        self.assertEqual(THIN_ABOVE, 1e6)

    def test_the_scale_set_is_not_silently_narrowed(self) -> None:
        self.assertEqual(SCALES, (1.0, 2.5, 0.0078125))

    def test_the_quantile_set_is_not_silently_narrowed(self) -> None:
        self.assertEqual(QUANTILES, (QUANTILE_FLOOR, 0.001, 0.01, 0.1, 0.25,
                                     0.5, 0.75, 0.9, 0.99, 0.999))
        self.assertEqual(QUANTILE_FLOOR, 1e-4)
        self.assertEqual(QUANTILE_FLOOR_SHAPES, (1.1, 1.25, 1.5, 1.9, 2.0, 2.5))

    def test_the_documented_q_floor_is_probed_AT_its_value(self) -> None:
        """The same rule as the ceilings, on the other axis.

        The documents exclude `q` below `QUANTILE_FLOOR` because the quantile's
        Newton descent does not converge there for a shape near 2. An excluded
        boundary still has to be measured AT the boundary, or the claim cannot
        fail at its own edge -- which is how the first version of this gate came
        to assert a bound that was false three decades below its smallest `q`.
        """
        for export in QUANTILE_EXPORTS:
            at = [case for case in self.spec
                  if case[1] == export
                  and arguments(case[2])[0] == f32(QUANTILE_FLOOR)]
            self.assertTrue(at, f"{export} is never probed at q = "
                                f"{QUANTILE_FLOOR:.0e}, its documented floor")

    def test_no_case_is_generated_below_the_documented_q_floor(self) -> None:
        # The documents make no claim below the floor, so a row there would be
        # the gate asserting something nothing stands behind.
        for export in QUANTILE_EXPORTS:
            below = [case[2] for case in self.spec
                     if case[1] == export
                     and arguments(case[2])[0] < f32(QUANTILE_FLOOR)]
            self.assertEqual(below, [], f"{export} probes below its floor")

    def test_the_floored_wilson_hilferty_shapes_are_probed(self) -> None:
        # Shapes where `s**3` goes negative and the start is floored. Without a
        # row here, raising `gamma_inv_floor()` to the continued fraction's
        # Lentz tiny passed the whole test suite, the C lane and this gate
        # while sending `gamma_inv_cdf(0.001, 1.25, 2)` to +inf.
        probed = {arguments(case[2])[1] for case in self.spec
                  if case[1] == "gamma_inv_cdf"}
        for shape in QUANTILE_FLOOR_SHAPES:
            self.assertIn(f32(shape), probed,
                          f"gamma_inv_cdf is never probed at shape {shape}")

    def test_the_probe_imports_every_export_it_calls(self) -> None:
        """Caught a real break: `chi_squared_pdf` was added to the grid and not
        to the probe's import line, so every one of its rows failed to compile
        and the whole run aborted with `unbound variable`. A loud failure, but
        one a unit test is cheaper than an eight-minute gate run.
        """
        from parity.check_gamma_accuracy import MODULE, PROBE, evaluate
        import unittest.mock as mock
        captured = {}

        def fake_run(command, **kwargs):
            captured["source"] = PROBE.read_text()
            raise RuntimeError("stop before invoking the compiler")

        with mock.patch("subprocess.run", fake_run):
            try:
                evaluate("chelis", self.spec[:5])
            except Exception:
                pass
        source = captured.get("source", "")
        self.assertTrue(source, "the probe was never written")
        imported = source.split("import Nautilus.Distributions (")[1].split(")")[0]
        declared = {part.strip() for part in imported.split(",")}
        for export in DOCUMENTED:
            self.assertIn(export, declared,
                          f"{export} is measured but the probe does not import it")

    def test_the_bound_is_not_silently_widened(self) -> None:
        # Pins the table so widening it is a deliberate edit that a reviewer
        # sees, with the documents in the same commit.
        self.assertEqual(DOCUMENTED, {
            "gamma_cdf": (5e7, 2e-6),
            "gamma_sf": (5e7, 2e-6),
            "gamma_pdf": (5e7, 2e-6),
            "chi_squared_cdf": (1e8, 2e-6),
            "chi_squared_sf": (1e8, 2e-6),
            "chi_squared_pdf": (1e8, 2e-6),
            "poisson_cdf": (5e7, 2e-6),
            "gamma_inv_cdf": (1e7, 2e-6),
            "chi_squared_inv_cdf": (2e7, 2e-6),
        })

    def test_the_shape_ladder_reaches_its_ceiling_exactly(self) -> None:
        for export, (ceiling, _) in DOCUMENTED.items():
            ladder = shape_ladder(ceiling, BEYOND[export])
            self.assertIn(ceiling, ladder, export)
            self.assertIn(BEYOND[export], ladder, export)
            self.assertEqual(len(ladder), len(set(ladder)), export)



class Oracle(unittest.TestCase):
    """The reference itself, checked two ways that do not share its algorithm.

    `check_gamma_accuracy.py` spells out the series and the continued fraction
    rather than calling `mpmath.gammainc`, so those recursions are code this
    repository owns and they need their own tests. A reference cannot catch an
    error it makes identically to its subject, and the arithmetic precision is
    only half the argument -- the other half is agreeing with something that
    computes the same quantity a different way.

    Route one is `mpmath.gammainc`, wherever it converges at this working
    precision. Route two is a high-precision quadrature of the density, which
    shares no series with either. Route three is the elementary closed forms at
    shape 1 and 2, which share nothing with anything.
    """

    @classmethod
    def setUpClass(cls) -> None:
        # `staticmethod`, because a plain function assigned to a class attribute
        # becomes a bound method and would be handed `self` as its first
        # argument. Without it every test here fails with a TypeError about
        # argument counts, which reads like a signature change in the gate.
        p, q, pdf, inv = references()
        cls.p = staticmethod(p)
        cls.q = staticmethod(q)
        cls.pdf = staticmethod(pdf)
        cls.inv = staticmethod(inv)

    def test_the_reference_agrees_with_mpmaths_own_incomplete_gamma(self) -> None:
        from mpmath import gammainc, inf, mp, mpf
        mp.dps = MP_DPS
        checked = 0
        for a in (0.5, 2.5, 100.0, 1e4, 1e6):
            for ratio in (0.5, 0.9, 1.0, 1.1, 2.0):
                x = a * ratio
                try:
                    theirs = gammainc(mpf(a), mpf(x), inf, regularized=True)
                except Exception:
                    continue  # their term budget, not our disagreement
                mine = self.q(a, x)
                if theirs <= 0 or theirs >= 1:
                    continue  # no relative resolution to compare at
                error = abs(mine - theirs) / theirs
                self.assertLess(float(error), REF_AGREE,
                                f"Q({a}, {x}): ours {mine} vs mpmath {theirs}")
                checked += 1
        self.assertGreaterEqual(checked, 10, "too few points actually compared")

    def test_the_reference_agrees_with_a_quadrature_of_the_density(self) -> None:
        # Q(a, x) is the integral of the density from x to infinity, which
        # shares no series with the continued fraction or with mpmath's own
        # incomplete gamma. The upper cut is far enough out that the tail
        # beyond it is below the tolerance compared against.
        from mpmath import mp, mpf, quad, sqrt
        mp.dps = MP_DPS
        checked = 0
        for a in (2.5, 100.0, 1e4):
            for ratio in (0.9, 1.0, 1.1):
                A, X = mpf(a), mpf(a * ratio)
                hi = X + 60 * sqrt(A) + 120
                points = [X, hi]
                if X < A - 1 < hi:
                    points = [X, A - 1, hi]
                theirs = quad(lambda t: self.pdf(t, A, 1), points)
                mine = self.q(a, float(X))
                error = abs(mine - theirs) / theirs
                self.assertLess(float(error), REF_QUAD,
                                f"Q({a}, {X}): series {mine} vs quadrature {theirs}")
                checked += 1
        self.assertGreaterEqual(checked, 9)

    def test_the_reference_matches_the_elementary_closed_forms(self) -> None:
        # At shape 1 and 2 the incomplete gamma is elementary and shares
        # nothing at all with the recursions under test.
        from mpmath import exp, mp, mpf
        mp.dps = MP_DPS
        for x in (0.25, 1.0, 2.0, 7.5, 40.0):
            X = mpf(x)
            self.assertLess(float(abs(self.q(1.0, x) - exp(-X)) / exp(-X)),
                            REF_AGREE, f"Q(1, {x}) = exp(-x)")
            two = (1 + X) * exp(-X)
            self.assertLess(float(abs(self.q(2.0, x) - two) / two), REF_AGREE,
                            f"Q(2, {x}) = (1 + x)exp(-x)")
            dens = exp(-X)
            self.assertLess(float(abs(self.pdf(x, 1.0, 1.0) - dens) / dens),
                            REF_AGREE, f"pdf(x; 1, 1) = exp(-x)")

    def test_the_reference_quantile_inverts_the_reference_cdf(self) -> None:
        from mpmath import mp, mpf
        mp.dps = MP_DPS
        for shape in (0.5, 1.0, 10.0, 1e3, 1e5):
            for quantile in (0.001, 0.5, 0.999):
                root = self.inv(shape, quantile)
                back = self.p(shape, float(root))
                error = abs(back - mpf(quantile)) / mpf(quantile)
                self.assertLess(float(error), REF_ROOT,
                                f"inv({shape}, {quantile}) = {root}, P of it is {back}")

    def test_the_reference_quantile_matches_the_closed_form_at_shape_one(self) -> None:
        # At shape 1 the quantile is -log(1 - q), so this pins the root finder
        # against something that is not a root finder.
        from mpmath import log, mp, mpf
        mp.dps = MP_DPS
        for quantile in (0.001, 0.05, 0.5, 0.9, 0.999):
            exact = -log(1 - mpf(quantile))
            root = self.inv(1.0, quantile)
            self.assertLess(float(abs(root - exact) / exact), REF_ROOT,
                            f"inv(1, {quantile}) = {root}, closed form {exact}")

    def test_scipy_is_not_usable_as_this_gates_oracle(self) -> None:
        """Why mpmath is a dependency, as a measurement rather than a sentence.

        If a later change proposes dropping mpmath and referencing SciPy again,
        this is the test that has to be confronted. It asserts the divergence is
        still there and still larger than the bound the gate enforces -- not
        that SciPy is bad, but that `gammainc`'s left tail at a large shape
        cannot adjudicate a 2e-6 claim.
        """
        from scipy.special import gammainc as scipy_lower
        worst = 0.0
        for a, x in ((1e6, 995000.0), (5e7, 5e7 - 5 * 5e7 ** 0.5),
                     (5e7, 5e7 - 8 * 5e7 ** 0.5)):
            mine = self.p(a, x)
            if float(mine) <= F32_MIN_NORMAL:
                continue
            theirs = float(scipy_lower(a, x))
            worst = max(worst, float(abs(theirs - mine) / mine))
        bound = max(b for _, b in DOCUMENTED.values())
        self.assertGreater(worst, bound,
                           f"scipy.special.gammainc's worst error over the three "
                           f"recorded points is {worst:.2e}, no longer above the "
                           f"{bound:.0e} this gate enforces. Re-measure before "
                           f"concluding it has become usable.")


# This has to stay at the END of the file. It sat above the `Oracle` class, so
# `python parity/test_check_gamma_accuracy.py` ran 25 tests, printed OK, and
# silently omitted all six oracle-validation tests -- including
# `test_scipy_is_not_usable_as_this_gates_oracle`, the one that pins why mpmath
# is a dependency at all. CI runs `unittest discover` and saw all 31, so this
# was latent rather than live, and it is exactly the "a skipped test is
# indistinguishable from a passing one" shape this file's docstring warns about.
if __name__ == "__main__":
    unittest.main()
