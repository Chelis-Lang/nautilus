"""Check Nautilus interpolation properties and a false-claim control with SMT."""

from __future__ import annotations

import json
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CASES = (
    ("properties/interpolation.ch", 0, {"hermite_left_endpoint": "passed", "hermite_right_endpoint": "passed"}),
    ("proof_controls/hermite_wrong.ch", 1, {"hermite_left_returns_right": "failed"}),
)
DOMAIN = "forall(x0: f32, x1: f32, y0: f32, y1: f32, m0: f32, m1: f32) where x1 > x0: "
CALL = "Nautilus.Interpolation.cubic_hermite(x0, x1, y0, y1, m0, m1, {})"
GOALS = {
    "hermite_left_endpoint": DOMAIN + f"({CALL.format('x0')} == y0)",
    "hermite_right_endpoint": DOMAIN + f"({CALL.format('x1')} == y1)",
    "hermite_left_returns_right": DOMAIN + f"({CALL.format('x0')} == y1)",
}


def validate_records(records: list[dict], expected: dict[str, str], goals: dict[str, str]) -> None:
    properties = {record["name"]: record for record in records if record.get("kind") == "property"}
    summaries = [record for record in records if record.get("kind") == "summary"]
    if set(properties) != set(expected) or len(summaries) != 1:
        raise ValueError(f"property/summary set differs from expected: {set(properties)}, {len(summaries)} summaries")
    summary = summaries[0]
    if (summary.get("total") != len(expected) or summary.get("errors") != 0
            or summary.get("unsupported") != 0
            or summary.get("passed") != sum(status == "passed" for status in expected.values())
            or summary.get("failed") != sum(status == "failed" for status in expected.values())):
        raise ValueError(f"incomplete property summary: {summary}")
    for name, wanted_status in expected.items():
        result = properties[name]
        if result.get("goal") != goals[name]:
            raise ValueError(f"{name} proves a different goal: {result.get('goal')}")
        if (result.get("status"), result.get("proof_tier"), result.get("samples"), result.get("arith_model")) != (
            wanted_status, "smt", 0, "real"
        ):
            raise ValueError(f"{name} did not reach the expected SMT verdict")
        if wanted_status == "passed":
            if result.get("qualifiers") != ["real_arithmetic"]:
                raise ValueError(f"{name} has unexpected proof qualifiers")
            assumptions = result.get("assumptions", [])
            if not assumptions or not all(item.get("non_vacuity", {}).get("status") == "established" for item in assumptions):
                raise ValueError(f"{name} has an unestablished guard")
        elif not result.get("counterexample"):
            raise ValueError(f"{name} refuted without a counterexample")


def validate_source_graph(graph: object, property_file: str, property_module: str,
                          targets: dict[str, tuple[str, str, str]]) -> None:
    """Require the exact compiler-owned property-to-export declarations and edges."""
    if not isinstance(graph, dict) or graph.get("status") != "complete":
        raise ValueError("complete compiler dependency graph required")
    declarations, edges = graph.get("declarations"), graph.get("edges")
    if not isinstance(declarations, list) or not isinstance(edges, list):
        raise ValueError("malformed dependency graph")
    if not all(isinstance(d, dict) and isinstance(d.get("id"), str) for d in declarations):
        raise ValueError("malformed declaration")
    ids = [d["id"] for d in declarations]
    if len(ids) != len(set(ids)):
        raise ValueError("duplicate declaration IDs")
    pairs = set()
    for edge in edges:
        if not isinstance(edge, dict) or edge.get("from") not in ids or edge.get("to") not in ids:
            raise ValueError("edge has unknown declaration endpoints")
        pairs.add((edge["from"], edge["to"]))

    def exact(kind: str, module: str, name: str, source: str) -> str:
        matches = [d for d in declarations if d.get("kind") == kind
                   and d.get("package") == "nautilus" and d.get("module") == module
                   and d.get("name") == name and isinstance(d.get("source"), dict)
                   and d["source"].get("file") == source]
        if len(matches) != 1:
            raise ValueError(f"{module}.{name}: expected one exact declaration, got {len(matches)}")
        return matches[0]["id"]

    for name, (module, function, source) in targets.items():
        origin = exact("property", property_module, name, property_file)
        target = exact("function", module, function, source)
        if (origin, target) not in pairs:
            raise ValueError(f"{name}: missing direct edge to {module}.{function}")


def main() -> int:
    for path, expected_exit, expected in CASES:
        run = subprocess.run(
            ["chelis", "prove", path, "--tier", "smt-only", "--smt-timeout", "20000", "--json"],
            cwd=ROOT,
            capture_output=True,
            text=True,
            timeout=120,
            check=False,
        )
        if run.returncode != expected_exit:
            raise RuntimeError(f"{path}: exit {run.returncode}, expected {expected_exit}\n{run.stdout}\n{run.stderr}")
        records = [json.loads(line) for line in run.stdout.splitlines() if line]
        validate_records(records, expected, {name: GOALS[name] for name in expected})
        summary = next(record for record in records if record.get("kind") == "summary")
        module = ("Nautilus.Properties.Interpolation" if path.startswith("properties/")
                  else "Nautilus.Proof_controls.Hermite_wrong")
        validate_source_graph(summary.get("dependency_graph"), path, module,
                              {name: ("Nautilus.Interpolation", "cubic_hermite", "src/interpolation.ch")
                               for name in expected})
        print(f"{path}: {', '.join(expected)} checked by SMT")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
