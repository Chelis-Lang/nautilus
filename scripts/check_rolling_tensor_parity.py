#!/usr/bin/env python3
"""Prove that every `Nautilus.Rolling` tensor export is a literal delegation.

`tests/rolling.ch` checks that each `tensor_*` export agrees with its list
twin on a fixture. That is necessary and not sufficient: a tensor form that
re-derived the window could agree on the fixture and diverge elsewhere, and a
tensor form added later without a test would agree with nothing at all. This
script reads the source instead, and requires each tensor export to be exactly
its twin applied to `to_list(xs)` with the remaining arguments passed through
unchanged -- optionally wrapped in `to_tensor` where the result has no absent
position.

    uv run --no-project --python 3.12 python scripts/check_rolling_tensor_parity.py

Success is exit 0 with a final `TENSOR DELEGATION: PASS` line. The export
parity is proven by parsing; what the delegation MEANS is proven by
`tests/rolling.ch` and `scripts/check_rolling_parity.py`.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
SOURCE = REPO / "src" / "rolling.ch"
TENSOR_PREFIX = "tensor_"

EXPORT_RE = re.compile(r"export\s*\(([^)]*)\)", re.S)
# A def header runs to its `=`; the body is whatever follows on that line,
# which is empty for the multi-line list definitions and is the whole
# delegation for every tensor one.
DEF_RE = re.compile(
    r"^def[ \t]+(?P<name>[a-z_][\w]*)"
    r"(?:\[(?P<binders>[^\]]*)\])?"
    r"\((?P<params>[^)]*)\)[ \t]*->[ \t]*(?P<ret>[^=]+?)[ \t]*=[ \t]*(?P<body>.*)$",
    re.M,
)
# `f(to_list(xs), a, b)` or `to_tensor(f(to_list(xs), a, b))`.
DELEGATION_RE = re.compile(
    r"^(?P<wrap>to_tensor\()?"
    r"(?P<callee>[a-z_][\w]*)\("
    r"to_list\((?P<first>[a-z_][\w]*)\)"
    r"(?P<rest>(?:,\s*[a-z_][\w]*)*)"
    r"\)(?(wrap)\))$"
)


def parse_exports(text: str) -> list[str]:
    match = EXPORT_RE.search(text)
    if match is None:
        raise ValueError(f"{SOURCE}: no export(...) clause")
    return [token.strip() for token in match.group(1).split(",") if token.strip()]


def parse_defs(text: str) -> dict[str, re.Match]:
    out: dict[str, re.Match] = {}
    for match in DEF_RE.finditer(text):
        out[match.group("name")] = match
    return out


def split_top_level(params: str) -> list[str]:
    """Split a parameter list on commas that are not inside brackets.

    `xs: &tensor[n, f64], k: i64` has two parameters, not three. Splitting on
    every comma made this script report a parameter named `f64]`, which is the
    kind of self-inflicted finding a guard has to be tested against.
    """
    parts: list[str] = []
    depth = 0
    current = ""
    for char in params:
        if char in "[(":
            depth += 1
        elif char in "])":
            depth -= 1
        if char == "," and depth == 0:
            parts.append(current)
            current = ""
        else:
            current += char
    parts.append(current)
    return [part.strip() for part in parts if part.strip()]


def parameter_names(params: str) -> list[str]:
    return [part.split(":", 1)[0].strip() for part in split_top_level(params)]


def check(text: str) -> list[str]:
    problems: list[str] = []
    exports = parse_exports(text)
    defs = parse_defs(text)

    tensor_exports = [name for name in exports if name.startswith(TENSOR_PREFIX)]
    list_exports = [name for name in exports if not name.startswith(TENSOR_PREFIX)]
    if not tensor_exports or not list_exports:
        return [f"{SOURCE}: expected both list and tensor exports, "
                f"found {len(list_exports)} and {len(tensor_exports)}"]

    # Every list export owes a tensor twin, so a new list export cannot land
    # without one. The converse is checked below.
    for name in list_exports:
        if f"{TENSOR_PREFIX}{name}" not in exports:
            problems.append(f"list export `{name}` has no `{TENSOR_PREFIX}{name}` twin")

    for name in tensor_exports:
        twin = name[len(TENSOR_PREFIX):]
        if twin not in exports:
            problems.append(f"`{name}` names no exported list twin `{twin}`")
            continue
        definition = defs.get(name)
        if definition is None:
            problems.append(f"`{name}` is exported but has no single-line def")
            continue
        body = definition.group("body").strip()
        delegation = DELEGATION_RE.match(body)
        if delegation is None:
            problems.append(
                f"`{name}` body is not a literal delegation: {body[:90]}"
            )
            continue
        if delegation.group("callee") != twin:
            problems.append(
                f"`{name}` delegates to `{delegation.group('callee')}`, "
                f"not to its twin `{twin}`"
            )
            continue

        tensor_params = parameter_names(definition.group("params"))
        if not tensor_params:
            problems.append(f"`{name}` takes no parameters")
            continue
        if delegation.group("first") != tensor_params[0]:
            problems.append(
                f"`{name}` converts `{delegation.group('first')}`, "
                f"which is not its first parameter `{tensor_params[0]}`"
            )
        forwarded = [
            token.strip() for token in delegation.group("rest").split(",") if token.strip()
        ]
        if forwarded != tensor_params[1:]:
            problems.append(
                f"`{name}` forwards {forwarded}, not its own remaining "
                f"parameters {tensor_params[1:]}"
            )

        list_definition = defs.get(twin)
        if list_definition is None:
            problems.append(f"`{twin}` is exported but has no single-line def")
            continue
        list_params = parameter_names(list_definition.group("params"))
        if list_params[1:] != tensor_params[1:]:
            problems.append(
                f"`{name}` and `{twin}` disagree after the series argument: "
                f"{tensor_params[1:]} vs {list_params[1:]}"
            )

        wrapped = delegation.group("wrap") is not None
        returns_tensor = "tensor[" in definition.group("ret")
        if wrapped != returns_tensor:
            detail = (
                "wraps in to_tensor but does not return a tensor"
                if wrapped
                else "returns a tensor without a to_tensor wrap"
            )
            problems.append(f"`{name}` {detail}")
        if returns_tensor and "Option" in list_definition.group("ret"):
            problems.append(
                f"`{name}` returns a tensor while `{twin}` returns "
                f"{list_definition.group('ret').strip()}; a tensor element "
                f"cannot carry an absent position"
            )

    return problems


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=SOURCE)
    args = parser.parse_args()

    try:
        text = args.source.read_text()
    except OSError as exc:
        print(f"TENSOR DELEGATION: FAIL -- {exc}", file=sys.stderr)
        return 1
    try:
        problems = check(text)
    except ValueError as exc:
        print(f"TENSOR DELEGATION: FAIL -- {exc}", file=sys.stderr)
        return 1

    if problems:
        print(f"TENSOR DELEGATION: FAIL -- {len(problems)} problem(s)", file=sys.stderr)
        for problem in problems:
            print(f"  {problem}", file=sys.stderr)
        return 1

    exports = parse_exports(text)
    pairs = len([n for n in exports if n.startswith(TENSOR_PREFIX)])
    print(f"{pairs} tensor exports each delegate literally to their list twin")
    print("TENSOR DELEGATION: PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
