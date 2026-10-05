# Chelis Capability Surface (this shell)

<!-- BEGIN CHELIS MANAGED BLOCK: chelis-surface chelis@0.18.13 (sha256:13fd8ecdc638efcb) -->
# Chelis capability surface

This guide maps language operations, compiler support, and bundled `chelis-std`.
The numbered specs decide language behavior; code and executable tests establish
which parts the compiler implements. `chelis reef conform sync` copies this
guide into every shell's `docs/CHELIS_SURFACE.md`
([`spec/design/shell_repo_contract.md`](https://github.com/Chelis-Lang/chelis/blob/v0.18.13/spec/design/shell_repo_contract.md) §3),
so a shell reads the guide of the release it pins.

This page describes the source tree it ships with: `main` in the compiler
repository, and the pinned release in a shell's copy. Relative paths and links
name files in [`Chelis-Lang/chelis`](https://github.com/Chelis-Lang/chelis).
Language rules, registered builtins, and target execution support have
separate owners, identified below.

If this guide disagrees with an owning source, correct the guide:

| Surface | Source of truth |
|---|---|
| Language operations and adjoints | [`spec/05-risc-primitives.md`](https://github.com/Chelis-Lang/chelis/blob/v0.18.13/spec/05-risc-primitives.md), [`spec/06-transformations.md`](https://github.com/Chelis-Lang/chelis/blob/v0.18.13/spec/06-transformations.md) |
| Syntax, types, dtypes and effects | [`spec/02-surf-syntax.md`](https://github.com/Chelis-Lang/chelis/blob/v0.18.13/spec/02-surf-syntax.md), [`spec/04-type-system.md`](https://github.com/Chelis-Lang/chelis/blob/v0.18.13/spec/04-type-system.md) |
| Builtin registration | `BUILTIN_NAMES` and `builtin_env`, `crates/chelis-types/src/builtins.rs` |
| IR and target implementation | `RiscOp`, `crates/chelis-ir/src/dag.rs`; `crates/chelis-compiler-api/src/compiler.rs`; `crates/chelis-backend-{c,hip,metal}` |
| Target contract | [`spec/08-backends.md`](https://github.com/Chelis-Lang/chelis/blob/v0.18.13/spec/08-backends.md) and the dtype matrix in `spec/04` §1.1.3 |
| Command surface | `crates/chelis-cli/src/main.rs` and its CLI integration tests |
| Scope taxonomy (core vs std vs shell) | [`spec/design/chelis_canonical_reference.md`](https://github.com/Chelis-Lang/chelis/blob/v0.18.13/spec/design/chelis_canonical_reference.md) §8.5 |

---

## 0. Checked programs, tensor DAGs, and host execution

Checking establishes types, effects, and ownership before target selection.
Lowering then keeps tensor work in a `RiscOp` DAG and represents functions,
collections, I/O, and other host work in a host execution program. One source
program can contain both. The host interpreter and generated host code call
tensor helpers admitted by the selected target (§6).

- **DAG:** `crates/chelis-ir/src/dag.rs`, `lower.rs`, and `tier2.rs` contain
  tensor nodes and derived-op lowerings. Eval and the C, HIP, and Metal emitters
  check capability separately by dtype, shape, and target.
- **Host execution:** `crates/chelis-ir/src/host.rs` represents calls, control,
  scalar and collection values, and tensor helpers. Eval uses
  `chelis-compiler-api/src/runtime/host_ops.rs`; compiled host programs use
  target host emitters and the carried runtime. Some builtin applications are
  explicitly eval/test-only (§3.5, §3.8, §3.9).

Transform rules include host values, lists, branches, and recursion;
implementation coverage is in §5. The prover's supported subset is in §12.
The checker's alias-resolved ADT information and authored signatures feed
host representation decisions.

**Lane legend used in the tables below:**

| Mark | Meaning |
|---|---|
| `DAG` | Has a tensor DAG lowering; target admission is described in §6. |
| `Host` | Uses a host execution form and its target's host-runtime support. |
| `DAG+Host` | Has both lowering paths; the selected entry and context decide which one is used. |

---

## 1. Tier-1 RISC primitives (the DAG)

These registered builtins have direct tensor DAG nodes. Their contracts come from
`spec/05` §2 and the dtype rules of `spec/04`. `D` denotes dimensions and `p`
a precision. Read-only tensor inputs are borrow-typed (`&tensor`) and are
auto-borrowed at ordinary call sites. An adjoint column describes float data
paths unless the named atom says otherwise. Scalar forms and target limits
are specified separately.

### 1.1 Elementwise binary — `spec/05` §2.1

| Name | Signature | AD adjoint (given upstream `g`) |
|---|---|---|
| `add` | `(&tensor[D,p], &tensor[D,p]) -> tensor[D,p]` | `(g, g)` |
| `sub` | `(&tensor[D,p], &tensor[D,p]) -> tensor[D,p]` | `(g, -g)` on floats; signed-integer forms are forward-only |
| `mul` | `(&tensor[D,p], &tensor[D,p]) -> tensor[D,p]` | `(g*y, g*x)` |
| `div` | `(&tensor[D,p_float], &tensor[D,p_float]) -> tensor[D,p_float]` | `(g/b, -g*y/b)`; IEEE-754, **float operands only** |
| `floor_div` | `(&tensor[D,p], &tensor[D,p]) -> tensor[D,p]` | **non-differentiable** — `grad` rejects; round quotient toward −∞ (Python `//`); ints and floats |
| `trunc_div` | `(&tensor[D,p_int], &tensor[D,p_int]) -> tensor[D,p_int]` | **non-differentiable** — `grad` rejects; round toward zero (C `/`); **integer operands only** |
| `max_elem` | `(&tensor[D,p], &tensor[D,p]) -> tensor[D,p]` | complete `g` to the exact operand selected by [05-OP-40], including its stored-bit tie rule; integer forms are forward-only |
| `min_elem` | `(&tensor[D,p], &tensor[D,p]) -> tensor[D,p]` | complete `g` to the exact operand selected by [05-OP-40], including its stored-bit tie rule; integer forms are forward-only |
| `cmplt` | `(&tensor[D,p], &tensor[D,p]) -> tensor[D,bool]` | zero gradient (by design) |

`div` and `recip` follow IEEE-754 float division, including signed zero and
infinity. `/` desugars to
`div`, so integer `/` is a type error. Use `floor_div` for a quotient rounded
toward −∞, `trunc_div` for an integer quotient rounded toward zero, or
explicitly cast before float division. Integer overflow is checked unless a
separately named modular operation applies (`spec/04` [04-NUM-3/7]).

### 1.2 Elementwise unary — `spec/05` §2.2

| Name | AD adjoint |
|---|---|
| `neg` | `-g` for floats; integer forward execution is checked |
| `recip` | `-g*y*y` (= `-g/x²`) |
| `exp` | `g*exp(x)` |
| `log` | `g/x` |
| `sin` | `g*cos(x)` |
| `cos` | `-g*sin(x)` |
| `tan` | `g/cos²(x)` |
| `atan` | `g/(1+x²)` |
| `erf` | `g*(2/sqrt(pi))*exp(-x²)` |
| `erfc` | `-g*(2/sqrt(pi))*exp(-x²)` |
| `sqrt` | `g/(2*sqrt(x))` |
| `abs` | `g*sign(x)` (0 at x=0) for floats; integer form is forward-only |
| `floor` | float path: `grad` rejects (`PiecewiseConstant`); integer form is identity |
| `ceil` | float path: `grad` rejects (`PiecewiseConstant`); integer form is identity |
| `round` | ties to even; float path: `grad` rejects (`PiecewiseConstant`); integer form is identity |

`recip`, transcendental functions, and `sqrt` admit floats. `neg`, `abs`,
`floor`, `ceil`, and `round` also admit signed integers under the rules above.

### 1.3 Reduction — `spec/05` §2.3

| Name | Signature | AD adjoint |
|---|---|---|
| `sum` | `(&tensor[D,p], axes: Axis+, accumulator: prec = default(p)) -> tensor[D\K,sum_result(p,accumulator)]` | expand `g` across each removed axis at operand precision |
| `count` | `(&tensor[D,bool], axes: Axis+) -> tensor[D\K,i64]` | **non-differentiable** (`IntegerReductionOutput`) |
| `max_reduce` | `(&tensor[D,p], axes: Axis+) -> tensor[D\K,p]` | split `g` among equal extrema; first NaN receives all of `g` |
| `min_reduce` | `(&tensor[D,p], axes: Axis+) -> tensor[D\K,p]` | split `g` among equal extrema; first NaN receives all of `g` |
| `prod_reduce` | `(&tensor[D,p], axes: Axis+) -> tensor[D\K,p]` | reverse the exact balanced multiplication tree, including zeros |
| `argmax_reduce` | `(&tensor[..,p], axis: i32) -> tensor[..,i64]` | **non-differentiable** (index output) |
| `argmin_reduce` | `(&tensor[..,p], axis: i32) -> tensor[..,i64]` | **non-differentiable** (index output) |

`Axis+` is one or more unique statically resolved positional `i32` axes or
named axes. Positional negative axes count from the end. Concrete-rank
multi-axis reductions accept positional axes; rank-polymorphic forms use
named axes. Runtime axis expressions and mixed or duplicate selections
are type errors. The checker applies these rules before a backend is chosen.

`sum` and `prod_reduce` use the specified balanced trees, with integer
overflow checked at each operation. `count` has one dedicated node with
normalized original positions in descending order. For `sum`, the default
`bf16`/`f16` accumulator is `f32`, and the result returns to `bf16`/`f16`.
Other defaults are
`f32→f32`, `f64→f64`, `i8/i16→i32`, `i32→i32`, and `i64→i64`.
`sum`, `cumsum`, `trace`, and `einsum` all return
`sum_result(p, default(p))`, so over `i8` or `i16` each returns `i32`: a
total of N values needs more bits than its elements, so the stored tensor
keeps its dtype and only the aggregate widens. Declare the result as `i32`,
pass `accumulator=i64` to `sum` or `einsum`, or narrow it with an explicit
`cast`.
An explicit wider accumulator, written as the final argument
`accumulator=<dtype>` (`sum(x, 0i32, accumulator=f64)`), follows the exact
result matrix in `spec/04` §5.7.1. `mean` is a float-only derived reduction (§2) with no
accumulator parameter.

### 1.4 Windowed reduction — `spec/05` §2.3.1 (Valid padding only)

| Name | Signature |
|---|---|
| `reduce_window_max` / `_min` / `_sum` / `_mean` | `(&tensor[..,p], window_shape: List[i64], strides: List[i64]) -> tensor[..,p]` |

This family lowers to `RiscOp::ReduceWindow` with a reducer kind and uses
`ReduceWindowGrad` for its adjoint. With valid padding, output extent is
`floor((d - window)/stride) + 1`; explicit `pad` supplies other boundaries.
The C target has a guarded windowed path. HIP and Metal reject this node;
see §6 for dtype and dynamic-extent restrictions.

### 1.5 Movement — `spec/05` §2.4

| Name | Signature | AD adjoint |
|---|---|---|
| `reshape` | `(&tensor[D_old,p], shape) -> tensor[D_new,p]` | `reshape(g, old_shape)` |
| `permute` | `(&tensor[..,p], axes: i32...) -> tensor[..,p]` | `permute(g, inverse_axes)` |
| `expand` | `(&tensor[D,p], axis: i32, size: i64) -> tensor[D',p]` | `insert(sum(g, axis), axis, 1i64)` |
| `insert` | `(&tensor[D,p], axis: i32, size: i64) -> tensor[D_plus,p]` | `sum(g, axis)` |
| `pad` | `(&tensor[D,p], padding, fill) -> tensor[D',p]` | `shrink(g, inverse_padding)` |
| `shrink` | `(&tensor[D,p], bounds) -> tensor[D',p]` | `pad(g, inverse_bounds)` |
| `stride` | `(&tensor[D,p], strides) -> tensor[D',p]` | [05-MOV-1]'s zero-filled inverse sampling map at the original shape |

`expand` sets an existing size-1 axis to `size` and leaves the rank alone; `insert`
adds an axis and raises the rank by one. Neither copies data (stride-0 on the
broadcast axis). Axes for `expand` and `insert` are statically resolved;
the spec also admits named-axis forms. Their size/bound values have
separate runtime-extent rules (`spec/04` §4.7 and `spec/05` §2.4).
Target support for node-valued bounds is narrower than the language rule.

### 1.6 Memory & effectful — `spec/05` §2.5–2.6

| Name | Signature | AD / effect |
|---|---|---|
| `const` | `(value, shape...) -> tensor[shape,p]` | zero gradient |
| `load` | `(source, shape...) -> tensor[shape,p]` | zero gradient |
| `dropout` | `(key, &tensor[D,p_float], rate: p_float) -> tensor[D,p_float]` | consumes its key; fixed-control data adjoint replays the forward mask. Eval and selected C builds admit runtime key/rate; device draws are rejected (§6). |
| `uniform_like` | `(key, &tensor[D,p_float], lo: p_float, hi: p_float) -> tensor[D,p_float]` | active float `p`; consumes its key and introduces no effect; zero gradient to the template |
| `key_from_seed` | `(i64) -> key` | [05-OP-69]; non-differentiable |
| `split_key` | `(key) -> (key, key)` | [05-OP-70]; consumes its key ([04-LIN-9]) |
| `split_keys` | `(key, i64) -> tensor[n, key]` | [05-OP-71]; consumes its key; `n` is the runtime count |
| `fold_in` | `(key, i64) -> key` | [05-OP-72]; consumes its key |

`const` and `load` are lowering-created memory nodes. Other IR nodes, including `Store`, `Copy`, `Realize`, `Cast`, `FusedElem`,
`OneHot`, and `BlasMatmul`, are internal representations or come from
separate language forms. Random keys are affine values. A draw consumes its
key without introducing `IO`; the exact mask, rate validation, and pathwise
adjoint are governed by [05-OP-37]. C entry support is described in §6.

### 1.7 Sparse tensor-lane nodes — `spec/05` §3.5

The sparse builtins below have distinct DAG identities. Eval and C implement
them; HIP admits a narrower payload/index/source subset and Metal rejects
the sparse nodes (§6).

| Surf builtin | Lowers to | Signature | AD adjoint |
|---|---|---|---|
| `gather` | `RiscOp::Gather{axis}` | `(&values, &indices, axis: i32) -> tensor` | `ScatterAdd` |
| `scatter_replace` | `RiscOp::Scatter{axis}` | `(&base, &indices, &updates, axis: i32) -> tensor` | **no_grad** (`NonDeterministicAtDuplicateIndices`) |
| `scatter_elements` | `RiscOp::ScatterElements{axis}` | `(&data, &indices, &updates, axis: i32) -> tensor` | **no_grad** (`NonDeterministicAtDuplicateIndices`) |
| _(scatter-add internal)_ | `RiscOp::ScatterAdd{axis}` | — | `Gather` |

`scatter_replace` uses a deterministic last-write-wins row-major rule for
duplicate indices. `scatter_elements` is the elementwise variant
(`indices.shape == updates.shape`, `output.shape == data.shape`,
`spec/05` §3.5.1), with the same duplicate policy and AD rejection.
The five-argument, string-mode `scatter` is a separate host-runtime form (§3).

---

## 2. Derived builtins and tensor compositions

`spec/05` §3–4 gives these names typed identities and lowering rules. Most
are implemented by compositions of primitive nodes in
`crates/chelis-ir/src/tier2.rs`. `relu` has a dedicated DAG node and
its own zero rule.

| Name | Lowering | AD |
|---|---|---|
| `eq`,`neq`,`gt`,`gte`,`lte`,`lt` | exact comparison identities; direct `Compare` nodes exist alongside the specified compositions | bool result has zero cotangent |
| `and`,`or`,`not` | bool-only operations ([05-OP-26..28]); direct `Logical` nodes exist | structural `grad` rejection |
| `relu` | dedicated `RiscOp::Relu`; forward equals stored-bit `max_elem(x, 0)` | `g` only where `0 < x`; exact +0 at both zeros and NaN |
| `sigmoid` | `recip(add(1, exp(neg(x))))` | differentiable |
| `tanh`,`silu`,`gelu`,`gelu_tanh`,`standard_normal_cdf` | `tier2.rs` decompositions; `standard_normal_cdf` is the standard normal CDF `Phi` over `erfc`, `gelu` is exact (`x*Phi(x)`), `gelu_tanh` the tanh approximation | differentiable |
| `matmul` | `expand`+`mul`+`sum`, pattern-matched to BLAS (`spec/05` §4.1); optional `accumulator` | differentiable |
| `mean` | float-only `sum` followed by division by the selected axis extent, in canonical multi-axis order | differentiable |
| `softmax` | max-shift + `exp` + `sum` + `div` (`spec/05` §4.2) | differentiable |
| `layer_norm` | explicit epsilon plus mean/var normalize + affine (`spec/05` §4.4) | differentiable |
| `conv` | N-dimensional padded window gather → one matrix contraction → reshape/permute; explicit per-axis i64 strides and `(low,high)` padding pairs (`spec/05` §4.5) | differentiable |

Some derived arithmetic also has a compiled-host path when a surrounding
function is represented in the host program. Target admission is checked
separately.

Composite recipes such as `linear`,
`cross_entropy`, `embedding`, `multi_head_attention`, and `argmax`
(`spec/05` §3.5, §4.3–4.7) are library compositions. Use an imported definition or
compose the underlying operations explicitly.

The [`explicit_normalization.ch`](https://github.com/Chelis-Lang/chelis/blob/v0.18.13/examples/explicit_normalization.ch)
example defines `normalize` as an ordinary function.

---

## 3. Host-runtime and other non-primitive builtins

Most operations here have a host execution form, evaluated by
`host_ops.rs` or emitted through target host code and `chelis_*` runtime
calls. Some also acquire a direct tensor DAG form in a tensor context:
`where`, comparison/logical operations, integer bitwise operations, and
selected tensor helpers are examples. Section 4 lists builtin names;
lowering and target support depend on the operation and selected entry
(§6). Host AD is
implemented for selected paths, with wider semantics specified by
`spec/06` (§5).

### 3.1 Data-dependent and tensor construction operations — `spec/05` §1, §3

| Name | Signature | Notes |
|---|---|---|
| `cumsum` | `(&tensor, axis: i32) -> tensor` | cumulative sum along axis; result uses `sum_result(p, default(p))`, so narrow-integer output can widen |
| `sort` | `(&tensor, axis: i32) -> (values, indices)` | stable ordering; returns values and an `i64` index tensor |
| `einsum` | `(equation: string, &lhs, &rhs) -> tensor` | the implemented equation subset is two-operand and excludes ellipsis; static contradictions reject at checking |
| `diagonal` | `(&tensor, axis1: i32, axis2: i32) -> tensor` | diagonal extraction |
| `trace` | `(&tensor, axis1: i32, axis2: i32) -> tensor` | matrix trace |
| `where` | `(&cond, &a, &b) -> tensor` | bool selection has a direct `RiscOp::Where` form; compiled Metal rejects that direct node |
| `clamp` | `(&tensor, lo, hi) -> tensor` | elementwise clip |
| `concat` | `(tensors: List[tensor], axis: i32) -> tensor` | join tensors along axis; ordinary two-list concatenation has no axis slot |
| `split` | `(&tensor, axis: i32, sizes: List[int]) -> list` | partition along axis |
| `scatter` | `(base, indices, updates, axis: i32, mode: string) -> tensor` | registered host form; its string mode conflicts with the public [05-OP-33] contract |
| `pad_sequences`, `pad_sequences_to` | typed List input, pad value, and optional width | runtime-derived extents; [05-OP-9..10] govern all-dtype padding and adjoints |

### 3.2 Host-runtime tensor builder — `spec/05` §3.6

| Name | Signature | Notes |
|---|---|---|
| `tensor_scan` | `(initial: T, fn: (T,i64)->T ! E, n: i64) -> tensor[n,..state_shape(T),element(T)] ! E` | [05-HOST-1] and [05-OP-38] define scalar or fixed-shape tensor state, ordered callback effects, and typed output. Eval and compiled C run scalar and tensor states; transform coverage is incomplete. |

`tensor_scan` stacks successive states into a tensor; list `scan` (§3.3)
returns a `List`. Its spec includes float-state AD and `vmap` rules.
Compiled C runs it as the list `scan` over `range(0, n)` stacked at the
state's own dtype; a tensor state stacks against the initial state, so
`n = 0` keeps every state extent.

### 3.3 Higher-order list / sequence combinators

`map`, `filter`, `fold`, `scan`, `partition`, `flat_map`, `flatten`, `zip`,
`enumerate`, `chunk`, `take`, `skip`, `range`, `append`, `index`, `len`,
and the List overload of `concat`. Higher-order forms accept callable values
and execute eagerly in list order. `len` and `index` auto-borrow a List or
Dict query argument; they do not consume that container (`spec/05` §1.3.1).
At each function entry, tensors in a `List[tensor[n, p]]` parameter
contribute to the named extent `n` check; `List[tensor[2, p]]` checks the
literal extent of each element. This includes nested Lists, internal calls,
and retained callable invocations. An empty List contributes no named witness.
Eval and C enforce these checks before the function body; see
[`list_shared_extent.ch`](https://github.com/Chelis-Lang/chelis/blob/v0.18.13/examples/list_shared_extent.ch).
The spec defines positional List cotangents for several forms. Eval/C tests
cover selected list gradients, including
`to_list`/`map`/`to_tensor` paths; other transforms and callback shapes
may reject (`crates/chelis-cli/tests/ad_host_list_combinators.rs`). The C
build rejects a direct named List gradient when the List actual selected for
differentiation is local and its recursive shape cannot be reconstructed;
Eval handles the form. See [#2740](https://github.com/Chelis-Lang/chelis/issues/2740).

### 3.4 Collections, strings, conversions

- **Dict:** `dict_of`, `dict_get`, `dict_contains`, `dict_remove`, `dict_insert`,
  `dict_merge`, `dict_keys`, `dict_values`, `dict_entries`.
- **String:** `char_code`, `char_from_code`, `string_len`, `string_concat`,
  `string_slice`, `string_contains`, `string_starts_with`, `string_ends_with`,
  `string_trim`, `to_string`.
- **Scalar coercion:** `to_int`, `to_float`.
- **Tensor↔host bridges & queries:** `rank`, `shape`, `numel`, `tensor_to_scalar`,
  `scalar_to_tensor`, `to_tensor`, `to_list`. `shape(t, axis: i32)` returns the
  selected runtime extent as `i64`; reductions/expands still need
  compile-time-constant axes regardless.

### 3.5 I/O and process — introduces `IO`

`read_file`, `write_file`, `read_lines`, `read_bytes`, `file_exists`, `list_dir`,
`mmap_file`, `mmap_read`, `mmap_len`, `process_run`, `clock_wall_read`,
`clock_monotonic_read`.

| Name | Signature | Notes |
|---|---|---|
| `list_dir` | `string -> List[string]` | Entry names, not paths. Ordered by host-name bytes; strict UTF-8 conversion under [05-HOST-4]. An invalid name traps `IO` for the complete call. |
| `process_run` | `(cmd: string, args: List[string]) -> (i64, string, string)` | argv, no shell. Eval and compiled C run it; a signal reports `-1`, and a capture that is not UTF-8 traps `IO`. |
| `clock_wall_read` | `() -> (i64, i64)` | Host wall clock on the POSIX timescale as `(seconds, nanoseconds)` since 1970-01-01T00:00:00 UTC, from one reading; nanoseconds in `[0, 10^9)`. Eval and compiled C run it. [05-OP-75] |
| `clock_monotonic_read` | `() -> (i64, i64)` | A clock that never runs backwards, as `(seconds, nanoseconds)` from an unspecified origin. Eval and compiled C run it. [05-OP-75] |

String-valued path APIs cannot directly name non-UTF-8 files. `list_dir`
preserves valid names exactly, without normalization; on conversion failure its
diagnostic identifies the directory and first invalid entry in host-name order
using reversible byte escapes. A byte-preserving path API is not provided by
this contract.

The executable [directory listing example](https://github.com/Chelis-Lang/chelis/blob/v0.18.13/examples/io/list_directory.ch)
prints names in that order. The fixture-based eval/C integration test is
`crates/chelis-cli/tests/issue_1479_list_dir_lane_parity.rs`.

### 3.6 Diagnostics & test — `Test` effect on asserts

`print`, `fail`, `debug`, and the `test_assert*` family: `test_assert`,
`test_assert_eq`, `test_assert_close_tensor`, `test_assert_eq_tensor`.

### 3.7 Integer and bitwise elementwise

`mod`, `bitand`, `bitor`, `bitxor`, `shl`, `shr` operate on integer scalars
or same-shaped integer tensors, and `mod` also on floats, where it is C
`fmod` ([05-OP-64]). They have direct DAG forms (`RiscOp::Mod` and
`RiscOp::Bitwise`). Eval and
compiled C execute bitwise work at the declared width, including integer
expressions used as runtime extents. `grad` retains discrete expressions
that are fixed coefficients and rejects a selected discrete path; `vmap`
maps admitted bitwise work elementwise. HIP has direct typed tensor kernels and
Metal has direct rank-one tensor kernels for all four signed widths. Metal rejects activated shifts
until it can gate their checks. Shifts use declared-width
two's-complement semantics; counts at or above the width fully shift out
the value, while negative counts trap ([04-NUM-13]).

### 3.8 Decimal rounding

`round_to(x: f64|f32|f16|bf16, places: int) -> same dtype` rounds the
operand's exact binary value to the nearest multiple of `10^(-places)`,
ties to the even coefficient, and finalizes once at the operand's own width
([05-OP-1], [04-NUM-8]). `places` is any signed integer: a negative count
rounds left of the decimal point, a count finer than the value is the
identity, a zero result keeps the operand's sign, and a result past the
largest finite value is the signed infinity. Non-finite operands pass
through unchanged. Eval and compiled C share one definition.
Eval/test execute it; compiled builds reject it through the shared
eval-only gate. [05-HOST-2] requires compiled-host support.

The source-defined `Std.Io.Json` module (§11) provides JSON values with
distinct `JsonInt`, `JsonBigInt`, and `JsonFloat` numeric variants.

### 3.9 CSV I/O

The builtin CSV carrier is exactly `List[Dict[string,string]]`: the input's
first record supplies the column names, the carrier contains only data rows,
and parsing keeps every cell as text. Numeric meaning enters only through an
explicit `csv_int*` or `csv_f64*` accessor ([05-OP-2..3]).
Every operation validates the carrier and fails loudly; no cell is silently
coerced or defaulted. Eval and compiled C share one definition of every
operation. The separate source-defined module is `Std.Io.Csv` (§11).

| Name | Signature | Notes |
|---|---|---|
| `parse_csv` | `(s: string) -> List[Dict[string,string]]` | RFC-4180-style quoted fields, doubled quotes, embedded commas/newlines, LF or CRLF, leading UTF-8 BOM; rejects malformed, ragged, blank-interior, or duplicate-header input |
| `to_csv` | `(rows: List[Dict[string,string]]) -> string` | requires every row to have the first row's unique string-keyed columns; quotes fields as needed and emits LF rows with a trailing newline |
| `csv_f64s` | `(rows, col: string) -> List[f64]` | strict finite JSON-number grammar after ASCII space/tab trim; overflow and non-numbers fail |
| `csv_ints` | `(rows, col: string) -> List[i64]` | exact integer grammar and i64 range; float syntax fails naming `csv_f64s` |
| `csv_strs` | `(rows, col: string) -> List[string]` | whole column verbatim |
| `csv_nrows` | `(rows) -> i64` | exact data-row count |
| `csv_cols` | `(rows) -> List[string]` | first row's columns in insertion order |
| `csv_f64` | `(rows, row: int, col: string) -> f64` | one cell; row is a nonnegative 0-based data-row index |
| `csv_int` | `(rows, row: int, col: string) -> i64` | one exact integer cell |
| `csv_str` | `(rows, row: int, col: string) -> string` | one cell verbatim |

Missing columns name the requested column and list the available columns.
The shared eval-only gate in `crates/chelis-ir/src/host.rs` rejects these
builtins in compiled builds, including calls reached through a helper.
The source-defined `Std.Io.Csv` module supplies the compiled-host path
(§11). Builtin compiled-host support required by [05-HOST-2] is tracked
by chelis#1297.

---

## 4. Complete closed vocabulary (completeness check)

Every name in `BUILTIN_NAMES` (`crates/chelis-types/src/builtins.rs`), verbatim. The
fenced block below mirrors the array exactly and is locked to it by the
`doc_surface_section_4_mirrors_builtin_names` test (`crates/chelis-types/src/builtins.rs`),
so it cannot silently drift. Its group labels reflect the vocabulary
organization. Target and AD support are described in their own sections.
To change the array, review
the owning spec, registration, and this exact list together.

Two capabilities live *outside* the array and are intentionally absent below: `const`
and `load` are `RiscOp` memory nodes produced during lowering. Both are documented in
§1.6. Keywords and special forms include `cast`, `cast_trunc`,
`cast_saturate`, `cast_wrap`, `copy`, `grad`, `vmap`, `jit`, and `realize`.

```
Tier-1 DAG:   add sub mul div floor_div trunc_div max_elem min_elem cmplt neg recip exp log sin cos tan atan erf erfc sqrt
              abs floor ceil round sum count max_reduce min_reduce prod_reduce argmax_reduce
              argmin_reduce reduce_window_max reduce_window_min reduce_window_sum
              reduce_window_mean reshape permute expand insert pad shrink stride
              uniform_like dropout gather scatter_replace scatter_elements
              key_from_seed split_key split_keys fold_in
Tier-2 DAG:   eq neq lt gt lte gte and or not relu sigmoid tanh silu gelu gelu_tanh
              standard_normal_cdf
              softmax mean matmul layer_norm conv
Host lane:    cumsum sort einsum diagonal trace where clamp concat split scatter
              pad_sequences pad_sequences_to tensor_scan
              map filter fold scan partition flat_map flatten zip enumerate chunk
              take skip range append index len
              dict_of dict_get dict_contains dict_remove dict_insert dict_merge
              dict_keys dict_values dict_entries
              char_code char_from_code string_len string_concat string_slice string_contains
              string_starts_with string_ends_with string_trim to_string to_int
              to_float rank shape numel tensor_to_scalar scalar_to_tensor to_tensor
              to_list
              read_file write_file read_lines read_bytes file_exists list_dir
              mmap_file mmap_read mmap_len process_run
              clock_wall_read clock_monotonic_read
              round_to
              parse_csv to_csv csv_f64s csv_ints csv_strs csv_nrows csv_cols
              csv_f64 csv_int csv_str
              print fail debug test_assert test_assert_eq test_assert_close_tensor
              test_assert_eq_tensor
              mod bitand bitor bitxor shl shr
              drop
```

Prelude ADTs/constructors (also in scope): `Option`/`Some`/`None`,
`List`/`Cons`/`Nil`, and `MappedFile`.

---

## 5. Autodiff: specified rules and implemented paths

`grad` is a compiler transform. `spec/06` §2 and the [05-OP-N] atoms
determine an operation's adjoint, zero cotangent, or structural rejection.
Each target checks whether it can lower the selected source function.

- **Float tensor paths:** `add`, `sub`, `mul`, `div`, supported unary functions,
  reductions, movement, `matmul`, derived activations, `relu`, and `gather`
  have specified adjoints. `max_elem`/`min_elem` use [05-OP-40]'s exact
  selection; `relu` uses its distinct [05-OP-43] zero rule. `prod_reduce`
  differentiates its balanced tree. A target may reject the resulting
  backward DAG.
- **Zero cotangent or barrier:** `cmplt` and comparison results, `const`,
  `load`, and the `uniform_like` template carry zero cotangent.
  `stop_gradient` cuts a selected path. Logical operations reject `grad`
  structurally.
- **Structural rejection:** float `floor`/`ceil`/`round` and the named
  casts `cast_trunc`, `cast_saturate` and `cast_wrap` are piecewise constant; `count` and argument reductions have discrete
  outputs; replace-scatter variants reject duplicate-sensitive gradients.
  Integer arithmetic is forward-only where its atom says so.
- **Host values and control:** `spec/06` §2.10 defines cotangents for
  selected `List` combinators, the executed `if`/`match` branch, recursive
  trajectories, and ADT fields. Integration tests cover
  Eval list `map`/round-trip gradients and selected compiled List,
  scalar, and ADT paths (`ad_host_list_combinators.rs`,
  `issue_620_static_if_adt_grad.rs`). Other shapes can fail at transform
  lowering or at a target ABI; `tensor_scan` is one such incomplete builder.

For a composed gradient, use a scalar result and check the exact execution
mode. A non-scalar result needs an explicit seed under `spec/06` §8.3.
`grad(f, wrt=x)` returns one selected gradient directly; multiple selected
parameters return a tuple in authored selector order. A discrete field of
a recursive parameter has `unit` cotangent.
[`spec/design/differentiable_language.md`](https://github.com/Chelis-Lang/chelis/blob/v0.18.13/spec/design/differentiable_language.md)
tracks implementation sequencing, while `spec/06` owns the language rule.

---

## 6. Backends — `spec/08-backends.md`

`chelis build` selects C, HIP, or Metal and invokes the native toolchain to
produce an executable for observable programs or a static library for
modules of callable definitions. It retains generated source, headers,
and carried runtime artifacts. `--emit-c` stops after source emission and
runtime staging, prints compile guidance, and requires no native compiler
or archiver. Host compilation disables implicit floating-point contraction.
CPU is the primary acceptance lane; HIP and Metal are prerelease targets
with known imperfections. Generated host code can carry selected tensor
helpers, while device kernels have their own supported operation sets.
`spec/04` §1.1.3 controls dtype admission and `spec/08` controls target
strategy; rejection gates are in
`chelis-compiler-api/src/compiler.rs`.

Build checks type, effect, and linearity over its selected source or linked
Reef target before removing unreachable definitions for emission. A dormant
semantic error in selected code fails the build; files outside that target do
not enter the check. Well-typed unreachable eval-only definitions can still be
removed before the retained program reaches backend capability checks.

| Target | Emits | Status |
|---|---|---|
| `c` (default) | C source, header, carried runtime and flags; OpenMP and BLAS paths where selected | broad host and tensor path with explicit feature gates |
| `hip` | C++ host source with embedded HIP kernel strings, runtime, and rocBLAS matmul path | selected GPU nodes and host wrappers; capability gates apply before emission |
| `metal` | Objective-C++ host source with embedded MSL kernel strings and runtime | selected GPU nodes and host wrappers; dtype and operation gates apply |

### 6.1 Host wrappers and device routing

HIP and Metal both emit host programs. Host wrappers invoke compiled tensor
helpers according to the target and selected entry
(`crates/chelis-cli/src/main.rs`). Before emission, the compiler checks
effects, eval-only builtins, and helper DAG capabilities. HIP admits
literal-bound `pad`/`shrink` DAG nodes but rejects their C-host helper
route; count helpers also receive device capability checks.

### 6.2 DAG-lane GPU coverage gaps

| Op / feature | C | HIP | Metal |
|---|---|---|---|
| Ordinary supported elementwise and reductions | available by operation | device subset; exact reduction cells have gates | device subset; exact reduction cells have gates |
| Direct `Compare`, `Logical`, `Where` | admitted | admitted | rejected pending exact kernels |
| Direct `Sub`, `MaxElem`, `MinElem` and extrema adjoints | admitted | admitted with target dtype limits | rejected pending exact kernels |
| `BlasMatmul` | BLAS/host path | rocBLAS, including selected f16/bf16 paths | tiled MSL path |
| `ReduceWindow` / `ReduceWindowGrad` | guarded C path | rejected | rejected |
| `Pad`, `Shrink` | admitted, including supported runtime bounds | literal-bound direct DAG admitted; node-valued bounds and inexact host-helper routing rejected | target-specific bounds and direct-op gates apply |
| Runtime `shape` value reads / node-valued movement | admitted where the C entry can carry them | device reads and node-valued bounds rejected | device reads and node-valued bounds rejected |
| `dropout` | selected C entries admit runtime key and rate | draws rejected | draws rejected |
| Sparse `Gather`/scatter nodes | admitted by exact operation | f32 payload and restricted index/source forms | rejected |
| `f64` tensor work | admitted | admitted on supported operations | hard-rejected ([04-TGT-1]) |
| f16/bf16 tensor work | admitted by operation | operation-limited (`spec/04` §1.1.3) | f16 admitted; bf16 requires Apple7+ |

The exact `spec/04` table and target gates decide each operation and dtype
cell. Unsupported operations produce target diagnostics before emission.

### 6.3 Exact eval/C output gate

`chelis lane-check <FILE|DIRECTORY> [--json] [--timeout SECONDS]` evaluates
each `.ch` program, builds C, compiles and links its carried runtime with
strict `-O2 -ffp-contract=off -fno-fast-math` flags, runs the binary, and
compares complete UTF-8 stdout through the shared exact comparator.
Directory entries are visited in sorted relative-path order without following
symlinks. No float tolerance or automatic skip applies; unsupported C,
library-only/zero-output programs, and an empty corpus are errors.
Exit 0 requires at least one comparison and no errors or divergences;
divergences exit 1 and infrastructure/unsupported/timeout errors exit 2.
`--json` writes one versioned NDJSON record per program followed by a
summary with a `proof_scope`. Human-readable diagnostics are the default.

Local invocations report an `unpinned-host` scope for diagnosis, **not**
hermetic acceptance. The authoritative x86-64 Linux gate is
`nix build .#checks.x86_64-linux.lane-check`; inspect its
`report.ndjson` output. The check owns the locked Chelis/compiler/native
closure, an exact-safe int/bool/dyadic-float corpus (including signed zero),
the sanitized runtime environment, and a queried-compiler-target check.
It is not available as a Darwin check, and its passing verdict does not
generalize to another hardware tuple. See
[`manual_gates.md`](https://github.com/Chelis-Lang/chelis/blob/v0.18.13/docs/manual_gates.md#compiler-feature-acceptance-gates).

An existing or substituted Nix output is a receipt from its recorded builder,
not evidence that the current host ran the gate. To repeat on the current
Linux builder, first build the check, then use
`nix build --rebuild --no-substitute .#checks.x86_64-linux.lane-check`;
Nix compares the fresh report against the existing output.

---

## 7. Types, shapes, and ownership — `spec/04-type-system.md`

- **Primitive types:** four floats (`f16`, `bf16`, `f32`, `f64`), four
  signed integers (`i8`, `i16`, `i32`, `i64`), `bool`, `key`, and
  `string`. `unit` is a separate type. `f8e4m3` and the `uint*`
  spellings are reserved and rejected. Each target's admitted numeric cells are in `spec/04`
  §1.1.3; a language-level dtype is not automatically a device dtype.
- **Literals and conversion:** unsuffixed integers default to `i32`
  and floats to `f32`. There is no implicit precision promotion.
  `cast(x, T)` is checked ([04-NUM-14]); a fractional or non-finite
  float cannot be silently converted to an integer. The named lossy
  casts each state their loss: `cast_trunc(x, T)` truncates a float
  toward zero with `Domain`/`Overflow` traps ([05-OP-6]);
  `cast_saturate(x, T)` truncates a float and clamps it, or clamps a
  signed integer, to the integer target, trapping `Domain` only on NaN
  ([05-OP-23]); `cast_wrap(x, T)` keeps the target-width two's
  complement value of a signed integer and never traps ([05-OP-24]).
  `spec/04` [04-NUM-15] fixes the first offending element of a tensor
  cast by lowest row-major flat index. HIP currently rejects the compiled
  named casts until their device traps are implemented.
- **Dimensions:** named axes agree by name, with symbolic extents
  for runtime-varying sizes and concrete extents for fixed sizes.
  Wildcard `*` and rank binders `..r` have restricted contexts
  (`spec/04` §4.5). Ordinary binary tensor operators never broadcast;
  use explicit `expand` or movement. A runtime `shape(t, axis)` query
  can return an `i64` extent, while an axis that selects a reduction
  or `expand` dimension resolves statically.
- **Ownership:** owned tensor and key values have linear-use rules.
  Read-only primitive tensor arguments auto-borrow; `len`/`index`
  auto-borrow their List/Dict query argument. `copy()` makes an
  explicit owned copy; `realize` and `drop` consume. Key operations
  consume their key. The ownership pass carries borrow, move, clone,
  and drop obligations into verified lowering.
- **Generic bounds:** a binder may declare `Float`, `Int`, or
  `Numeric` ([04-DTYPE-2]); `Numeric` excludes `bool`. Bounds survive
  aliases, imports, and higher-order uses. The exported stdlib signatures declare
  applicable dtype families in `packages/chelis-std/src/`.

`spec/04` §5.7.1 gives reduction result dtypes and accumulator choices.
The checker rejects unsupported generic bodies and ambiguous dimensions
before target selection.

---

## 8. Effects — `crates/chelis-effects`

| Effect | Introduced by | Handled by |
|---|---|---|
| `IO` | file ops, `mmap_*`, `process_run`, `clock_*_read`, `print` | checked execution boundary / runtime |
| `Test` | `test_assert*` | test/root boundary |
| `Accum` | internal gradient accumulation | compiler-internal |
| `Resource(Device)` | `with device(...)` placement region | checked handler and selected target |

Effects are inferred and checked with types before lowering; `chelis check`
reports effect rows. `dropout` and `uniform_like` take and consume explicit
`key` arguments.

Resource regions are checked against the chosen target before an artifact
is exposed. C host emission recognizes the exact `cpu` selector
and rejects other designators with `BuildTargetMismatch`. Entry-scoped
compilation validates its selected dependency closure, while whole-program
emission covers all definitions. Contextual compilation rejects an imported
callable if its host representation cannot carry it.

---

## 9. Transformations — `spec/06-transformations.md`

These are language forms and compiler transforms, not stdlib functions:

| Transform | Semantics |
|---|---|
| `grad` | Reverse-mode AD; `wrt` selects parameters. One selected target returns its gradient directly; several return an ordered tuple. See §5. |
| `vmap` | Map a function over a batch axis; mapped tensor and key forms, shared arguments, and runtime-extent restrictions are in `spec/06` §3. |
| `jit` | Compilation and cache hint that preserves the function's language semantics (`spec/06` §4); target execution requires a supported lowering. |
| `realize` | Force materialization of a (lazy) tensor; a consuming operation. |

Transform composition is governed by `spec/06`, including
`vmap(grad(f))` for per-example gradients. Transform preparation
rejects a body that reaches an unsupported host-only builder such as
`tensor_scan` at the transform boundary. A successful transform check does
not replace the selected backend's admission check.

---

## 10. `chelis` CLI surface — `crates/chelis-cli`

| Command | Purpose | Style gate? |
|---|---|---|
| `build` | Emit C/HIP/Metal source (`--target {c\|hip\|metal}`, default `c`) and carried runtime artifacts; `.dp` inputs use Deep ingestion | yes |
| `check` | Type/effect/linearity front-end (`--show-inferred`) | yes |
| `validate` | Syntax validation (`--surf`/`--deep`/`--desugar`) | yes for file input |
| `eval` | Evaluate an expression or `--file`; `--json`, `--target`, and `--timeout` are available | yes for file input |
| `fmt` | Canonical formatter (`--check`, `--inplace`) | gate subject |
| `lint` | Naming/style rules (`--check`, `--fix`, `--list`, `--rule`) — `spec/01-nomenclature.md` | gate subject |
| `lane-check` | Compare evaluator and compiled-C stdout exactly over a file or corpus (`--json`, `--timeout`); see §6.3 | yes, through its `eval --file` and `build` runs |
| `cost` | Report lowered-IR copy cost (`--json`) | no |
| `deep` | Desugar Surf → Deep s-expr (`--annotate`) | no |
| `surf` | Resugar well-formed public Deep → canonical Surf; invalid or unpreservable metadata is an error | no |
| `migrate` | Explicit `surf`/`deep` source migrations from a named older grammar; normal parsing does not silently migrate | command-specific |
| `prove` | `@property` verifier (`--tier`, `--samples`, `--seed`, `--smt-timeout`, `--capabilities`); see §12 | no |
| `test` | Run Chelis-native tests (`--filter`, `--json`, `--jobs`, `--expect`, `--batch-mode`) | no |
| `tide` | REPL / HTTP API / MCP / LSP entry points (`serve`, `lsp`, and MCP mode) | no |
| `cove` | Terminal UI (`--file`) | no |
| `reef` | Package, artifact, setup, and conformance commands (`init`, `update`, `build`, `install`, `setup`, `conform`, and others) | no |
| `runtime` | `export <dir>`: write the carried runtime archive, public headers and staging receipt | no |

The style gate (`fmt --check` + blocking `lint`) runs inside `build`, `check`,
`validate`, and `eval --file` where a Surf file is subject to the gate.
The CLI provides `--allow-style-violations` for emergency local use;
`CHELIS_STYLE_GATE_DISABLE=1` is reserved for the integration-test corpus.
Inline `eval` snippets do not run an on-disk file style gate. `fmt`
is the canonical spelling check (`spec/02` §0.1), while `deep` and `surf`
expose the two source representations.

---

## 11. Bundled `chelis-std` — `packages/chelis-std`

`chelis-std` ships with the selected compiler toolchain. Its module
exports are the `export` declarations under `packages/chelis-std/src/`.
Concrete calls depend on their target execution mode. Neural-network layers,
losses, optimizers, and training loops live in a shell, not in `chelis-std`
(`spec/design/chelis_canonical_reference.md` §8.5).

| Module | Key exports |
|---|---|
| `Std.Tensor.Construct` | `linspace`, `arange`, `stack`, `squeeze`, `unsqueeze`. `Float`/`Int` bounds are checked; some concrete calls have gaps ([#1416](https://github.com/Chelis-Lang/chelis/issues/1416)). |
| `Std.Tensor.Mask` | `where_indices`, a source-defined mask index helper. |
| `Std.Sort`, `Std.Scan`, `Std.Index` | `sort`; `scan_list`; `list_index`, `take_list`, `skip_list`. The `sort` wrapper and host builtin return `i64` indices. Selected List index/selection adjoints have Eval/C coverage. |
| `Std.Io` | `read_text`, `write_text`, `read_trimmed_lines`, `read_head_bytes`, `exists`, `list`, `mmap_size`. |
| `Std.Io.Csv` | `read_csv`, `try_read_csv`, `to_csv`, `try_to_csv`, `write_csv`, `try_write_csv`. These are source-defined functions, distinct from the eval-only CSV builtin family. The line-based reader and serializer do not accept CR/LF inside a cell. |
| `Std.Io.Json` | `Json` with `JsonNull`, `JsonBool`, `JsonInt`, `JsonBigInt`, `JsonFloat`, `JsonString`, `JsonArray`, `JsonObject`; parsing, serialization, file I/O, accessors, and `try_*` forms. Integer tokens preserve the `JsonInt(i64)`/`JsonBigInt(string)` distinction instead of passing through `f64`; decimal/exponent tokens use `JsonFloat(f64, string)`, keeping the token text beside its correctly rounded `f64`. |
| `Std.Io.Parquet`, `Std.Io.Safetensors` | `read_parquet`/`write_parquet`; `save_tensors`/`load_tensors`. Check concrete dtype, shape, and target support for a selected call. |
| `Std.Scalar`, `Std.Text`, `Std.Test` | Scalar `max`/`min`/`abs`; `join`; assertions, shape checks, and failure helpers. |
| `Std.Datetime`, `Std.Datetime.Business`, `Std.Datetime.Clock`, `Std.Datetime.Columns`, `Std.Rounding`, `Std.Decimal`, `Std.Process`, `Std.Contracts` | Validated dates, times, instants, offsets, durations, periods, and date/instant columns; business-day calendars over a declared horizon; the host wall and monotonic clocks, which carry `IO`; elementwise column forms and a `Durations[n]` column; the shared rounding modes; exact 38-digit decimal arithmetic; `run`/`run_chelis`; named contract predicates. |
| `Std.Datetime.Zone` | `TimeZone` values read from TZif bytes the program supplies (`time_zone_from_tzif`) or fixed (`time_zone_fixed`, `time_zone_utc`); `Zoned` values with local-reading resolution under a required `Disambiguation`, and RFC 9557 text resolved under a required `OffsetConflict`. |

Compiled-host support for a source-defined module depends on its
selected dependencies and execution path.
For example, `packages/chelis-std/tests/io/json.ch` and `io/csv.ch`
exercise the respective modules, while the builtin CSV family has a
separate build rejection (§3.9). `Std.Tensor.Reduce` is absent; call
`min_reduce`, `prod_reduce`, `argmax_reduce`, or `argmin_reduce` with a
statically resolved axis instead.

---

## 12. `@property` and `chelis prove`

`@property` declarations desugar to a `bool`-returning `def` tagged
`chelis_role: "property"`, with typed binders and optional `where` preconditions and
`with tolerance|seed|samples|contract` metadata. The property spec lives in
[`spec/design/chelis_property_spec.md`](https://github.com/Chelis-Lang/chelis/blob/v0.18.13/spec/design/chelis_property_spec.md);
the executable dispatch is in `crates/chelis-prove/src/property_runner.rs`.

| Tier / option | Route |
|---|---|
| `induction-only` | Surf structural-recursion subset: separate base and step SMT obligations; unsupported shapes stop without sampling. |
| `smt-only` | Lowerable arithmetic and supported contract/gradient forms go to SMT; unsupported forms do not become sampled passes. |
| `fuzz-only` | Deterministic typed sampling with `where` precondition filtering; an observed pass is empirical evidence. |
| `type-only` | Type-oriented result without a proof artifact. |
| `beacon-only` | Optional feature-gated scalar bound-propagation route; `--capabilities` reports availability for the selected build. |

`--tier auto` tries induction first for a checked Surf property that
reaches a recursive model; that outcome is terminal. Otherwise it tries
the SMT route and then sampling for a goal outside the supported SMT
subset. Deep properties do not use the Surf-only induction classifier.
The machine result distinguishes proved, disproved, unsupported,
timed-out, and sampled outcomes; real-arithmetic qualifications and
contract assumptions must be read with the verdict. A host-runtime
operation is not automatically SMT-lowerable, and a sampled pass is
not a proof.

---

## 13. Where to read more

| Doc | Why |
|---|---|
| [`spec/02-surf-syntax.md`](https://github.com/Chelis-Lang/chelis/blob/v0.18.13/spec/02-surf-syntax.md), [`spec/03-deep-syntax.md`](https://github.com/Chelis-Lang/chelis/blob/v0.18.13/spec/03-deep-syntax.md) | source syntax, canonical Surf/Deep conversion, and metadata |
| [`spec/04-type-system.md`](https://github.com/Chelis-Lang/chelis/blob/v0.18.13/spec/04-type-system.md) | dtypes, shapes, accumulators, effects, and linearity |
| [`spec/05-risc-primitives.md`](https://github.com/Chelis-Lang/chelis/blob/v0.18.13/spec/05-risc-primitives.md) | operation signatures, traps, and adjoints |
| [`spec/06-transformations.md`](https://github.com/Chelis-Lang/chelis/blob/v0.18.13/spec/06-transformations.md) | `grad`, `vmap`, and `jit` semantics |
| [`spec/08-backends.md`](https://github.com/Chelis-Lang/chelis/blob/v0.18.13/spec/08-backends.md) | backend strategy and target constraints |
| [`spec/design/differentiable_language.md`](https://github.com/Chelis-Lang/chelis/blob/v0.18.13/spec/design/differentiable_language.md) | implementation sequence for broader AD |
| [`spec/design/rank_polymorphism.md`](https://github.com/Chelis-Lang/chelis/blob/v0.18.13/spec/design/rank_polymorphism.md) | rank-polymorphic implementation |
| [`spec/design/implicit_linearity.md`](https://github.com/Chelis-Lang/chelis/blob/v0.18.13/spec/design/implicit_linearity.md) | ownership implementation |
| [`spec/design/chelis_canonical_reference.md`](https://github.com/Chelis-Lang/chelis/blob/v0.18.13/spec/design/chelis_canonical_reference.md) | core, stdlib, and shell boundary |
| [`spec/design/shell_repo_contract.md`](https://github.com/Chelis-Lang/chelis/blob/v0.18.13/spec/design/shell_repo_contract.md) | a downstream shell's required surface view |

### Deep metadata and source conversion

`spec/03` [03-META-1..3] owns registered metadata, producer extensions,
and their placement. Ingress rejects malformed values, duplicate keys,
and forbidden placements with the key and source location. Extension
payloads are opaque data, not executable subtrees; semantic rewrites
preserve them without interpreting a nested variable spelling or macro
form. Surf conversion rejects an extension it cannot preserve. `grad`'s
`wrt` metadata uses a variable reference or a nonempty tuple of them,
not bare names.

Rust callers receive typed `Metadata`/`MetadataValue` and sealed
`ExtensionData` rather than an unchecked expression map. The
`chelis_surf::resugar::normalize_deep_for_surface_roundtrip` API is
fallible: handle its `ResugarError` before using normalized Deep as a
round-trip witness. `chelis deep`/`surf` are the CLI views; `spec/02`
§0.1 gives the canonical conversion laws.
<!-- END CHELIS MANAGED BLOCK: chelis-surface -->

## Version scope

| Item | Value |
|---|---|
| Source package version | Nautilus `0.7.48` candidate; last published Nautilus package is `v0.7.47` |
| Pinned compiler | Published `chelis 0.18.13` (`reef.toml`: `=0.18.13`) |
| Latest upstream release | `chelis 0.18.13` (checked 2026-10-05) |
| Bundled standard library | `chelis-std 0.4.0`, compiler-bound to `=0.18.13` in the regenerated local `reef.lock` (ignored build output) |
| Upstream release identity | Tag `v0.18.13` at source commit `d753138f5e0059eab35e2babe86b17d6cfcfed37`; release workflow run `37333621011` succeeded; Darwin arm64 tarball SHA-256 `2f7bb08780fdf9b10a8a7a2d4dbce98e993e01e621ac9e85202648bf4c812235` |
| Installed compiler payload | Darwin arm64 binary SHA-256 `6bdc2ca8faeb13a4c47e2cce3bd2ef39a86d1ac1f699e700f85b5c612350bb8c`, byte-identical to the binary extracted from the official v0.18.13 tarball; the tarball passed its release SHA-256 sidecar |
| Validation status | Official Darwin arm64 binary: 616 native tests, 32 negative contracts, 216 strict SciPy parity samples, 88 formatted Chelis sources, tree lint, `reef build`, 34 Rolling C consumers in package and across a package boundary, and a byte-identical release artifact rebuild pass. The 4 SKILL and 18 book examples, mdBook build, 107 script unit tests, conform audit, and bump-check also pass. Manual upstream re-probes are recorded in `docs/UPSTREAM_BUGS.md`. |
| Last refreshed | 2026-10-05 |

`@pin` means the row describes behavior available (or a limitation verified)
on the exact pinned release. `@upstream` means a capability exists in a newer
published release and will arrive at the next bump. The pin is the latest
published release, so this snapshot has no `@upstream` rows; unreleased
compiler work is not listed as upstream.

This is the Nautilus-scoped view of the canonical Chelis inventory. The gate
that backs it ran on the published Darwin arm64 asset: the tarball was checked
against its release sidecar and its extracted compiler payload is byte-identical
to the installed toolchain, so every result below comes from official release
bytes. Version-sensitive statements resolve to the executable 0.18.13 re-probes
cited in [`docs/UPSTREAM_BUGS.md`](UPSTREAM_BUGS.md).

## Capability inventory

### Types, dimensions, and ownership

| Capability | Nautilus consequence | Status |
|---|---|---|
| Active scalar precisions | Chelis admits `f32`, `f64`, `bf16`, `f16`, signed `i8`/`i16`/`i32`/`i64`, `bool`, and `string`. Most Nautilus modules remain f32; `Nautilus.Rolling` is f64. All 23 `Nautilus.Special` exports have the explicit `{f32, f64}` dtype-set bound, which accepts f32 and f64 and rejects f16/bf16 at checking. The same function serves both supported widths, though genericity does not guarantee f64 accuracy. Widening remaining modules is tracked in nautilus#70. | `@pin` |
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
| Unsupported Special precisions | All 67 Special binders are bounded by `{f32, f64}`. `gamma(5.5bf16)` and `bessel_j0(5.0f16)` are rejected at the call site by the negative tests, preventing the former misleading finite value and the latter NaN. The f32 and f64 positive and parity suites pass. The 35 explicit `f64` coefficient suffixes are retained for nautilus#83. | `@pin` |
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
| Keyed tensor generation | `key_from_seed`, `split_key`, `split_keys`, `fold_in`, `uniform_like` | Each sampler takes a first `key` argument. A bound key has at most one consuming use per path; derive distinct children for separate draws. Fresh keys from the same seed replay the same draw. `normal_sample` splits a key for its two uniforms. Sampling is not advertised as differentiable randomness. | `@pin` |
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
| `uniform_like` | A deterministic draw from an explicit affine key; no randomness effect. | Sampling exports are not advertised as reparameterized gradients. | `@pin` |
| Host-list and host-tensor operations (`map`, `fold`, `sort`, `einsum`, general `to_list`/`to_tensor`) | No general host-lane adjoint. The compiler has narrow documented boundary rewrites, but Nautilus does not infer package-wide differentiability from them. | Solvers/decompositions need an executable gradient oracle before being advertised as differentiable. | `@pin` |
| Multi-parameter CurveFit Jacobian wrapper | The generic and concrete Jacobian-row witnesses pass as positive tests (`tests/curvefit_lm_jacobian_*.ch`). The complete LM path still uses finite differences pending a passing exact-AD recovery oracle (chelis#2370, under tracker chelis#1277). | `lm_scalar_nparam` keeps its finite-difference Jacobian until that oracle passes. | `@pin` |
| `grad` call forms | `grad(f, wrt=x)(args...)` differentiates a named definition with respect to one parameter, and evaluates correctly through `normal_cdf` (the Black-Scholes Greeks in the book). A `grad` of a closure that captures the enclosing function's parameters type-checks but fails in the evaluator with `missing required input`. `grad` through `rk4_solve` fails to lower because its recursion depth is a runtime value. | Use the `wrt=` form; no solver is advertised as differentiable. | `@pin` |

No broad LinAlg, solver, distribution, or special-function AD promise is made
by this inventory. The [acceptance rules in `spec/scope.md`](../spec/scope.md#acceptance)
require an executable gradient oracle for each advertised differentiable verb.
The current CurveFit residue is described in
[`docs/UPSTREAM_BUGS.md`](UPSTREAM_BUGS.md#actively-blocking).

### Effects, execution, and packaging

| Capability | Pinned behavior in Nautilus | Status |
|---|---|---|
| Explicit keys | `uniform_like` consumes a key. The seven sampling exports each take a first `key` parameter; there is no randomness handler. | `@pin` |
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
| [Canonical capability surface](https://github.com/Chelis-Lang/chelis/blob/v0.18.13/docs/CHELIS_SURFACE.md) | Complete builtin vocabulary, DAG/host lanes, backends, effects, and chelis-std inventory. |
| [spec/04 — type system](https://github.com/Chelis-Lang/chelis/blob/v0.18.13/spec/04-type-system.md) | Precisions, literals, dimensions, no broadcasting, runtime shapes, effects, and linearity. |
| [spec/05 — RISC primitives](https://github.com/Chelis-Lang/chelis/blob/v0.18.13/spec/05-risc-primitives.md) | Primitive semantics, movement, reductions, and per-op adjoints. |
| [spec/06 — transformations](https://github.com/Chelis-Lang/chelis/blob/v0.18.13/spec/06-transformations.md) | `grad` result shape, `wrt`, symbolic adjoints, and tensor/host transform boundaries. |
| [spec/08 — backends](https://github.com/Chelis-Lang/chelis/blob/v0.18.13/spec/08-backends.md) | C, HIP, and Metal backend scope and rejection rules. |
| [Rank polymorphism design](https://github.com/Chelis-Lang/chelis/blob/v0.18.13/spec/design/rank_polymorphism.md) | Name-preserving `..r` support and body discipline. |
| [Implicit linearity design](https://github.com/Chelis-Lang/chelis/blob/v0.18.13/spec/design/implicit_linearity.md) | Inserted copy/drop behavior and preserved hard errors. |
| [Differentiable-language design](https://github.com/Chelis-Lang/chelis/blob/v0.18.13/spec/design/differentiable_language.md) | Shipped AD slices versus later control/ADT/effect/implicit-diff scope. |
| [Shell repo contract](https://github.com/Chelis-Lang/chelis/blob/v0.18.13/spec/design/shell_repo_contract.md#3-capability-surface-doc--docschelis_surfacemd-must) | Required downstream `@pin`/`@upstream` inventory contract. |
| [`spec/scope.md`](../spec/scope.md) | Nautilus architecture, acceptance rules, and deferrals. |
| [`docs/UPSTREAM_BUGS.md`](UPSTREAM_BUGS.md) | Re-probes at the pin, current residues, workarounds, and triggers. |
