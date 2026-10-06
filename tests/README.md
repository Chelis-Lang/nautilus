# Nautilus tests/

Native Chelis identity and structural tests run with `chelis test tests/`.
This is the internal correctness gate on every PR.

SciPy parity lives in `parity/`. Python files under `tests/` fail the CI
hard-rule guard.

---

## How CI runs these

CI runs the positive and expected-failure suites on one runner:

```text
chelis test tests/ --jobs auto
chelis test tests_neg/ --expect neg
```

When `tests_blocked/` contains `.ch` probes, CI also runs
`chelis test tests_blocked/ --expect blocked`. The directory is empty at this
pin, so running that command exits nonzero. A populated blocked suite must
keep its pinned diagnostics; FIX-DETECTED or DRIFTED requires triage. See
[`tests_blocked/README.md`](../tests_blocked/README.md).

Use the serial fallback only for debugging order-dependent failures:

```sh
chelis test tests/ --jobs 1
```

The workflow downloads the released Chelis binary from GitHub Releases.
It must not build Chelis from source.

---

## Why per-file overhead matters more than per-test count

`chelis test` supports node-local file parallelism via `--jobs auto`.
There is still fixed compile/setup cost per file, so file count matters
for runtime. CI parallelizes files within a runner.

The practical consequence:

> **Adding tests to an existing file is usually cheaper than adding a new
> file.**

When you have a new identity to assert, **prefer extending an existing
test file** unless the imports / dependency surface are materially
different. Don't create `tests/foo_extra.ch` just because `tests/foo.ch`
already has 30 tests.

---

## Eight principles

1. **PR gate must complete in ≤ 5 minutes wall-clock.** Anything that
   doesn't fit gets demoted to a scheduled `nightly.yml` job or a
   post-merge runner. Long-running tests are a red flag, not a
   completeness signal.

2. **chelis-tests is the *internal-correctness* gate.** Mathematical
   identities (`erf(0) = 0`, `Q^T Q ≈ I`), structural invariants
   (transpose-of-transpose, trace-equals-sum-of-eigenvalues), exact
   known constants (π, e, √π, 1/e, …), round-trips
   (`erfinv(erf(x)) ≈ x`), smoke-callability. **No scipy.** If the
   expected value comes from `scipy.foo(...)`, the test belongs in
   `parity/`, not here.

3. **scipy-parity is the *external-oracle* gate.** Lives in
   `parity/run_parity.py`. It catches Nautilus drift from scipy
   semantics. Runs on every PR (it's fast — ~70s, batched probes).

4. **One test, one conceptual claim.** Pack assertions only when they
   share both setup AND failure mode. Don't pack `erf(0) = 0` and
   `gamma(1) = 1` together — they fail for different reasons. DO pack
   `erf` symmetry at three different x values into one
   `test_erf_odd_symmetry` (one setup, one failure mode: oddness
   broken).

5. **Per-file overhead still matters.** See the section above. Add tests
   to existing files unless the import surface materially changes
   (e.g., bringing in heavy LinAlg factorizations into a low-cost
   file).

6. **CI parallelizes locally at the file boundary.** Do not add custom
   per-file shell loops or GitHub matrix sharding for speed. Use
   `chelis test tests/ --jobs auto`; use `--jobs 1` only as a debugging
   fallback. Don't structure tests assuming serial execution.

7. **Use the existing correctness gates.** Native `tests/*.ch`,
   `tests_neg/`, and the checked-golden `parity/` project cover the positive,
   expected-failure, and external-oracle cases. Do not duplicate the golden
   corpus in another harness.

8. **Trivial tests are deleted on sight.** `assert_true(true, ...)`,
   `assert_close(x, x, tol)`, `assert_eq(constant, constant, label)`,
   tests where the expected value is computed from the actual value
   in the same expression — all banned. Smoke tests must call a real
   export with real input.

---

## How to add a test

1. **Pick the existing file** that already imports the symbol you want
   to test. `tests/special.ch` for special-function identities,
   `tests/distributions.ch` for PDF/CDF claims, `tests/linalg.ch`
   for vector ops, `tests/linalg_factor.ch` for the heavy
   factorizations (lu_solve, cholesky_n, qr_decompose, eig_n,
   cg_solve), `tests/linalg_matmul.ch` for matmul/permute/sum-using
   surface (transpose, det, inv, solve, gram, aat, frobenius, svd).

2. **Add a `def test_*() -> unit ! { Test }` function**. Prefer
   single-assertion tests for clarity. If you must pack multiple
   asserts:

   ```chelis
   module Nautilus.Tests.ReadmeExample
   import Nautilus.Distributions (normal_pdf)
   import Std.Test (assert_close)
   def test_normal_pdf_symmetry() -> unit ! { Test } = {
     left_half = normal_pdf(cast(-0.5, f32), cast(0.0, f32), cast(1.0, f32))
     right_half = normal_pdf(cast(0.5, f32), cast(0.0, f32), cast(1.0, f32))
     _ = assert_close(left_half, right_half, cast(1e-7, f32), "symmetric at 0.5")
     left_two = normal_pdf(cast(-2.0, f32), cast(0.0, f32), cast(1.0, f32))
     right_two = normal_pdf(cast(2.0, f32), cast(0.0, f32), cast(1.0, f32))
     assert_close(left_two, right_two, cast(1e-7, f32), "symmetric at 2")
   }
   ```

   Bind leading assertions as `_ = assert_*(...)` and leave only the
   final assertion bare in a multi-assert block.

3. **Run locally** before pushing:

   ```
   chelis test --filter test_my_new_thing --timeout 120 tests/<file>.ch
   ```

4. **Self-check:** `grep -E '[0-9]\.[0-9]{4,}' tests/<file>.ch`. Every
   4+-digit decimal must either be a documented mathematical constant
   (with an inline `--` comment naming it: `1.4142135` = √2, etc.) or
   be removed.

---

## Adding a new test file

Only do this if the dependency surface is materially different from
existing files. Adds another node-local file slot to the native test
suite.

When you do:

1. Create `tests/<name>.ch` with a `module Nautilus.Tests.<Name>`
   header.
2. **No CI yaml change needed** — CI runs `chelis test tests/ --jobs
   auto`.
3. **No README update needed** unless the new file represents a new
   testing pattern worth documenting in the "How to add a test"
   section above.

---

## Runtime constraints

The pinned `chelis test` host runtime supports `matmul`, `permute`, and
`sum`. `Nautilus.LinAlg` exports are testable natively. See
[`docs/UPSTREAM_BUGS.md`](../docs/UPSTREAM_BUGS.md) for active compiler
limitations.

Test conventions at the pinned compiler:

- The chelis test parser requires `_ = assert_*(...)` for all but the
  last assert in a multi-assert block (see point 2 of "How to add a
  test").
- `chelis test --jobs auto` is the default native-suite gate. Use
  `--jobs 1` when debugging.
- `assert_eq` is f32-strict. For int64 comparisons, use
  `assert_true(eq(x, y), "...")`.

---

## Forbidden imports / patterns

The CI hard-rule guards (`hard-rule-guard` job in `.github/workflows/ci.yml`)
will reject:

- `.py` / `.pyc` / `.pyi` files anywhere under `tests/`
- `import scipy` / `import numpy` / `import pandas` / etc. in any `.py`
  file under `src/` or `tests/`
- `scipy.foo(...)` / `numpy.linalg.solve(...)` / etc. in any `.ch` file
  (descriptive comments are fine — the grep matches dotted callable
  syntax, not bare-word mentions)
- An empty `tests/` directory (the native suite would otherwise have no
  tests to execute)
