#!/usr/bin/env python3
"""Validate all compile-checked code examples in the mdBook.

Walks docs/book/src/**/*.md and checks two kinds of example, each written as
a temporary file inside src/ so reef imports resolve:

- every ```chelis block (a complete module) must pass `chelis check`;
- every ```chelis-fragment block followed directly by a ```text block is a
  captured example: it is evaluated with `chelis eval --file` under a
  generated module header, and its output must equal the text block exactly.

Fragments without an output block are illustrative and are not run.
Exit non-zero if any example fails or too few examples are found.
"""
from __future__ import annotations

import json
import os
import re
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
DOCS_SRC = REPO / "docs" / "book" / "src"
SRC = REPO / "src"
sys.path.insert(0, str(REPO))

from scripts.chelis_toolchain import resolve_chelis_bin


CHELIS = resolve_chelis_bin()
MIN_CHELIS_BLOCKS = int(os.environ.get("MIN_BOOK_CHELIS_BLOCKS", "13"))


def extract_chelis_blocks(text: str) -> list[str]:
    """Extract ```chelis blocks but NOT ```chelis-fragment blocks."""
    all_blocks = re.findall(r"```chelis\n(.*?)```", text, re.DOTALL)
    fragments = set(re.findall(r"```chelis-fragment\n(.*?)```", text, re.DOTALL))
    return [b for b in all_blocks if b not in fragments]


def validate_block(code: str, source_file: str, index: int) -> bool:
    mod_match = re.search(r"^module\s+Nautilus\.(\w+)", code, re.M)
    if mod_match:
        fname = mod_match.group(1).lower()
    else:
        fname = f"_book_check_{index}"
    tmp = SRC / f"{fname}.ch"
    try:
        tmp.write_text(code)
        result = subprocess.run(
            [CHELIS, "check", str(tmp)],
            capture_output=True, text=True, cwd=str(REPO),
        )
        output = result.stdout.strip()
        try:
            d = json.loads(output)
            if result.returncode == 0 and d.get("score") == 1 and not d.get("errors"):
                return True
            print(f"  FAIL: {source_file} block {index} "
                  f"(exit={result.returncode}, score={d.get('score')}, "
                  f"errors={d.get('errors', [])}, stderr={result.stderr[:200]})")
            return False
        except json.JSONDecodeError:
            print(f"  FAIL: {source_file} block {index}: "
                  f"stdout={output[:300]}, stderr={result.stderr[:200]}")
            return False
    finally:
        tmp.unlink(missing_ok=True)


BLOCK = re.compile(r"```(chelis|chelis-fragment)\n((?:(?!```).)*?)```(?:\n\n```text\n((?:(?!```).)*?)```)?", re.DOTALL)


def extract_captured(text: str) -> list[tuple[str, str, str]]:
    """Captured fragments as (code, expected output, page context).

    A captured fragment may continue the page: it can use names that an
    earlier block on the same page defined. The context is every earlier
    block on the page, module and export lines dropped, so the fragment can be
    retried in the setting the reader sees it in.
    """
    out, earlier = [], []
    for m in BLOCK.finditer(text):
        kind, code, expected = m.group(1), m.group(2), m.group(3)
        if kind == "chelis-fragment" and expected is not None:
            out.append((code, expected, "\n".join(earlier)))
        earlier.append("\n".join(
            line for line in code.splitlines()
            if not re.match(r"^(module|export)\b", line)))
    return out


def run_captured(code: str, index: int) -> subprocess.CompletedProcess[str]:
    tmp = SRC / f"bookcaptured{index}.ch"
    try:
        lines, seen = [], set()
        for line in code.splitlines():
            # Earlier blocks often repeat an import or a one-line fixture
            # definition. Only unindented lines are top-level declarations.
            top_level = line[:1] not in ("", " ", "\t", "}", ")")
            if top_level and line in seen:
                continue
            seen.add(line)
            lines.append(line)
        tmp.write_text(f"module Nautilus.BookCaptured{index}\n" + "\n".join(lines) + "\n")
        # A page shows an excerpt, not a formatted file: format the temporary
        # copy so the style gate judges nothing the reader cannot see.
        subprocess.run([CHELIS, "fmt", "--inplace", str(tmp)],
                       capture_output=True, text=True, cwd=str(REPO))
        return subprocess.run([CHELIS, "eval", "--file", str(tmp)],
                              capture_output=True, text=True, cwd=str(REPO))
    finally:
        tmp.unlink(missing_ok=True)


def shows(expected: str, got: str) -> bool:
    """The page shows the bindings it is about: every expected line must
    appear in the evaluator's output, in order (fixture bindings may be
    omitted from the page)."""
    remaining = iter(got.strip().splitlines())
    return all(any(line == g for g in remaining) for line in expected.strip().splitlines())


def validate_captured(code: str, expected: str, context: str, source_file: str, index: int) -> bool:
    result = run_captured(code, index)
    if not (result.returncode == 0 and shows(expected, result.stdout)) and context:
        result = run_captured(f"{context}\n{code}", index)
    if result.returncode == 0 and shows(expected, result.stdout):
        return True
    print(f"  FAIL: {source_file} captured example {index} (exit={result.returncode})")
    print(f"    expected: {expected.strip()!r}")
    print(f"    got:      {result.stdout.strip()!r}")
    if result.stderr.strip():
        print(f"    stderr:   {result.stderr.strip()[:300]}")
    return False


def main() -> int:
    if not DOCS_SRC.exists():
        print("docs/book/src/ not found, skipping book validation")
        return 0

    failures = 0
    total = 0

    for md_file in sorted(DOCS_SRC.rglob("*.md")):
        text = md_file.read_text()
        blocks = extract_chelis_blocks(text)
        rel = md_file.relative_to(DOCS_SRC)
        for i, block in enumerate(blocks):
            total += 1
            if not validate_block(block, str(rel), i):
                failures += 1
        for code, expected, context in extract_captured(text):
            total += 1
            if not validate_captured(code, expected, context, str(rel), total):
                failures += 1

    if total == 0:
        print("No compile-checked code blocks found in mdBook.")
        return 1
    print(f"{total - failures}/{total} mdBook examples passed.")
    if total < MIN_CHELIS_BLOCKS:
        print(f"FAIL: only {total} checked examples found; need at least {MIN_CHELIS_BLOCKS}.")
        return 1
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
