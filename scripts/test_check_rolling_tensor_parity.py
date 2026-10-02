#!/usr/bin/env python3
"""Unit tests for the Nautilus.Rolling tensor delegation guard.

Each test mutates the source the guard reads and asserts that the guard
objects. A structural guard that cannot be shown to fail proves nothing about
the source it passed.
"""

from __future__ import annotations

import unittest
from pathlib import Path

from check_rolling_tensor_parity import (
    SOURCE,
    check,
    parameter_names,
    parse_exports,
    split_top_level,
)

SHIPPED = SOURCE.read_text()

MINIMAL = """module Nautilus.Rolling
export (rolling_sum, shift_fill, tensor_rolling_sum, tensor_shift_fill)
def rolling_sum(xs: List[f64], window: i64) -> List[Option[f64]] = body
def shift_fill(xs: List[f64], k: i64, fill: f64) -> List[f64] = body
def tensor_rolling_sum[n](xs: &tensor[n, f64], window: i64) -> List[Option[f64]] = rolling_sum(to_list(xs), window)
def tensor_shift_fill[n](xs: &tensor[n, f64], k: i64, fill: f64) -> tensor[n, f64] = to_tensor(shift_fill(to_list(xs), k, fill))
"""


class SplitTopLevel(unittest.TestCase):
    def test_a_tensor_type_is_one_parameter(self) -> None:
        self.assertEqual(
            parameter_names("xs: &tensor[n, f64], k: i64"), ["xs", "k"]
        )

    def test_nested_brackets_do_not_split(self) -> None:
        self.assertEqual(
            split_top_level("a: List[(i64, f64)], b: i64"),
            ["a: List[(i64, f64)]", "b: i64"],
        )

    def test_an_empty_list_has_no_parameters(self) -> None:
        self.assertEqual(parameter_names(""), [])


class ShippedSource(unittest.TestCase):
    def test_the_shipped_module_passes(self) -> None:
        self.assertEqual(check(SHIPPED), [])

    def test_every_list_export_has_a_tensor_twin(self) -> None:
        exports = parse_exports(SHIPPED)
        plain = [name for name in exports if not name.startswith("tensor_")]
        self.assertTrue(plain)
        for name in plain:
            self.assertIn(f"tensor_{name}", exports)

    def test_the_minimal_fixture_passes(self) -> None:
        self.assertEqual(check(MINIMAL), [])


class Mutations(unittest.TestCase):
    """Each case is a defect the guard exists to catch."""

    def assert_rejected(self, text: str, fragment: str) -> None:
        problems = check(text)
        self.assertTrue(problems, "guard accepted a mutated source")
        self.assertTrue(
            any(fragment in problem for problem in problems),
            f"no problem mentioned {fragment!r}: {problems}",
        )

    def test_a_tensor_form_that_re_derives_is_rejected(self) -> None:
        self.assert_rejected(
            MINIMAL.replace(
                "= rolling_sum(to_list(xs), window)",
                "= map(fn (i: i64) -> None, range(cast(0, i64), window))",
            ),
            "not a literal delegation",
        )

    def test_delegating_to_the_wrong_twin_is_rejected(self) -> None:
        self.assert_rejected(
            MINIMAL.replace(
                "= rolling_sum(to_list(xs), window)",
                "= shift_fill(to_list(xs), window)",
            ),
            "not to its twin",
        )

    def test_dropping_an_argument_is_rejected(self) -> None:
        self.assert_rejected(
            MINIMAL.replace(
                "= to_tensor(shift_fill(to_list(xs), k, fill))",
                "= to_tensor(shift_fill(to_list(xs), k))",
            ),
            "forwards",
        )

    def test_reordering_arguments_is_rejected(self) -> None:
        self.assert_rejected(
            MINIMAL.replace(
                "= to_tensor(shift_fill(to_list(xs), k, fill))",
                "= to_tensor(shift_fill(to_list(xs), fill, k))",
            ),
            "forwards",
        )

    def test_a_list_export_without_a_twin_is_rejected(self) -> None:
        self.assert_rejected(
            MINIMAL.replace(
                "export (rolling_sum, shift_fill, tensor_rolling_sum, tensor_shift_fill)",
                "export (rolling_sum, rolling_mean, shift_fill, tensor_rolling_sum, tensor_shift_fill)",
            ),
            "has no `tensor_rolling_mean` twin",
        )

    def test_a_tensor_export_without_a_def_is_rejected(self) -> None:
        self.assert_rejected(
            MINIMAL.replace(
                "def tensor_rolling_sum[n](xs: &tensor[n, f64], window: i64) -> List[Option[f64]] = rolling_sum(to_list(xs), window)\n",
                "",
            ),
            "no single-line def",
        )

    def test_an_option_form_returning_a_tensor_is_rejected(self) -> None:
        self.assert_rejected(
            MINIMAL.replace(
                "def tensor_rolling_sum[n](xs: &tensor[n, f64], window: i64) -> List[Option[f64]] = rolling_sum(to_list(xs), window)",
                "def tensor_rolling_sum[n](xs: &tensor[n, f64], window: i64) -> tensor[n, f64] = to_tensor(rolling_sum(to_list(xs), window))",
            ),
            "cannot carry an absent position",
        )

    def test_a_missing_to_tensor_wrap_is_rejected(self) -> None:
        self.assert_rejected(
            MINIMAL.replace(
                "= to_tensor(shift_fill(to_list(xs), k, fill))",
                "= shift_fill(to_list(xs), k, fill)",
            ),
            "returns a tensor without a to_tensor wrap",
        )

    def test_converting_a_parameter_that_is_not_the_series_is_rejected(self) -> None:
        self.assert_rejected(
            MINIMAL.replace(
                "def tensor_rolling_sum[n](xs: &tensor[n, f64], window: i64) -> List[Option[f64]] = rolling_sum(to_list(xs), window)",
                "def tensor_rolling_sum[n](ys: &tensor[n, f64], window: i64) -> List[Option[f64]] = rolling_sum(to_list(xs), window)",
            ),
            "which is not its first parameter",
        )

    def test_a_signature_that_drifts_from_its_twin_is_rejected(self) -> None:
        self.assert_rejected(
            MINIMAL.replace(
                "def shift_fill(xs: List[f64], k: i64, fill: f64) -> List[f64] = body",
                "def shift_fill(xs: List[f64], k: i64, fill: f64, extra: i64) -> List[f64] = body",
            ),
            "disagree after the series argument",
        )

    def test_a_source_with_no_exports_is_rejected(self) -> None:
        with self.assertRaises(ValueError):
            check("module Nautilus.Rolling\ndef f(x: i64) -> i64 = x\n")

    def test_a_source_with_no_tensor_exports_is_rejected(self) -> None:
        self.assert_rejected(
            "module Nautilus.Rolling\nexport (rolling_sum)\n"
            "def rolling_sum(xs: List[f64]) -> List[Option[f64]] = body\n",
            "expected both list and tensor exports",
        )


if __name__ == "__main__":
    unittest.main()
