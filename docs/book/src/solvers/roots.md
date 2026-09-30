# Root Finding

The `Nautilus.Roots` module provides three scalar root-finders. Each takes
a function `f: f32 -> f32` and returns an approximate root. Invalid brackets,
near-zero derivatives, and exhausted iteration limits can produce NaN.

## Functions

| Function | Signature |
|---|---|
| `bisection` | `(f: f32 -> f32, lo: f32, hi: f32, tol: f32, max_iters: i64) -> f32` |
| `newton` | `(f: f32 -> f32, df: f32 -> f32, x0: f32, tol: f32, max_iters: i64) -> f32` |
| `brent` | `(f: f32 -> f32, lo: f32, hi: f32, tol: f32, max_iters: i64) -> f32` |

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

## Example: Brent's method and Newton's method

```chelis
module Nautilus.BookRootsExamples
import Nautilus.Roots (brent, newton)
export (find_sqrt2, find_cos_eq_x)
def find_sqrt2() -> f32 = {
  f = fn (x: f32) -> sub(mul(x, x), cast(2.0, f32))
  brent(f, cast(1.0, f32), cast(2.0, f32), cast(1e-6, f32), cast(100, i64))
}
def find_cos_eq_x() -> f32 = {
  f = fn (x: f32) -> sub(cos(x), x)
  df = fn (x: f32) -> sub(neg(sin(x)), cast(1.0, f32))
  newton(f, df, cast(0.5, f32), cast(1e-10, f32), cast(50, i64))
}
```

`find_sqrt2` returns approximately 1.414213. `find_cos_eq_x` solves
cos(x) = x with the analytic derivative -sin(x) - 1 and returns approximately
0.739085.

## Edge cases

- **No sign change**: `bisection` and `brent` return NaN if
  `f(lo) * f(hi) > 0`.
- **Zero derivative**: `newton` returns NaN if `|df(x)| < 1e-30` at
  any step.
- **Iteration limit**: all three return NaN when `max_iters` is exhausted
  before any stopping condition. They can also return a finite point
  before reaching the requested tolerance when f32 arithmetic makes an
  iteration stop changing the point.
- **Tolerance**: bisection and Brent compare bracket width or `|f(x)|`
  with a threshold; Newton compares `|f(x)|`. Brent uses at least
  `1e-6` inside its iteration even if you pass a smaller `tol`.
  Check `|f(root)|` yourself when a particular residual is required.
