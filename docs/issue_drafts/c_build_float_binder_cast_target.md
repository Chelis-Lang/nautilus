# `chelis build` rejects a cast to a `Float`-bounded binder in an imported generic def, even at a concrete call

**Filing condition:** measure the reproducer below on current chelis `main`,
and re-run the duplicate search. The measurements in this draft are on the
0.18.10 release only. The 26 commits on `main` after `v0.18.10`, checked on
2026-09-17, do not mention cast targets or bounded binders, and do not change
the host-lowering diagnostic below. That is an inference that `main` still
fails, not a measurement.

## Summary

A library package defines a `[prec: Float]` function containing `cast(…, prec)`.
A consumer package imports it and calls it at a concrete dtype. The consumer's
`chelis build` (C) then fails in host lowering:

```text
unsupported: dtype `prec` on a `cast` target in host lowering (lowering);
deliberate [04-DTYPE-1]: the cast target must name an active primitive type
(spec/04-type-system.md section 1.1); a bogus target previously lowered as the
operand type silently in the build lane (chelis#744, chelis#730 census row 13)
```

The same library passes `chelis check`, `chelis test` and `reef build`. So does
the consumer's `reef build`, and so does `eval` at both f32 and f64. Only C
lowering rejects it.

## Reproducer (0.18.10 package lane)

Library package `minlib` (`module_prefix = "Minlib"`), `src/core.ch`:

```chelis
module Minlib.Core
export (cnt)
def cnt[n, prec: Float](v: &tensor[n, prec]) -> prec = cast(numel(v), prec)
```

Consumer package, depending on `minlib`, `src/main.ch`:

```chelis
module Cons.Main
import Minlib.Core (cnt)
export (go)
def go(v: tensor[3, f32]) -> f32 = cnt(v)
```

Steps: `chelis +0.18.10 reef build` the library, `reef install --from-monorepo`
it into a temporary `CHELIS_REEF_HOME`, then run `chelis +0.18.10 build src/main.ch`
in the consumer.

## Measured (0.18.10)

| library body | consumer `chelis build` |
|---|---|
| scalar target, int source: `cast(numel(v), prec)` | **rejected**, at a concrete f32 call |
| scalar target, owned tensor param: `cast(numel(v), prec)` | **rejected** |
| scalar target, float literal: `cast(0.0, prec)` | **rejected** |
| tensor target `cast(v, prec)` over `tensor[n, int64]`, called directly | accepted |
| tensor-routed scalar cast (`k -> length-1 tensor -> cast(prec) -> element`), reached from inside another `[prec: Float]` def | **rejected** |
| no cast in the generic def (control) | accepted |

Realistic control: `Nautilus.Stats` on nautilus `main` (`ffe3beb`, f32
signatures) compiles and links for a consumer that calls `mean_vec`, `std_vec`,
`quantile_vec`, `trimmed_mean_vec` and `correlation_matrix`. The same functions
converted to `[prec: Float]` (nautilus branch `fix/69-stats-float-generic`)
are rejected for that consumer at f32 and at f64.

## Authority

- [04-DTYPE-2]: the bound "survives aliases, wrappers, higher-order values,
  imports, and recursive calls". At each call here, `prec` is instantiated at
  an active primitive (f32 or f64).
- [05-OP-63]: `cast`'s domain is [04-NUM-14]'s checked cast domain, and "No
  backend or host carrier narrows the source or target domain." C host lowering
  is narrowing it.
- [04-DTYPE-1] rejects a target that is not an active primitive. An
  instantiated bounded binder is not that case, so the rejection in the
  diagnostic above belongs to an unactualized binder, not to a bogus spelling.

## Related, not duplicates

- chelis#1418 (closed 2026-09-10) is this diagnostic. Its fixes (#1759,
  #1758) are in v0.18.9 and v0.18.10, and it was accepted on published
  `arange`/`linspace`, which cast to a generic target inside recursive helpers
  producing tensors. The shapes above are not covered: a scalar target at any
  depth, and a tensor target reached through a generic-to-generic call.
- chelis#2151 is the checker's mirror of this: a scalar source typed by a
  bounded binder is rejected. That is a type-checking failure, not a lowering
  one.
- chelis#1564 covers `cast(tensor, bounded binder)` through checker and
  evaluator actualization, not the C host lowering.

## Downstream impact

Every Chelis shell converting to `[prec: Float]`: `Nautilus.Stats` (nautilus#69),
`Nautilus.Interpolation`/`Roots` (nautilus#67), and `Nautilus.LinAlg`
(nautilus#12), tracked under nautilus#70. Worse, converting silently *regresses*
existing f32 C consumers, and no shell-side gate that stops at `reef build` can
see it.
