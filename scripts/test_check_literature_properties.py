"""Keep the literature gate bound to the stated goals and parameter domains."""

import unittest

from check_literature_properties import validate_goal


class LiteratureGoalTests(unittest.TestCase):
    def test_accepts_the_stated_bound(self) -> None:
        validate_goal({
            "name": "uniform_cdf_upper_wrong",
            "goal": "forall(lo: f32, hi: f32) where hi > lo: (Nautilus.Distributions.uniform_cdf(hi, lo, hi) <= 0.9f32)",
        })

    def test_rejects_same_named_tautology(self) -> None:
        with self.assertRaises(AssertionError):
            validate_goal({"name": "uniform_cdf_range", "goal": "(x == x)"})

    def test_rejects_a_changed_domain(self) -> None:
        with self.assertRaises(AssertionError):
            validate_goal({
                "name": "uniform_cdf_upper_wrong",
                "goal": "forall(lo: f32, hi: f32) where hi > lo, lo > 0.0f32: (Nautilus.Distributions.uniform_cdf(hi, lo, hi) <= 0.9f32)",
            })


if __name__ == "__main__":
    unittest.main()
