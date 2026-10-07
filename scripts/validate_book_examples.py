#!/usr/bin/env python3
"""Validate the code examples in the mdBook against the pinned compiler.

Walks docs/book/src/**/*.md and checks two kinds of example. Each is written
to a temporary file with a unique name inside a private package: this
repository's reef.toml and reef.lock plus the src/ modules the example
imports, directly or transitively. Reef imports resolve to the same files, no
real source file is touched, and parallel jobs never change a package another
job is reading:

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

Speed. A `chelis` call loads every module in its package, so each call runs
in a package that holds only the example's import closure, and there are few
calls. A page's complete modules and captured fragments are evaluated together
as one program, with a marker binding around each captured fragment, so each
shown output is matched against its own fragment's segment of the evaluator's
output. A fragment is checked alone, exactly as above, whenever the page
program cannot vouch for it: the program fails, its segment does not show the
expected lines, or the fragment uses a name that only a later block on the page
defines or imports (the page program would supply it; the reader would not
have it yet). Module checks, page programs and those fallbacks run in parallel
on os.cpu_count() workers (BOOK_VALIDATOR_JOBS overrides).
"""
from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import uuid
from concurrent.futures import ThreadPoolExecutor
from contextlib import contextmanager
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
WORKERS = int(os.environ.get("BOOK_VALIDATOR_JOBS", "0")) or os.cpu_count() or 1

FENCE_OPEN = re.compile(r"^```(\S*)\s*$")
MARKER = "book_block_marker_{}"
DEFINES = re.compile(r"^(?:def\s+)?([a-z_]\w*)\s*(?:\[[^\]]*\])?\s*(?:\(|=)", re.M)
IMPORTS = re.compile(r"^import\s+[\w.]+\s*\(([^)]*)\)", re.M)
WORD = re.compile(r"\b[a-z_]\w*\b")


@dataclass
class Block:
    lang: str
    code: str
    start: int  # line number of the opening fence, 1-based
    end: int  # index of the closing fence line, 0-based


@dataclass
class Captured:
    page: str
    code: str
    expected: str
    context: str
    line: int
    index: int  # position of the fragment among the page's code blocks


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


def strip_header(code: str) -> str:
    return "\n".join(line for line in code.splitlines()
                     if not re.match(r"^(module|export)\b", line))


def captured_examples(page: str, text: str, blocks: list[Block]) -> tuple[list[Captured], list[str]]:
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
                pairs.append(Captured(page, prev.code, block.code, "\n".join(earlier[:-1]),
                                      block.start, len(earlier) - 1))
        if block.lang in ("chelis", "chelis-fragment"):
            earlier.append(strip_header(block.code))
    return pairs, errors


IMPORT_MODULE = re.compile(r"^import\s+Nautilus\.(\w+)", re.M)
SANDBOX_ROOT: list[Path] = []


def closure(code: str) -> set[Path]:
    """The package source files `code` imports, directly or transitively."""
    seen: set[Path] = set()
    todo = IMPORT_MODULE.findall(code)
    while todo:
        path = SRC / f"{todo.pop().lower()}.ch"
        if path in seen or not path.exists():
            continue
        seen.add(path)
        todo += IMPORT_MODULE.findall(path.read_text())
    return seen


@contextmanager
def temp_source(stem: str, code: str):
    """A private package holding the modules `code` imports, plus a unique
    source path and module name for the example.

    Each `chelis` call loads every module in its package, so a package that
    holds only the example's import closure is what makes a call cheap. The
    modules it holds are the package's own files, so every name resolves to
    the same definition it does in the full package.
    """
    tag = uuid.uuid4().hex[:12]
    box = SANDBOX_ROOT[0] / f"{stem}{tag}"
    (box / "src").mkdir(parents=True)
    for name in ("reef.toml", "reef.lock"):
        if (REPO / name).exists():
            shutil.copy2(REPO / name, box / name)
    for source in closure(code):
        shutil.copy2(source, box / "src" / source.name)
    try:
        yield box, box / "src" / f"{stem}{tag}.ch", f"{stem.capitalize()}{tag}"
    finally:
        shutil.rmtree(box, ignore_errors=True)


def check_module(page: str, block: Block) -> tuple[bool, str]:
    with temp_source("bookcheck", block.code) as (box, tmp, name):
        # Rename the module to match the unique file; the book's own name
        # could be the name of a real src/ file.
        code = re.sub(r"^module\s+Nautilus\.\w+", f"module Nautilus.{name}", block.code, count=1, flags=re.M)
        tmp.write_text(code)
        result = subprocess.run([CHELIS, "check", str(tmp)],
                                capture_output=True, text=True, cwd=str(box))
    output = result.stdout.strip()
    try:
        d = json.loads(output)
    except json.JSONDecodeError:
        return False, (f"  FAIL: {page}:{block.start} module: "
                       f"stdout={output[:300]}, stderr={result.stderr[:200]}")
    if result.returncode == 0 and d.get("score") == 1 and not d.get("errors"):
        return True, ""
    return False, (f"  FAIL: {page}:{block.start} module "
                   f"(exit={result.returncode}, score={d.get('score')}, "
                   f"errors={d.get('errors', [])}, stderr={result.stderr[:200]})")


def evaluate(code: str) -> subprocess.CompletedProcess[str]:
    lines, seen = [], set()
    for line in code.splitlines():
        # Blocks often repeat an import or a one-line fixture definition.
        # Only unindented lines are top-level declarations.
        top_level = line[:1] not in ("", " ", "\t", "}", ")")
        if top_level and line in seen:
            continue
        seen.add(line)
        lines.append(line)
    with temp_source("bookcaptured", "\n".join(lines)) as (box, tmp, name):
        tmp.write_text(f"module Nautilus.{name}\n" + "\n".join(lines) + "\n")
        # A page shows an excerpt, not a formatted file: format the temporary
        # copy so the style gate judges nothing the reader cannot see.
        subprocess.run([CHELIS, "fmt", "--inplace", str(tmp)],
                       capture_output=True, text=True, cwd=str(box))
        return subprocess.run([CHELIS, "eval", "--file", str(tmp)],
                              capture_output=True, text=True, cwd=str(box))


def shows(expected: str, got: str) -> bool:
    """Every expected line appears in the evaluator's output, in order. The
    page may omit setup lines the evaluator also prints."""
    remaining = iter(got.strip().splitlines())
    return all(any(line == g for g in remaining) for line in expected.strip().splitlines())


def check_alone(ex: Captured) -> tuple[bool, str]:
    """The reference check: the fragment alone, then after the page's earlier blocks."""
    result = evaluate(ex.code)
    if not (result.returncode == 0 and shows(ex.expected, result.stdout)) and ex.context:
        result = evaluate(f"{ex.context}\n{ex.code}")
    if result.returncode == 0 and shows(ex.expected, result.stdout):
        return True, ""
    message = (f"  FAIL: {ex.page}:{ex.line} output (exit={result.returncode})\n"
               f"    expected: {ex.expected.strip()!r}\n"
               f"    got:      {result.stdout.strip()!r}")
    if result.stderr.strip():
        message += f"\n    stderr:   {result.stderr.strip()[:300]}"
    return False, message


def names_in(code: str) -> tuple[set[str], set[str]]:
    """(names the code defines or imports, words it uses)."""
    defined = set(DEFINES.findall(code))
    for group in IMPORTS.findall(code):
        defined.update(n.strip() for n in group.split(",") if n.strip())
    return defined, set(WORD.findall(code))


def forward_dependent(codes: list[str], pairs: list[Captured]) -> set[int]:
    """Fragments that use a name only a later block in the page program provides."""
    provided = [names_in(c)[0] for c in codes]
    out = set()
    for ex in pairs:
        before = set().union(*provided[:ex.index + 1])
        after = set().union(*provided[ex.index + 1:]) if ex.index + 1 < len(codes) else set()
        if (names_in(ex.code)[1] & after) - before:
            out.add(ex.line)
    return out


def check_page(codes: list[str], langs: list[str], pairs: list[Captured]) -> set[int]:
    """Evaluate the page as one program; return the lines of the output blocks it vouches for.

    The program is the page's complete modules and captured fragments, in page
    order. Illustrative fragments are left out: they are often signatures or
    excerpts that do not parse on their own.
    """
    starts = {ex.index: n for n, ex in enumerate(pairs)}
    codes = [c if (lang == "chelis" or k in starts) else "" for k, (c, lang) in enumerate(zip(codes, langs))]
    parts = []
    for k, code in enumerate(codes):
        if k in starts:
            parts.append(f"{MARKER.format(2 * starts[k])} = 0i64")
        parts.append(code)
        if k in starts:
            parts.append(f"{MARKER.format(2 * starts[k] + 1)} = 0i64")
    result = evaluate("\n".join(parts))
    if result.returncode != 0:
        return set()
    out = result.stdout.splitlines()
    position = {line.split(" = ", 1)[0]: i for i, line in enumerate(out)
                if line.startswith("book_block_marker_")}
    vouched = set()
    for n, ex in enumerate(pairs):
        lo, hi = position.get(MARKER.format(2 * n)), position.get(MARKER.format(2 * n + 1))
        if lo is not None and hi is not None and shows(ex.expected, "\n".join(out[lo + 1:hi])):
            vouched.add(ex.line)
    return vouched - forward_dependent(codes, pairs)


def main() -> int:
    if not DOCS_SRC.exists():
        print("docs/book/src/ not found, skipping book validation")
        return 0

    failures = 0
    messages: list[str] = []
    module_jobs: list[tuple[str, Block]] = []
    pages: list[tuple[list[str], list[str], list[Captured]]] = []
    for md_file in sorted(DOCS_SRC.rglob("*.md")):
        text = md_file.read_text()
        rel = str(md_file.relative_to(DOCS_SRC))
        blocks = fenced_blocks(text)
        module_jobs += [(rel, b) for b in blocks if b.lang == "chelis"]
        pairs, errors = captured_examples(rel, text, blocks)
        for error in errors:
            messages.append(f"  FAIL: {rel} {error}")
            failures += 1
        if pairs:
            code_blocks = [b for b in blocks if b.lang in ("chelis", "chelis-fragment")]
            pages.append(([strip_header(b.code) for b in code_blocks], [b.lang for b in code_blocks], pairs))
    captured = [ex for _, _, pairs in pages for ex in pairs]

    with tempfile.TemporaryDirectory(prefix="book-examples-") as root, \
            ThreadPoolExecutor(max_workers=WORKERS) as pool:
        SANDBOX_ROOT.append(Path(root))
        module_results = [pool.submit(check_module, page, b) for page, b in module_jobs]
        page_results = [pool.submit(check_page, *page) for page in pages]
        vouched = set()
        for (_, _, pairs), future in zip(pages, page_results):
            lines = future.result()
            vouched |= {(ex.page, ex.line) for ex in pairs if ex.line in lines}
        alone = [ex for ex in captured if (ex.page, ex.line) not in vouched]
        alone_results = [pool.submit(check_alone, ex) for ex in alone]
        for future in module_results + alone_results:
            ok, message = future.result()
            if not ok:
                failures += 1
                messages.append(message)

    for message in messages:
        print(message)
    print(f"{len(module_jobs)} complete modules and {len(captured)} output examples checked "
          f"({len(pages)} page programs, {len(alone)} fragments checked alone); {failures} failures.")
    status = 1 if failures else 0
    if len(module_jobs) < MIN_MODULES:
        print(f"FAIL: only {len(module_jobs)} complete `chelis` modules; need at least {MIN_MODULES}.")
        status = 1
    if len(captured) < MIN_CAPTURED:
        print(f"FAIL: only {len(captured)} output examples; need at least {MIN_CAPTURED}.")
        status = 1
    return status


if __name__ == "__main__":
    sys.exit(main())
