# Interpolation

The `Nautilus.Interpolation` module provides five functions for f32 data:
two piecewise-linear interpolators, a single-interval cubic Hermite, and a
natural cubic spline with its fitting step exposed. All are pure (no effects),
and the tensor-taking ones are polymorphic over length and borrow their
inputs (`&tensor`).

## linear_interp_uniform

Interpolates on a uniformly spaced grid. The caller provides the y-values,
the x-range endpoints, and a query point; knot `i` sits at
`x_min + i * (x_max - x_min) / (n - 1)`.

**Signature:** `[n](ys: &tensor[n, f32], x_min: f32, x_max: f32, x_query: f32) -> f32`

```chelis-fragment
import Nautilus.Interpolation (linear_interp_uniform)

def ys() -> tensor[5, f32] = to_tensor([0.0f32, 1.0f32, 4.0f32, 9.0f32, 16.0f32])
uniform_mid = linear_interp_uniform(ys(), 0.0f32, 4.0f32, 1.5f32)
uniform_clamped = linear_interp_uniform(ys(), 0.0f32, 4.0f32, 7.0f32)
```

```text
ys = tensor(shape=[5], data=[0.0, 1.0, 4.0, 9.0, 16.0])
uniform_mid = 2.5
uniform_clamped = 16.0
```

The five values sit at x = 0, 1, 2, 3, 4, so x = 1.5 lies halfway between
1 and 4. Queries outside `[x_min, x_max]` return the nearest endpoint value.
Use at least two values and `x_min < x_max`.

## linear_interp_sorted

Interpolates on a non-uniform grid. The caller provides the knots `xs` and
the values `ys` as separate tensors of the same length.

**Signature:** `[n](xs: &tensor[n, f32], ys: &tensor[n, f32], x_query: f32) -> f32`

```chelis-fragment
import Nautilus.Interpolation (linear_interp_sorted)

def knots() -> tensor[4, f32] = to_tensor([0.0f32, 1.0f32, 3.0f32, 4.0f32])
def vals() -> tensor[4, f32] = to_tensor([0.0f32, 2.0f32, 2.0f32, 0.0f32])
sorted_mid = linear_interp_sorted(knots(), vals(), 2.5f32)
sorted_left = linear_interp_sorted(knots(), vals(), -1.0f32)
```

```text
sorted_mid = 2.0
sorted_left = 0.0
```

Queries below the first knot return the first value; queries above the last
knot return the last value.

`xs` must be strictly ascending. The function scans the knots in order and
uses the first interval `[xs[i-1], xs[i]]` that contains the query; it does
not check the order. Consequences:

- A repeated knot works when an earlier interval already contains the query:
  knots `[0, 1, 1, 2]` with values `[0, 1, 5, 6]` give `1.0` at x = 1.
- A query that first meets a zero-width interval returns NaN: knots
  `[1, 1, 2]` with values `[0, 5, 6]` give NaN at x = 1.
- Unsorted knots return the interpolant on whichever interval matches
  first, with no error.

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
C1 continuity. Returns NaN if `x0 == x1` (zero-width interval). A query
outside `[x0, x1]` is not clamped: the cubic is extrapolated. With endpoints
(0, 0) and (1, 1) and zero slopes, x = 0.5 gives `0.5` and x = 2 gives
`-4.0`. Clamp the query yourself if you need endpoint values. To build
a full piecewise Hermite spline, call this function once per interval.

## spline_eval and spline_fit

`spline_eval` fits a natural cubic spline through strictly increasing knots
and evaluates it at one query point. `spline_fit` returns the vector M of
second derivatives at the knots that the spline uses; natural boundary
conditions fix M[0] = M[m-1] = 0.

**Signatures:**
`spline_eval[m](xs: &tensor[m, f32], ys: &tensor[m, f32], x_query: f32) -> f32` and
`spline_fit[m](xs: &tensor[m, f32], ys: &tensor[m, f32]) -> tensor[m, f32]`

```chelis-fragment
import Nautilus.Interpolation (spline_eval, spline_fit)

def knots() -> tensor[4, f32] = to_tensor([0.0f32, 1.0f32, 3.0f32, 4.0f32])
def vals() -> tensor[4, f32] = to_tensor([0.0f32, 2.0f32, 2.0f32, 0.0f32])
spline_mid = spline_eval(knots(), vals(), 2.0f32)
spline_m = spline_fit(knots(), vals())
```

```text
spline_mid = 2.75
spline_m = tensor(shape=[4], data=[0.0, -1.5, -1.5, 0.0])
```

The linear interpolant is flat at 2 between x = 1 and x = 3; the spline
bulges to 2.75 there because it keeps the second derivative continuous.

Queries outside `[xs[0], xs[m-1]]` return the nearest endpoint value, for a
knot vector that satisfies the requirement below.

### Knots must be strictly increasing

Both functions require every `xs[i+1] - xs[i]` to be greater than zero. A
knot vector that repeats a value or steps backwards has no natural cubic
spline through it, because a segment would have zero or negative width.
Both refuse such input: `spline_eval` returns NaN, and `spline_fit` returns
a vector of NaN.

```chelis-fragment
import Nautilus.Interpolation (spline_eval)

def reordered() -> tensor[4, f32] = to_tensor([0.0f32, 2.0f32, 1.0f32, 3.0f32])
def reordered_vals() -> tensor[4, f32] = to_tensor([0.0f32, 4.0f32, 1.0f32, 9.0f32])
unsorted_mid = spline_eval(reordered(), reordered_vals(), 1.5f32)
unsorted_low = spline_eval(reordered(), reordered_vals(), -1.0f32)
```

```text
unsorted_mid = NaN
unsorted_low = NaN
```

The requirement is on the sign of the gap, not its size: a gap of one f32
ulp is accepted, and a gap of minus one ulp is refused. An ill-conditioned
spline is still a spline, so these functions do not second-guess a knot
vector that is merely tightly spaced. Accepted is not the same as accurate,
and for a very small gap it is not even the same as finite, or as visibly
wrong. See the knot requirements below.

`unsorted_low` is the reason the check sits in both exports rather than in
the fit alone. The out-of-range arm returns `ys[0]` or `ys[m-1]` without
consulting the fitted second derivatives, so a NaN reaching it from
`spline_fit` would not have stopped it returning a plausible endpoint value
for a knot vector that has no spline.

Every `spline_eval` call refits the spline, an O(m^2) tridiagonal solve in
this implementation. Nautilus has no evaluator that takes a stored fit. For
many queries on the same knots, call `spline_fit` once and evaluate the
segment yourself: on `[xs[i], xs[i+1]]`, with `h = xs[i+1] - xs[i]` and
`t = x - xs[i]`,

    y = ys[i] + b*t + (M[i]/2)*t^2 + ((M[i+1] - M[i]) / (6*h))*t^3
    b = (ys[i+1] - ys[i]) / h - h * (2*M[i] + M[i+1]) / 6

which is the formula `spline_eval` uses, though it evaluates it in f64 and
returns f32. In f32 the two are not interchangeable at extreme knot
magnitudes, because `t^2` and `t^3` leave the f32 exponent range while the
coefficients they multiply are still in it, and the product can leave it even
when both factors are inside. A hand-rolled f32 version of this
formula drops the quadratic term for a gap near 1e-24, returning
`a + b*t` rather than the curve, and returns NaN for a gap near 1e-26. It also
breaks at the top of the range: `t^3` overflows f32 once `t` passes about
7e12, and `t` is the distance from the left knot, so how large the knots may
be depends on where the query sits in its segment. Compute it in f64 and
return f32, as `spline_eval` does, or keep the knots and the values at
ordinary magnitudes.
On the knots above, segment 1
(`h = 2`, `M = -1.5, -1.5`) gives `b = 1.5` and, at x = 2 (`t = 1`),
`2 + 1.5 - 0.75 = 2.75`, the `spline_eval` result.

Knot requirements:

- `xs` strictly ascending, as for `linear_interp_sorted`, and here it is
  enforced: a repeated or descending knot is refused, as described above.
  Merge duplicate knots before fitting rather than relying on a result.
- Two knots give the straight line through them; one knot gives its value
  everywhere.
- An accepted gap is used exactly as given, however small, so an
  ill-conditioned knot vector gives an ill-conditioned answer. Three outcomes
  are possible and the size of the gap alone does not tell you which:
  - a very large value: knots `[0, 1e-20, 1, 2]` with values
    `[0, 1, 2, 5]` give `1.6071428e19` at x = 0.5, and with a gap of 1e-31,
    `1.607143e30`;
  - a NaN: the same knots with a gap of 1e-38;
  - a plausible finite value that is simply wrong. This is the one you cannot
    detect. Scaling the knots, the values and the query by one factor must
    scale the result by that factor, so `[0, 1, 2, 3]` with `[0, 1, 4, 9]` at
    x = 1.5, which gives `2.2`, should give `2.2` times the factor. For a
    uniform gap it does, down to a gap of `2.6795e-31`. Below that it does
    not: scaled by 1e-31 the result is `2.5e-31`, 14% high.

  That threshold belongs to the solve rather than to the evaluation, and it
  depends on how many knots you have. The fitted system carries
  `2*(h[i-1] + h[i])` on its diagonal, and the solve's forward elimination
  reduces each one to `d[k] = 4 - 1/d[k-1]` in units of the gap, starting at
  4. The last interior pivot is therefore `3.75*h` for four knots, `3.7333*h`
  for five, and tends to `(2 + sqrt 3)*h`, about `3.7320508*h`. A pivot below
  1e-30 is replaced by 1.0, as `la_tridiag_solve` records on its own page, so
  the second derivatives come back the wrong size as soon as that last pivot
  falls under 1e-30.

  The boundary thus rises with knot count, from `2.5e-31` at three knots,
  where there is one interior pivot of `4*h`, through `2.6667e-31` at four,
  toward `1e-30` over `(2 + sqrt 3)`, which is `2.6794919e-31`. A gap of
  `2.6795e-31` is above that limit and is equivariant at every knot count
  tried, up to a thousand; the exact quotient is not, because it leaves no
  margin and nine knots there are already wrong.
  At a gap of `2.667e-31`, four knots are still equivariant while five, six
  and eight are not: all three collapse to the four-knot ratio `2.2` against
  correct ratios of `2.232143`, `2.223684` and `2.2253523`. At `2.6795e-31`
  all four counts are equivariant. For four knots specifically, `2.666e-31`
  gives `2.3125` times the factor, where one of the two interior pivots has
  been replaced, and below `2.5e-31`, where `4*h` crosses the same floor, both
  are replaced and the ratio settles at `2.5`. A non-uniform gap has no single
  threshold at all, because each interior knot carries its own diagonal.

  So what governs this is the gap, through that diagonal, rather than the
  magnitude of the knots. Apart from gaps under 1e-30, where the fit used to
  substitute a unit gap, this behaviour is the same before and after the
  ordering requirement: it is a property of fitting at tiny coordinate scales,
  not of the knot check.
- So a NaN does not by itself mean the knots were rejected. It means either
  that, or an accepted gap too small for f32 to carry the result through.
  Equally, a finite result is not a promise that the gap was large enough.
