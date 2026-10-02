#!/usr/bin/env python3
"""Unit tests for the Nautilus.Rolling pandas parity replayer.

These cover the parts that decide whether the gate can fail: golden
validation, the `chelis eval` value decoding, the comparison, and the
handling of a case whose result never came back. The end-to-end run against
the compiler is the gate itself; it is not duplicated here.
"""

from __future__ import annotations

import json
import math
import struct
import tempfile
import unittest
from pathlib import Path

from check_rolling_parity import (
    GOLDEN,
    GoldenError,
    SCHEMA,
    check,
    compare,
    decode,
    load_golden,
    probe_source,
)


def bits(value: float) -> str:
    return struct.pack(">d", value).hex()


def some(value: float) -> dict:
    return {
        "type": "adt",
        "ctor": "Some",
        "fields": [{"type": "scalar", "value": {"dtype": "f64", "bits": bits(value)}}],
    }


NONE = {"type": "adt", "ctor": "None", "fields": []}


def listed(*elements: dict) -> dict:
    return {"type": "list", "value": list(elements)}


def minimal_golden(**overrides) -> dict:
    golden = {
        "schema": SCHEMA,
        "generated_with": {"pandas": "2.3.3"},
        "fixtures": {"xs": {"values": [1.0, 2.0], "literal": "[a, b]"}},
        "cases": [
            {
                "label": "rolling_sum",
                "configuration": "window=2,min_periods=2",
                "fixture": "xs",
                "expression": "rolling_sum(FIXTURE, w)",
                "expected": [None, 3.0],
                "rel_tolerance": 1e-12,
            },
            {
                "label": "rolling_sum",
                "configuration": "window=2,min_periods=1",
                "fixture": "xs",
                "expression": "rolling_sum(FIXTURE, v)",
                "expected": [1.0, 3.0],
                "rel_tolerance": 1e-12,
            },
        ],
    }
    golden.update(overrides)
    return golden


def write(golden: dict) -> Path:
    handle = tempfile.NamedTemporaryFile(
        "w", suffix=".json", delete=False, encoding="utf-8"
    )
    json.dump(golden, handle)
    handle.close()
    return Path(handle.name)


class ShippedGolden(unittest.TestCase):
    def test_the_committed_golden_loads(self) -> None:
        golden = load_golden(GOLDEN)
        self.assertEqual(golden["schema"], SCHEMA)
        self.assertTrue(golden["cases"])

    def test_the_committed_golden_covers_every_rolling_export(self) -> None:
        golden = load_golden(GOLDEN)
        labels = {case["label"] for case in golden["cases"]}
        source = (GOLDEN.parent.parent.parent / "src" / "rolling.ch").read_text()
        exported = {
            token.strip()
            for token in source.split("export (", 1)[1].split(")", 1)[0].split(",")
        }
        plain = {name for name in exported if not name.startswith("tensor_")}
        self.assertEqual(
            plain - labels,
            set(),
            "a list export with no pandas golden is an unchecked parity claim",
        )

    def test_the_probe_substitutes_every_fixture(self) -> None:
        golden = load_golden(GOLDEN)
        source, names = probe_source(golden)
        self.assertEqual(len(names), len(golden["cases"]))
        self.assertNotIn("FIXTURE", source)
        self.assertIn("import Nautilus.Rolling (", source)


class GoldenValidation(unittest.TestCase):
    def reject(self, golden: dict, fragment: str) -> None:
        path = write(golden)
        try:
            with self.assertRaises(GoldenError) as caught:
                load_golden(path)
            self.assertIn(fragment, str(caught.exception))
        finally:
            path.unlink()

    def test_a_valid_golden_loads(self) -> None:
        path = write(minimal_golden())
        try:
            self.assertEqual(len(load_golden(path)["cases"]), 2)
        finally:
            path.unlink()

    def test_a_missing_file_is_a_failure_not_a_skip(self) -> None:
        with self.assertRaises(GoldenError):
            load_golden(Path("/nonexistent/rolling.json"))

    def test_a_wrong_schema_is_rejected(self) -> None:
        self.reject(minimal_golden(schema="something/else"), "schema")

    def test_no_cases_is_rejected(self) -> None:
        self.reject(minimal_golden(cases=[]), "no cases")

    def test_a_single_configuration_is_rejected(self) -> None:
        golden = minimal_golden()
        golden["cases"] = golden["cases"][:1]
        self.reject(golden, "fewer than 2 distinct configurations")

    def test_an_unknown_fixture_is_rejected(self) -> None:
        golden = minimal_golden()
        golden["cases"][0]["fixture"] = "nope"
        self.reject(golden, "unknown fixture")

    def test_a_missing_key_is_rejected(self) -> None:
        golden = minimal_golden()
        del golden["cases"][0]["rel_tolerance"]
        self.reject(golden, "rel_tolerance")

    def test_a_non_finite_expectation_is_rejected(self) -> None:
        golden = minimal_golden()
        golden["cases"][0]["expected"] = [None, "Infinity"]
        self.reject(golden, "not a finite number")

    def test_an_empty_expectation_is_rejected(self) -> None:
        golden = minimal_golden()
        golden["cases"][0]["expected"] = []
        self.reject(golden, "empty expectation")


class Decoding(unittest.TestCase):
    def test_an_option_list_decodes_to_optional_floats(self) -> None:
        self.assertEqual(decode(listed(NONE, some(1.5))), [None, 1.5])

    def test_a_dense_list_decodes_to_floats(self) -> None:
        node = listed(
            {"type": "scalar", "value": {"dtype": "f64", "bits": bits(2.25)}},
            {"type": "scalar", "value": {"dtype": "f64", "bits": bits(-4.0)}},
        )
        self.assertEqual(decode(node), [2.25, -4.0])

    def test_round_tripping_preserves_every_bit(self) -> None:
        value = 0.1 + 0.2
        self.assertEqual(decode(listed(some(value)))[0], value)

    def test_a_non_list_result_is_rejected(self) -> None:
        with self.assertRaises(GoldenError):
            decode({"type": "scalar", "value": {"dtype": "f64", "bits": bits(1.0)}})

    def test_an_f32_scalar_is_rejected(self) -> None:
        with self.assertRaises(GoldenError):
            decode(listed({"type": "scalar", "value": {"dtype": "f32", "bits": "0000"}}))

    def test_an_unknown_constructor_is_rejected(self) -> None:
        with self.assertRaises(GoldenError):
            decode(listed({"type": "adt", "ctor": "Maybe", "fields": []}))


class Comparison(unittest.TestCase):
    def case(self, expected: list, rtol: float = 1e-12) -> dict:
        return {"expected": expected, "rel_tolerance": rtol}

    def test_an_exact_match_has_no_failures(self) -> None:
        self.assertEqual(compare(self.case([None, 3.0]), [None, 3.0]), [])

    def test_a_length_mismatch_fails(self) -> None:
        self.assertTrue(compare(self.case([None, 3.0]), [None]))

    def test_an_absence_where_a_value_was_expected_fails(self) -> None:
        problems = compare(self.case([1.0, 3.0]), [None, 3.0])
        self.assertIn("expected Some(1.0), got None", problems[0])

    def test_a_value_where_an_absence_was_expected_fails(self) -> None:
        problems = compare(self.case([None, 3.0]), [0.0, 3.0])
        self.assertIn("expected None", problems[0])

    def test_a_value_outside_the_tolerance_fails(self) -> None:
        self.assertTrue(compare(self.case([1.0]), [1.0 + 1e-6]))

    def test_a_value_inside_the_tolerance_passes(self) -> None:
        self.assertEqual(compare(self.case([1.0]), [1.0 + 1e-15]), [])

    def test_a_non_finite_actual_fails(self) -> None:
        self.assertTrue(compare(self.case([1.0]), [math.inf]))
        self.assertTrue(compare(self.case([1.0]), [math.nan]))

    def test_the_tolerance_is_relative_but_never_below_absolute(self) -> None:
        # A golden of 0.0 must not accept an arbitrary small number just
        # because its relative tolerance scales to nothing.
        self.assertEqual(compare(self.case([0.0]), [1e-15]), [])
        self.assertTrue(compare(self.case([0.0]), [1e-6]))


class MissingRoots(unittest.TestCase):
    def golden(self) -> dict:
        return minimal_golden()

    def test_a_case_with_no_root_is_reported(self) -> None:
        golden = self.golden()
        roots = [{"name": "case_0", "value": listed(NONE, some(3.0))}]
        problems = check(golden, roots, ["case_0", "case_1"])
        self.assertEqual(len(problems), 1)
        self.assertIn("no `case_1` root", problems[0])

    def test_every_root_present_and_correct_passes(self) -> None:
        golden = self.golden()
        roots = [
            {"name": "case_0", "value": listed(NONE, some(3.0))},
            {"name": "case_1", "value": listed(some(1.0), some(3.0))},
        ]
        self.assertEqual(check(golden, roots, ["case_0", "case_1"]), [])

    def test_an_unexpected_root_is_reported(self) -> None:
        golden = self.golden()
        roots = [
            {"name": "case_0", "value": listed(NONE, some(3.0))},
            {"name": "case_1", "value": listed(some(1.0), some(3.0))},
            {"name": "stray", "value": listed(some(0.0))},
        ]
        problems = check(golden, roots, ["case_0", "case_1"])
        self.assertTrue(any("unexpected roots" in problem for problem in problems))


if __name__ == "__main__":
    unittest.main()
