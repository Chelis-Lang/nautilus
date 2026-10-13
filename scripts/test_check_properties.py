"""Fail the property gate when an SMT result is absent or mislabeled."""

import unittest
import copy

from check_properties import validate_records, validate_source_graph


class PropertyGateTests(unittest.TestCase):
    def test_accepts_one_proved_property(self) -> None:
        records = [
            {"kind": "property", "name": "p", "goal": "bound claim", "status": "passed", "proof_tier": "smt", "samples": 0,
             "arith_model": "real", "qualifiers": ["real_arithmetic"],
             "assumptions": [{"non_vacuity": {"status": "established"}}]},
            {"kind": "summary", "total": 1, "passed": 1, "failed": 0, "errors": 0, "unsupported": 0},
        ]
        validate_records(records, {"p": "passed"}, {"p": "bound claim"})

    def test_rejects_a_replaced_goal(self) -> None:
        records = [
            {"kind": "property", "name": "p", "goal": "y1 == y1", "status": "passed", "proof_tier": "smt",
             "samples": 0, "arith_model": "real", "qualifiers": ["real_arithmetic"],
             "assumptions": [{"non_vacuity": {"status": "established"}}]},
            {"kind": "summary", "total": 1, "passed": 1, "failed": 0, "errors": 0, "unsupported": 0},
        ]
        with self.assertRaises(ValueError):
            validate_records(records, {"p": "passed"}, {"p": "bound claim"})

    def test_rejects_a_sampled_pass(self) -> None:
        records = [
            {"kind": "property", "name": "p", "status": "passed", "proof_tier": "fuzz", "samples": 100,
             "arith_model": "real", "qualifiers": ["real_arithmetic"]},
            {"kind": "summary", "total": 1, "passed": 1, "failed": 0, "errors": 0, "unsupported": 0},
        ]
        with self.assertRaises(ValueError):
            validate_records(records, {"p": "passed"}, {"p": "bound claim"})

    def test_rejects_an_empty_result(self) -> None:
        with self.assertRaises(ValueError):
            validate_records([{"kind": "summary", "total": 0, "passed": 0, "failed": 0,
                              "errors": 0, "unsupported": 0}], {"p": "passed"}, {"p": "bound claim"})


class SourceGraphTests(unittest.TestCase):
    def fixture(self) -> dict:
        return {
            "status": "complete",
            "declarations": [
                {"id": "p", "kind": "property", "package": "nautilus", "module": "Nautilus.Properties.Interpolation", "name": "hermite_left_endpoint", "source": {"file": "properties/interpolation.ch"}},
                {"id": "f", "kind": "function", "package": "nautilus", "module": "Nautilus.Interpolation", "name": "cubic_hermite", "source": {"file": "src/interpolation.ch"}},
            ],
            "edges": [{"from": "p", "to": "f"}],
        }

    def check_graph(self, graph: dict) -> None:
        validate_source_graph(graph, "properties/interpolation.ch", "Nautilus.Properties.Interpolation", {"hermite_left_endpoint": ("Nautilus.Interpolation", "cubic_hermite", "src/interpolation.ch")})

    def test_accepts_direct_export_binding(self) -> None:
        self.check_graph(self.fixture())

    def test_rejects_missing_or_substituted_source_binding(self) -> None:
        baseline = self.fixture()
        variants = []
        for key, value in [("status", "partial"), ("edges", []), ("declarations", baseline["declarations"][1:])]:
            changed = copy.deepcopy(baseline)
            changed[key] = value
            variants.append(changed)
        for index, key, value in [(0, "module", "Other.Properties"), (1, "package", "other"), (1, "name", "different_function")]:
            changed = copy.deepcopy(baseline)
            changed["declarations"][index][key] = value
            variants.append(changed)
        for index in (0, 1):
            changed = copy.deepcopy(baseline)
            changed["declarations"][index]["source"]["file"] = "wrong.ch"
            variants.append(changed)
        changed = copy.deepcopy(baseline)
        changed["declarations"].append(copy.deepcopy(changed["declarations"][0]))
        variants.append(changed)
        changed = copy.deepcopy(baseline)
        changed["edges"] = [{"from": "p", "to": "unknown"}]
        variants.append(changed)
        for graph in variants:
            with self.subTest(graph=graph), self.assertRaises(ValueError):
                self.check_graph(graph)


if __name__ == "__main__":
    unittest.main()
