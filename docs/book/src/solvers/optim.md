# Scalar optimization

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

## Choosing a method

- **golden_section_search:** Requires only function evaluations on a
  bracket [lo, hi] where f is unimodal. Linear convergence (golden
  ratio reduction per step).
- **brent_minimize:** Alternates parabolic interpolation with golden
  section fallback. Superlinear convergence for smooth functions while
  staying within [lo, hi]. Use it when derivatives are unavailable.
- **gradient_descent_1d:** Uses a fixed learning rate and needs the derivative
  `df`. Each step is `x - lr * df(x)`. Returns NaN on divergence
  (|x| > 1e15). Useful when you have analytic gradients and want to tune
  learning rate.
- **newton_minimize_1d:** Uses both first and second derivatives
  (`df`, `ddf`). Quadratic convergence near a minimum with positive
  curvature. Returns NaN if the Hessian is non-positive or below 0.01
  at the point it stops on.

## Example

```chelis-fragment
import Nautilus.Optim (golden_section_search, brent_minimize, newton_minimize_1d, gradient_descent_1d)

def parabola(x: f32) -> f32 = {
  d = sub(x, 3.0f32)
  add(mul(d, d), 7.0f32)
}
def d_parabola(x: f32) -> f32 = mul(2.0f32, sub(x, 3.0f32))
def dd_parabola(x: f32) -> f32 = 2.0f32
golden = golden_section_search(parabola, 0.0f32, 10.0f32, 1.0e-6f32, 200i64)
brent = brent_minimize(parabola, 0.0f32, 10.0f32, 1.0e-6f32, 200i64)
newton = newton_minimize_1d(parabola, d_parabola, dd_parabola, 0.0f32, 1.0e-6f32, 50i64)
gd = gradient_descent_1d(parabola, d_parabola, 0.0f32, 0.1f32, 500i64)
```

```text
golden = 3.000132
brent = 2.9998934
newton = 3.0
gd = 2.9999995
```

All four find the minimum of `(x - 3)^2 + 7`. Newton lands on 3 exactly in
one step because the objective is quadratic. The two bracketing methods stop
on bracket width, so their answers are within about 1e-4 of 3 for this
`tol`: the minimum of a smooth function is flat, and an f32 objective cannot
distinguish points closer than about `sqrt(ulp)` of the minimum.

## gradient_descent_1d contract

`lr` must be positive and small enough for the iteration to contract:
below `2 / f''(x)` near the minimum, so below 1 for this parabola. It is not
checked. With the parabola above and `x0 = 0`:

| `lr` and budget | Result | Why |
|---|---|---|
| `0.1`, 500 iterations | `2.9999995` | converged |
| `0.01`, 10 iterations | `0.5487816` | budget exhausted; the last iterate, with no signal |
| `0.0` | `0.0` | the first step leaves x unchanged, which ends the search |
| `-0.1` | NaN | ascends until \|x\| > 1e15 |
| `1.5` | NaN | overshoots with growing amplitude until \|x\| > 1e15 |

Gradient descent stops when `|df(x)| < 1e-10`, when a step leaves `x`
unchanged, or when the budget runs out; only divergence returns NaN. Check
`df` at the result when convergence matters.

## Notes

- `golden_section_search` and `brent_minimize` assume unimodality on
  [lo, hi]. Multiple local minima may cause convergence to any one of
  them.
- `gradient_descent_1d` stops when `|df(x)| < 1e-10` (hard-coded).
- Newton stops when `|df(x)| < tol` or `df(x)` is exactly zero. The exact-zero
  test still works when `tol` is zero, negative, or NaN. It also stops when
  `x - df(x)/ddf(x)` rounds back to `x`. Both exits require a finite point
  and positive curvature at least at the `0.01` floor; NaN curvature fails.
- At a gradient-based stop, Newton accepts `ddf(x) = +inf`. At a rounding
  stall it requires finite curvature. Infinite curvature can make the step
  zero even when the gradient is large, so such a stall returns NaN.
  Negative infinite curvature fails at either exit.
- A finite rounding stall can occur near a minimum with a nonzero gradient.
  For `(x^2-2)^2` from `x0 = 1.2`, the iterate stalls at `sqrt(2.0f32)` with
  gradient `-6.74e-7` and step `-4.2e-8`. Rejecting every nonzero gradient
  would also reject this result. The finite-curvature check does not prove
  stationarity, however; a very large finite `ddf` can also make a step vanish.
- Curvature overflow near a minimum can therefore produce NaN. A `tol` above
  the gradient magnitude uses the gradient-based exit instead, but must be
  appropriate to the calculation. One ULP above the minimum of `(x-3)^2`,
  the gradient is `4.8e-7`, so `tol = 1e-6` accepts it and `tol = 1e-9` does
  not. Scaling to `2e38*(x-3)^2` gives `ddf = 4e38`, which overflows f32,
  and a gradient of `9.5e31` at that point. A tolerance useful for resolving
  this minimum cannot recover it. Scale the objective so its curvature is
  representable, or use derivative-free `brent_minimize`.
- The curvature floor also rejects flat minima. For `3.1e-4*(x^2-2)^2`,
  Newton stalls at `sqrt(2.0f32)` with curvature `0.00496` and gradient
  `-2.09e-10`. It returns NaN with `tol = 1e-10`, `tol = 0`, or
  `tol = 1e-6`. Changing tolerance cannot bypass the floor; use
  `brent_minimize` or `golden_section_search` for flat objectives.
- Newton does not check that `ddf` is the derivative of `df`. Inconsistent
  derivatives can produce a finite stall at a nonstationary point that passes
  the curvature check. Supply consistent derivatives or use a derivative-free
  method.
- A NaN endpoint, starting point, or evaluated function result gives NaN.
  `golden_section_search` and `brent_minimize` evaluate `f`;
  `gradient_descent_1d` and `newton_minimize_1d` evaluate only the supplied
  derivatives and never call `f`. A NaN objective therefore does not reach
  the derivative-based methods.
- No method detects NaN in regions it never evaluates. `brent_minimize`
  initially samples the quarter, midpoint, and three-quarter points;
  `golden_section_search` samples different points. One can return NaN while
  the other returns a finite point for the same partially defined objective.
- `tol` for the bracketing methods is a bracket width in x and should be
  positive. `brent_minimize` raises any `tol` below 1e-6 to 1e-6.
  `golden_section_search` does not: with `tol <= 0` the width test never
  passes, and it returns the bracket midpoint after `max_iters` iterations,
  or earlier if `f` returns equal values at its two probe points.
- A NaN `tol` is not rejected. For the bracketing methods, it disables width
  stopping; the method can still return at its iteration budget or an f32
  stall. Validate a computed tolerance before calling.
- All methods are pure Chelis. AD flows through the objective function
  but you must supply `df`/`ddf` explicitly. The optimizer does not
  call `grad` internally.
