# Root Finding

The `Nautilus.Roots` module provides three scalar root-finders. All take
a function-typed argument `f: f32 -> f32` and return the approximate
root, or NaN on failure.

## Functions

| Function | Signature |
|---|---|
| `bisection` | `(f: f32 -> f32, lo: f32, hi: f32, tol: f32, max_iters: int64) -> f32` |
| `newton` | `(f: f32 -> f32, df: f32 -> f32, x0: f32, tol: f32, max_iters: int64) -> f32` |
| `brent` | `(f: f32 -> f32, lo: f32, hi: f32, tol: f32, max_iters: int64) -> f32` |

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
  brent(f, cast(1.0, f32), cast(2.0, f32), cast(0.0000000001, f32), cast(100, int64))
}
def find_cos_eq_x() -> f32 = {
  f = fn (x: f32) -> sub(sin(add(x, cast(1.5707963267948966, f32))), x)
  df = fn (x: f32) -> sub(neg(sin(x)), cast(1.0, f32))
  newton(f, df, cast(0.5, f32), cast(0.0000000001, f32), cast(50, int64))
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
  `|f(x)|` against `tol`. A value of 1e-8 to 1e-10 is typical.
