#!/usr/bin/env python3
"""Unit tests for the discrete-PMF accuracy oracle's bookkeeping.

The measurement itself is the gate and needs the compiler, so it is not
duplicated here. These cover the parts that silently decide what the gate sees:
the generated identifiers, the argument spellings, and the coverage of the
documented table.

Two of these pin a defect that actually happened while the oracle was written.
`test_every_probability_is_actually_probed` exists because a first version
filtered the grid down to arguments exactly representable in f32 -- and `0.2`
and `0.01` are not f32 values, so it silently discarded every skewed `p` and
left the large-`n` claim resting on `p = 0.5` alone. The worst in-range case is
at `p = 0.999999`. `test_every_export_is_exercised_AT_its_ceiling` exists
because a bound indexed on a parameter the grid never reaches at its stated
value cannot fail at its own boundary.
"""

from __future__ import annotations

import re
import unittest

from parity.check_pmf_accuracy import (
    BEYOND,
    DOCUMENTED,
    F32_MIN_NORMAL,
    PROBABILITIES,
    cases,
    f32,
    lit,
)

IDENTIFIER = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")
CALL = re.compile(r"^(\w+)\((.*)\)$")

# No scipy guard here on purpose. This file lives under `parity/`, where SciPy is
# a declared, locked dependency, so an ImportError is a broken environment and
# should fail loudly. A `skipUnless` would turn that into a silent pass, and a
# test skipped everywhere is indistinguishable from a passing one.


def arguments(expression: str) -> list[float]:
    """The f32 values the probe will hold, not the decimals that spell them.

    `lit` emits the shortest decimal that round-trips, so `1e-07` reads back as
    the f64 1e-07 while the probe holds f32(1e-7). Comparing the decimal is how
    the probability-coverage test first failed against its own grid.
    """
    body = CALL.match(expression).group(2)
    return [f32(float(part)) for part in body.split(", ")]


class Names(unittest.TestCase):
    def setUp(self) -> None:
        self.spec = cases()

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
        for value in (0.5, 0.2, 0.01, 1e-7, 0.999999, 1e9, 2.0 ** 24, 1.0, 0.0):
            self.assertEqual(f32(float(lit(value))), f32(value), repr(value))

    def test_an_integral_value_is_spelled_as_a_float(self) -> None:
        # A digit string with no "." or "e" lexes as an integer literal, which
        # is an i32 at these call sites and fails to type-check.
        for value in (0.0, 1.0, 10.0, 100.0, 2.0 ** 24):
            text = lit(value)
            self.assertTrue("." in text or "e" in text, f"{value!r} -> {text!r}")

    def test_every_generated_expression_parses_as_a_call(self) -> None:
        for _, export, expression, *_ in cases():
            matched = CALL.match(expression)
            self.assertIsNotNone(matched, expression)
            self.assertEqual(matched.group(1), export, expression)


class Coverage(unittest.TestCase):
    def setUp(self) -> None:
        self.spec = cases()

    def test_documented_covers_every_export_measured(self) -> None:
        self.assertEqual({case[1] for case in self.spec}, set(DOCUMENTED))

    def test_every_export_has_a_case_inside_its_documented_range(self) -> None:
        for export, (ceiling, _) in DOCUMENTED.items():
            inside = [case for case in self.spec
                      if case[1] == export and case[3] <= ceiling]
            self.assertTrue(inside, f"{export} has no in-range case to fail on")

    def test_every_export_is_exercised_AT_its_ceiling(self) -> None:
        # A grid that stops a decade below the documented ceiling cannot fail at
        # the boundary it claims, which is how the sibling beta range came to be
        # false at its own edge.
        for export, (ceiling, _) in DOCUMENTED.items():
            at = [case for case in self.spec
                  if case[1] == export and case[3] == f32(ceiling)]
            self.assertTrue(at, f"{export} is never probed at {ceiling:.0e}")

    def test_every_export_is_exercised_BEYOND_its_ceiling(self) -> None:
        # The documents claim the error grows past the ceiling. That claim is
        # measured, not asserted, so the run has to carry out-of-range rows.
        for export, (ceiling, _) in DOCUMENTED.items():
            beyond = [case for case in self.spec
                      if case[1] == export and case[3] > ceiling]
            self.assertTrue(beyond, f"{export} is never probed above {ceiling:.0e}")
        self.assertGreater(BEYOND, max(c for c, _ in DOCUMENTED.values()))

    def test_every_probability_is_actually_probed(self) -> None:
        probed = {arguments(case[2])[2] for case in self.spec
                  if case[1] == "binomial_pmf"}
        for p in PROBABILITIES:
            self.assertIn(f32(p), probed,
                          f"p = {p!r} is in PROBABILITIES but reaches no case")

    def test_the_binomial_grid_is_not_a_single_probability(self) -> None:
        probed = {arguments(case[2])[2] for case in self.spec
                  if case[1] == "binomial_pmf"}
        self.assertGreaterEqual(len(probed), len(PROBABILITIES))

    def test_both_endpoints_of_k_are_probed(self) -> None:
        # k = 0 and k = n make one log-gamma exactly ln(Gamma(1)) = 0, so the
        # cancellation differs structurally there from the mode.
        zero = any(arguments(case[2])[0] == 0.0 for case in self.spec
                   if case[1] == "binomial_pmf")
        full = any(arguments(case[2])[0] == arguments(case[2])[1]
                   for case in self.spec if case[1] == "binomial_pmf")
        self.assertTrue(zero, "binomial_pmf is never probed at k = 0")
        self.assertTrue(full, "binomial_pmf is never probed at k = n")

    def test_the_two_to_the_24_neighbourhood_is_probed(self) -> None:
        counts = {arguments(case[2])[0] for case in self.spec
                  if case[1] == "binomial_pmf"}
        self.assertIn(f32(2.0 ** 24), counts)
        self.assertTrue(any(count > 2.0 ** 24 for count in counts))

    def test_no_case_carries_a_reference_f32_cannot_hold(self) -> None:
        for _, export, expression, _, reference in self.spec:
            self.assertGreaterEqual(reference, F32_MIN_NORMAL, expression)
            self.assertLess(reference, 1.0, expression)

    def test_the_bound_is_not_silently_widened(self) -> None:
        # Pins the table so widening it is a deliberate edit that a reviewer
        # sees, with the documents in the same commit.
        self.assertEqual(DOCUMENTED, {
            "poisson_pmf": (1e8, 2e-6),
            "binomial_pmf": (2e8, 2e-6),
        })


if __name__ == "__main__":
    unittest.main()
