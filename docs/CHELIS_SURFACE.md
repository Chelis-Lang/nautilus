# Chelis Capability Surface (this shell)

<!-- BEGIN CHELIS MANAGED BLOCK: chelis-surface-header chelis@0.17.4 (sha256:28011bed9ccb5778) -->
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
| Pinned compiler | Published `chelis 0.17.4` (`reef.toml`: `=0.17.4`) |
| Bundled standard library | `chelis-std 0.4.0`, compiler-bound to `=0.17.4` in `reef.lock` |
| Upstream release identity | Source commit `0b0c92f9916163b05a483fba70473496923730e6`; Linux glibc-2.31 asset SHA-256 `6b7f477d65b2dea4e85b5107a51ae5714a5113138a6791361b74205f9448a121` |
| Last refreshed | 2026-07-31 |

`@pin` means the row describes behavior available (or a limitation verified)
on the exact pinned release. `@upstream` means a capability exists in a newer
published release and will arrive at the next pin bump. There are no
`@upstream` rows in this snapshot because the 0.17.4 release adds no
Nautilus-facing capability beyond the re-probed pin surface. Planned Phase 5
work is not mislabeled as `@upstream`.

This is the Nautilus-scoped view of the canonical Chelis inventory. The
published Linux glibc-2.31 asset was checked against its release sidecar, then
its byte-identical compiler payload (SHA-256
`d08ebfe67fed11f4458251d47e732de3249d93a3d700c87991a39e219887cc7e`)
ran the full local gate. Version-sensitive statements resolve to the executable
0.17.4 probes cited in
[`docs/UPSTREAM_BUGS.md`](UPSTREAM_BUGS.md).

## Capability inventory

### Types, dimensions, and ownership

| Capability | Nautilus consequence | Status |
|---|---|---|
| Active scalar precisions | Chelis admits `f32`, `f64`, `bf16`, `f16`, signed `int8`/`int16`/`int32`/`int64`, `bool`, and `string`. Nautilus's public numerical surface is deliberately `f32`; iteration/count parameters use `int64`, and predicates use `bool`. Public `f64` numerical overloads are not shipped by Phase 3j. | `@pin` |
| Literals, casts, and promotion | Unsuffixed floats default to `f32` and integers to `int32`. There is no implicit precision promotion; `cast` is explicit. This is why the unsupported `int64` matrix contract in `tests_neg/linalg/` is rejected instead of silently converting to `f32`. | `@pin` |
| Literal and symbolic dimensions | Fixed extents such as `tensor[2,2,f32]` and symbolic parameters such as `tensor[n,f32]` are both available. Distinct declared dimensions are rigid in a generic definition; call sites instantiate them by unification. Nautilus uses `[n]` and `[m,k,n]` extensively. | `@pin` |
| Shape safety | Dimension lists must match and Chelis never broadcasts implicitly. Shape changes must be explicit. Nautilus relies on this for fixed-size LinAlg rejection and generic vector/matrix signatures. | `@pin` |
| Name-preserving rank polymorphism | `tensor[..r,p]` and named-axis reductions/expands exist with a restricted, name-trackable body discipline. Nautilus does not currently use a rank spread: its APIs intentionally state rank-1/rank-2 or fixed rank, so `n` is a dimension variable, not a shape-vector variable. Mixed-rank tensor lists remain invalid. | `@pin` |
| Borrowing and implicit linearity | Read-only `&tensor` parameters auto-borrow owned arguments. The compiler inserts ordinary fan-out copies and end-of-scope drops; explicit `copy(x)` is still required to turn a borrow into a fresh owner and at other real ownership boundaries. Obsolete defensive copies are not a language requirement. | `@pin` |

The f32-only package contract is a Phase 3j scope decision, not evidence that
the compiler lacks f64. See the
[accepted implementation strategy](../spec/phase3j.md#accepted-implementation-strategy).

### Primitive and builtin families used by Nautilus

| Family touched by `src/` | Names used by Nautilus | Lane and architectural consequence | Status |
|---|---|---|---|
| Elementwise arithmetic | `add`, `sub`, `mul`, `div`, `neg`, `floor_div`, `mod` | Arithmetic is the core of all numerical modules. Float `div` follows IEEE-754 (including NaN/Inf sentinels); `floor_div` is piecewise constant and `mod` is integer-only host behavior. | `@pin` |
| Smooth unary math | `exp`, `log`, `sin`, `sqrt` | Float-only primitives used by Special, Distributions, integration, and solvers. They have tensor-DAG adjoints, but their presence alone does not make a recursive or host-list wrapper an advertised AD surface. | `@pin` |
| Comparisons and logic | `eq`, `neq`, `lt`, `lte`, `gt`, `gte`, `and`, `or`, `not` | Used for domain guards, convergence tests, and piecewise formulas. Comparisons/logicals are discrete; gradients do not flow through the predicate choice. | `@pin` |
| Tensor contraction and movement | `matmul`, `permute`, `sum` | `matmul` and `sum` lower to differentiable DAG compositions; `permute` has the inverse-permutation adjoint. Nautilus uses these in the straightforward tensor paths. | `@pin` |
| Phase 3h tensor/host operations | `einsum`, `diagonal`, `trace`, `sort` | These operations evaluate and emit through the C host lane used by Nautilus. They are not a basis for blanket AD or GPU claims. `einsum` supports the two-operand explicit-output forms used by LinAlg; ellipsis is not part of the pinned surface. | `@pin` |
| Tensor/host bridges and queries | `to_tensor`, `to_list`, `numel` | Pure-Chelis algorithms convert between tensors and host lists and read element counts. These are valid for eval and C/package build, but a general bridge-crossing reverse pass is not assumed. | `@pin` |
| Higher-order sequences | `map`, `fold`, `scan`, `zip`, `enumerate`, `range`, `len` | Many solver and factorization implementations are host-lane compositions or recursive drivers. They are supported by the C package path and are outside the general tensor-DAG AD/GPU contract. | `@pin` |
| Explicit precision and ownership | `cast`, `copy` | Casts implement the f32/int64 boundary explicitly. Remaining copies express real ownership needs after the 0.16.1 linearity cleanup; they are not the archived redundant-linearity workaround. | `@pin` |
| Random tensor generation | `uniform_like` | Sampling exports declare `! { Random }`; callers handle the effect with `with seed(42i64)` (seed literals require an explicit `i64` suffix). `uniform_like` has zero gradient with respect to generated values/seed and is not an implicit source of differentiable randomness. | `@pin` |
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
| `uniform_like` | Random source; zero gradient and handled `Random` effect. | Sampling exports are not advertised as reparameterized gradients. | `@pin` |
| Host-list and host-tensor operations (`map`, `fold`, `sort`, `einsum`, general `to_list`/`to_tensor`) | No general host-lane adjoint. The compiler has narrow documented boundary rewrites, but Nautilus does not infer package-wide differentiability from them. | Solvers/decompositions need an executable gradient oracle before being advertised as differentiable. | `@pin` |
| Multi-parameter CurveFit Jacobian wrapper | Plain tensor-wrt and capture-free multi-argument controls pass. The former generic-dimension checker collapse remains resolved at 0.17.4, but both the generic and concrete arbitrary-model wrappers still reach malformed backward-DAG lowering (chelis#676). | `lm_scalar_nparam` retains its finite-difference Jacobian. Both exact wrapper shapes are executable in `tests_blocked/curvefit/`. | `@pin` |

No broad LinAlg, solver, distribution, or special-function AD promise is made
by this inventory. The acceptance rule in
[`spec/phase3j.md`](../spec/phase3j.md) requires an executable gradient oracle
for each advertised differentiable verb. The current CurveFit residue is
specified in the two ready-to-file drafts linked from
[`docs/UPSTREAM_BUGS.md`](UPSTREAM_BUGS.md#actively-blocking).

### Effects, execution, and packaging

| Capability | Pinned behavior in Nautilus | Status |
|---|---|---|
| `Random` | `uniform_like` introduces `Random`; all sampling exports declare it. `with seed(42i64) { ... }` is the handler (seed literals require an explicit `i64` suffix). | `@pin` |
| `Io`, `Test`, and resources | Library `src/` introduces no I/O or device-resource effect. `Std.Test` assertions in `tests/` introduce the test effect. | `@pin` |
| Package-aware `eval --file` | Real imported Nautilus calls pass and strict parity batches 216 reviewed samples through this route. The separate import-only/symbolic-input startup shape can still report “missing required input `a` for symbolic dimension `k`”; it is a tracked benchmark residue, not a reason to avoid real package-aware eval. | `@pin` |
| C/package build | `chelis reef build` packages the full pure-Chelis surface successfully. Host-lane list/tensor operations are supported by the C host emitter. | `@pin` |
| Canonical artifact verification | `chelis reef verify-artifact` fully consumes the CHB, enforces canonical metadata, and checks its paired archive digest. Nautilus's release gate also proves archive-mutation and CHB-trailing-byte rejection plus unchanged-build byte identity. | `@pin` |
| HIP/Metal | Upstream DAG subsets exist, but Nautilus's host-lane algorithms and lack of a package-level GPU oracle mean no Nautilus GPU support claim is made. | `@pin` |
| Complex numbers | Complex scalar/tensor precision is not in the active type set. Six `Nautilus.Signal` transform/filter names therefore remain explicit NaN-returning stubs under the dated Phase 5f deferral; `fftfreq` is functional. | `@pin` |

## chelis-std consumption

The bundled dependency is present because Nautilus's native tests use it. The
shipped library modules themselves do not import a runtime `Std.*` module.

| Module/package surface | How Nautilus consumes it | Status |
|---|---|---|
| `chelis-std 0.4.0` | Bundled, compiler-bound Reef dependency. It is not versioned independently of the selected compiler in this lockfile. | `@pin` |
| `Std.Test` | Test-only imports of `assert_close`, `assert_close_tensor`, `assert_true`, and `assert_eq`; not part of Nautilus's exported runtime dependency graph. | `@pin` |
| Other `Std.*` modules | No direct import under `src/`. Numerical behavior comes from Chelis builtins and `Nautilus.*` composition rather than a hidden std fallback. | `@pin` |

## Design-around review at 0.16.1

| Former or suspected gap | Disposition after the pin review | Status |
|---|---|---|
| Explicit copies for every repeated read | Removed where 0.16.1 implicit-linearity analysis proves them redundant (131 removals in `src/linalg.ch`). Copies that remain are semantic ownership boundaries; `tests/linalg.ch` and `tests_neg/linearity/` pin the required owned-from-borrowed behavior in both directions. | `@pin` |
| Package imports under `eval --file` | Real imported calls are now used directly by parity; the former broad avoidance is retired. Only the separately cited import-only symbolic-input residue remains tracked. | `@pin` |
| Exact multi-parameter CurveFit AD | Workaround retained: the one remaining backward-DAG compiler layer is reproduced through generic and concrete wrapper shapes under `tests_blocked/curvefit/` and cited at `src/curvefit.ch`. | `@pin` |
| Signal transforms without complex numbers | Stubs retained under the dated [`spec/phase3j.md` deferral](../spec/phase3j.md#explicit-deferrals); this is planned scope, not an invented real-only FFT design. | `@pin` |
| f64 package overloads | Not added: canonical Phase 3j deliberately specifies an f32 numerical package even though f64 is a compiler capability. | `@pin` |

## Where to read more

| Authoritative source | Relevance to this view |
|---|---|
| [Canonical capability surface](https://github.com/Chelis-Lang/chelis/blob/0b0c92f9916163b05a483fba70473496923730e6/docs/CHELIS_SURFACE.md) | Complete builtin vocabulary, DAG/host lanes, backends, effects, and chelis-std inventory. |
| [spec/04 — type system](https://github.com/Chelis-Lang/chelis/blob/0b0c92f9916163b05a483fba70473496923730e6/spec/04-type-system.md) | Precisions, literals, dimensions, no broadcasting, runtime shapes, effects, and linearity. |
| [spec/05 — RISC primitives](https://github.com/Chelis-Lang/chelis/blob/0b0c92f9916163b05a483fba70473496923730e6/spec/05-risc-primitives.md) | Primitive semantics, movement, reductions, and per-op adjoints. |
| [spec/06 — transformations](https://github.com/Chelis-Lang/chelis/blob/0b0c92f9916163b05a483fba70473496923730e6/spec/06-transformations.md) | `grad` result shape, `wrt`, symbolic adjoints, and tensor/host transform boundaries. |
| [spec/08 — backends](https://github.com/Chelis-Lang/chelis/blob/0b0c92f9916163b05a483fba70473496923730e6/spec/08-backends.md) | C, HIP, and Metal backend scope and rejection rules. |
| [Rank polymorphism design](https://github.com/Chelis-Lang/chelis/blob/0b0c92f9916163b05a483fba70473496923730e6/spec/design/rank_polymorphism.md) | Name-preserving `..r` support and body discipline. |
| [Implicit linearity design](https://github.com/Chelis-Lang/chelis/blob/0b0c92f9916163b05a483fba70473496923730e6/spec/design/implicit_linearity.md) | Inserted copy/drop behavior and preserved hard errors. |
| [Differentiable-language design](https://github.com/Chelis-Lang/chelis/blob/0b0c92f9916163b05a483fba70473496923730e6/spec/design/differentiable_language.md) | Shipped AD slices versus later control/ADT/effect/implicit-diff scope. |
| [Shell repo contract](https://github.com/Chelis-Lang/chelis/blob/0b0c92f9916163b05a483fba70473496923730e6/spec/design/shell_repo_contract.md#3-capability-surface-doc--docschelis_surfacemd-must) | Required downstream `@pin`/`@upstream` inventory contract. |
| [`spec/phase3j.md`](../spec/phase3j.md) | Nautilus architecture, acceptance rules, and dated deferrals. |
| [`docs/UPSTREAM_BUGS.md`](UPSTREAM_BUGS.md) | Executable 0.17.4 re-probes, current residues, workarounds, and triggers. |
