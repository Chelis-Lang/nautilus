# Root Finding

The `Nautilus.Roots` module provides three scalar root-finders. All are
generic over the `Float` dtype family: one binder governs the objective,
the bracket, the tolerance and the result, so a call is entirely f32 or
entirely f64. Each returns the approximate root, or NaN on failure.

Verified at f32 and f64. `Float` also admits f16 and bf16 per
[04-DTYPE-2], which are untested here (nautilus#67).

## Functions

| Function | Signature |
|---|---|
| `bisection` | `[prec: Float](f: prec -> prec, lo: prec, hi: prec, tol: prec, max_iters: int64) -> prec` |
| `newton` | `[prec: Float](f: prec -> prec, df: prec -> prec, x0: prec, tol: prec, max_iters: int64) -> prec` |
| `brent` | `[prec: Float](f: prec -> prec, lo: prec, hi: prec, tol: prec, max_iters: int64) -> prec` |

## When to use which

- **bisection** -- simplest and most robust. Requires a bracket [lo, hi]
  where f changes sign. Converges linearly (one bit per iteration). Use
  when you have a reliable bracket and do not need speed.
- **newton** -- quadratic convergence near simple roots, but requires the
  user to supply the derivative `df`. Can fail if `df` is near zero or
  the initial guess is far from the root. Use when you have analytic
  derivatives and a good starting point.
- **brent** -- combines inverse quadratic interpolation, secant, and
  bisection fallback. Requires a sign-change bracket like bisection but
  converges superlinearly. The best general-purpose choice.

## Example: find sqrt(2) via Brent's method

```chelis
module Nautilus.BookRootsExamples
import Nautilus.Roots (brent, newton)
export (find_sqrt2, find_cos_eq_x)
def find_sqrt2() -> f32 = {
  f = fn (x: f32) -> sub(mul(x, x), cast(2.0, f32))
  brent(f, cast(1.0, f32), cast(2.0, f32), cast(1e-10, f32), cast(100, int64))
}
def find_cos_eq_x() -> f32 = {
  f = fn (x: f32) -> sub(sin(add(x, cast(1.5707963267948966, f32))), x)
  df = fn (x: f32) -> sub(neg(sin(x)), cast(1.0, f32))
  newton(f, df, cast(0.5, f32), cast(1e-10, f32), cast(50, int64))
}
```

## Example: Newton's method with analytic derivative

## Edge cases

- **No sign change**: `bisection` and `brent` return NaN if
  `f(lo) * f(hi) > 0`.
- **Zero derivative**: `newton` returns NaN if `|df(x)| < 1e-30` at
  any step.
- **Non-convergence**: all three return NaN if `max_iters` is exhausted
  without meeting the tolerance.
- **Tolerance semantics**: the solvers check both interval width and
  `|f(x)|` against `tol`. A value of 1e-8 to 1e-10 is typical at f32.
  `tol` is honoured as given: nothing clamps it to a floor, so the
  reachable accuracy is bounded by the dtype rather than by the module.
  At f64, `brent` on `x^2 - 2` with `tol = 1e-13` lands within 1e-12 of
  sqrt(2).
- **Sub-resolution tolerance**: a `tol` below the dtype's resolution, `0`
  included, stops at the resolution plateau (the step lands on a bracket
  end) and returns that iterate. It does not exhaust `max_iters` into NaN.
