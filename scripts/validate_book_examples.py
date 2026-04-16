#!/usr/bin/env python3
"""Validate all compile-checked code examples in the mdBook.

Walks docs/src/**/*.md, extracts code blocks tagged with ```chelis
(not ```chelis-fragment), writes each as a temporary file inside
src/ so reef imports resolve, and runs `chelis check`.

Exit non-zero if any block fails.
"""
from __future__ import annotations

import json
import os
import re
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
DOCS_SRC = REPO / "docs" / "src"
SRC = REPO / "src"
CHELIS = os.environ.get("CHELIS_BIN", "chelis")


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
        output = (result.stdout + result.stderr).strip()
        try:
            d = json.loads(output)
            if d.get("score", 0) >= 0.95 and not d.get("errors"):
                return True
            print(f"  FAIL: {source_file} block {index} "
                  f"(score={d.get('score')}, errors={d.get('errors', [])})")
            return False
        except json.JSONDecodeError:
            if "error:" in output:
                print(f"  FAIL: {source_file} block {index}: {output[:200]}")
                return False
            return True
    finally:
        tmp.unlink(missing_ok=True)


def main() -> int:
    if not DOCS_SRC.exists():
        print("docs/src/ not found, skipping book validation")
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

    if total == 0:
        print("No compile-checked code blocks found in mdBook.")
    else:
        print(f"{total - failures}/{total} mdBook examples passed.")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
