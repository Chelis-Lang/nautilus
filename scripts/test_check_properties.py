"""Fail the property gate when an SMT result is absent or mislabeled."""

import unittest

from check_properties import validate_records


class PropertyGateTests(unittest.TestCase):
    def test_accepts_one_proved_property(self) -> None:
        records = [
            {"kind": "property", "name": "p", "status": "passed", "proof_tier": "smt", "samples": 0,
             "arith_model": "real", "qualifiers": ["real_arithmetic"],
             "assumptions": [{"non_vacuity": {"status": "established"}}]},
            {"kind": "summary", "total": 1, "passed": 1, "failed": 0, "errors": 0, "unsupported": 0},
        ]
        validate_records(records, {"p": "passed"})

    def test_rejects_a_sampled_pass(self) -> None:
        records = [
            {"kind": "property", "name": "p", "status": "passed", "proof_tier": "fuzz", "samples": 100,
             "arith_model": "real", "qualifiers": ["real_arithmetic"]},
            {"kind": "summary", "total": 1, "passed": 1, "failed": 0, "errors": 0, "unsupported": 0},
        ]
        with self.assertRaises(ValueError):
            validate_records(records, {"p": "passed"})

    def test_rejects_an_empty_result(self) -> None:
        with self.assertRaises(ValueError):
            validate_records([{"kind": "summary", "total": 0, "passed": 0, "failed": 0,
                              "errors": 0, "unsupported": 0}], {"p": "passed"})


if __name__ == "__main__":
    unittest.main()
