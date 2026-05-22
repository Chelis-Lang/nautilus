# Issue 1: scalar-f32 evaluator vs C backend divergence

Labels: `bug`, `soundness`

Filed: [Chelis-Lang/chelis#189](https://github.com/Chelis-Lang/chelis/issues/189)
on 2026-05-22.

---

## Title

`chelis eval` and `chelis build --target c` produce divergent scalar-f32
constants (evaluator preserves f64 precision; C backend quantizes via
`as f32` cast plus `%.8` format string)

## Body

### Summary

Reading the same Surf scalar-f32 constant through `chelis eval` and through
`chelis build --target c && run` produces different values. The evaluator
preserves the source f64 value verbatim (its internal `TensorValue.data`
is `Vec<f64>`), whereas the C backend emits the constant through an
`as f32` cast composed with a `%.8` format-string truncation. The
resulting C-side scalar can drift up to ~3% from the source-text value
for small magnitudes.

This is a soundness item because it means the same Surf program has two
official numeric semantics depending on which execution path the caller
takes.

### Reproducer

`f32_divergence.ch`:

```surf
module F32Divergence
small_val = cast(0.000000123456789, f32)
```

`chelis eval --file f32_divergence.ch` reports:

```
small_val = tensor(shape=[], data=[1.23456789e-7])
```

`chelis build --target c f32_divergence.ch` emits (line from
`f32_divergence.c`):

```c
chelis_fill_f32(t0, 0.00000012f);
```

Running the compiled binary against the emitted module yields:

```
small_val = 1.199999957179898e-07 (hex 0x1.01b2b2p-23)
```

Evaluator value: `1.23456789e-7`. C-backend value: `1.19999996e-7`.
Relative discrepancy: ~3%.

A second reproducer using the f32-ULP-near-1.0 value (the originally
proposed shape) confirms the same direction:

```surf
module F32Divergence
eps = cast(0.00000011920929, f32)
one = cast(1.0, f32)
result = add(one, eps)
```

`chelis eval`:

```
eps    = tensor(shape=[], data=[1.1920929e-7])
one    = tensor(shape=[], data=[1.0])
result = tensor(shape=[], data=[1.00000011920929])
```

C-backend run:

```
eps    = 1.199999957179898e-07 (hex 0x1.01b2b2p-23)
one    = 1                     (hex 0x1p+0)
result = 1.0000001192092896    (hex 0x1.000002p+0)
```

In this second reproducer the `result` happens to round to the same
f32 representation in both paths because the f32 ULP at 1.0 is wider
than the eps discrepancy -- but the intermediate `eps` constant still
differs, and any computation depending on `eps` directly (not via a
sum that rounds it away) will diverge.

### Mechanism (source anchors)

**Evaluator** at `crates/chelis-ir/src/eval.rs:722-728`:

```rust
RiscOp::Const { value } => {
    let shape = concrete_shape(&node.output_type).unwrap_or_default();
    TensorValue {
        data: vec![*value; numel(&shape)],
        shape,
    }
}
```

`TensorValue.data` is `Vec<f64>` (declared at `eval.rs:12`), so the
constant's f64 source value is preserved verbatim in the evaluator. No
`as f32` round-trip happens for declared-`f32` scalars.

**C backend** at `crates/chelis-backend-c/src/emit.rs:1158-1180` (the
f32 fall-through arm at line 1177):

```rust
_ => {
    self.line(&format!("chelis_fill_f32(t{id}, {:.8}f);", value as f32));
}
```

Two truncations compose here:

1. `value as f32` -- the f64-to-f32 narrowing cast.
2. `{:.8}` format string -- eight digits after the decimal point. For
   values in the `1e-7` range this leaves only one or two significant
   digits; the printed literal `0.00000012f` represents
   `1.19999996e-7` rather than the source-text value.

### Impact

- **nautilus** has hardened its iterative numeric modules
  (`Nautilus.Optim`, `Nautilus.Special`, `Nautilus.Roots`) with
  plateau-stops and tolerance floors so it is robust to either
  semantics -- but the divergence is still a soundness concern for
  any caller that hasn't done that work.
- Tests that pass under `chelis eval` may produce different numeric
  outputs when the same module is built and run through the C backend.
  Property tests, parity gates, and reproducible-numeric-result
  assertions are all affected.
- The divergence is not gated by an opt-in flag -- it is structural
  behavior of the two paths.

### Suggested resolution

Two viable directions, both acceptable; choose one and document in
spec §1.1 (numeric semantics):

1. **Unify on f32-semantics**. Make the evaluator narrow declared-f32
   constants via `as f32` before storing into `TensorValue.data`
   (preserving the existing `Vec<f64>` storage, but ensuring the
   bit-pattern matches a round-trip through f32). Replace the C
   backend's `{:.8}f` format with `{:.9e}f` or the bit-exact
   hexadecimal float literal form (`0x1.01b2b2p-23f`), so the C
   side reproduces the f32 value used by the evaluator with no
   precision loss.

2. **Unify on f64-semantics for evaluator, f32 for backend, with
   an explicit advisory**. Keep the evaluator faithful to source
   f64 and document that the C backend rounds to f32 at the
   compile-time constant boundary. Add a `chelis check`-time warning
   when a declared-f32 constant's f64 source value would round
   differently than what the `{:.8}` format string emits, so callers
   can spot the divergence before they see it at runtime.

Option 1 is the soundness-preserving choice. Option 2 is the
pragmatic choice if there's a downstream reason to keep evaluator
arithmetic in f64.

### Reference framing

The plan that triggered this filing predicted "evaluator over-promotes
to f64; C backend computes in true f32". The actual mechanism on the
C side turned out to be *not* true f32 arithmetic per se but the
`%.8` format string in `emit.rs:1177` (composed with `as f32`). The
direction of the divergence matches the prediction -- evaluator gives
the higher-fidelity value; C backend gives the lossier one.

### Cross-reference

This issue is tracked in
`nautilus/docs/upstream-issues-drafts/issue-01-scalar-f32-evaluator-vs-c-backend.md`
and referenced in nautilus's `CHANGELOG.md` under the 0.7.10 release
section ("Tracked upstream").
