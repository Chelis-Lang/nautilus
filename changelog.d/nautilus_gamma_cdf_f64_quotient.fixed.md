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
`P(1, 1e-50)` is `1e-50`, which f32 cannot hold either way. At shape 1 and
above the answer is at most the quotient itself, and a quotient that
underflowed in f32 is at most half f32's smallest subnormal, so f32 carries
none of it anywhere in that half of the class. One argument in it nevertheless
returns non-zero: at exactly that half-subnormal quotient,
`chi_squared_cdf(1.4e-45, 2)` returns the smallest subnormal, where the exact
`7.0064923e-46` sits `2.5e-91` below the 0-to-subnormal midpoint. **Both
answers are 100% relative error**, since f32 has no value between them, so
this is a rounding direction at an unrepresentable quantity rather than a lost
answer -- and it is lane-dependent, the value coming from `exp(log(t))` landing
just above the tie. Pinned to the behaviour in `tests/distributions.ch`.

**`chi_squared_cdf` was reachable too**, which the issue's own controls read as
impossible: it fixes `scale = 2`, so `x / 2` cannot underflow for a normal `x`.
It can for a subnormal one -- the smallest f32 subnormal halves to exactly 0.0,
because the quotient is the midpoint between zero and that subnormal and the tie
rounds to even. `chi_squared_cdf(1.4e-45, 1)` returned `0.0` against a true
`2.986794786e-23` and now returns `2.986795e-23`, 5.2e-8 relative. That is one
`x`, but every `df` below about 3 at that `x`, and the named witness is the
mild one: at `df = 0.1` the same argument discarded `0.005674625` -- a 0.57%
probability returned as exactly zero. The adjacent subnormal, `2.8e-45`,
halves to a non-zero value and was correct before and after.

**The fix is a deletion.** `gammap_core` and `gammaq_core` already decide a
NaN, a `+inf` and a non-positive `x` at their own entry, in f64, and to the
same limits a guard in front of them would return, so the three f32 tests were
a second copy of those three decisions taken at a narrower precision than the
answer. Removing them is what makes the class structurally impossible rather
than one precision further away. Every degenerate answer on the `x` and
`scale` axes is unchanged: a NaN `x` or `scale` is NaN, `x <= 0` is 0.0 for the
CDF and 1.0 for the survival function, `x = +inf` is 1.0 and 0.0, and
`x = +inf` with `scale = +inf` is still NaN -- by the quotient now rather than
by a guard.

**The `shape` axis is not unchanged at one value, and it is worth stating
rather than leaving to be discovered.** A NaN `shape` already aborts the
process at ordinary arguments on both lanes -- `log_gamma` traps, which
nautilus#150 tracks as the surviving degenerate-argument trap -- and the
removed f32 guards were incidentally shielding that trap at the three
`(x, scale)` pairs where the f32 quotient over- or underflowed. So
`gamma_cdf(1.4e-45, NaN, 2)` returned `0.0` and now aborts, in six
(function, pair) combinations. That widens a tracked abort inside a parameter
value which already aborts; putting a guard back to hide it would reinstate
the defect this change removes. The `shape = +inf` rows move the other way and
become consistent: they returned 0.0 or 1.0 at those same three pairs and now
return the NaN they already returned everywhere else.

The clause nautilus#140 settled is preserved as a statement about the f64
quotient: a finite `x` whose `x / scale` overflows lands on the same answer as
`x = +inf`. No pair of finite f32 arguments can reach it -- `3.4e38 / 1.4e-45`
is 2.4e83 -- so `gamma_cdf(1e38, 1, 1e-10)` is now computed by the continued
fraction rather than asserted by a guard, and is still 1.0.

`parity/check_gamma_accuracy.py` gained the rung that holds the repair: shapes
0.01, 0.05, 0.25, 0.5 and 0.75 at `scale = 1e20` in both directions, and the
chi-squared subnormal at `df` 0.02, 0.1, 0.5 and 1. It is a separate block rather than a `SCALES` entry because the
gate's `x` walk cannot reach the region at any scale -- it places `x` within
twenty standard deviations of `shape*scale`, where the quotient is about
`shape` -- and because a fourth scale would multiply the whole grid for three
exports to reach one corner. The gate now enforces 1655 cases of 1702
measured, and its three new unit tests fail if a constant edit leaves the rung
looking intact while its quotient no longer underflows, or empties either
tail.

**The survival functions lose too, and the first version of this change said
they could not.** That claim took a maximum measured over the rung's own shape
floor -- `P <= 3.5e-13` at shapes 0.25 and above, where `1 - P` is exactly 1.0
in f32 whichever route computes it -- for a bound on the class. `P` grows as
`x^shape`, so a small enough shape lifts it above f32's resolution at 1.0,
about 6e-8, and then the upper tail is resolvable and the f32 guard destroyed
it as well: `gamma_sf(1e-30, 0.01, 1e20)` returned `1.0` against a true
`0.6819677`, a relative error of **0.47**, and `chi_squared_sf(1.4e-45, 0.02)`
returned `1.0` against a true `0.6444290`, a relative error of **0.55**. A
red-team mutant that reinstated the f32 guards in `gamma_sf` alone passed all
753 tests, the C lane, the parity goldens and the accuracy gate; against the
rung as it now stands it fails the gate at nine rows and the test suite at one.

There is no shape threshold to state, because the boundary moves with the
quotient: at `x / scale` of 1e-50 the survival function differs from 1.0 up to
shape 0.15 and is exactly 1.0 from 0.16, and at 1.4e-65 it differs only up to
0.11. So the rung carries both regimes -- 0.01 and 0.05, where all four exports
resolve, and 0.25, 0.5 and 0.75, where only the two lower tails do -- and a
unit test fails if any one of the four loses its last usable row.
