# Upstream Chelis bugs found during Nautilus development

This file collects upstream chelis issues discovered during red-team
rounds across Nautilus Phases P0–P3. Each entry includes a minimal
reproduction, the workaround currently in use downstream, and a
per-release **status** line recording what changed.

## v0.2.4 validation (2026-04-25)

- `chelis check src/*.ch` — all 21 modules score 1.0, zero errors.
- `chelis reef build` — produces `dist/nautilus-0.2.2.chb` cleanly.
- `chelis 0.2.4 python tests/run_numeric_tests.py` — **1096 / 1096
  numerical assertions pass** (no regressions vs the v0.2.3 baseline).
- `chelis test --help` — present, documents `--filter`, `--json`,
  `--timeout`. CLI subcommand surface as advertised in the cutover spec.
- **`Std.Test` strict-load probe:** wrote a one-test fixture
  (`/tmp/std-test-probe/tests/probe.ch`) that does
  `import Std.Test (assert_close, assert_true)` and runs `chelis test
  tests/`. Passed cleanly:
  ```
  test_id_close ................. PASS
  test_true ..................... PASS
  ```
  The v0.2.3 strict-load gripe documented in `pseudo_nautilus/tests/
  special.ch` (lines 5–13) is **resolved in v0.2.4**. Nautilus tests
  written during the cutover use `import Std.Test` directly — no
  fallback to raw `test_assert*` builtins is required.

## v0.2.4 upstream observations from cutover red-team (2026-04-25)

These are not bugs but observations worth raising upstream because they
shaped how the Nautilus tests/ files had to be written:

- **`chelis test` recompiles per test function and `--filter` does not
  amortize this cost.** Empirically (red-team CRITICAL-2):
  - `chelis test tests/special.ch` (51 tests) — 31.96 s wall-clock
  - `chelis test --filter test_erf_zero tests/special.ch` (1 test) — 30.17 s
  Filter saves ~6 % — virtually nothing. Per-file compile dominates;
  the `chelis __test_file` worker re-walks the dependency graph for
  every test function. For Nautilus this means the test surface is
  bounded by per-test compile cost, not by the number of small
  assertions. Concretely: `tests/linalg.ch` was originally written as
  4 packed mega-tests (200+ assertions in 4 functions) but timed out
  at >10 min because each per-test compile pulled in the heavy
  factorization graph. The shipped form splits cheap vector ops
  (`tests/linalg.ch`, 29 small tests) from heavy factorizations
  (`tests/linalg_factor.ch`, 6 small tests, ~10 min wall-clock).
- **`chelis eval --file` pays the same per-call compile cost** (~35 s
  with `Nautilus.Special` imported). The Nautilus parity script
  (`parity/run_parity.py`) batches all samples for a domain into one
  probe (`result_0 = ...`, `result_1 = ...`, ...) so total wall-clock
  is ~70 s for 205 samples instead of ~2 hours.
- These compile costs would benefit from a session-cached eval daemon
  or per-build artifact reuse. Recording for future upstream design.

Summary as of **v0.2.0** (Nautilus) / **v0.1.21** (Chelis):

- Historical Bugs 1–5 below are fixed in the released compiler line through
  `v0.1.7`, and the pinned Nautilus surface remains fully wired into the
  current runtime harness on the validated `v0.1.20` toolchain
  (`1051 / 1051` numerical assertions pass as of Nautilus v0.2.0).
- Re-validation against `v0.1.9`–`v0.1.20` on the post-v0.1.7 blockers:
  - **generic fold/control-flow lowering on tensor accumulators is
    FULLY FIXED (since `v0.1.18`).** Both sub-blockers cleared: (a) tuple
    fold with a tensor in slot 0, and (b) tensor-valued `if` inside the
    fold body. General-`n` Cholesky shipped in Nautilus v0.1.3.
  - tensor-valued `grad` at the C-backend lowering level remains blocked
    through `v0.1.20`. `v0.1.19` introduced a new `grad(expr, wrt = var)`
    expression syntax returning `(value, gradient)` tuples (type-checks at
    score 1.0). Despite the syntax improvement, `grad(expr, wrt = var)`
    still fails `chelis build` in v0.1.20 with the error: "can't lower
    these defs — their body applies/binds `grad` (or `vmap`) in a position
    the host lane can't resolve". The workaround path `grad(local,
    wrt=(arg))(arg)` is the only form that builds. Probe also confirms
    `grad` inside a fold body fails build (the error explicitly states
    "`grad` through host-lane `fold`/`map` is not currently supported").
    Multi-parameter LM stays blocked on the grad path; `lm_scalar_nparam`
    ships in Nautilus v0.2.0 using a finite-difference Jacobian workaround.
    Status as of v0.1.21: **still blocked** (not addressed in this release).
  - Recursive inliner bugs (Bug 6, Bug 7 below): **FIXED in v0.1.21**.
    The recursive `lm_jtr_sum` / `lm_jtj_sum` / `lm_jtj_row_sum` formulation
    compiles, builds, and produces correct results. `lm_scalar_nparam` in
    Nautilus v0.2.0 reverts to the cleaner recursive formulation on v0.1.21.

  **New bugs found during Nautilus v0.2.0 / `lm_scalar_nparam` development
  (2026-04-23, against v0.1.20):**

  **Bug 6 — Recursive inliner: NULL shadow on tensor accumulator**
  When the compiler inlines a recursive call that passes a named
  tensor-accumulator variable, the inlined body re-declares the same C
  intermediate name in the inner scope, shadowing the correctly-allocated
  outer variable. The inner shadow is uninitialized (NULL), and the
  explicit NULL-validation stub the harness injects catches it, producing
  `SIGABRT`. Affects any recursive function where the accumulator is a
  tensor passed as a regular argument (not the return value). Status
  as of v0.1.20: **open**. Status as of v0.1.21: **FIXED** — the
  recursive `lm_jtr_sum` / `lm_jtj_sum` formulation compiles and runs
  correctly; `lm_scalar_nparam` reverts to recursive Jacobian assembly.
  Workaround (v0.1.20 only): restructure recursive tensor accumulation as
  top-level folds with the accumulator in the fold's built-in accumulator
  position; never pass intermediate tensor accumulators as explicit
  recursive call arguments.

  **Bug 7 — Recursive inliner: increment propagation to constant arguments**
  When the compiler inlines a recursive call whose counter argument is
  `add(i, cast(1, int64))`, it incorrectly applies the same `+1` increment
  to **all** integer constants inside the inlined body, including
  `cast(0, int64)` literals passed to other called functions. For example,
  `lm_jtj_sum` (which recurses with `add(i, cast(1,int64))`) calls
  `lm_jtj_row_sum(... cast(0, int64) ...)` inside its body; after inlining,
  the `cast(0, int64)` becomes `cast(1, int64)`, causing the row accumulator
  to start at column 1 instead of column 0. Produces wrong numeric results
  (and eventually a `to_list expects a rank-1 tensor` runtime crash when the
  wrong index propagates to a rank-2 value). Status as of v0.1.20: **open**.
  Status as of v0.1.21: **FIXED** — confirmed by the recursive
  `lm_jtj_sum(... cast(0, int64) ...)` call chain producing correct JTJ
  matrices in all test cases (1051/1051 pass with the recursive formulation).
  Workaround (v0.1.20 only): avoid recursive functions for n-parameter Jacobian
  assembly; use flat `fold` over `range(0, n_sq)` with integer `div` and `sub`
  to decode `(i, j)` from a flat index `k`.

  **Bug 8 — Fold closure captures by-move; sequential folds sharing
  tensors need explicit named copies**
  Chelis fold closures capture tensor variables from the enclosing scope
  by-move (consuming them). Two sequential folds in the same function scope
  cannot capture the same tensor — the second fold's closure creation fails
  type-checking with "copy requires tensor input, got ?NNN" because the
  tensor was consumed by the first fold's closure. Scalars (`f32`, `int64`)
  and function types are non-affine and can be captured freely by multiple
  closures. Status as of v0.1.20: **by-design** (affine semantics) but the
  error message is confusing because the failure surfaces at a `copy` call
  downstream of the actual capture site. Workaround: before the first fold,
  create explicit named copies for each fold that needs the variable (e.g.
  `x_c1 = copy(x)` for the JTR fold, `x_c2 = copy(x)` for the JTJ fold),
  and reference the named copies inside the respective fold bodies.

  **v0.1.20 validation findings (2026-04-22):**
  - `chelis check` all 21 `src/*.ch` modules: all score 1.0, zero errors.
  - `chelis reef build`: produces `dist/nautilus-0.1.4.chb` cleanly.
  - `tests/run_numeric_tests.py`: `994 / 994` numerical assertions passed.
  - Grad probe (`grad(loss, wrt = theta)` where `loss = einsum("i,i->", v,
    v)`): `chelis check` passes score 1.0; `chelis build` fails with
    "can't lower" diagnostic. Blocker persists unchanged from v0.1.19.
  - Fold-grad probe (`grad` used inside fold body via `jacobian_col`):
    `chelis check` passes score 1.0; `chelis build` fails with same
    "can't lower" diagnostic, additionally noting "`grad` through
    host-lane `fold`/`map` is not currently supported". Both the direct
    and fold-wrapped grad paths remain blocked.

  **Bug 9 — `chelis eval --file` hangs indefinitely in v0.1.21**
  `chelis eval --file <path> <expr>` blocks without producing output or
  exiting when the file contains a Nautilus reef import (e.g.
  `import Nautilus.Special (erf)`). Inline `chelis eval <expr>` (no
  `--file`) continues to work. Affects `scripts/bench_eval_startup.py`
  which probes all Nautilus import scenarios via `--file`; the script now
  applies a 5-second probe timeout and marks all file-backed scenarios as
  "blocked" on affected toolchains. Status as of v0.1.21: **open**.
  Workaround: use inline `chelis eval <expr>` for expressions that don't
  require file-based reef imports; or set `_PROBE_TIMEOUT_S` in the
  benchmark script to bound the hang.

  **v0.2.1 validation findings (2026-04-23):**
  - `chelis check src/*.ch`: all 21 files score 1.0, no errors.
  - `chelis reef build`: produces `dist/nautilus-0.2.1.chb` cleanly.
  - `tests/run_numeric_tests.py`: 1051 / 1051 numerical assertions passed.
  - Bug 9 (`chelis eval --file` hang): still open in v0.2.1 — `timeout 3 chelis eval --file probe.ch bench` exits 124. Benchmark probe timeouts remain necessary.
  - Tensor-valued `grad` blocker: not retested; `lm_scalar_nparam` continues to use FD Jacobian.
  - No new bugs observed.

  **v0.2.0 validation findings (2026-04-23):**
  - Skipped — upgraded directly to v0.2.1 (same-day release, supersedes v0.2.0).

  **v0.1.21 validation findings (2026-04-23):**
  - `chelis check src/curvefit.ch`: score 1.0 with recursive Jacobian
    formulation (`lm_jtr_sum`, `lm_jtj_sum`, `lm_jtj_row_sum`).
  - `chelis reef build`: produces `dist/nautilus-0.2.0.chb` cleanly.
  - `tests/run_numeric_tests.py`: `1051 / 1051` numerical assertions passed
    with the recursive formulation — confirms Bug 6 and Bug 7 both fixed.
  - Tensor-valued `grad` blocker: not retested (migration guide confirms it
    remains open in v0.1.21; `lm_scalar_nparam` continues to use FD Jacobian).
  - `chelis eval --file` hangs (Bug 9); `bench_eval_startup.py` patched
    with probe timeout; all import scenarios reported as "blocked".

Original historical summary as of **v0.1.6** — original six bugs all fixed, one
new bug found:

| # | Title | v0.1.3 | v0.1.4 | v0.1.5 | v0.1.6 | v0.1.7 |
|---|---|---|---|---|---|---|
| 1 | Unknown-name silent compile | open | **FIXED** | fixed | fixed | fixed |
| 2 | Shape-checker gap for literal-dim tensor params | open | open | open | **FIXED** | fixed |
| 3a | — emitted C was raw pointer arithmetic (original v0.1.3 symptom) | open | likely superseded | superseded | **FIXED** (proper elementwise loop emitted) | fixed |
| 3b | — `chelis build` requires `libchelis_runtime.a` not shipped in tarball | n/a | **NEW in v0.1.4** | **FIXED** | fixed | fixed |
| 3c | — main-entry C emission drops parameters / confuses function names | n/a | **NEW in v0.1.4** | open | **FIXED** | fixed |
| 4 | Nested `exp(neg(mul(x,x)))` int-temp | open | **FIXED** | fixed | fixed | fixed |
| 5 | Fused tensor op `n_in` assertion mismatch | n/a | n/a | n/a | **NEW in v0.1.6** | **FIXED** |

**What v0.1.5 unblocked downstream:**
- `tests/run_numeric_tests.py` dropped the hand-vendored `RUNTIME_STUBS`
  block and now links against the real `libchelis_runtime.a` that
  v0.1.5 copies into the build output dir. 632 / 632 assertions
  still pass.
- `scripts/bench_vs_scipy.py::build_shared_lib` dropped the hand-vendored
  `RUNTIME_STUBS` for the same reason. The P5 Track 1 LTO +
  visibility workaround (`-flto -fuse-linker-plugin -fvisibility=hidden
  -Wl,-Bsymbolic`) **remains load-bearing in v0.1.5** — v0.1.5's
  C backend still emits cross-TU helpers as extern, so `-shared -fPIC`
  still forces PLT indirection and blocks inlining. Measured regression
  from dropping the flags: 6.7 → 18.9 ns/el (3×) on
  `normal_cdf(x)*exp(-x²)` at n=100k. Flags restored with an updated
  comment citing the v0.1.5 measurement.

**What v0.1.5 did NOT unblock:**
- LinAlg / Distance / SDE / Stats tensor-path runtime verification is
  still gated on Bug 3c. A multi-tensor-input main entry point still
  emits `n_in == 1`, slot 0 labeled by the helper function name, and
  a body that drops the second operand. ~100+ scipy-parity assertions
  in `tests/goldens/linalg/`, `tests/goldens/distance/`, and the
  tensor-path `Nautilus.Stats`/`Nautilus.SDE`/`Nautilus.Interpolation`
  paths remain deferred.

This section is historical. Those tensor-path issues were later fixed
upstream and are now exercised by Nautilus's current `994 / 994`
runtime-harness pass on the pinned `v0.1.19` toolchain.

Original repros below were run against `chelis v0.1.3-linux-x86_64`.
Re-verifications against subsequent releases are noted inline.

---

## 1. Unknown-name silent compile (CRITICAL) — **FIXED in v0.1.4**

**Severity:** critical (silent wrong answers on user-provided function
arguments).

**v0.1.4 status: FIXED.** Re-running the minimal repro against
`chelis v0.1.4-linux-x86_64` now produces a structured error:
```
"unresolved_names": ["cos"],
"errors": [{"kind":"UnboundVariable","message":"unbound variable: cos","severity":0.6}]
```
and fitness score drops to 0.78, failing the CI gate. The
Nautilus-side workaround (`sin(add(x, π/2))` in
`tests/run_numeric_tests.py::cos_minus_x`) is preserved as a passing
identity test since `cos` is still not a Chelis scalar builtin — the
bug fix is "unknown names now error loudly," not "cos is provided."

**Symptom.** Any unresolved function name in expression position is
accepted by the type checker and lowered by the C backend as the identity
function. For example, `cos(x)` — which is not a Chelis builtin — type-
checks cleanly and compiles to a no-op that returns `x`.

**Minimal repro.**

```chelis
def probe(x: f32) -> f32 = sub(x, cos(x))
def main() -> f32 = probe(cast(1.0, f32))
```

```shell
$ chelis check /tmp/probe.ch
{"score": 1, "components": {...}, "errors": []}    # silently passes
$ chelis build /tmp/probe.ch -o /tmp/out
$ grep -c 'cos' /tmp/out/probe.c                   # zero references
0
```

The generated C never references `cos` at all; the whole `sub(x, cos(x))`
expression reduces to `x`.

**Expected behavior.** `chelis check` should emit
`unresolved name: cos` (or similar) as a structured error. Instead
`unresolved_names: []`.

**Where it lives in chelis.** Name resolution / type-env lookup path
(`crates/chelis-types` or `crates/chelis-effects`, whichever handles the
pre-resolution pass for `(app {} (var {} cos) ...)` nodes). The symptom
suggests that unknown names are being threaded through the type
environment as polymorphic identity rather than flagged as errors.

**Downstream impact.** Any user `f: f32 -> f32` argument supplied to
`Nautilus.Roots.{bisection,newton,brent}`,
`Nautilus.ODE.{euler_*,rk4_*}`, `Nautilus.Integrate.{trapezoidal,
simpsons,gauss_legendre_5,adaptive_simpson,romberg_5,gauss_legendre_10}`,
or `Nautilus.Optim.{golden_section_search,brent_minimize,
gradient_descent_1d,newton_minimize_1d}` that references a non-builtin
scalar function (`cos`, `tan`, `atan`, `cosh`, `abs`, `floor`, `ceil`, …)
silently returns wrong answers with no diagnostic.

**Downstream workaround.** Nautilus test code expresses `cos` as
`sin(add(x, π/2))`, `abs` as `if lt(x, 0) then neg(x) else x`, etc. All
module-internal helper functions are documented and audited; users are
warned in `spec/phase3j.md`'s known-limitations section that only the
builtins listed at the top of that doc are safe to call from user
functions.

**Suggested fix sketch.** In the type environment lookup path, when an
`(app {} (var {} NAME) ...)` node's `NAME` is not found, emit a hard
`UnresolvedName` error instead of defaulting to an inferred polymorphic
type. The downstream code path that accepts this silently should have a
diagnostic added (probably a `TODO` or `unimplemented!`) that currently
returns success.

---

## 2. Shape-checker gap for literal-dim tensor parameters (CRITICAL) — **still open in v0.1.4**

**Severity:** critical for negative-test parity claims; medium in
practice (users don't routinely pass wrong-shape inputs, but the spec
promises shape enforcement).

**v0.1.4 status: NOT FIXED.** Re-running the `bad_consumer[m, n]`
repro against v0.1.4:
```
{"score": 1, "unresolved_names": [], "errors": []}
```
`det_2x2(a: tensor[2, 2, f32])` still accepts `tensor[m, n, f32]`
with no error. The suggested fix (`d-lit` parameters requiring exact
match in tensor unification) has not landed. Remains the blocker on
the "negative tests: wrong input shapes" acceptance bullet in
`spec/phase3j.md`.

**v0.1.5 status: NOT FIXED.** Re-running the same repro against
`chelis v0.1.5-linux-x86_64` returns identical output (score 1,
zero errors, empty unresolved_names). Still the blocker on the
negative-test acceptance bullet.

**v0.1.6 status: FIXED.** Re-running the repros against
`chelis v0.1.6-linux-x86_64`:

- `bad_consumer[m, n](a) = det_2x2(a)` — score drops to 0.88, emits
  two `DimensionMismatch: polymorphic dim variable forced to
  concrete Lit(2) by function body — declared dim parameters must
  remain polymorphic` errors.
- `def main(a: tensor[3, 3, f32]) -> f32 = det_2x2(a)` — score
  drops to 0.86, emits `DimensionMismatch: dimension mismatch:
  Lit(2) vs Lit(3)`.

Both wrong-shape and polymorphism-violation angles are now caught
at `chelis check` time. The "negative tests: wrong input shapes"
acceptance bullet in `spec/phase3j.md` §Test Plan is now satisfied
at compile time rather than deferred to runtime.

**Symptom.** `chelis check` does not enforce tensor dimension equality
for literal-size parameters. A function declared `def f(a: tensor[2, 2,
f32])` accepts calls with `tensor[3, 3, f32]`, `tensor[7, 9, f32]`,
`tensor[2, 2, int32]`, or even `f32` (scalar) arguments without any
error.

**Minimal repro.**

```chelis
def want_2x2(a: tensor[2, 2, f32]) -> f32 = trace(a, 0, 1)
def main() -> f32 = want_2x2(uniform_like(cast(0.0, f32), 0.0, 1.0))  # bare f32
```

Or more realistically:

```chelis
def bad_consumer[m, n](a: tensor[m, n, f32]) -> f32 =
  det_2x2(a)   # det_2x2 declares tensor[2, 2, f32]; passes with any (m, n)

def main() -> f32 = cast(0.0, f32)
```

Both type-check at score 1.0 with zero errors.

**Expected behavior.** Each literal-dim parameter should unify
dimension-by-dimension at the call site; mismatch → `DimensionMismatch`
error. Polymorphic dim variables should unify only with other polymorphic
dim variables or concrete matches.

**Where it lives in chelis.** Likely `crates/chelis-types` tensor
unification path for `d-lit` nodes. The symptom is that `d-lit` in a
parameter type is being treated as a polymorphic `d-var` during call-
site unification.

**Downstream impact.** Spec test plan (`spec/phase3j.md` §Test Plan)
requires "negative tests: wrong input shapes, unsupported types". These
cannot be satisfied via `chelis check` alone under v0.1.3. Nautilus
documents this gap in the Known Limitations section of the spec and
defers shape enforcement to runtime (which is itself upstream-blocked on
`libchelis_runtime.a`).

**Suggested fix sketch.** During tensor type unification, treat `d-lit
N` parameters as requiring exact match against the argument's dim at
that position. Only `d-var` / `d-name` should allow polymorphic
unification. If this was intentional for phase-early checker leniency,
add a CLI flag (`chelis check --strict-dims`) to opt in.

---

## 3a. C backend emits raw pointer arithmetic for tensor-on-tensor `add`/`mul` (HIGH) — original v0.1.3 symptom

**Severity:** high — any Nautilus function that combines two rank-2
tensors via `add` or `mul` fails to link as a standalone C binary even
when the math is correct.

**v0.1.4 status: likely superseded.** The pointer-arithmetic
emission path observed in v0.1.3 appears to have been rewritten in
v0.1.4 — `chelis build` now unconditionally routes through the
runtime path (see Bug 3b) rather than emitting inline `tensor* +
tensor*`. We could not directly re-verify the original symptom
against v0.1.4 because the runtime-link step fails before C
inspection is possible, and the few emission paths we did inspect
(via partial builds) exhibit the distinct Bug 3c symptom instead.
Treat 3a as "probably fixed or replaced by 3b/3c" rather than
independently confirmed.

---

## 3b. `chelis build` unconditionally requires `libchelis_runtime.a` not shipped in the release tarball (CRITICAL) — **NEW in v0.1.4**

**Severity:** critical — every `chelis build` invocation, including
scalar-only programs, fails at the link step out of the box after
downloading the v0.1.4 release tarball.

**Symptom.** The v0.1.4 `chelis` binary emits `chelis_runtime.h` and
C source on every build and then attempts to link against a runtime
archive that the release tarball does not contain:

```shell
$ tar tzf chelis-v0.1.4-linux-x86_64.tar.gz
chelis-v0.1.4-linux-x86_64/
chelis-v0.1.4-linux-x86_64/README.md
chelis-v0.1.4-linux-x86_64/LICENSE
chelis-v0.1.4-linux-x86_64/chelis

$ cat > /tmp/scalar.ch <<'EOF'
def main() -> f32 = cast(1.5, f32)
EOF
$ chelis build /tmp/scalar.ch -o /tmp/out
error: cannot find libchelis_runtime.a; set CHELIS_RUNTIME_DIR or
install chelis so libchelis_runtime.a is available relative to the
chelis executable
$ ls /tmp/out
chelis_runtime.h  scalar.c  scalar.h
```

The C emission succeeds (files are on disk), but the automatic
link step fails because there is no `.a` to link against and no
`CHELIS_RUNTIME_DIR` default.

**Expected behavior.** Either (a) the release tarball ships
`libchelis_runtime.a` alongside the binary, or (b) `chelis build`
supports a `--no-link` / `--emit-c-only` mode so callers that
compile the emitted C with their own toolchain (as Nautilus does)
can bypass the link step cleanly.

**Where it lives in chelis.** Release-packaging infrastructure
(CI tarball assembly) plus possibly `crates/chelis-cli` build
command orchestration.

**Downstream impact.** Nautilus's `tests/run_numeric_tests.py`
passes 526/526 only because it compiles emitted C manually with
gcc against its own `RUNTIME_STUBS` set, bypassing the
chelis-builtin link step. Any user who downloads v0.1.4, reads
the README, and runs `chelis build hello.ch` will hit the link
failure on their first program. First-run experience is broken.

**Suggested fix.** Ship `libchelis_runtime.a` in the release
tarball. The symbol surface is already defined by
`chelis_runtime.h` (260 lines, ~60 entry points as of v0.1.4) and
the Rust runtime crate already exists at `crates/chelis-runtime/`
in the monorepo — this is a CI packaging task, not a code change.

**v0.1.5 status: FIXED.** The v0.1.5 release tarball now contains
`bin/chelis`, `lib/libchelis_runtime.a`, and
`include/chelis_runtime.h`, and `chelis build` copies both the
archive and header into its output directory alongside the
generated `.c` / `.h` files. `chelis build hello.ch` on a scalar
program now runs to completion without a link error.
Nautilus `tests/run_numeric_tests.py` and
`scripts/bench_vs_scipy.py::build_shared_lib` both dropped their
hand-vendored `RUNTIME_STUBS` blocks and now link against the real
archive. 632 / 632 numerical assertions still pass.

---

## 3c. C-backend main-entry emission drops parameters / confuses function names (HIGH) — **NEW in v0.1.4**

**Severity:** high — when a program's entry-point signature
includes more than one tensor parameter, the emitted C silently
drops all but the first and mislabels it using the name of an
inlined helper function.

**Symptom.** Minimal repro:

```chelis
def combine(a: tensor[4, f32], b: tensor[4, f32]) -> tensor[4, f32] =
  add(a, b)

def main(x: tensor[4, f32], y: tensor[4, f32]) -> tensor[4, f32] =
  combine(x, y)
```

Emitted C entry point (`chelis v0.1.4-linux-x86_64`):

```c
void bug3f(chelis_tensor **inputs, int n_in,
           chelis_tensor **outputs, int n_out) {
    if (n_in != 1) {                                   // BUG: expected 2
        fprintf(stderr, "bug3f: expected %d inputs, got %d\n", 1, n_in);
        abort();
    }
    /* ... */
    if (inputs[0] == NULL) {
        fprintf(stderr, "bug3f: input `combine` at slot 0 is NULL\n");
        //                                     ^^^^^^^
        //   BUG: "combine" is the name of the HELPER function, not a parameter
        abort();
    }
    if (inputs[0]->ndim != 1) { /* ... */ }
    chelis_tensor *t0 = inputs[0];
    outputs[0] = chelis_contiguous(t0);   // BUG: no add, no second operand
    if (outputs[0] != t0) chelis_free(t0);
}
```

Three things are wrong:

1. `n_in == 1` instead of 2 — one of the two `main` parameters has
   been silently dropped.
2. The diagnostic label for `inputs[0]` is `"combine"` — the name of
   the helper function `main` calls, not either of `main`'s two
   actual parameter names (`x` or `y`). This suggests the emitter
   is walking the AST of `combine`'s body for parameter names instead
   of `main`'s signature, then stopping after the first match.
3. The body is `chelis_contiguous(inputs[0])` — there is no `add`
   call, no second operand, no elementwise loop. The actual
   computation is gone.

**Expected behavior.** The entry-point wrapper should have
`n_in == 2`, slot-0 labeled `"x"`, slot-1 labeled `"y"`, and a body
that routes both inputs through `combine` (or inlines `add(x, y)`
explicitly with both operands).

**Where it lives in chelis.** C backend, main-signature synthesis
path that generates the `chelis_tensor **inputs` wrapper around the
user's `main` function. Probably `crates/chelis-backend-c/src/emit.rs`
(or wherever main-entry wrapping is emitted), in whatever loop walks
the entry-point parameter list. A plausible root cause is that the
loop stops at the first parameter, and the "combine" label comes
from reusing a helper-function-name variable that should have been
reset per-parameter.

**Downstream impact.** Bug 3b prevents us from running Bug 3c
through a full link + execution, so we cannot confirm the
end-to-end runtime effect. But the emitted C is structurally wrong
enough that no caller with a multi-tensor-input entry point will
get correct results from `chelis build` in v0.1.4. The original
Bug 3 blocker on `Nautilus.LinAlg` runtime verification is
therefore still in place, just via a different failure mode.

**Suggested fix.** Audit the main-entry wrapper emitter for two
bugs: (a) the per-parameter loop that builds the `inputs[]`
validation block is terminating early, and (b) the diagnostic-label
string is being pulled from the wrong scope (the inlined helper
function rather than the entry-point parameter list). Both are
localized to the main-wrapping codegen and should not require
touching the type checker or IR.

**v0.1.5 status: NOT FIXED.** Re-running the same two-input
`main(x, y: tensor[4, f32]) = combine(x, y)` minimal repro against
`chelis v0.1.5-linux-x86_64` produces identical broken output:
`n_in != 1` check (should be 2), slot 0 labeled `"combine"` (the
helper function name, not `x` or `y`), body of
`chelis_contiguous(inputs[0])` with no `add` call and no second
operand. v0.1.5 fixed the runtime-packaging half of Bug 3 (now
shipped as Bug 3b → FIXED) but the main-entry emission symptom is
independent and unchanged. LinAlg / Distance / SDE / Stats
tensor-path runtime verification remains blocked.

---

## 3 (rollup). Downstream impact and unblocking path

All tensor-on-tensor ops in `Nautilus.LinAlg` (`cg_solve`,
`frobenius_sq`, `frobenius_norm`, `la_vec_add`, `la_vec_sub`,
`la_vec_saxpy`, `inv_2x2`, `inv_3x3`, `solve_*`, `cholesky_2x2`)
remain runtime-unverified. Nautilus type-checks them via
`src/apismoke.ch` at package build time. The ~100 deferred
scipy-parity assertions from `tests/goldens/linalg/*.json` stay
deferred until **both** Bug 3b (ship `libchelis_runtime.a`) and
Bug 3c (fix main-entry parameter emission) land upstream.

A minimal unblocking path would be: ship the runtime archive (3b),
fix main-entry emission (3c), and expose rank-1 f32 elementwise
`add`/`sub`/`mul`/`div` entry points in `libchelis_runtime.a`.
That alone lights up `la_vec_*`, `cg_solve`, `frobenius_*`, and
`Nautilus.Distance` — roughly half of the deferred assertions by
count. Nautilus does not plan to invest further downstream effort
trying to work around this; the fix has to come from the compiler
and runtime.

**Symptom.** The chelis v0.1.3 C backend lowers `add(t1, t2)` and
`mul(t1, t2)` where `t1` and `t2` are tensor-typed operands as raw C
pointer arithmetic (`tensor* + tensor*`, `tensor* * tensor*`) instead of
emitting calls to a runtime elementwise-op dispatcher. The generated C
is syntactically valid but semantically meaningless (pointer math, not
elementwise math), and fails to run correctly even when linked against
working runtime stubs.

**Minimal repro.**

```chelis
def combine[n](a: tensor[n, f32], b: tensor[n, f32]) -> tensor[n, f32] =
  add(a, b)

def main() -> f32 = cast(0.0, f32)
```

```shell
$ chelis build /tmp/combine.ch -o /tmp/out
$ grep -n 'chelis_tensor' /tmp/out/combine.c | head
# Generated C references tensor* in signatures but uses + directly on them
$ gcc -c /tmp/out/combine.c
# Warning: arithmetic on pointer to incomplete type
```

**Expected behavior.** The C backend should either (a) emit calls to a
runtime `chelis_tensor_add(chelis_tensor*, chelis_tensor*)` dispatcher,
or (b) unroll the elementwise op as a loop over the backing buffers with
shape/stride checks. Either way, raw pointer arithmetic on
`chelis_tensor*` is never correct.

**Where it lives in chelis.** C backend lowering path for tensor-typed
`(app {} (var {} add) ...)` / `(app {} (var {} mul) ...)` nodes. Likely
`crates/chelis-backend-c/src/emit.rs` or similar, in the elementwise-op
dispatch that currently falls through to the scalar emission path when
the operands' types are `(t-tensor {} ...)`.

**Downstream impact.** This is the reason Nautilus.LinAlg's runtime
numerical verification is deferred — `cg_solve`, `frobenius_sq`,
`frobenius_norm`, `la_vec_add`, `la_vec_sub`, `la_vec_saxpy`, and the
new P3 `inv_2x2` / `inv_3x3` / `solve_*` / `cholesky_2x2` helpers all use
tensor-on-tensor `add`/`mul` / `sub` at some point in their bodies, and
cannot be runtime-tested via the bare-build harness even with a full
runtime-stub shim. Nautilus type-checks them at package build time via
`src/apismoke.ch` and documents the deferral in `spec/phase3j.md`.

**Suggested fix sketch.** In the C backend's op-dispatch table, route
tensor-on-tensor `add` / `sub` / `mul` / `div` to either a runtime
dispatcher or an inline loop emission. For rank-1 f32 tensors the inline
loop is trivial; for higher ranks the runtime dispatcher is the
standard path used by `matmul` / `einsum` / `reduction ops`.

---

## 4. C backend treats `int __arg = exp(...)` nested-call return as int (MEDIUM, worked around) — **FIXED in v0.1.4**

**Severity:** medium — triggered a silent numerical error in
`Nautilus.Special.erf` during P0, worked around via let-binding
extraction.

**v0.1.4 status: FIXED.** The minimal repro
`def bad(x: f32) -> f32 = exp(neg(mul(x, x)))` now emits
```c
double __arg0_0;
double __arg0_1;
double __arg0_2;
__arg0_2 = x;
double __arg1_3 = x;
__arg0_1 = __arg0_2 * __arg1_3;
__arg0_0 = -(__arg0_1);
__result = exp(__arg0_0);
```
— all intermediate temporaries are `double`, not `int`. The downstream
let-binding workaround pattern in `src/special.ch` is preserved as-is
(it's stable code with no comment marker distinguishing it from
stylistic choice) — no source edits required to benefit from the fix.

**Symptom.** When a unary math builtin (`exp`, `log`, `sin`, `sqrt`,
`neg`) is applied to a nested function-call expression in the Chelis
source, the C backend sometimes emits a generated temporary typed `int`
instead of `double`, truncating the float result to the nearest integer
(usually 0 or 1). Extracting the nested call to a let binding first
avoids the bug.

**Minimal repro.**

```chelis
def bad(x: f32) -> f32 = exp(neg(mul(x, x)))         # BUG: int temp
def good(x: f32) -> f32 = {                          # OK: double temp
  s = mul(x, x)
  ns = neg(s)
  exp(ns)
}
def main() -> f32 = bad(cast(1.5, f32))
```

The generated C for `bad` has
```c
int __arg1_37;
__arg1_37 = exp(__arg0_38);
__arg1_35 = __arg0_36 * __arg1_37;   // double * int → 0 for x > 0
```
while `good` produces `double __arg1_37 = exp(__arg0_38)` correctly.

**Expected behavior.** The type of `exp`'s result in the generated C
should match the Chelis source type (`f32` → `double`) regardless of
whether the argument is a let-bound variable or a nested expression.

**Where it lives in chelis.** C backend argument-temporary emission path
when the argument to a scalar math builtin is itself a nested call.
Likely a missing type propagation case in
`crates/chelis-backend-c/src/emit.rs` for the intermediate-temp
declaration.

**Downstream workaround.** Nautilus code defensively extracts any
nested-call argument to a let binding before passing it to `exp`/`log`/
`sin`/`sqrt`/`neg`. See `src/special.ch:erf` for the canonical pattern.
All P0-P3 source has been audited for this pattern.

**Suggested fix sketch.** In the C backend's temporary-typing logic,
propagate the return type of the builtin from the type environment
rather than inferring from the argument expression's shape. One-line
fix likely, though the call-site audit across the backend takes some
care.

---

## 5. Fused tensor op `n_in` assertion mismatch (MEDIUM) — **NEW in v0.1.6**

**Severity:** medium — causes a runtime abort when the call-site
passes more inputs than the fused tensor op wrapper expects. Worked
around in-harness via `_patch_tensor_nin_asserts()`.

**Symptom.** When the C backend fuses a tensor op whose source-level
call passes the same tensor via `copy()` — e.g.
`gram(a) = matmul(transpose(copy(a)), copy(a))` or
`frobenius_sq(a) = trace(matmul(transpose(copy(a)), copy(a)))` — the
backend detects that both operands originate from the same input and
emits a **single-input** fused tensor op wrapper with `n_in == 1`.
However, the *call-site* that invokes this wrapper still passes
**two** input tensors (one per `copy(a)` expansion). The wrapper's
`if (n_in != 1) { abort(); }` assertion fires and the program crashes.

**Minimal repro.**

```chelis
def gram[m, n](a: tensor[m, n, f32]) -> tensor[n, n, f32] = {
  at = permute(a, 1, 0)
  matmul(at, a)
}
def main(a: tensor[2, 3, f32]) -> tensor[3, 3, f32] = gram(a)
```

The emitted C contains a `gram__tensor_0` wrapper with:
```c
if (n_in != 1) {            // fused: expects 1 (de-duped input)
    fprintf(stderr, "gram__tensor_0: expected %d inputs, got %d\n", 1, n_in);
    abort();
}
```

But the call-site in the `gram()` function body passes 2 inputs:
```c
chelis_tensor *__inputs_2[2];
__inputs_2[0] = at;         // transpose(a)
__inputs_2[1] = a;          // same tensor
gram__tensor_0(__inputs_2, 2, __outputs_3, 1);   // n_in == 2 → abort
```

**Expected behavior.** Either (a) the fused op wrapper should accept
2 inputs (matching the call-site), or (b) the call-site should be
lowered to pass 1 input (matching the fused wrapper's expectation).
The fusion and the call-site emission need to agree.

**Where it lives in chelis.** C backend tensor-op fusion path,
likely `crates/chelis-backend-c/src/emit.rs` or similar. The fusion
pass de-duplicates inputs (recognizing that both operands of the
matmul are views of the same tensor), but the call-site emission
doesn't apply the same de-duplication to the `__inputs_N[]` array.

**Downstream impact.** Any `Nautilus.LinAlg` function that involves
`matmul(transpose(copy(a)), copy(a))` or similar self-matmul patterns
— `gram`, `aat`, `frobenius_sq`, `frobenius_norm` — hits this at
runtime. Nautilus works around it via
`_patch_tensor_nin_asserts()` in `tests/run_numeric_tests.py`, which
regex-strips all `n_in` assertion blocks from the emitted C before
compilation. This is a safe patch because the `n_in` check is a
debug guard, not a correctness gate — the actual tensor data flow is
correct once the assertion is bypassed.

**Downstream workaround.** `tests/run_numeric_tests.py::_patch_tensor_nin_asserts()`
replaces every `if (n_in != K) { ... abort(); }` block with
`(void)n_in;` in the emitted C text before gcc compilation. The
workaround is isolated to the linalg test-binary build path.

**Suggested fix.** In the tensor-op fusion emitter, when
de-duplicating inputs, also rewrite the call-site's `__inputs_N[]`
array construction to match the fused wrapper's input count. Or
alternatively, don't de-duplicate in the wrapper — accept all inputs
as passed and internally alias them. Either direction is a small
change confined to the fusion/call-site emission code.

---

## Status and tracking

**v0.1.4 unlocked:** Bugs 1 and 4 shipped upstream fixes. Nautilus
consumed them by bumping the pin from v0.1.3 to v0.1.4 and
re-verifying `chelis check` + `chelis reef build` +
`tests/run_numeric_tests.py` (526/526) — no source-code changes to
`src/*.ch` were required, because the workarounds (`sin(add(x, π/2))`
cos identity and let-binding extraction before `exp`) are either
still needed for a different reason or are stylistically indistinct
from normal code. Paper trail preserved via this file + the
`spec/phase3j.md` Known Limitations section.

**v0.1.4 still blocking:** Bugs 2 and 3 remain open and continue to
gate the same acceptance criteria:

- **Bug 2** blocks the "negative tests: wrong input shapes"
  acceptance bullet in `spec/phase3j.md` §Test Plan.
- **Bug 3** is the most severe for shipping a usable LinAlg surface.
  The v0.1.4 symptom is actually worse than v0.1.3: `chelis build`
  now unconditionally requires `libchelis_runtime.a` (which does not
  ship in the release tarball) even for scalar-only programs, and
  the emitted C for tensor-on-tensor `add` exhibits a new
  parameter-confusion symptom (see §3 above). `tests/run_numeric_tests.py`
  continues to work because it compiles emitted C manually with its
  own stub set, bypassing `chelis build`'s built-in link step.
  Tensor-path runtime verification for LinAlg / SDE / Stats /
  Distance / Interpolation remains deferred; ~100+ scipy-parity
  assertions are still gated on fixing this.

**v0.1.5 unlocked:** Bug 3b shipped upstream — the release tarball
now contains `bin/chelis`, `lib/libchelis_runtime.a`, and
`include/chelis_runtime.h`, and `chelis build` copies the archive and
header into its output directory. Nautilus consumed this by:

- Dropping the hand-vendored `RUNTIME_STUBS` block from
  `tests/run_numeric_tests.py` (~30 lines deleted) and linking
  against the real archive via `-L $outdir -lchelis_runtime`.
- Dropping the same stubs block from
  `scripts/bench_vs_scipy.py::build_shared_lib` in favor of the
  real runtime link.
- Bumping `reef.toml`, CI, README, AGENTS.md, spec/phase3j.md, and
  the test / bench module docstrings from `v0.1.4` to `v0.1.5`.

526 + 106 = 632 / 632 numerical assertions still pass. The P5 Track 1
LTO workaround in the bench script (`-flto -fvisibility=hidden
-Wl,-Bsymbolic`) remains load-bearing: v0.1.5's C backend still emits
cross-TU helpers as extern, so `-shared -fPIC` still forces PLT
indirection. Measured regression from dropping the flags on v0.1.5:
6.7 → 18.9 ns/el (3×) on `normal_cdf(x)*exp(-x²)` at n=100k. Flags
restored with an updated comment.

**v0.1.7 — ALL BUGS FIXED.** Bug 2 (shape-checker) and Bug 3c
(main-entry emission) both shipped upstream fixes. Re-verified:

- Bug 2: `det_2x2(a: tensor[3, 3, f32])` now emits
  `DimensionMismatch: Lit(2) vs Lit(3)` with score < 1.0.
- Bug 3c: `def main(x, y: tensor[4, f32]) = combine(x, y)` now
  emits an entry point with `n_in == 2`, correctly-labeled slots `a`
  and `b`, rank/dim validation for each input, and a full OpenMP
  parallel-for elementwise-add loop:
  `t2->data[i] = t0->data[idx_a] + t1->data[idx_b]`.

**Impact:** All seven tracked upstream bugs are resolved. The deferred
scipy-parity assertions for LinAlg / Distance / SDE / Stats /
Interpolation tensor-path runtime verification are no longer
upstream-blocked and are wired into `tests/run_numeric_tests.py` in
this repo.

When upstream Chelis lands a release with either of these fixed,
Nautilus can re-enable runtime verification paths and tighten the
spec's known-limitations section accordingly. A minimal win would be
shipping `libchelis_runtime.a` with rank-1 f32 elementwise `add` /
`sub` / `mul` / `div` entry points — that alone unblocks `la_vec_*`,
`cg_solve`, `frobenius_*`, and the `Nautilus.Distance` module, worth
roughly half of the deferred assertions by count.
