#!/usr/bin/env python3
"""Unit tests for the gamma-family C-lane oracle's detection logic.

The end-to-end run against the compiler is the gate itself and is not
duplicated here. What these cover is the part that decides whether the gate can
*fail*: a gate whose checks cannot fire is an assertion dressed as an oracle.

Each test flips exactly one thing and requires the check to fire, and the
`StaysSilent` cases are the controls on those controls. Every seeded value is
distinct on purpose: the sibling beta tests record a version whose controls
seeded every case to the same number, so a "mutation" set a value to itself and
detected nothing while appearing to pass.

The values this file mutates *to* are mostly the ones the f32 lane actually
returned before nautilus#152, so each test states what the anchor would have
caught rather than an invented number.
"""

from __future__ import annotations

import math
import unittest

from check_gamma_c_lane import (
    CASES,
    CLOSED_FORMS,
    CLOSED_TOL,
    GAP_LAMBDA,
    GAP_TOL,
    MEDIAN_PAIRS,
    LaneError,
    check_anchors,
    compare,
    probe_source,
    values,
)

EXPECTED_GAP = 1.0 / math.sqrt(2.0 * math.pi * GAP_LAMBDA)


def seed() -> dict[str, str]:
    """One distinct value per case, with every anchor at a passing value."""
    out = {name: f"0.{index + 1:06d}" for index, (name, _) in enumerate(CASES)}
    for name, value in CLOSED_FORMS.items():
        out[name] = repr(value)
    for high, low in MEDIAN_PAIRS:
        out[high] = "0.5000188"
        out[low] = "0.4997340"
    # The gap anchor: poisson_cdf must exceed gamma_sf by poisson_pmf.
    out["lane_sf_big"] = "0.49998119"
    out["lane_pois_big"] = repr(0.49998119 + EXPECTED_GAP)
    return out


class Seed(unittest.TestCase):
    def test_every_anchor_free_case_has_a_distinct_value(self) -> None:
        anchored = set(CLOSED_FORMS) | {"lane_sf_big", "lane_pois_big"}
        for high, low in MEDIAN_PAIRS:
            anchored |= {high, low}
        seen = [v for k, v in seed().items() if k not in anchored]
        self.assertEqual(len(seen), len(set(seen)),
                         "the seed must not repeat a value, or a mutation can be a no-op")

    def test_the_seed_itself_passes_every_check(self) -> None:
        check_anchors(seed(), "seed")
        compare(seed(), seed(), "a", "b")

    def test_every_case_is_reached_by_an_anchor_or_by_cross_lane_comparison(self) -> None:
        # Not every row needs an anchor -- the ordinary rows exist to be
        # compared across lanes -- but every row must be in CASES, or the
        # probe would not declare it and `compare` would never see it.
        names = {name for name, _ in CASES}
        for anchored in set(CLOSED_FORMS) | {"lane_sf_big", "lane_pois_big"}:
            self.assertIn(anchored, names, anchored)
        for high, low in MEDIAN_PAIRS:
            self.assertIn(high, names)
            self.assertIn(low, names)


class ClosedForms(unittest.TestCase):
    """Shape 1 and 2 are elementary, so these need no reference library."""

    def test_a_grossly_wrong_closed_form_fires(self) -> None:
        bad = seed()
        bad["lane_pdf_two"] = "0.5"
        with self.assertRaises(LaneError) as caught:
            check_anchors(bad, "probe")
        self.assertIn("closed form", str(caught.exception))

    def test_the_f32_lanes_shape_2_value_does_NOT_fire(self) -> None:
        """And that is the point of the two anchor kinds after this one.

        At shape 2 the f32 front factor had nothing to cancel, so the lane this
        change replaces was already correct to 4.7e-7 here -- inside
        CLOSED_TOL. Asserting the non-detection keeps a later reader from
        mistaking these elementary anchors for the ones that catch the defect.
        That mistake was in this harness's own docstring until this test
        failed.
        """
        f32_lane = seed()
        f32_lane["lane_pdf_two"] = "0.27067044"
        check_anchors(f32_lane, "probe")
        exact = CLOSED_FORMS["lane_pdf_two"]
        self.assertLess(abs(0.27067044 - exact) / exact, CLOSED_TOL)

    def test_a_value_just_outside_tolerance_fires(self) -> None:
        bad = seed()
        bad["lane_cdf_two"] = repr(CLOSED_FORMS["lane_cdf_two"] * (1 + 2 * CLOSED_TOL))
        with self.assertRaises(LaneError):
            check_anchors(bad, "probe")

    def test_a_value_inside_tolerance_stays_silent(self) -> None:
        ok = seed()
        ok["lane_cdf_two"] = repr(CLOSED_FORMS["lane_cdf_two"] * (1 + CLOSED_TOL / 2))
        check_anchors(ok, "probe")

    def test_a_missing_closed_form_fires(self) -> None:
        bad = seed()
        del bad["lane_inv_ln2"]
        with self.assertRaises(LaneError) as caught:
            check_anchors(bad, "probe")
        self.assertIn("missing", str(caught.exception))

    def test_a_non_numeric_value_fires(self) -> None:
        bad = seed()
        bad["lane_pois_zero"] = "not-a-float"
        with self.assertRaises(LaneError):
            check_anchors(bad, "probe")

    def test_a_nan_fires(self) -> None:
        """`float("NaN")` parses, and this harness did not notice.

        Every comparison against NaN is False, so a NaN row reached
        `relative_error > CLOSED_TOL`, answered False, and passed. It passed
        the gap check for the same reason. This test is why `value` now
        rejects non-finite values explicitly.
        """
        for row in ("lane_pois_zero", "lane_pois_big", "lane_median_hi_6"):
            bad = seed()
            bad[row] = "NaN"
            with self.assertRaises(LaneError, msg=f"NaN in {row} went unnoticed"):
                check_anchors(bad, "probe")

    def test_an_infinity_fires(self) -> None:
        for row in ("lane_inv_ln2", "lane_sf_big"):
            bad = seed()
            bad[row] = "inf"
            with self.assertRaises(LaneError, msg=f"inf in {row} went unnoticed"):
                check_anchors(bad, "probe")


class MedianOrder(unittest.TestCase):
    """P(a, a) > 0.5 > P(a - d, a), for every a and every d >= 1."""

    def test_the_f32_lanes_own_value_fires_on_the_upper_side(self) -> None:
        bad = seed()
        bad[MEDIAN_PAIRS[0][0]] = "0.029631412"   # f32 at shape 1e6
        with self.assertRaises(LaneError) as caught:
            check_anchors(bad, "probe")
        self.assertIn("below its mean", str(caught.exception))

    def test_the_f32_lanes_own_value_fires_on_the_lower_side(self) -> None:
        bad = seed()
        bad[MEDIAN_PAIRS[1][1]] = "0.9993269"     # f32 just under shape 5e7
        with self.assertRaises(LaneError) as caught:
            check_anchors(bad, "probe")
        self.assertIn("Chen-Rubin", str(caught.exception))

    def test_exactly_one_half_fires_on_both_sides(self) -> None:
        # Both anchors are strict, so the boundary itself must not pass: a
        # lane that returned 0.5 for every large shape would otherwise be
        # certified by an anchor that cannot distinguish it.
        for index, side in ((0, 0), (0, 1)):
            bad = seed()
            bad[MEDIAN_PAIRS[index][side]] = "0.5"
            with self.assertRaises(LaneError):
                check_anchors(bad, "probe")


class Gap(unittest.TestCase):
    """poisson_cdf(k, lam) - gamma_sf(lam, k, 1) = poisson_pmf(k, lam) > 0."""

    def test_a_zero_gap_fires(self) -> None:
        # Exactly what the lost f32 `k + 1` produced: both expressions
        # returned the identical value.
        bad = seed()
        bad["lane_pois_big"] = bad["lane_sf_big"]
        with self.assertRaises(LaneError) as caught:
            check_anchors(bad, "probe")
        self.assertIn("strictly positive", str(caught.exception))

    def test_a_negative_gap_fires(self) -> None:
        bad = seed()
        bad["lane_pois_big"] = repr(float(bad["lane_sf_big"]) - EXPECTED_GAP)
        with self.assertRaises(LaneError):
            check_anchors(bad, "probe")

    def test_a_gap_of_the_wrong_size_fires(self) -> None:
        # Positive but not poisson_pmf: a `k + 2` would look like this.
        bad = seed()
        bad["lane_pois_big"] = repr(float(bad["lane_sf_big"]) + 3 * EXPECTED_GAP)
        with self.assertRaises(LaneError) as caught:
            check_anchors(bad, "probe")
        self.assertIn("sqrt", str(caught.exception))

    def test_a_gap_inside_tolerance_stays_silent(self) -> None:
        ok = seed()
        ok["lane_pois_big"] = repr(float(ok["lane_sf_big"])
                                   + EXPECTED_GAP * (1 + GAP_TOL / 2))
        check_anchors(ok, "probe")


class CrossLane(unittest.TestCase):
    def test_a_single_disagreement_fires(self) -> None:
        other = seed()
        other["lane_cdf_small"] = "0.123456"
        with self.assertRaises(LaneError) as caught:
            compare(seed(), other, "eval", "C")
        self.assertIn("lane_cdf_small", str(caught.exception))

    def test_a_last_digit_disagreement_fires(self) -> None:
        # Agreement is required bit for bit, so a one-ulp difference between
        # the lanes is a finding and not a rounding.
        other = seed()
        other["lane_inv_big"] = other["lane_inv_big"] + "1"
        with self.assertRaises(LaneError):
            compare(seed(), other, "eval", "C")

    def test_a_value_missing_from_one_lane_fires(self) -> None:
        other = seed()
        del other["lane_chi_inv"]
        with self.assertRaises(LaneError) as caught:
            compare(seed(), other, "eval", "C")
        self.assertIn("missing", str(caught.exception))

    def test_identical_lanes_stay_silent(self) -> None:
        compare(seed(), seed(), "eval", "C")


class Probe(unittest.TestCase):
    def test_values_reads_the_eval_and_executable_format(self) -> None:
        parsed = values("lane_cdf_two = 0.59399414\nlane_sf_two = 0.40600586\n")
        self.assertEqual(parsed,
                         {"lane_cdf_two": "0.59399414", "lane_sf_two": "0.40600586"})

    def test_values_ignores_a_name_outside_the_probe_namespace(self) -> None:
        self.assertEqual(values("other_thing = 1.0\n"), {})

    def test_the_probe_declares_every_case_and_nothing_else(self) -> None:
        source = probe_source("Nautilus.LaneGamma")
        for name, _ in CASES:
            self.assertIn(f"def {name}() -> f32 =", source, name)
        self.assertEqual(source.count("def "), len(CASES))

    def test_the_module_name_and_the_prefix_agree(self) -> None:
        # chelis section 7.1 rejects a shared prefix that is not the module's
        # own domain shorthand, and the style gate runs before the build.
        source = probe_source("Nautilus.LaneGamma")
        self.assertIn("module Nautilus.LaneGamma", source)
        for name, _ in CASES:
            self.assertTrue(name.startswith("lane_"), name)

    def test_the_probe_imports_every_export_it_calls(self) -> None:
        source = probe_source("Nautilus.LaneGamma")
        imported = source.split("import Nautilus.Distributions (")[1].split(")")[0]
        declared = {part.strip() for part in imported.split(",")}
        for _, expression in CASES:
            called = expression.split("(")[0]
            self.assertIn(called, declared, f"{called} is called but not imported")


if __name__ == "__main__":
    unittest.main()
