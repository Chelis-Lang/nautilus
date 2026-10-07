#!/usr/bin/env python3
"""Unit tests for the beta-family accuracy oracle's bookkeeping.

The measurement itself is the gate and needs the compiler, so it is not
duplicated here. These cover the parts that silently decide what the gate sees:
the generated identifiers, the governing-parameter choice, and the coverage of
the documented table.

The identifier test is not hypothetical. The first version of this script named
each case after its parameters, which produced `acc_1e+06_0p01` -- and `chelis`
rejected the file with "unrecognized literal suffix `p01`", because `06_0` was
lexed as a number. Names are positional now, and this pins that.
"""

from __future__ import annotations

import re
import unittest

from check_beta_accuracy import DOCUMENTED, PHI1, cases, f32

IDENTIFIER = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")


class Names(unittest.TestCase):
    def setUp(self) -> None:
        self.spec = cases()

    def test_every_generated_name_is_a_valid_identifier(self) -> None:
        for name, _, _, _, _ in self.spec:
            self.assertRegex(name, IDENTIFIER, f"{name!r} is not a usable def name")

    def test_no_name_contains_a_character_the_lexer_reads_as_a_literal(self) -> None:
        for name, _, _, _, _ in self.spec:
            for bad in "+-.e":
                if bad == "e":
                    continue        # 'e' is fine in a name, just not beside digits
                self.assertNotIn(bad, name, f"{name!r} would not lex")

    def test_names_are_unique(self) -> None:
        names = [name for name, _, _, _, _ in self.spec]
        self.assertEqual(len(names), len(set(names)))

    def test_every_name_shares_the_module_domain_prefix(self) -> None:
        # chelis §7.1 rejects a shared prefix that is not the module's own
        # shorthand, and the style gate runs before the build.
        for name, _, _, _, _ in self.spec:
            self.assertTrue(name.startswith("acc_"), name)


class GoverningParameter(unittest.TestCase):
    """The range is indexed on the LARGE parameter. Indexing it on the small one
    is the defect a red-team round found: for `student_t_cdf` the small parameter
    is always 0.5, so such a range would describe nothing."""

    def test_beta_cases_are_indexed_on_the_larger_parameter(self) -> None:
        spec = [s for s in cases() if s[1] == "beta_cdf"]
        self.assertTrue(spec)
        for name, _, expr, governing, _ in spec:
            numbers = [float(v) for v in re.findall(r"cast\(([-\d.e+]+), f32\)", expr)]
            # expr is beta_cdf(x, a, b)
            _, a, b = numbers
            self.assertEqual(governing, max(a, b), f"{name}: {expr}")
            if a != b:
                self.assertNotEqual(governing, min(a, b), f"{name} indexed on the small one")

    def test_student_t_is_indexed_on_df_not_on_the_constant_half(self) -> None:
        spec = [s for s in cases() if s[1] == "student_t_cdf"]
        self.assertTrue(spec)
        for name, _, expr, governing, _ in spec:
            self.assertNotEqual(governing, 0.5, f"{name}: df, not b")
            self.assertGreaterEqual(governing, 1.0)


class Coverage(unittest.TestCase):
    def test_documented_covers_every_export_measured(self) -> None:
        measured = {export for _, export, _, _, _ in cases()}
        self.assertEqual(measured, set(DOCUMENTED))

    def test_every_export_has_a_case_inside_its_documented_range(self) -> None:
        inside = {export for _, export, _, governing, _ in cases()
                  if governing <= DOCUMENTED[export][0]}
        self.assertEqual(inside, set(DOCUMENTED),
                         "an export with no in-range case cannot fail the gate")

    def test_every_export_has_a_case_at_the_top_of_its_range(self) -> None:
        for export, (limit, _) in DOCUMENTED.items():
            tops = [g for _, e, _, g, _ in cases() if e == export and g >= limit / 10]
            self.assertTrue(tops, f"{export} is never exercised near {limit:g}")

    def test_the_bound_is_not_silently_widened(self) -> None:
        # A future edit that relaxes a bound has to change docs/book too; this
        # pins the value the documents currently state.
        for export, (limit, bound) in DOCUMENTED.items():
            self.assertEqual(bound, 1e-6, export)
            self.assertEqual(limit, 3e8, export)


class ReferenceFreeAnchors(unittest.TestCase):
    def test_symmetric_beta_and_f_cases_use_the_exact_half(self) -> None:
        anchors = [s for s in cases()
                   if s[1] in {"beta_cdf", "f_cdf"} and s[4] == 0.5
                   and re.search(r"cast\(([-\d.e+]+), f32\)\, cast\(\1, f32\)", s[2])]
        self.assertTrue(anchors, "the symmetry anchors are gone")

    def test_the_largest_df_cases_use_the_normal_limit(self) -> None:
        normals = [s for s in cases() if s[1] == "student_t_cdf" and s[4] == PHI1]
        self.assertTrue(normals, "no case checks student_t against the normal limit")
        # and they are the ones past where scipy's own betainc saturates
        for _, _, _, governing, _ in normals:
            self.assertGreaterEqual(governing, 1e9)


class F32(unittest.TestCase):
    def test_f32_rounds_like_the_compiler(self) -> None:
        self.assertEqual(f32(0.99999994), 0.9999999403953552)
        self.assertEqual(f32(1e8) + 1.0, 100000001.0)   # the f64 sum is exact


if __name__ == "__main__":
    unittest.main()
