# Scalar Optimization

The `Nautilus.Optim` module provides four 1D minimization methods. All
take function-typed arguments and return the approximate minimizer (or
NaN on failure).

## Functions

| Function | Signature |
|---|---|
| `golden_section_search` | `(f: f32 -> f32, lo, hi: f32, tol: f32, max_iters: i64) -> f32` |
| `brent_minimize` | `(f: f32 -> f32, lo, hi: f32, tol: f32, max_iters: i64) -> f32` |
| `gradient_descent_1d` | `(f, df: f32 -> f32, x0, lr: f32, max_iters: i64) -> f32` |
| `newton_minimize_1d` | `(f, df, ddf: f32 -> f32, x0: f32, tol: f32, max_iters: i64) -> f32` |

## When to use which

- **golden_section_search** -- requires only function evaluations on a
  bracket [lo, hi] where f is unimodal. Linear convergence (golden
  ratio reduction per step). Simplest and most robust.
- **brent_minimize** -- alternates parabolic interpolation with golden
  section fallback. Superlinear convergence for smooth functions while
  staying within [lo, hi]. Best general-purpose choice.
- **gradient_descent_1d** -- fixed learning rate, needs the derivative
  `df`. Returns NaN on divergence (|x| > 1e15). Useful when you have
  analytic gradients and want to tune learning rate.
- **newton_minimize_1d** -- uses both first and second derivatives
  (`df`, `ddf`). Quadratic convergence near a minimum with positive
  curvature. Returns NaN if the Hessian is non-positive or below 0.01
  at convergence, guarding against saddle points.

## Example: golden section

```chelis-fragment
import Nautilus.Optim (golden_section_search)

def find_min() -> f32 = {
  f = fn (x: f32) -> {
    d = sub(x, cast(3.0, f32))
    add(mul(d, d), cast(7.0, f32))
  }
  golden_section_search(f, cast(0.0, f32), cast(10.0, f32),
                        cast(1.0e-8, f32), cast(200, i64))
}
```

Returns approximately 3.0 (the minimum of (x-3)^2 + 7).

## Example: Newton minimization

```chelis-fragment
import Nautilus.Optim (newton_minimize_1d)

def parabola(x: f32) -> f32 = {
  d = sub(x, cast(3.0, f32))
  add(mul(d, d), cast(7.0, f32))
}
def d_parabola(x: f32) -> f32 = mul(cast(2.0, f32), sub(x, cast(3.0, f32)))
def dd_parabola(x: f32) -> f32 = cast(2.0, f32)

def find_min_newton() -> f32 =
  newton_minimize_1d(parabola, d_parabola, dd_parabola,
                     cast(0.0, f32), cast(1.0e-10, f32), cast(50, i64))
```

## Notes

- `golden_section_search` and `brent_minimize` assume unimodality on
  [lo, hi]. Multiple local minima may cause convergence to any one of
  them.
- `gradient_descent_1d` stops when `|df(x)| < 1e-10` (hard-coded).
- `newton_minimize_1d` checks that the second derivative at the
  converged point is positive and above 0.01. If not, it returns NaN
  to signal that the point may be a saddle or inflection.
- All methods are pure Chelis. AD flows through the objective function
  but you must supply `df`/`ddf` explicitly -- the optimizer does not
  call `grad` internally.
