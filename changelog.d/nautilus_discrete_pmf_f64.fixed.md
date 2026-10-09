`poisson_pmf` and `binomial_pmf` now evaluate their log-space bodies in f64 and
return an f32. **Values change.** The public signatures do not: this is an
internal working precision, not an f64 surface (nautilus#146).

Both are `exp` of a log-space expression whose dominant term is
`ln(Gamma(k + 1)) = ln(k!)`. An absolute error there is a *multiplicative* error
in the answer, and `ln(k!)` grows without bound: 1.05e6 at `k = 1e5`, 1.74e9 at
`n = 1e8`, where one f32 rounding is an absolute error of 128 in an exponent.
`binomial_pmf` is worse again because `ln C(n, k)` is a difference of three
log-factorials, so its f32 error was bounded by the largest of them rather than
by the answer, and the three terms rounded independently.

On top of that, `k + 1` and `n - k` lost their low bits above `k = 2^24`, where
the spacing of f32 values at 5e7 is 4, so the normalising constant was computed
for the wrong factorial.

| call | was | now | reference (f32) |
|---|---|---|---|
| `binomial_pmf(5e7, 1e8, 0.5)` | `inf` | 7.978849e-5 | 7.978846e-5 |
| `binomial_pmf(2e7, 4e7, 0.5)` | 1.0 | 1.261566e-4 | 1.2615662e-4 |
| `binomial_pmf(1e5, 2e5, 0.5)` | 2.0549577e-3 | 1.7841219e-3 | 1.7841219e-3 |
| `binomial_pmf(1e3, 2e3, 0.5)` | 1.7815081e-2 | 1.783901e-2 | 1.783901e-2 |
| `poisson_pmf(5e7, 5e7)` | 1.0 | 5.6418965e-5 | 5.641895e-5 |
| `poisson_pmf(1e5, 1e5)` | 1.3267804e-3 | 1.2615653e-3 | 1.2615653e-3 |
| `poisson_pmf(1e3, 1e3)` | 1.2612753e-2 | 1.2614612e-2 | 1.2614612e-2 |

`inf` and 1.0 are not probabilities, which is the cheapest way to notice this
but not its boundary. **The error was continuous in the parameter, not a cliff
at 2^24** -- 15% at `binomial_pmf(1e5, 2e5, 0.5)` and 59% at
`binomial_pmf(1e6, 2e6, 0.5)`, both well below it -- so widening only `k + 1`
and `n - k`, which is what the issue first proposed, would have left errors of
10.3% and 7.2% at `k = 1e5` behind, both on the low side. Two tests in
`tests/distributions.ch` sit below 2^24 specifically to kill that repair, and a
third pins `n - k` at 16777217, the first odd integer above 2^24 and so not an
f32 value at all.

Over the 582 cases of `parity/check_pmf_accuracy.py`, which span the count
parameter from 0.5 to 1e9 and thirteen values of `p`, the new form is at least
as accurate as the old at every case and strictly better at 577 of them. The
documented range --

> relative error below 2e-6 for `lambda` up to 1e8 and `n` up to 2e8, at every
> `p`, for any result f32 can hold as a normal number

-- is now gated by `parity/check_pmf_accuracy.py` on every CI run rather than
asserted in prose. Past the ceiling the error is bounded by one f64 ulp of
`ln(k!)`, 3.81e-6 at a count of 1e9, where the gate measures 3.8e-6 for
`poisson_pmf` and 3.5e-6 for `binomial_pmf`.

The captured `ppmf` and `bpmf` values in
`docs/book/src/distributions/discrete.md` move with the change, and
`poisson_pmf(3, 2.5)` and `binomial_pmf(3, 10, 0.3)` now return the correctly
rounded f32 where they previously did not.

**`poisson_cdf` was not fixed by this and was not meant to be.** It routes
through `gamma_sf`, whose incomplete-gamma lane was f32 when this entry was
written, so there was nowhere for a widened `k + 1` to go. That was a much
larger effect than the lost `+ 1`: `poisson_cdf(5e7, 5e7)` returned 6.731102e-4
against a true 0.50003761, where the `+ 1` accounted for only 0.011% of it.
nautilus#152 has since moved that lane to f64 and formed `k + 1` there, so the
call now returns 0.50003755 and both effects are gone. This paragraph is kept
rather than deleted because the reasoning it records -- that fixing the PMFs
could not reach the CDF -- is why the two were separate changes.
