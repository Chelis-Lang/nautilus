#!/usr/bin/env python3
"""Contract tests for scripts/validate_surface.py's README surface check.

The check reads export-name claims out of prose, so the interesting failure
is not "it rejected a bad README" but "it rejected a good one". Both
exclusions in `listed_names` rest on a property of the live surface, and the
last two tests here fail if the surface stops having that property -- so a
future export named `_private`, or a parenthesised backticked export name in
the README table, turns into a red test rather than a silently skipped claim.
"""
from __future__ import annotations

import re
import unittest
from pathlib import Path

from scripts.validate_surface import (
    INLINE_NAME_PATTERN,
    METHOD_SUFFIX_SHORTHAND,
    MODULES,
    README_TABLE_PATTERN,
    check_readme,
    listed_names,
    parse_exports,
)

REPO = Path(__file__).resolve().parent.parent


class ListedNamesTest(unittest.TestCase):
    def test_a_real_name_is_still_claimed(self):
        """The plain case: ordinary backticked names are read as claims.

        This is not what stops the exclusion tests passing vacuously -- each
        of those asserts against a non-empty expected set, so each already
        fails a `listed_names` that returns the empty set. Measured: delete
        this test and make `listed_names` vacuous, and 4 of the remaining 7
        still fail. It covers the unexcluded path directly instead.
        """
        self.assertEqual(listed_names("`erf`, `erfc` and `erfinv`"), {"erf", "erfc", "erfinv"})

    def test_parenthesised_token_is_not_a_claim(self):
        """``(`alpha`)`` is the row's stability label, not an export."""
        cell = "scalar `minimize` and `root` entry points (`alpha`)"
        self.assertEqual(listed_names(cell), {"minimize", "root"})

    def test_underscore_fragment_is_not_a_claim(self):
        """"names ending in `_stub`" states a pattern, not a name."""
        cell = "`fftfreq`; FFT, STFT, and filter names ending in `_stub` return NaN tensors"
        self.assertEqual(listed_names(cell), {"fftfreq"})

    def test_method_suffix_shorthand_is_not_a_claim(self):
        cell = "normal and lognormal `pdf`, `cdf`, `inv_cdf` plus `normal_pdf_t`"
        self.assertEqual(listed_names(cell), {"normal_pdf_t"})

    def test_a_label_word_that_is_also_an_export_survives(self):
        """`beta` is a real Nautilus.Special export as well as a label word.

        This is why the parenthesised rule is positional rather than a
        denylist of label names.
        """
        self.assertIn("beta", listed_names("`beta`, `lbeta` and `digamma`"))
        self.assertIn("beta", parse_exports(MODULES["Nautilus.Special"]))


class SurfaceInvariantTest(unittest.TestCase):
    """The two properties `listed_names`'s exclusions depend on."""

    def test_no_export_begins_with_underscore(self):
        offenders = sorted(
            name
            for path in MODULES.values()
            for name in parse_exports(path)
            if name.startswith("_")
        )
        self.assertEqual(
            offenders,
            [],
            "listed_names() skips leading-underscore tokens as naming-pattern "
            "fragments; an export spelled that way would be skipped silently. "
            "Narrow the rule before adding one.",
        )

    def test_no_parenthesised_table_token_is_an_export(self):
        txt = (REPO / "README.md").read_text()
        offenders = []
        for row in README_TABLE_PATTERN.finditer(txt):
            module, cell = row.group(1), row.group(2)
            if module not in MODULES:
                continue
            exports = parse_exports(MODULES[module])
            for match in INLINE_NAME_PATTERN.finditer(cell):
                token = match.group(1)
                if token in METHOD_SUFFIX_SHORTHAND:
                    continue
                start, end = match.span()
                if cell[max(0, start - 1):start] == "(" and cell[end:end + 1] == ")":
                    if token in exports:
                        offenders.append(f"{module}: ({token})")
        self.assertEqual(
            offenders,
            [],
            "listed_names() treats a parenthesised backticked token as an "
            "annotation; one that is also an export name would be skipped "
            "silently. Rewrite the README cell or narrow the rule.",
        )


class RealReadmeTest(unittest.TestCase):
    def test_the_committed_readme_has_no_surface_drift(self):
        failures: list[str] = []
        check_readme(failures)
        self.assertEqual(failures, [])


if __name__ == "__main__":
    unittest.main()
