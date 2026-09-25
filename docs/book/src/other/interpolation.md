# Interpolation

The `Nautilus.Interpolation` module provides five functions for f32 data:
two piecewise-linear interpolators, a single-interval cubic Hermite, and a
natural cubic spline with its fitting step exposed. All are pure (no effects),
and the tensor-taking ones are polymorphic over length and borrow their
inputs (`&tensor`).

## linear_interp_uniform

Interpolates on a uniformly-spaced grid. The caller provides the y-values
as a tensor, the x-range endpoints, and a query point.

```chelis-fragment
import Nautilus.Interpolation (linear_interp_uniform)

// ys: 5 equally-spaced y-values over [0, 4]
// Query at x = 1.5 (between indices 1 and 2)
result = linear_interp_uniform(ys, cast(0.0, f32), cast(4.0, f32), cast(1.5, f32))
```

**Signature:** `[n](ys: &tensor[n, f32], x_min: f32, x_max: f32, x_query: f32) -> f32`

Extrapolation is clamped: queries outside `[x_min, x_max]` return the
nearest endpoint value. Internally uses `fold` over `enumerate(to_list(ys))`
to locate the bracketing interval.

## linear_interp_sorted

Interpolates on a non-uniform but sorted grid. The caller provides both
x-knots and y-values as separate tensors.

```chelis-fragment
import Nautilus.Interpolation (linear_interp_sorted)

result = linear_interp_sorted(xs, ys, cast(2.5, f32))
```

**Signature:** `[n](xs: &tensor[n, f32], ys: &tensor[n, f32], x_query: f32) -> f32`

Extrapolation is flat: queries below the first knot return the first
y-value; queries above the last knot return the last y-value. The xs
tensor must be sorted in ascending order.

## cubic_hermite

Single-interval cubic Hermite spline. The caller supplies two endpoints
`(x0, y0)` and `(x1, y1)`, tangent slopes `m0` and `m1` at each
endpoint, and a query point.

```chelis
module Nautilus.BookHermite
import Nautilus.Interpolation (cubic_hermite)
export (hermite_midpoint)
def hermite_midpoint() -> f32 = {
  x0 = cast(0.0, f32)
  x1 = cast(1.0, f32)
  y0 = cast(0.0, f32)
  y1 = cast(1.0, f32)
  m0 = cast(1.0, f32)
  m1 = cast(1.0, f32)
  cubic_hermite(x0, x1, y0, y1, m0, m1, cast(0.5, f32))
}
```

With linear data and matching slopes the Hermite cubic reduces to linear
interpolation, so `hermite_midpoint` returns 0.5.

**Signature:** `(x0: f32, x1: f32, y0: f32, y1: f32, m0: f32, m1: f32, x_query: f32) -> f32`

Uses the standard Hermite basis polynomials h00, h10, h01, h11 to ensure
C1 continuity. Returns NaN if `x0 == x1` (zero-width interval). To build
a full piecewise Hermite spline, call this function once per interval.

## spline_eval and spline_fit

`spline_eval` fits a natural cubic spline through sorted knots and evaluates
it at one query point. `spline_fit` returns the vector M of second
derivatives at the knots that the spline uses; natural boundary conditions
fix M[0] = M[m-1] = 0. Both are `alpha` stability.

**Signatures:**
`spline_eval[m](xs: &tensor[m, f32], ys: &tensor[m, f32], x_query: f32) -> f32` and
`spline_fit[m](xs: &tensor[m, f32], ys: &tensor[m, f32]) -> tensor[m, f32]`

Queries outside `[xs[0], xs[m-1]]` return the nearest endpoint value. Every
`spline_eval` call refits the spline, so avoid it in tight loops over the
same knots. `xs` must be sorted ascending.
