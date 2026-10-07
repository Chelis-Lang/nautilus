The regularized incomplete beta behind `beta_cdf`, `f_cdf`, `student_t_cdf` and
`binomial_cdf` is now evaluated in f64 and returned as f32. **Values change.**
The public signatures do not: this is an internal working precision, not an f64
surface.

`betai`'s front factor is
`exp(lgamma(a+b) - lgamma(a) - lgamma(b) + a*ln x + b*ln(1-x))`, whose exponent
is a difference of large quantities. At `a = b = 1e5` the individual log-gammas
are about 2.2e6, where `lgamma(2e6) = 2.70e7` has an f32 ulp of exactly 2.0 --
so one rounding in the largest term is an absolute error of 2 in the exponent,
a factor of `exp(2)` in the result. At `a = b = 1e6` the observed error was a
factor of 0.133 against `exp(-2.0) = 0.1353`, consistent to the digit.

**This was not a convergence failure**, which is what nautilus#143 originally
reported and what its title still says. At `a = 1e5` the continued fraction
converged in 162 of its 200 iterations and `beta_cdf(0.5, 1e5, 1e5)` was still
38% wrong; raising the budget a hundredfold left the value unchanged. The budget
does not bind until `min(a, b)` passes about 3.4e5. The error was also not
monotone in the parameters -- 1.1e-1 at 5e4, 2.4e-2 at 6e4, 3.8e-1 at 1e5,
9.4e-2 at 1.2e5 -- which is the signature of a rounding rather than of a
shortfall. A corrected mechanism is recorded on the issue.

Three changes:

- **The incomplete beta evaluates in f64.** This is the whole of the accuracy
  gain.
- **The continued fraction's budget is 4096 rather than 200**, spent through
  three levels of chunking: 16 single steps per chunk, 16 chunks per block, 16
  blocks per driver call. Peak depth is about 48 frames rather than 4096.
  `chelis eval --file` aborts the process outright when a recursion outruns its
  stack (chelis#2471, no tail-call elimination, with the frame budget shrinking
  as the body grows), so without the chunking this budget could not be spent in
  that lane at all. The chunking changes no arithmetic.
- **`betai` takes the caller's own `1 - x` instead of recovering it by
  subtraction.** Every call site can form it exactly, and three of the four
  were losing it:
  - `student_t_cdf`'s `df/(df+t*t)` was exactly 1.0 from `df = 2^24 =
    16777216` upward, because `ulp(2^24) = 2` makes `df + 1` a tie that rounds
    back to `df`. `betai`'s `x >= 1` guard then returned 1.0 and the continued
    fraction was never entered. The answer was exactly 0.5 -- the same value
    the function returns at `t = 0`, so nothing about it looked wrong.
    `student_t_cdf(1.0, 1e8)` was 0.5 and is 0.8413447 against a true
    0.84134475.
  - `f_cdf`'s `u = d1*x/(d1*x+d2)` saturated the same way for a small
    denominator df. `f_cdf(1.0, 1e8, 1.0)` was 1.0 against a true 0.317.
  - `binomial_cdf`'s `1-p` was exactly 1.0 for tiny `p`, and lost its digits
    for `p` near 1. `binomial_cdf(0, 1e6, 1e-8)` was 1.0 against a true 0.990,
    and `binomial_cdf(999999, 1e6, 0.99999994)` was wrong by 84%.

**A result outside [0, 1] is now NaN.** A regularized incomplete beta lies in
[0, 1], so a value outside it is not an approximation of anything. Only the
exhausted-budget extreme reaches this: a sweep of 3024 `(a, b, x)` points with
`min(a, b) <= 1e7` produced no out-of-range value, while
`beta_cdf(0.5, 1e12, 1e12)` produced -0.416 and is now NaN. The guard is
deliberately **not** a convergence test: an exhausted budget still returns its
value wherever that value is in range, because near the budget the partial value
is usually the better answer. That is the conclusion the gamma family reached
for its own continued fraction, and a test pins both halves.

## What changed, measured

Through `chelis eval` on the real compiler, references from scipy's `betainc`
taken at the f32 value of every argument:

- **885 cases** across the four exports: worst relative error **5.7e-7**, no
  case above 1e-5, no unexpected NaN. 487 of those have a reference f32 can
  carry and is not exactly 1.0; the other 398 are a reference below 1e-30
  (returned as ~0, max 7.9e-31) or an exact 1.0 (returned as 1.0), all correct
  by inspection.
- **`beta_cdf(0.5, a, a)` is exactly 0.5 by symmetry**, so it needs no
  reference. Error is 0 at 1e2, 1e3, 1e6 and 1e7, 3.0e-8 at 1e4 and 1e5, and
  1.5e-7 at 1e8. It was 8.5e-4 at 1e3, 38% at 1e5, 87% at 1e6 and `-inf` at 1e8.
- **The old code cannot evaluate that grid at all.** On `origin/main` the same
  885-case probe dies with `fatal runtime error: stack overflow, aborting`.
- **`t_p_value_upper` / `t_p_value_two_sided`** over the 210-point grid
  `docs/book/src/stats/testing.md` already documents: worst relative error
  **7.3e-8**, against 4.4e-5 before, and it no longer grows with `df` (6.3e-8 at
  `df = 1`, 3.9e-8 at 30, 4.9e-8 at 100; no row above 1e-6). The `df` dependence
  that page recorded *was* this defect, since the log-gammas grow with `df`.
- **Which values move.** On the 567-case range the old code can also evaluate
  (`min(a, b) <= 2000`), 299 values are bit-identical and 268 change. Of the 263
  changed values with a usable reference, **261 are closer to it, 2 are further**
  -- `beta_cdf(0.3, 2, 3)` from 5.45e-8 to 6.04e-8 and
  `binomial_cdf(0, 10, 0.01)` from 2.54e-8 to 2.99e-8, both one-ulp moves. The
  remaining 5 have a reference below 1e-30.
- **scipy parity: 206 passed, 0 failed**, goldens unchanged.

## Residual, stated rather than hidden

The budget still runs short above `min(a, b)` of roughly 1e9, and between there
and 1e12 the family returns an in-range value that is wrong without saying so:
8.0e-6 at 1e9, 1.2e-3 at 1e10, 21% at 1e11. The `[0, 1]` guard does not catch
those, and nothing else does either. `docs/book/src/appendix/precision.md`
carries the table.

## Test-lane note

Nine tests are added. **Seven fail against the unpatched module**; the two that
pass -- the non-positive-parameter guards and the `x = 0` / `x = 1` / Beta(1,1)
boundaries -- pin pre-existing behaviour the f64 path could have broken, and are
regression cover rather than detectors. All nine run in `chelis test`, whose
worker holds about 500 frames, so they do not observe the `chelis eval` abort;
`docs/UPSTREAM_BUGS.md` and `tests_blocked/README.md` record that probe as
manual, because a probe of it kills the harness that would report the verdict.

Addresses nautilus#143.
