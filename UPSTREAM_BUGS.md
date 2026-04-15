# Upstream Chelis bugs found during Nautilus development

This file collects upstream chelis issues discovered during red-team
rounds across Nautilus Phases P0–P3. Each entry includes a minimal
reproduction, the workaround currently in use downstream, and a
**v0.1.4 status** line recording what changed in the v0.1.4 release.

Summary as of v0.1.4:

| # | Title | v0.1.3 | v0.1.4 |
|---|---|---|---|
| 1 | Unknown-name silent compile | open | **FIXED** |
| 2 | Shape-checker gap for literal-dim tensor params | open | open (re-verified) |
| 3 | Tensor-on-tensor `add`/`mul` lowering | open | open (new symptom; see below) |
| 4 | Nested `exp(neg(mul(x,x)))` int-temp | open | **FIXED** |

Original repros below were run against `chelis v0.1.3-linux-x86_64`.
Re-verifications against `chelis v0.1.4-linux-x86_64` are noted inline.

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

## 3. C backend emits raw pointer arithmetic for tensor-on-tensor `add`/`mul` (HIGH) — **still open, new symptom in v0.1.4**

**Severity:** high — any Nautilus function that combines two rank-2
tensors via `add` or `mul` fails to link as a standalone C binary even
when the math is correct.

**v0.1.4 status: NOT FIXED — different symptom, same blocker.** The
v0.1.4 C backend now emits a `chelis_runtime.h` header and expects to
link against `libchelis_runtime.a`, but:

1. **`libchelis_runtime.a` is not in the v0.1.4 release tarball.**
   Only the `chelis` binary, `README.md`, and `LICENSE` ship. Every
   `chelis build` invocation — even for a scalar-only program — now
   fails at the link step with
   `error: cannot find libchelis_runtime.a; set CHELIS_RUNTIME_DIR
   or install chelis so libchelis_runtime.a is available relative to
   the chelis executable`. Nautilus's existing tests still pass
   because `tests/run_numeric_tests.py` compiles the emitted C
   manually with gcc and its own stub set, bypassing the built-in
   link step.
2. **`chelis_runtime.h` exposes no tensor binary-op dispatcher.**
   Grepping for `chelis_tensor_add` / `chelis_elementwise_*` /
   `chelis_binop_*` in the header (260 lines total) returns nothing.
   The only tensor entry points are `chelis_alloc`,
   `chelis_alloc_view`, `chelis_free`, `chelis_fill_f32`,
   `chelis_scalar_tensor_from_{i64,f64}`, `chelis_tensor_to_f64`,
   `chelis_tensor_rank/shape/numel`, and `chelis_contiguous`. There
   is nowhere for the C backend to route a tensor-on-tensor `add`
   even if it wanted to.
3. **The emitted C for a tensor-on-tensor `add` is now broken in a
   new way.** A minimal program
   ```chelis
   def combine(a: tensor[4, f32], b: tensor[4, f32]) -> tensor[4, f32] = add(a, b)
   def main(x: tensor[4, f32], y: tensor[4, f32]) -> tensor[4, f32] = combine(x, y)
   ```
   compiles to an entry point with `n_in == 1` (not 2) and a body
   that just returns `chelis_contiguous(inputs[0])` — no `add`
   call, no second operand, no elementwise loop. One of the two
   parameters has been silently dropped somewhere in main-signature
   lowering. The function name `combine` also appears as the
   diagnostic label for `inputs[0]`, suggesting parameter-name /
   function-name confusion in the C backend's main-signature
   synthesis.

**Downstream impact (unchanged).** All tensor-on-tensor ops in
`Nautilus.LinAlg` (`cg_solve`, `frobenius_sq`, `frobenius_norm`,
`la_vec_add`, `la_vec_sub`, `la_vec_saxpy`, `inv_2x2`, `inv_3x3`,
`solve_*`, `cholesky_2x2`) remain runtime-unverified. Nautilus
type-checks them via `src/apismoke.ch` at package build time. The
~100 deferred scipy-parity assertions from `tests/goldens/linalg/*.json`
stay deferred.

**Suggested upstream path.** Either (a) ship `libchelis_runtime.a`
with `chelis_tensor_add` / `_sub` / `_mul` / `_div` entry points in
the release tarball, or (b) have the C backend emit an inline
`for (i < numel) out[i] = a[i] + b[i]` loop for rank-1 f32 tensors
(the trivial case that unblocks `la_vec_*` and `cg_solve`). Path (b)
is ~30 lines of backend code and unblocks ~50 of the deferred
assertions on its own.

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

When upstream Chelis lands a release with either of these fixed,
Nautilus can re-enable runtime verification paths and tighten the
spec's known-limitations section accordingly. A minimal win would be
shipping `libchelis_runtime.a` with rank-1 f32 elementwise `add` /
`sub` / `mul` / `div` entry points — that alone unblocks `la_vec_*`,
`cg_solve`, `frobenius_*`, and the `Nautilus.Distance` module, worth
roughly half of the deferred assertions by count.
