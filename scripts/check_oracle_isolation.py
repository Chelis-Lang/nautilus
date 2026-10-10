#!/usr/bin/env python3
"""Fail when external-oracle code escapes parity/ or appears in Chelis files."""

from __future__ import annotations

import ast
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
# `mpmath` is an oracle like the rest and is confined with them. It arrived
# with the incomplete-gamma accuracy gate, which needs an arbitrary-precision
# reference because SciPy's own `gammainc` is up to 22% wrong in the left tail
# at a large shape. Adding the dependency without adding it here would have
# left it the one oracle this guard could not see.
ORACLE_MODULES = frozenset(
    {"jax", "mpmath", "numpy", "pandas", "quantlib", "scipy", "sklearn",
     "sympy", "torch"}
)
ORACLE_CALL_RE = re.compile(
    r"\b(?:jax|mpmath|numpy|pandas|quantlib|scipy|sklearn|sympy|torch)"
    r"\.[A-Za-z_][A-Za-z0-9_.]*\s*\("
)


def repository_files() -> list[Path]:
    """Return tracked and untracked, non-ignored files for local and CI use."""
    completed = subprocess.run(
        [
            "git",
            "ls-files",
            "--cached",
            "--others",
            "--exclude-standard",
            "-z",
        ],
        cwd=ROOT,
        check=True,
        capture_output=True,
    )
    paths = [
        ROOT / item for item in completed.stdout.decode().split("\0") if item
    ]
    return [path for path in paths if path.is_file()]


def oracle_imports(path: Path) -> list[str]:
    try:
        tree = ast.parse(path.read_text(), filename=str(path.relative_to(ROOT)))
    except (SyntaxError, UnicodeDecodeError) as exc:
        return [f"cannot inspect Python syntax: {exc}"]

    violations: list[str] = []
    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            modules = [alias.name.split(".", 1)[0] for alias in node.names]
        elif isinstance(node, ast.ImportFrom):
            modules = [node.module.split(".", 1)[0]] if node.module else []
        else:
            modules = []
        for module in modules:
            if module in ORACLE_MODULES:
                violations.append(f"line {node.lineno}: imports {module}")

        if not isinstance(node, ast.Call) or not node.args:
            continue
        first = node.args[0]
        if not isinstance(first, ast.Constant) or not isinstance(first.value, str):
            continue
        imported = first.value.split(".", 1)[0]
        if imported not in ORACLE_MODULES:
            continue
        if isinstance(node.func, ast.Name) and node.func.id == "__import__":
            violations.append(f"line {node.lineno}: dynamically imports {imported}")
        elif (
            isinstance(node.func, ast.Attribute)
            and node.func.attr == "import_module"
            and isinstance(node.func.value, ast.Name)
            and node.func.value.id == "importlib"
        ):
            violations.append(f"line {node.lineno}: dynamically imports {imported}")
    return violations


def chelis_oracle_calls(path: Path) -> list[str]:
    violations: list[str] = []
    for line_number, line in enumerate(path.read_text().splitlines(), start=1):
        code = line.split("--", 1)[0]
        if ORACLE_CALL_RE.search(code):
            violations.append(f"line {line_number}: oracle callable in Chelis source")
    return violations


def main() -> int:
    violations: list[str] = []
    for path in repository_files():
        relative = path.relative_to(ROOT)
        if path.suffix == ".py" and relative.parts[:1] != ("parity",):
            for detail in oracle_imports(path):
                violations.append(f"{relative}: {detail}")
        elif path.suffix == ".ch":
            for detail in chelis_oracle_calls(path):
                violations.append(f"{relative}: {detail}")

        if (
            relative.parts[:2] == (".github", "workflows")
            and path.suffix in {".yml", ".yaml"}
            and "--regen-goldens" in path.read_text()
        ):
            violations.append(
                f"{relative}: CI may validate goldens but may not regenerate them"
            )

    if violations:
        print("oracle isolation violations:", file=sys.stderr)
        for violation in violations:
            print(f"  {violation}", file=sys.stderr)
        print(
            "External oracle code belongs under parity/; Chelis sources may not "
            "call oracle libraries.",
            file=sys.stderr,
        )
        return 1

    print(
        "OK: oracle imports are confined to parity/, no .ch calls an oracle, "
        "and CI never regenerates goldens"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
