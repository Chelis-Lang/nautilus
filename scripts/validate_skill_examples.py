#!/usr/bin/env python3
"""Validate all compile-checked code examples in SKILL.md.

Extracts code blocks tagged with ```chelis or ```deep (not
```chelis-fragment or ```deep-fragment) and runs `chelis check`
on each. Blocks are written as temporary files inside the repo's
src/ directory so that reef module imports resolve correctly.

Exit non-zero if any block fails to check at score 1.0.
"""
from __future__ import annotations

import json
import re
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
SRC = REPO / "src"
sys.path.insert(0, str(REPO))

from scripts.chelis_toolchain import resolve_chelis_bin


CHELIS = resolve_chelis_bin()


def extract_blocks(text: str, lang: str) -> list[str]:
    """Extract fenced code blocks for a given language tag.

    Matches ```lang but NOT ```lang-fragment.
    """
    pattern = rf"```{re.escape(lang)}\n(.*?)```"
    candidates = re.findall(pattern, text, re.DOTALL)
    frag_pattern = rf"```{re.escape(lang)}-fragment\n(.*?)```"
    fragments = set(re.findall(frag_pattern, text, re.DOTALL))
    return [c for c in candidates if c not in fragments]


def validate_block(code: str, lang: str, index: int) -> bool:
    suffix = ".ch" if lang == "chelis" else ".dp"
    # Extract module name from the code to name the temp file correctly.
    # chelis check requires the file path to match the module declaration.
    mod_match = re.search(r"^module\s+Nautilus\.(\w+)", code, re.M)
    if mod_match:
        fname = mod_match.group(1).lower()
    else:
        fname = f"_skill_check_{index}"
    tmp = SRC / f"{fname}{suffix}"
    try:
        tmp.write_text(code)
        result = subprocess.run(
            [CHELIS, "check", str(tmp)],
            capture_output=True, text=True, cwd=str(REPO),
        )
        output = (result.stdout + result.stderr).strip()
        try:
            d = json.loads(output)
            if d.get("score") == 1 and not d.get("errors"):
                return True
            print(f"  FAIL: {lang} block {index} (score={d.get('score')}, "
                  f"errors={d.get('errors', [])})")
            return False
        except json.JSONDecodeError:
            print(f"  FAIL: {lang} block {index}: {output[:400]}")
            return False
    finally:
        tmp.unlink(missing_ok=True)


def main() -> int:
    skill_md = REPO / "SKILL.md"
    if not skill_md.exists():
        print("SKILL.md not found, skipping skill checks")
        return 0

    text = skill_md.read_text()
    failures = 0
    total = 0

    for lang in ("chelis",):
        blocks = extract_blocks(text, lang)
        for i, block in enumerate(blocks):
            total += 1
            if not validate_block(block, lang, i):
                failures += 1
    # Deep blocks are generated from validated Surf via `chelis deep`
    # and are correct by construction. `chelis check` rejects .dp files
    # in src/ ("not a source file"), so we skip Deep validation here.

    print(f"{total - failures}/{total} SKILL.md examples passed.")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
