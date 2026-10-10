`gamma_cdf` and `gamma_sf` test the standardised argument `x / scale` in f64,
the precision the body already evaluates it at. They used to test it in f32,
and when that quotient underflowed to zero the `xs <= 0` clause returned
exactly 0.0 -- discarding a lower tail f32 holds comfortably.
`gamma_cdf(1e-30, 0.5, 1e20)` returned `0.0` against a true `1.128379158e-25`
and now returns `1.1283791e-25`, 3.4e-8 relative (nautilus#165). **Values change** at those arguments; the signatures do not.

**A shape below 1 is what makes the discarded answer representable**, and it is
why the obvious reading of the witness is wrong. `P(a, x) ~ x^a / Gamma(a+1)`
as `x -> 0`, so at `a = 0.5` the answer is the square root of a quantity fifty
decades under f32's floor and lands twenty decades over it.
`gamma_cdf(1e-30, 1, 1e20)` is still `0.0`, and that is still correct:
`P(1, 1e-50)` is `1e-50`, which f32 cannot hold either way. A repair that
returned something non-zero at shape 1 would be wrong at exactly the parameters
a reader tries first.

**`chi_squared_cdf` was reachable too**, which the issue's own controls read as
impossible: it fixes `scale = 2`, so `x / 2` cannot underflow for a normal `x`.
It can for a subnormal one -- the smallest f32 subnormal halves to exactly 0.0,
because the quotient is the midpoint between zero and that subnormal and the tie
rounds to even. `chi_squared_cdf(1.4e-45, 1)` returned `0.0` against a true
`2.986794786e-23` and now returns `2.986795e-23`, 5.2e-8 relative. The adjacent subnormal, `2.8e-45`, halves to a non-zero value
and was correct before and after.

**The fix is a deletion.** `gammap_core` and `gammaq_core` already decide a
NaN, a `+inf` and a non-positive `x` at their own entry, in f64, and to the
same limits a guard in front of them would return, so the three f32 tests were
a second copy of those three decisions taken at a narrower precision than the
answer. Removing them is what makes the class structurally impossible rather
than one precision further away. Every degenerate answer is unchanged: a NaN
`x` or `scale` is NaN, `x <= 0` is 0.0 for the CDF and 1.0 for the survival
function, `x = +inf` is 1.0 and 0.0, and `x = +inf` with `scale = +inf` is
still NaN -- by the quotient now rather than by a guard.

The clause nautilus#140 settled is preserved as a statement about the f64
quotient: a finite `x` whose `x / scale` overflows lands on the same answer as
`x = +inf`. No pair of finite f32 arguments can reach it -- `3.4e38 / 1.4e-45`
is 2.4e83 -- so `gamma_cdf(1e38, 1, 1e-10)` is now computed by the continued
fraction rather than asserted by a guard, and is still 1.0.

`parity/check_gamma_accuracy.py` gained the rung that holds the repair: shapes
0.25, 0.5 and 0.75 at `scale = 1e20`, and the chi-squared subnormal at `df` 1
and 0.5. It is a separate block rather than a `SCALES` entry because the
gate's `x` walk cannot reach the region at any scale -- it places `x` within
twenty standard deviations of `shape*scale`, where the quotient is about
`shape` -- and because a fourth scale would multiply the whole grid for three
exports to reach one corner. The gate now enforces 1635 cases of 1682
measured, and its two new unit tests fail if a constant edit leaves the rung
looking intact while its quotient no longer underflows.

The two survival functions contribute no rows there, and that is a measurement
rather than a gap: their reference is `1 - P` with a `P` of at most 3.5e-13,
which is exactly 1.0 once f32 holds it, so such a row cannot fail. `gamma_sf`'s
behaviour at those arguments is pinned in `tests/distributions.ch` instead.
