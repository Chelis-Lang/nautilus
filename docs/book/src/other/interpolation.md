# Interpolation

The `Nautilus.Interpolation` module provides three interpolation functions
plus a natural cubic spline. All are pure (no effects) and polymorphic over
tensor length.

`linear_interp_uniform`, `linear_interp_sorted` and `cubic_hermite` are also
generic over the `Float` dtype family: one binder governs the grid, the query
and the result, so a call is entirely f32 or entirely f64. Verified at f32 and
f64; `Float` also admits f16 and bf16, which are untested (nautilus#67).
`spline_fit` and `spline_eval` remain f32 until `Nautilus.LinAlg` is generic
(nautilus#12).

## linear_interp_uniform

Interpolates on a uniformly-spaced grid. The caller provides the y-values
as a tensor, the x-range endpoints, and a query point.

```chelis-fragment
import Nautilus.Interpolation (linear_interp_uniform)

// ys: 5 equally-spaced y-values over [0, 4]
// Query at x = 1.5 (between indices 1 and 2)
result = linear_interp_uniform(ys, cast(0.0, f32), cast(4.0, f32), cast(1.5, f32))
```

**Signature:** `[n, prec: Float](ys: &tensor[n, prec], x_min: prec, x_max: prec, x_query: prec) -> prec`

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

**Signature:** `[n, prec: Float](xs: &tensor[n, prec], ys: &tensor[n, prec], x_query: prec) -> prec`

Extrapolation is flat: queries below the first knot return the first
y-value; queries above the last knot return the last y-value. The xs
tensor must be sorted in ascending order.

## cubic_hermite

Single-interval cubic Hermite spline. The caller supplies two endpoints
`(x0, y0)` and `(x1, y1)`, tangent slopes `m0` and `m1` at each
endpoint, and a query point.

```chelis-fragment
import Nautilus.Interpolation (cubic_hermite)

// Linear data with matching slopes -> reduces to linear interpolation
result = cubic_hermite(
  cast(0.0, f32), cast(1.0, f32),   // x0, x1
  cast(0.0, f32), cast(1.0, f32),   // y0, y1
  cast(1.0, f32), cast(1.0, f32),   // m0, m1
  cast(0.5, f32)                     // x_query
)
// result = 0.5
```

**Signature:** `[prec: Float](x0: prec, x1: prec, y0: prec, y1: prec, m0: prec, m1: prec, x_query: prec) -> prec`

Uses the standard Hermite basis polynomials h00, h10, h01, h11 to ensure
C1 continuity. Returns NaN if `x0 == x1` (zero-width interval). To build
a full piecewise Hermite spline, call this function once per interval.
