#!/usr/bin/env python3
"""Unit tests for the beta-family C-lane oracle's detection logic.

The end-to-end run against the compiler is the gate itself and is not
duplicated here. What these cover is the part that decides whether the gate can
*fail*: a gate whose checks cannot fire is an assertion dressed as an oracle.

Each test flips exactly one thing and requires the check to fire, and the
`StaysSilent` cases are the controls on those controls -- the seeds below give
every case a distinct value on purpose, because an earlier version of these
controls seeded them all to the same number and so "mutated" a value to itself,
detecting nothing while appearing to pass.
"""

from __future__ import annotations

import unittest

from check_beta_c_lane import (
    CASES,
    LaneError,
    SYMMETRIC,
    SYM_TOL,
    check_anchors,
    compare,
    probe_source,
    values,
)


def seed() -> dict[str, str]:
    """One distinct value per case, with the anchors at their true values."""
    out = {name: f"0.{index + 1:06d}" for index, (name, _) in enumerate(CASES)}
    for name in SYMMETRIC:
        out[name] = "0.5"
    out["lane_nan"] = "NaN"
    return out


class Seed(unittest.TestCase):
    def test_every_case_has_a_distinct_value(self) -> None:
        values_seen = [v for k, v in seed().items() if k not in SYMMETRIC and k != "lane_nan"]
        self.assertEqual(len(values_seen), len(set(values_seen)),
                         "the seed must not repeat a value, or a mutation can be a no-op")

    def test_the_seed_itself_passes_every_check(self) -> None:
        check_anchors(seed(), "seed")
        compare(seed(), seed(), "a", "b")


class Anchors(unittest.TestCase):
    """`beta_cdf(0.5, a, a)` and `f_cdf(1, d, d)` are 0.5 exactly, by symmetry."""

    def test_a_grossly_wrong_anchor_fires(self) -> None:
        bad = seed()
        bad["lane_sym_beta"] = "0.99934489"   # what f32 returned before nautilus#143
        with self.assertRaises(LaneError) as caught:
            check_anchors(bad, "probe")
        self.assertIn("by symmetry", str(caught.exception))

    def test_an_anchor_just_outside_tolerance_fires(self) -> None:
        bad = seed()
        bad["lane_sym_f"] = f"{0.5 + SYM_TOL * 4:.8f}"
        with self.assertRaises(LaneError):
            check_anchors(bad, "probe")

    def test_an_anchor_inside_tolerance_stays_silent(self) -> None:
        ok = seed()
        ok["lane_sym_f"] = f"{0.5 + SYM_TOL / 4:.8f}"
        check_anchors(ok, "probe")

    def test_a_missing_anchor_fires(self) -> None:
        bad = seed()
        del bad["lane_sym_beta"]
        with self.assertRaises(LaneError):
            check_anchors(bad, "probe")


class RangeGuard(unittest.TestCase):
    """A regularised incomplete beta outside [0, 1] must come back as NaN."""

    def test_a_negative_probability_fires(self) -> None:
        bad = seed()
        bad["lane_nan"] = "-0.41600209"   # what the raw computation produces there
        with self.assertRaises(LaneError) as caught:
            check_anchors(bad, "probe")
        self.assertIn("range guard", str(caught.exception))

    def test_an_in_range_number_where_nan_is_required_fires(self) -> None:
        bad = seed()
        bad["lane_nan"] = "0.39412470"
        with self.assertRaises(LaneError):
            check_anchors(bad, "probe")


class CrossLane(unittest.TestCase):
    def test_a_single_disagreement_fires(self) -> None:
        a, b = seed(), seed()
        self.assertNotEqual(b["lane_t_sat"], "0.5", "the mutation must change the value")
        b["lane_t_sat"] = "0.5"
        self.assertNotEqual(a["lane_t_sat"], b["lane_t_sat"])
        with self.assertRaises(LaneError) as caught:
            compare(a, b, "eval lane", "C lane")
        self.assertIn("lane_t_sat", str(caught.exception))

    def test_a_last_digit_disagreement_fires(self) -> None:
        a, b = seed(), seed()
        a["lane_beta"], b["lane_beta"] = "0.57982504", "0.57982510"
        with self.assertRaises(LaneError):
            compare(a, b, "eval lane", "C lane")

    def test_a_value_missing_from_one_lane_fires(self) -> None:
        a, b = seed(), seed()
        del b["lane_f"]
        with self.assertRaises(LaneError) as caught:
            compare(a, b, "eval lane", "C lane")
        self.assertIn("lane_f", str(caught.exception))

    def test_identical_lanes_stay_silent(self) -> None:
        compare(seed(), seed(), "eval lane", "C lane")


class Parsing(unittest.TestCase):
    def test_values_reads_the_eval_and_executable_format(self) -> None:
        parsed = values("lane_beta = 0.57982504\nlane_nan = NaN\nignored line\n")
        self.assertEqual(parsed, {"lane_beta": "0.57982504", "lane_nan": "NaN"})

    def test_values_ignores_a_name_outside_the_probe_namespace(self) -> None:
        self.assertEqual(values("other = 1.0\n"), {})


class Probe(unittest.TestCase):
    def test_the_probe_declares_every_case_and_nothing_else(self) -> None:
        source = probe_source("Nautilus.LaneBeta")
        for name, expression in CASES:
            self.assertIn(f"def {name}() -> f32 = {expression}", source)
        self.assertEqual(source.count("def "), len(CASES))

    def test_the_module_name_and_the_prefix_agree(self) -> None:
        # chelis §7.1 rejects a shared prefix that is not the module's own
        # domain shorthand, and the style gate runs before the build.
        source = probe_source("Nautilus.LaneBeta")
        self.assertTrue(all(name.startswith("lane_") for name, _ in CASES))
        self.assertIn("module Nautilus.LaneBeta", source)


if __name__ == "__main__":
    unittest.main()
