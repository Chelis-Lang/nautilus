# Chelis Capability Surface (this shell)

<!-- BEGIN CHELIS MANAGED BLOCK: chelis-surface-header chelis@0.18.11 (sha256:28011bed9ccb5778) -->
This file is a domain-scoped view of the canonical Chelis capability surface,
generated for the pinned toolchain. Each capability row is marked `@pin` (usable
at the current pin) or `@upstream` (lands at the next bump). **Read it before
designing around a suspected language gap** — most downstream over-narrowing
traces to not knowing the real surface. Regenerate with `chelis reef conform
sync` at every pin bump; the upstream source of truth is `docs/CHELIS_SURFACE.md`
in `Chelis-Lang/chelis`.
<!-- END CHELIS MANAGED BLOCK: chelis-surface-header -->

## Version scope

| Item | Value |
|---|---|
| Pinned compiler | Published `chelis 0.18.11` (`reef.toml`: `=0.18.11`) |
| Latest upstream release | `chelis 0.18.11` (published 2026-09-21; checked 2026-09-25) |
| Bundled standard library | `chelis-std 0.4.0`, compiler-bound to `=0.18.11` in the regenerated local `reef.lock` |
| Upstream release identity | Source commit `a7e592f88a148d8323b8f9a8f679c8e163ad3ee7` (tag `v0.18.11`; release workflow run `35665381014`); Linux glibc-2.31 asset SHA-256 `5b97fdf8d20582f022b945bccdc8020d222ad16cbc90047aa369e0d54fd3afd3` |
| Installed compiler payload | Darwin arm64 payload SHA-256 `416e7b5875c7b2d3c8cc5835e0b89a983ff46e866f6f4989d9876a93e2e60951`, installed by `chelisup` from `chelis-v0.18.11-darwin-arm64.tar.gz` (asset SHA-256 `386b2912d21f2b4a2fc6f7f42ab71625c5f1258b2d90c48c2e263b3fc435c289`) |
| Validation status | Full local gate on the official Darwin arm64 payload, run 2026-09-25: 537 positive tests, 8 negative contracts, no executable blocked probes, 216/216 strict SciPy parity, and 4/4 `SKILL.md` plus 13/13 book examples at score 1 with the style gate on; all maintained Surf format checks, `lint --check .`, `reef build`, the release-artifact seal and byte-identical rebuild, conform audit, and bump-check pass |
| Last refreshed | 2026-09-25 |

`@pin` means the row describes behavior available (or a limitation verified)
on the exact pinned release. `@upstream` means a capability exists in a newer
published release and will arrive at the next bump. The pin is the latest
published release, so this snapshot has no `@upstream` rows; unreleased
compiler work is not listed as upstream.

This is the Nautilus-scoped view of the canonical Chelis inventory. The gate
that backs it ran on the published Darwin arm64 asset: the tarball was checked
against its release sidecar and its extracted compiler payload is byte-identical
to the installed toolchain, so every result below comes from official release
bytes. Version-sensitive statements resolve to the executable 0.18.11 re-probes
cited in [`docs/UPSTREAM_BUGS.md`](UPSTREAM_BUGS.md).

## Capability inventory

### Types, dimensions, and ownership

| Capability | Nautilus consequence | Status |
|---|---|---|
| Active scalar precisions | Chelis admits `f32`, `f64`, `bf16`, `f16`, signed `i8`/`i16`/`i32`/`i64`, `bool`, and `string`. Most of Nautilus's public numerical surface is `f32`; iteration/count parameters use `i64`, and predicates use `bool`. `Nautilus.Special` is the exception: all 23 of its exports are generic over the `Float` family, so an f64 caller reaches `erf`, `erfc`, `gamma` and the rest without a second module. Genericity there is a signature property, not an accuracy one (see the table below). Widening the remaining modules is tracked in nautilus#70. `Float` is the narrowest bound Chelis offers, so the generic signatures also admit `f16` and `bf16`, which the f32-only signatures reject. | `@pin` |
| Literals, casts, and promotion | Unsuffixed floats default to `f32` and integers to `i32`. There is no implicit precision promotion; `cast` is explicit. This is why the unsupported `i64` matrix contract in `tests_neg/linalg/` is rejected instead of silently converting to `f32`. | `@pin` |
| Literal and symbolic dimensions | Fixed extents such as `tensor[2,2,f32]` and symbolic parameters such as `tensor[n,f32]` are both available. Distinct declared dimensions are rigid in a generic definition; call sites instantiate them by unification. Nautilus uses `[n]` and `[m,k,n]` extensively. | `@pin` |
| Shape safety | Dimension lists must match and Chelis never broadcasts implicitly. Shape changes must be explicit. Nautilus relies on this for fixed-size LinAlg rejection and generic vector/matrix signatures. | `@pin` |
| Name-preserving rank polymorphism | `tensor[..r,p]` and named-axis reductions/expands exist with a restricted, name-trackable body discipline. Nautilus does not currently use a rank spread: its APIs intentionally state rank-1/rank-2 or fixed rank, so `n` is a dimension variable, not a shape-vector variable. Mixed-rank tensor lists remain invalid. | `@pin` |
| Borrowing and implicit linearity | Read-only `&tensor` parameters auto-borrow owned arguments. The compiler inserts ordinary fan-out copies and end-of-scope drops; explicit `copy(x)` is still required to turn a borrow into a fresh owner and at other real ownership boundaries. Obsolete defensive copies are not a language requirement. | `@pin` |

The f32 default across the remaining modules is a package scope decision, not
evidence that the compiler lacks f64; see the
[architecture in `spec/scope.md`](../spec/scope.md#architecture).
`Nautilus.Special` is generic, and the facts below about what that does and
does not buy were measured rather than assumed. They are recorded in
`tests/special_f64.ch` and `docs/UPSTREAM_BUGS.md`:

| Fact | Evidence |
|---|---|
| Genericity does not change f32 results | A compiled-and-linked C consumer gets bit-identical f32 results from the generic module and from the earlier f32-only one. `reef build` alone does not show this. |
| `f16`/`bf16` are admitted and should not be used | `[prec: Float]` is the narrowest dtype-family bound the language offers, so every export typechecks at `f16` and `bf16`, where f32-only signatures raise `precision mismatch`. The approximations carry f32-tuned constants and do not degrade gracefully: at `bf16`, `gamma(5.5)` returns 58.0 against a true 52.343 (10.8% off) and `bessel_y1(2.2)` is out by 4x; at `f16`, `bessel_j0`/`j1`/`y0`/`y1` return NaN. Nothing rejects or warns. The language cannot narrow the bound today, so this is disclosed rather than fixed, and it would apply equally to any other module made generic under nautilus#70. Tracked as nautilus#75. |
| Widening buys arithmetic, not accuracy | Rerunning `tests/special_f64.ch` with every `f64` rewritten to `f32` fails 23 of its 30 tests, so most exports do compute differently at f64. How much better varies. Six -- `gamma`, `log_gamma`, `beta`, `lbeta`, `ellipk`, `ellipe` -- are limited by f32 rounding rather than by their own coefficients and so reach f64 grade. Of the remaining fifteen scalar exports, `erf` and `erfc` are covered separately below; the other thirteen are limited by their approximations and improve by less, by amounts that share no common bound: `bessel_y1` is nearly six orders better at its test point than near its large-x seam around 7.4, and `airy_ai`/`airy_bi` above x = 5 gain nothing at all, both dtypes sitting on the leading asymptotic term. No per-function, per-domain f64 figure is established for any of the thirteen, here or anywhere else in the repo; the two figures quoted for `bessel_y1` are single points, chosen to show that no single figure covers it. Measure the argument you care about. The `erf` and `erfc` figures below were measured directly and are exact. `erf` is the clearest case -- A&S 7.1.26's own 1.5e-7 bound dominates at every width, 1.385e-7 at f64 against 1.861e-7 at f32 at x = 0.5 (exhaustive maxima: 1.3884e-7 f64, 4.438e-7 f32). `erfc` is the opposite and the one real win: f32 underflows to exactly 0 from about x = 3.92, where f64 still returns 1.546e-8 at x = 4 (2.8e-3 relative). Narrowing that floor means replacing the coefficients; nautilus#74 tracks it. |

### Primitive and builtin families used by Nautilus

| Family touched by `src/` | Names used by Nautilus | Lane and architectural consequence | Status |
|---|---|---|---|
| Elementwise arithmetic | `add`, `sub`, `mul`, `div`, `neg`, `floor_div`, `mod` | Arithmetic is the core of all numerical modules. Float `div` follows IEEE-754 (including NaN/Inf sentinels); `floor_div` is piecewise constant and `mod` is integer-only host behavior. | `@pin` |
| Smooth unary math | `exp`, `log`, `sin`, `sqrt` | Float-only primitives used by Special, Distributions, integration, and solvers. `cos`, `tan`, `atan`, `abs`, `floor`, and `ceil` are also builtins; the sources compute cosines as shifted sines. They have tensor-DAG adjoints, but their presence alone does not make a recursive or host-list wrapper an advertised AD surface. | `@pin` |
| Comparisons and logic | `eq`, `neq`, `lt`, `lte`, `gt`, `gte`, `and`, `or`, `not` | Used for domain guards, convergence tests, and piecewise formulas. Comparisons/logicals are discrete; gradients do not flow through the predicate choice. | `@pin` |
| Tensor contraction and movement | `matmul`, `permute`, `sum` | `matmul` and `sum` lower to differentiable DAG compositions; `permute` has the inverse-permutation adjoint. Nautilus uses these in the straightforward tensor paths. | `@pin` |
| Tensor/host operations | `einsum`, `diagonal`, `trace`, `sort` | These operations evaluate and emit through the C host lane used by Nautilus. They are not a basis for blanket AD or GPU claims. `einsum` supports the two-operand explicit-output forms used by LinAlg; ellipsis is not part of the pinned surface. | `@pin` |
| Tensor/host bridges and queries | `to_tensor`, `to_list`, `numel` | Pure-Chelis algorithms convert between tensors and host lists and read element counts. These are valid for eval and C/package build, but a general bridge-crossing reverse pass is not assumed. | `@pin` |
| Higher-order sequences | `map`, `fold`, `scan`, `zip`, `enumerate`, `range`, `len` | Many solver and factorization implementations are host-lane compositions or recursive drivers. They are supported by the C package path and are outside the general tensor-DAG AD/GPU contract. | `@pin` |
| Explicit precision and ownership | `cast`, `copy` | Casts implement the f32/i64 boundary explicitly. Most tensor parameters are `&tensor` borrows, so callers pass one tensor to several functions without copying. The copies that remain in `src/` mark real ownership boundaries; `tests/linalg.ch` and `tests_neg/linearity/` pin the owned-from-borrowed behavior in both directions. | `@pin` |
| Elementwise selection and shape-sourced lifting | `where`, `insert`, `scalar_to_tensor`, `shape` | Tensor-domain formulas reach a scalar constant or a branch without dropping to `List`. Chelis has no implicit tensor-scalar broadcasting, so a constant is lifted as `insert(scalar_to_tensor(c), 0, shape(t, cast(0, i32)))` -- the spec/04 §4.7.2 Form-3 shape-sourced extent, since a bare runtime scalar has no shape source the backend can emit -- and a scalar `if` becomes an elementwise `where`. At this pin `insert` introduces the new axis and `expand` operates on an existing axis only. The tensor-domain normal family (`normal_cdf_t` and relatives) uses this pattern. | `@pin` |
| Random tensor generation | `uniform_like` | Sampling exports take a `key` as their first argument; a draw is reproducible from the key it is given (`key_from_seed(42i64)` builds a root key, `split_key`/`split_keys`/`fold_in` derive children). Keys are affine, so a function drawing more than once derives child keys. `uniform_like` has zero gradient with respect to generated values and the key, and is not an implicit source of differentiable randomness. | `@pin` |
| Control flow and functions | `if`, recursion, closures, and function-valued solver/model parameters | Forward eval and C package build support the patterns shipped here. AD supports only the transformable tensor-DAG subset and documented static-control slices; recursive/fold-based solver bodies are not automatically differentiable. | `@pin` |

Nautilus targets the evaluator and the default C/package lane. The package
contains host-lane operations, so it makes no whole-package HIP or Metal
claim even though pure Chelis DAG subsets have upstream GPU implementations.

### AD and grad-lane boundaries

Reverse-mode `grad` is a compiler transform over a scalar-returning tensor
DAG. A primitive having an adjoint is necessary but not sufficient: the
entire reached body must lower into a supported transform lane.

| Reached operation family | Pinned adjoint behavior relevant to Nautilus | Nautilus claim | Status |
|---|---|---|---|
| `add` / `sub` | Cotangents route unchanged (and negated for the subtrahend). | Available to a qualifying DAG target. | `@pin` |
| `mul` | `(g*y, g*x)`. | Available to a qualifying DAG target. | `@pin` |
| `div` | `(g/b, -g*y/b)` for float operands. | Available to a qualifying DAG target. | `@pin` |
| `neg`, `exp`, `log`, `sin`, `sqrt` | Standard analytic adjoints from spec/05 §2.2. | Available to a qualifying DAG target. | `@pin` |
| `sum`, `matmul`, `permute` | Expand, composed matmul, and inverse-permutation adjoints respectively. Symbolic extents are supported where structural/runtime extent rules can represent them. | Available to a qualifying DAG target. | `@pin` |
| Comparisons and logicals | Boolean/discrete results have zero cotangent; they do not make branch selection differentiable. | No derivative claim across convergence/domain decisions. | `@pin` |
| `floor_div` and integer/index arithmetic | Piecewise-constant/index math is non-differentiable or a stop-gradient boundary; unsupported differentiation fails closed. | Not an advertised AD path. | `@pin` |
| `uniform_like` | Random source; zero gradient, and the key carries no cotangent. | Sampling exports are not advertised as reparameterized gradients. | `@pin` |
| Host-list and host-tensor operations (`map`, `fold`, `sort`, `einsum`, general `to_list`/`to_tensor`) | No general host-lane adjoint. The compiler has narrow documented boundary rewrites, but Nautilus does not infer package-wide differentiability from them. | Solvers/decompositions need an executable gradient oracle before being advertised as differentiable. | `@pin` |
| Multi-parameter CurveFit Jacobian wrapper | The generic and concrete Jacobian-row witnesses pass as positive tests (`tests/curvefit_lm_jacobian_*.ch`). Composing the helper into the full generic LM path fails with a runtime-extent binder-provenance error (chelis#2370, under tracker chelis#1277). | `lm_scalar_nparam` keeps its finite-difference Jacobian until the full recovery path passes. | `@pin` |
| `grad` call forms | `grad(f, wrt=x)(args...)` differentiates a named definition with respect to one parameter, and evaluates correctly through `normal_cdf` (the Black-Scholes Greeks in the book). A `grad` of a closure that captures the enclosing function's parameters type-checks but fails in the evaluator with `missing required input`. `grad` through `rk4_solve` fails to lower because its recursion depth is a runtime value. | Use the `wrt=` form; no solver is advertised as differentiable. | `@pin` |

No broad LinAlg, solver, distribution, or special-function AD promise is made
by this inventory. The [acceptance rules in `spec/scope.md`](../spec/scope.md#acceptance)
require an executable gradient oracle for each advertised differentiable verb.
The current CurveFit residue is described in
[`docs/UPSTREAM_BUGS.md`](UPSTREAM_BUGS.md#actively-blocking).

### Effects, execution, and packaging

| Capability | Pinned behavior in Nautilus | Status |
|---|---|---|
| Randomness | Chelis has no randomness effect (`spec/02` §P5a). `uniform_like` and every sampling export take an explicit `key` first; seed literals require an explicit `i64` suffix, as in `key_from_seed(42i64)`. | `@pin` |
| `Io`, `Test`, and resources | Library `src/` introduces no I/O or device-resource effect. `Std.Test` assertions in `tests/` introduce the test effect. | `@pin` |
| Package-aware `eval --file` | Real imported Nautilus calls work, strict parity batches its reviewed samples through this route, and every import-only startup shape executes (`scripts/bench_eval_startup.py`; see `docs/eval_startup_findings.md`). An unused Reef import does not leak a symbolic input into eval (chelis#848). | `@pin` |
| C/package build | `chelis reef build` packages the full pure-Chelis surface successfully. Host-lane list/tensor operations are supported by the C host emitter. | `@pin` |
| Canonical artifact verification | `chelis reef verify-artifact` fully consumes the CHB, enforces canonical metadata, and checks its paired archive digest. Nautilus's release gate also proves archive-mutation and CHB-trailing-byte rejection plus unchanged-build byte identity. | `@pin` |
| HIP/Metal | Upstream DAG subsets exist, but Nautilus's host-lane algorithms and lack of a package-level GPU oracle mean no Nautilus GPU support claim is made. | `@pin` |
| Complex numbers | Complex scalar/tensor precision is not in the active type set. Six `Nautilus.Signal` transform/filter names therefore remain explicit NaN-returning stubs, [deferred](../spec/scope.md#deferrals) until Chelis supports complex numbers; `fftfreq` is functional. | `@pin` |

## chelis-std consumption

The bundled dependency is present because Nautilus's native tests use it. The
shipped library modules themselves do not import a runtime `Std.*` module.

| Module/package surface | How Nautilus consumes it | Status |
|---|---|---|
| `chelis-std 0.4.0` | Bundled, compiler-bound Reef dependency. It is not versioned independently of the selected compiler in this lockfile. | `@pin` |
| `Std.Test` | Test-only imports of `assert_close`, `assert_close_tensor`, `assert_true`, and `assert_eq`; not part of Nautilus's exported runtime dependency graph. | `@pin` |
| Other `Std.*` modules | No direct import under `src/`. Numerical behavior comes from Chelis builtins and `Nautilus.*` composition rather than a hidden std fallback. | `@pin` |

## Where to read more

| Authoritative source | Relevance to this view |
|---|---|
| [Canonical capability surface](https://github.com/Chelis-Lang/chelis/blob/b9095ccf2c0b76859aa447c6febe699fd287f1d2/docs/CHELIS_SURFACE.md) | Complete builtin vocabulary, DAG/host lanes, backends, effects, and chelis-std inventory. |
| [spec/04 — type system](https://github.com/Chelis-Lang/chelis/blob/b9095ccf2c0b76859aa447c6febe699fd287f1d2/spec/04-type-system.md) | Precisions, literals, dimensions, no broadcasting, runtime shapes, effects, and linearity. |
| [spec/05 — RISC primitives](https://github.com/Chelis-Lang/chelis/blob/b9095ccf2c0b76859aa447c6febe699fd287f1d2/spec/05-risc-primitives.md) | Primitive semantics, movement, reductions, and per-op adjoints. |
| [spec/06 — transformations](https://github.com/Chelis-Lang/chelis/blob/b9095ccf2c0b76859aa447c6febe699fd287f1d2/spec/06-transformations.md) | `grad` result shape, `wrt`, symbolic adjoints, and tensor/host transform boundaries. |
| [spec/08 — backends](https://github.com/Chelis-Lang/chelis/blob/b9095ccf2c0b76859aa447c6febe699fd287f1d2/spec/08-backends.md) | C, HIP, and Metal backend scope and rejection rules. |
| [Rank polymorphism design](https://github.com/Chelis-Lang/chelis/blob/b9095ccf2c0b76859aa447c6febe699fd287f1d2/spec/design/rank_polymorphism.md) | Name-preserving `..r` support and body discipline. |
| [Implicit linearity design](https://github.com/Chelis-Lang/chelis/blob/b9095ccf2c0b76859aa447c6febe699fd287f1d2/spec/design/implicit_linearity.md) | Inserted copy/drop behavior and preserved hard errors. |
| [Differentiable-language design](https://github.com/Chelis-Lang/chelis/blob/a7e592f88a148d8323b8f9a8f679c8e163ad3ee7/spec/design/differentiable_language.md) | Shipped AD slices versus later control/ADT/effect/implicit-diff scope. |
| [Shell repo contract](https://github.com/Chelis-Lang/chelis/blob/a7e592f88a148d8323b8f9a8f679c8e163ad3ee7/spec/design/shell_repo_contract.md#3-capability-surface-doc--docschelis_surfacemd-must) | Required downstream `@pin`/`@upstream` inventory contract. |
| [`spec/scope.md`](../spec/scope.md) | Nautilus architecture, acceptance rules, and deferrals. |
| [`docs/UPSTREAM_BUGS.md`](UPSTREAM_BUGS.md) | Re-probes at the pin, current residues, workarounds, and triggers. |
