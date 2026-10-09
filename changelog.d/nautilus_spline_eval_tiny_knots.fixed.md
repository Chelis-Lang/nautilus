`spline_eval`'s segment polynomial is now evaluated in f64 and returned as
f32. **Values change.** The public signature does not: this is an internal
working precision, not an f64 surface.

The offset into a segment is an absolute distance, not a position normalised
into `[0, 1]`, while the quadratic coefficient scales as `1/h` and the cubic
one as `1/h^2`. In f32 both ends of those products leave the exponent range
long before the product does, and it happens at **both** ends of the scale.

**Small knot magnitudes.** With the knots, the values and the query all scaled
by 1e-24, the offset is 5e-25 and its square falls below f32's 2^-150 flush
threshold, so the quadratic term became exactly zero and took all of the
curvature with it: `spline_eval` returned the segment polynomial's linear part
`a + b*t`, 14% low, finite, and indistinguishable from a correct answer. That
is **not** the chord through the bracketing knots, whose slope is 3 against
`b`'s 1.8; the chord gives `2.5e-24`, 14% **high**, so comparing against
`linear_interp_sorted` does not detect this. At 1e-26 and 1e-28 the residue the fit leaves in the
difference of second derivatives, divided by `6*h`, overflowed the cubic
coefficient to an infinity, and that infinity times the flushed cube of the
offset returned NaN.

**Large knot magnitudes.** The same powers saturate upward, and this half was
not in the original report. The cube of the offset leaves f32 once the offset
passes about 7e12. The rule is on the offset, not on the knot scale, and the
offset is the distance from the left knot, so which knot scale breaks depends
on where the query sits in its segment: a query landing on a knot has
`t = h` and failed from a knot scale bracketed by 6.98e12, which returned the
correct `2.792e13`, and 6.99e12, which returned an infinity, while a midpoint query has
`t = h/2` and lasted to roughly twice that. No single knot-scale boundary is
quoted here, because any one fixture's boundary understates it for the others.
A nanosecond epoch timestamp is above 1e18, well inside the affected range.
The offset is not the only route out of range: `c*t^2` can overflow with both
factors still inside it, so large values reach the same failure at ordinary
knots. `[0, 1000, 2000, 3000]` with values to 3.4e38, queried at a knot,
returned an infinity and now returns `3.4e38` exactly.

A cubic spline is scale equivariant, so `[0, 1, 2, 3]` with `[0, 1, 4, 9]` at
x = 1.5, which gives `2.2`, must give `2.2` times any scaling of all three.

| scale | before | after | reference |
|---|---|---|---|
| 1e-28 | NaN | `2.2e-28` | `2.2e-28` |
| 1e-26 | NaN | `2.2000003e-26` | `2.2e-26` |
| 1e-24 | `1.8999999e-24` | `2.2e-24` | `2.2e-24` |
| 2e13 | inf | `2.1999998` x scale | `2.2` x scale |
| 1e20 | NaN | `2.2` x scale | `2.2` x scale |

**Ordinary knot magnitudes also move, and goldens there will need
re-baselining.** No bound on the movement is offered, deliberately. The
absolute move scales with the data, and the relative move is unbounded
wherever the result is small next to the values around it, which is precisely
where the largest moves are: a query landing on a knot now returns that knot's
value exactly instead of a near-miss, so `[0, 0.1, 1, 5]` with
`[1, -2, 3, 0.5]` at x = 1.0 returns `3.0` where it returned `2.999998`, and a
fixture whose knot value is small beside its neighbours moves by a relative
2e-2 by the same mechanism. A maximum measured over any one set of fixtures is
a property of that sample rather than of this change, so sizing a tolerance
from one would be a mistake. The direction is usually toward the exact result
and sometimes away from it: `[0, 1, 2, 3]` with
`[-1.6156142, 1.9130057, -0.02419465, 5.8622055]` at x = 2.5 returned `2.0`
and now returns `1.9999999`.

f64 is what clears the failing rows. The same coefficients in f64 give
`2.2e-26` whether the polynomial is written expanded or in Horner form, and
rewriting it in Horner form while staying in f32 clears the 1e-24 row and
still returns an infinity at 1e-26 and 1e-28. Horner is used anyway, because
it forms no power of the offset on its own.

Evaluating in f64 does not rescue a fit that is already wrong. Once the solve's
last eliminated pivot falls below 1e-30, `la_tridiag_solve` replaces it with
1.0 and the second derivatives come back the wrong size. That pivot is
`4 - 1/d[k-1]` in units of the gap, so it is `3.75*h` for four knots and tends
to `(2 + sqrt 3)*h`, and the boundary therefore rises with knot count from
`2.5e-31` at three knots. Equivariance holds for every uniform gap at or above
`2.6795e-31`, which sits just above the limit `1e-30/(2 + sqrt 3)` =
`2.6794919e-31`; the margin matters, because at the exact quotient nine knots
already return `2.2253525` against a correct `2.2255154`. That replaces the
book's statement that no threshold could be given.

The book page also attributed the 1e-24 row to that pivot substitution; the
diagonal there is 4e-24, six orders above the floor, so the substitution never
fired and contributed nothing. The page now names the underflow for that row,
keeps the pivot floor for the gaps where it fires, and notes that
hand-evaluating the published segment formula in f32 is not equivalent to what
`spline_eval` does, since that formula is precisely the code this change
replaced.
