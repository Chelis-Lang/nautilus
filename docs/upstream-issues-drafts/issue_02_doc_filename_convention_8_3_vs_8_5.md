# Issue 2: `doc-filename-convention` §8.3 vs §8.5 retroactive-correctness footgun

Labels: `lint`, `design-discussion`

Filed: [Chelis-Lang/chelis#190](https://github.com/Chelis-Lang/chelis/issues/190)
on 2026-05-22.

---

## Title

`doc-filename-convention`: §8.3 (snake_case) vs §8.5 (kebab-case)
dichotomy retroactively flips every `docs/*.md` correctness verdict
when `book.toml` is added or removed in any ancestor

## Body

### Summary

The `doc-filename-convention` lint rule classifies any `.md` file
under `docs/` into one of two disjoint slots based solely on whether
a `book.toml` exists anywhere in the file's ancestor chain:

- **§8.3 (`Slot::Docs`)** -- narrative docs, must be snake_case (or
  SCREAMING_SNAKE_CASE for status reports; or kebab-case when the
  filename stem matches a Cargo package name).
- **§8.5 (`Slot::BookSrc`)** -- mdBook chapters, must be kebab-case
  (with `SUMMARY.md` and `README.md` exempt as mdBook tool-required
  filenames).

The two slots are detected by a single boolean check: does any
ancestor of the file contain `book.toml`? Adding a `book.toml`
anywhere upstream flips every `.md` under that ancestor from §8.3
to §8.5. Removing it flips them back. The same filename
(`getting_started.md` vs `getting-started.md`) is correct under one
classification and a violation under the other.

This is a retroactive-correctness footgun: a single-file edit to
the docs scaffold reclassifies the correctness of every doc filename
in the tree.

### Reproducer

Two trees containing the same filename, differing only by the
presence of `book.toml`:

```
case_a/
  docs/
    getting-started.md

case_b/
  docs/
    book.toml          # [book]\ntitle = "x"\n
    getting-started.md
```

Run `chelis lint --check --rule doc-filename-convention .` in each:

```
$ cd case_a && chelis lint --check --rule doc-filename-convention .
=== 1 blocking lint error(s) ===
case_a/docs/getting-started.md: doc-filename-convention (§8.3): filename
`getting-started.md` does not match the convention for this directory:
snake_case for narrative documents; SCREAMING_SNAKE_CASE for status
reports (e.g., `STATUS.md`, `RELEASES.md`); kebab-case is accepted only
when the filename stem matches a Cargo package name in the workspace
exit 1
```

```
$ cd case_b && chelis lint --check --rule doc-filename-convention .
exit 0
```

The converse (same dichotomy in the other direction) also fires:

```
case_c/
  docs/
    getting_started.md   # passes under §8.3

case_d/
  docs/
    book.toml
    getting_started.md   # FAILS under §8.5: snake_case in mdBook tree
```

```
$ cd case_d && chelis lint --check --rule doc-filename-convention .
=== 1 blocking lint error(s) ===
case_d/docs/getting_started.md: doc-filename-convention (§8.5): filename
`getting_started.md` does not match the convention for this directory:
kebab-case (mdBook URL stability), with `SUMMARY.md` and `README.md`
exempt as mdBook tool-required filenames
exit 1
```

### Source anchor (rule code)

From `crates/chelis-lint/src/rules/doc_filename_convention.rs`,
lines 49-80 -- the `classify_doc` function whose output determines
the verdict:

```rust
fn classify_doc(path: &Path) -> Slot {
    // §8.5: any mdBook source tree uses kebab-case. An mdBook source tree
    // is detected by the presence of a `book.toml` in an ancestor directory.
    // This generalizes the prior `chelis/docs/book/src/` hardcode to handle
    // shell repos with different layouts (e.g., nautilus uses `docs/src/`).
    if is_inside_mdbook_tree(path) {
        return Slot::BookSrc;
    }
    let s = path.to_string_lossy();
    if s.contains("/spec/design/") {
        return Slot::SpecDesign;
    }
    if let Some(idx) = s.find("/spec/") {
        let after = &s[idx + "/spec/".len()..];
        if !after.contains('/') {
            // Distinguish §8.1 (numbered language specs in chelis/spec/)
            // from §8.2 (snake_case design/phase notes) by the filename
            // itself: a leading `NN-` prefix indicates intent to be a
            // numbered spec. Other names follow §8.2. This shape-based
            // dispatch works for both absolute and relative paths.
            let name = path.file_name().and_then(|n| n.to_str()).unwrap_or("");
            if numbered_spec_prefix(name) {
                return Slot::SpecTop;
            }
            return Slot::SpecDesign;
        }
    }
    if s.contains("/docs/") {
        return Slot::Docs;
    }
    Slot::Other
}
```

Lines 97-106 -- the `is_inside_mdbook_tree` detector that drives the
flip:

```rust
fn is_inside_mdbook_tree(path: &Path) -> bool {
    let s = path.to_string_lossy();
    if s.contains("/docs/src/") || s.contains("/docs/book/src/") {
        return true;
    }
    // book.toml-anchored detection. We walk every ancestor directory and
    // probe for `book.toml`. The probe is cheap (one stat() per ancestor)
    // and bounded by path depth; no recursive walk.
    has_ancestor_marker(path, "book.toml")
}
```

The `has_ancestor_marker` walk (lines 111-120) terminates at the
filesystem root, so adding `book.toml` at any height above a `docs/`
tree -- even many levels up -- switches every doc beneath it from
§8.3 to §8.5.

### Three-repo evidence

Snapshot of the chelis ecosystem on 2026-05-22:

| Repo            | `book.toml` location           | `docs/*.md` style observed |
|-----------------|--------------------------------|----------------------------|
| `hello-chelis`  | none                           | snake_case (§8.3): `getting_started.md`, `feature_matrix.md`, `surf_and_deep.md` |
| `coral`         | `docs/book.toml`               | kebab-case (§8.5): `upstream-bugs.md`, `releases.md`, `status.md` |
| `nautilus`      | `docs/book.toml`               | kebab-case (§8.5): `benchmark-findings.md`, `nautilus-status.md`, `upstream-bugs.md` |

nautilus 0.7.10 actually renamed five files from SCREAMING_SNAKE_CASE
(originally compliant under §8.3) to kebab-case to satisfy §8.5, after
its `docs/book.toml` triggered the §8.5 classification. This is the
footgun in action: the rename did not reflect a change in the docs'
content or audience, only a change in the lint rule's interpretation
of the same filename driven by an unrelated scaffolding change
(mdBook setup).

### Why this is a wart, not just a quirk

1. **Retroactive correctness flip.** Adding `book.toml` to a `docs/`
   directory containing N existing snake_case narrative docs
   instantly produces N new lint violations. Nothing in the docs
   themselves changed; the lint reclassified them because of a
   sibling file's existence. The reverse (removing `book.toml`)
   also flips every existing kebab-case file from §8.5 to §8.3
   violation.

2. **Unbounded ancestor reach.** `has_ancestor_marker` walks all
   the way to the filesystem root. A `book.toml` placed many
   directories above an unrelated `docs/` tree still reclassifies
   the tree. There is no proximity bound.

3. **The §8.3 vs §8.5 distinction conflates two orthogonal axes.**
   §8.5 (kebab-case mdBook chapters) exists because mdBook publishes
   each `.md` as a URL slug and kebab is web-canonical. §8.3
   (snake_case narrative docs) is a code-style choice unrelated to
   web publishing. Whether a doc is "mdBook-published" should be a
   property declared on the doc itself (e.g., presence in
   `SUMMARY.md`), not inferred from a scaffolding file's location.

4. **The narrative-docs and mdBook-chapter use cases overlap.** Many
   chelis-ecosystem repos use `docs/` for both narrative status
   reports (e.g., `STATUS.md`, `RELEASES.md` -- SCREAMING_SNAKE under
   §8.3) and mdBook chapters. Forcing one classification per tree
   means the status reports either misclassify or must move out of
   `docs/`.

### Suggested resolution

Several options, listed in increasing order of disruption:

**Option A -- Tighten §8.5 scope to mdBook-specific subdirectories.**
Require §8.5 to fire only when a file is *inside* an `src/`
subdirectory of a `book.toml`-rooted tree (i.e., revert the
generalization from the path-string fast path on lines 99-101), so
that a sibling `docs/STATUS.md` next to a `docs/book/` mdBook tree
falls under §8.3 and an `docs/src/foo.md` falls under §8.5. This
removes the retroactive flip on top-level `docs/*.md` while keeping
mdBook chapter conventions intact.

**Option B -- Split into two rules with disjoint scopes.**
- `doc-filename-narrative` (§8.3) scoped to `/docs/` but excluding
  paths matching mdBook chapter paths.
- `doc-filename-mdbook-chapter` (§8.5) scoped only to `/docs/src/`,
  `/docs/book/src/`, or paths declared in an ancestor `SUMMARY.md`.

This makes the rule names self-explanatory and removes the
"same rule, opposite verdict" ambiguity.

**Option C -- Drive classification from `SUMMARY.md` membership.**
A doc is an mdBook chapter iff it's listed in the nearest ancestor
`SUMMARY.md`. This eliminates the ancestor-walk reach and the
retroactive flip: adding `book.toml` does not reclassify
non-chapter docs.

**Option D -- Document the dichotomy explicitly in §8 and accept
the trade-off.** Add a "migration note" to the spec section
spelling out that adding mdBook scaffolding to an existing `docs/`
tree requires renaming all docs to kebab-case, and that this is
intentional. This is the lowest-effort resolution but doesn't
address the footgun.

### Cross-reference

This issue is tracked in
`nautilus/docs/upstream-issues-drafts/issue-02-doc-filename-convention-8-3-vs-8-5.md`
and referenced in nautilus's `CHANGELOG.md` under the 0.7.10 release
section ("Tracked upstream").
