# Numerical Integration

The `Nautilus.Integrate` module provides quadrature rules for computing
definite integrals of scalar functions. Methods range from basic
composite rules to adaptive and Gaussian quadrature.

## Fixed composite rules

| Function | Signature | Notes |
|---|---|---|
| `trapezoidal` | `(f: f32 -> f32, a, b: f32, n_steps: int64) -> f32` | Composite trapezoidal; O(h^2) |
| `simpsons` | `(f: f32 -> f32, a, b: f32, n_steps: int64) -> f32` | Composite Simpson's; n_steps must be even, NaN otherwise; O(h^4) |

## Gaussian quadrature (finite interval)

| Function | Signature | Notes |
|---|---|---|
| `gauss_legendre_5` | `(f: f32 -> f32, a, b: f32, n_points: int64) -> f32` | 5-point; n_points is ignored |
| `gauss_legendre_10` | `(f: f32 -> f32, a, b: f32) -> f32` | 10-point; exact for polynomials up to degree 19 |

Pre-tabulated nodes and weights mapped from [-1, 1] to [a, b]. No
subdivision -- accuracy depends on how well a low-degree polynomial
approximates the integrand.

## Adaptive and Richardson methods

| Function | Signature | Notes |
|---|---|---|
| `adaptive_simpson` | `(f: f32 -> f32, a, b: f32, tol: f32, max_depth: int64) -> f32` | Recursive subdivision with Richardson extrapolation |
| `romberg_5` | `(f: f32 -> f32, a, b: f32) -> f32` | 5-level Romberg (trapezoidal base, up to 16 panels) |

`adaptive_simpson` subdivides intervals where the local error estimate
exceeds `15 * tol`. The tolerance is halved at each recursion level,
with a floor of 1e-7. Max depth is capped at 30.

## Specialized weight functions

| Function | Signature | Notes |
|---|---|---|
| `gauss_hermite_10` | `(f: f32 -> f32) -> f32` | Integrates f(x) * exp(-x^2) over (-inf, inf) |
| `gauss_laguerre_10` | `(f: f32 -> f32) -> f32` | Integrates f(x) * exp(-x) over [0, inf) |

These include the weight function in the quadrature. Pass only the
non-weight part of the integrand.

## Example: compute pi/4

```chelis-fragment
import Nautilus.Integrate (adaptive_simpson, gauss_legendre_10, romberg_5)

def inv_1_x2(x: f32) -> f32 =
  div(cast(1.0, f32), add(cast(1.0, f32), mul(x, x)))

def pi_over_4_adaptive() -> f32 =
  adaptive_simpson(inv_1_x2, cast(0.0, f32), cast(1.0, f32),
                   cast(1.0e-10, f32), cast(20, int64))

def pi_over_4_gl10() -> f32 =
  gauss_legendre_10(inv_1_x2, cast(0.0, f32), cast(1.0, f32))

def pi_over_4_romberg() -> f32 =
  romberg_5(inv_1_x2, cast(0.0, f32), cast(1.0, f32))
```

All three return approximately 0.7854 (pi/4).

## Notes

- `simpsons` returns NaN for odd `n_steps`.
- `trapezoidal` and `simpsons` return NaN for `n_steps <= 0`.
- For smooth integrands, `gauss_legendre_10` or `romberg_5` typically
  gives high accuracy without tuning a step count.
- For integrands with localized sharp features, prefer
  `adaptive_simpson`.
