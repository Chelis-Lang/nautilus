#!/usr/bin/env python3
"""Validate the code examples in the mdBook against the pinned compiler.

Walks docs/book/src/**/*.md and checks two kinds of example. Each is written
to a temporary file with a unique name inside src/, so reef imports resolve
and no real source file is touched:

- every ```chelis block is a complete module and must pass `chelis check`;
- every ```text block is the captured output of the ```chelis-fragment block
  before it (at most one short prose line, such as "`chelis eval --file`
  prints:", may sit between them). The fragment is evaluated with
  `chelis eval --file` under a generated module header, with the page's
  earlier blocks in scope when it continues them, and every line of the
  output block must appear in the evaluator's output, in order. The page may
  omit setup lines, such as fixture bindings, that the evaluator also prints.

An output block that is empty, or that does not follow a fragment, fails.
Fragments without an output block are illustrative and are not run.
Exit non-zero if any example fails or if either kind falls below its floor.
"""
from __future__ import annotations

import json
import os
import re
import subprocess
import sys
import uuid
from dataclasses import dataclass
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
DOCS_SRC = REPO / "docs" / "book" / "src"
SRC = REPO / "src"
sys.path.insert(0, str(REPO))

from scripts.chelis_toolchain import resolve_chelis_bin


CHELIS = resolve_chelis_bin()
# Floors at the book's real counts, so a page that loses its examples fails.
MIN_MODULES = int(os.environ.get("MIN_BOOK_MODULES", "9"))
MIN_CAPTURED = int(os.environ.get("MIN_BOOK_CAPTURED", "35"))

FENCE_OPEN = re.compile(r"^```(\S*)\s*$")


@dataclass
class Block:
    lang: str
    code: str
    start: int  # line number of the opening fence, 1-based
    end: int  # index of the closing fence line, 0-based


@dataclass
class Captured:
    code: str
    expected: str
    context: str
    line: int


def fenced_blocks(text: str) -> list[Block]:
    lines = text.splitlines()
    blocks, i = [], 0
    while i < len(lines):
        m = FENCE_OPEN.match(lines[i])
        if not m:
            i += 1
            continue
        j = i + 1
        while j < len(lines) and not lines[j].startswith("```"):
            j += 1
        blocks.append(Block(m.group(1), "\n".join(lines[i + 1:j]) + "\n", i + 1, j))
        i = j + 1
    return blocks


def module_blocks(blocks: list[Block]) -> list[Block]:
    return [b for b in blocks if b.lang == "chelis"]


def captured_examples(text: str, blocks: list[Block]) -> tuple[list[Captured], list[str]]:
    """Pair every output block with its fragment; report the ones that fail to pair."""
    lines = text.splitlines()
    pairs, errors, earlier = [], [], []
    for k, block in enumerate(blocks):
        if block.lang == "text":
            prev = blocks[k - 1] if k else None
            between = [l for l in lines[prev.end + 1:block.start - 1] if l.strip()] if prev else []
            if prev is None or prev.lang != "chelis-fragment" or len(between) > 1:
                errors.append(f"line {block.start}: output block does not follow a chelis-fragment")
            elif not block.code.strip():
                errors.append(f"line {block.start}: output block is empty")
            else:
                pairs.append(Captured(prev.code, block.code, "\n".join(earlier[:-1]), block.start))
        if block.lang in ("chelis", "chelis-fragment"):
            earlier.append("\n".join(
                line for line in block.code.splitlines()
                if not re.match(r"^(module|export)\b", line)))
    return pairs, errors


def temp_source(stem: str) -> tuple[Path, str]:
    """A src/ path and module name that cannot collide with a real module."""
    tag = uuid.uuid4().hex[:12]
    return SRC / f"{stem}{tag}.ch", f"{stem.capitalize()}{tag}"


def validate_block(code: str, source_file: str, line: int) -> bool:
    tmp, name = temp_source("bookcheck")
    # Rename the module to match the unique file; the book's own name could
    # be the name of a real src/ file.
    code = re.sub(r"^module\s+Nautilus\.\w+", f"module Nautilus.{name}", code, count=1, flags=re.M)
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
            print(f"  FAIL: {source_file}:{line} module "
                  f"(exit={result.returncode}, score={d.get('score')}, "
                  f"errors={d.get('errors', [])}, stderr={result.stderr[:200]})")
            return False
        except json.JSONDecodeError:
            print(f"  FAIL: {source_file}:{line} module: "
                  f"stdout={output[:300]}, stderr={result.stderr[:200]}")
            return False
    finally:
        tmp.unlink(missing_ok=True)


def run_captured(code: str) -> subprocess.CompletedProcess[str]:
    tmp, name = temp_source("bookcaptured")
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
        tmp.write_text(f"module Nautilus.{name}\n" + "\n".join(lines) + "\n")
        # A page shows an excerpt, not a formatted file: format the temporary
        # copy so the style gate judges nothing the reader cannot see.
        subprocess.run([CHELIS, "fmt", "--inplace", str(tmp)],
                       capture_output=True, text=True, cwd=str(REPO))
        return subprocess.run([CHELIS, "eval", "--file", str(tmp)],
                              capture_output=True, text=True, cwd=str(REPO))
    finally:
        tmp.unlink(missing_ok=True)


def shows(expected: str, got: str) -> bool:
    """Every expected line appears in the evaluator's output, in order. The
    page may omit setup lines the evaluator also prints."""
    remaining = iter(got.strip().splitlines())
    return all(any(line == g for g in remaining) for line in expected.strip().splitlines())


def validate_captured(ex: Captured, source_file: str) -> bool:
    result = run_captured(ex.code)
    if not (result.returncode == 0 and shows(ex.expected, result.stdout)) and ex.context:
        result = run_captured(f"{ex.context}\n{ex.code}")
    if result.returncode == 0 and shows(ex.expected, result.stdout):
        return True
    print(f"  FAIL: {source_file}:{ex.line} output (exit={result.returncode})")
    print(f"    expected: {ex.expected.strip()!r}")
    print(f"    got:      {result.stdout.strip()!r}")
    if result.stderr.strip():
        print(f"    stderr:   {result.stderr.strip()[:300]}")
    return False


def main() -> int:
    if not DOCS_SRC.exists():
        print("docs/book/src/ not found, skipping book validation")
        return 0

    failures = modules = captured = 0
    for md_file in sorted(DOCS_SRC.rglob("*.md")):
        text = md_file.read_text()
        rel = str(md_file.relative_to(DOCS_SRC))
        blocks = fenced_blocks(text)
        for block in module_blocks(blocks):
            modules += 1
            if not validate_block(block.code, rel, block.start):
                failures += 1
        pairs, errors = captured_examples(text, blocks)
        for error in errors:
            print(f"  FAIL: {rel} {error}")
            failures += 1
        for ex in pairs:
            captured += 1
            if not validate_captured(ex, rel):
                failures += 1

    print(f"{modules} complete modules and {captured} output examples checked; {failures} failures.")
    status = 1 if failures else 0
    if modules < MIN_MODULES:
        print(f"FAIL: only {modules} complete `chelis` modules; need at least {MIN_MODULES}.")
        status = 1
    if captured < MIN_CAPTURED:
        print(f"FAIL: only {captured} output examples; need at least {MIN_CAPTURED}.")
        status = 1
    return status


if __name__ == "__main__":
    sys.exit(main())
