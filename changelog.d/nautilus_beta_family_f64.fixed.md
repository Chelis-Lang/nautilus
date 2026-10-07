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
38% wrong; raising the budget a hundredfold left the value unchanged. The error
was also not monotone in the parameters -- 1.1e-1 at 5e4, 2.4e-2 at 6e4, 3.8e-1
at 1e5, 9.4e-2 at 1.2e5 -- which is the signature of a rounding rather than of a
shortfall. A corrected mechanism is recorded on the issue.

Four changes:

- **The incomplete beta evaluates in f64.** This is the whole of the accuracy
  gain.
- **The continued fraction's budget is 4096 rather than 200**, spent through
  three levels of chunking: 16 single steps per chunk, 16 chunks per block, 16
  blocks per driver call, so peak depth is 48 frames rather than 4096.
  `chelis eval --file` aborts the process outright when a recursion outruns its
  stack (chelis#2471, no tail-call elimination, with the frame budget shrinking
  as the body grows), so without the chunking this budget could not be spent in
  that lane at all. The chunking changes no arithmetic: a review round compared
  it against a flat f64 recursion and against an independent 7-by-7
  decomposition, over 320 consecutive convergence counts and 17 structural high
  counts, and found it bit-identical in every case.
- **`betai` takes the caller's own `1 - x`** instead of recovering it by
  subtraction. Every call site can form it exactly, and three of the four were
  losing it:
  - `student_t_cdf`'s `df/(df+t*t)` was exactly 1.0 from `df = 2^24 =
    16777216` upward, because `ulp(2^24) = 2` makes `df + 1` a tie that rounds
    back to `df`. `betai`'s `x >= 1` guard then returned 1.0 and the continued
    fraction was never entered. The answer was exactly 0.5 -- the same value
    the function returns at `t = 0`, so nothing about it looked wrong.
    `student_t_cdf(1.0, 1e8)` was 0.5 and is 0.8413447 against a true
    0.84134475. This moves the saturation to about `2^53`; it does not remove
    it, and the range below says where to stop trusting the result.
  - `f_cdf`'s `u = d1*x/(d1*x+d2)` saturated the same way for a small
    denominator df. `f_cdf(1.0, 1e8, 1.0)` was 1.0 against a true 0.317.
  - `binomial_cdf`'s `1-p` was exactly 1.0 for tiny `p`, and lost its digits
    for `p` near 1. `binomial_cdf(0, 1e6, 1e-8)` was 1.0 against a true 0.990,
    and `binomial_cdf(999999, 1e6, 0.99999994)` was wrong by 84%.
- **`binomial_cdf` forms `n - k` and `k + 1` in f64 too.** In f32 the `+ 1`
  vanishes once `k` reaches 2^24 -- `ulp(5e7)` is 4 -- which made
  `binomial_cdf(5e7, 1e8, 0.5)` the exactly-symmetric `I(0.5; 5e7, 5e7)` and
  threw away the 4e-5 offset that is the entire answer there. That was an 8e-5
  relative error at an ordinary sample size, found by the new accuracy oracle
  rather than by review.

## A value outside [0, 1]

A regularized incomplete beta lies in [0, 1], and two different things produce a
value outside it:

- A **converged** continued fraction can overshoot by a rounding, because the
  front factor's exponent is a difference of log-gammas. For a small `a` with a
  large `b`, where the true value is 1.0, it lands up to about four f32 ulps
  above -- measured 4.7e-7 at `a = 1e-7, b = 1e8`, converging in one to four
  iterations. That is the right answer with a rounding on it, and is **clamped
  to the boundary**.
- An **abandoned** one that lands outside has produced nothing:
  `beta_cdf(0.5, 1e12, 1e12)` reaches -0.416 that way, and becomes **NaN**.

Convergence is the separator rather than a tolerance, because the overshoot
grows with the cancellation and no fixed epsilon bounds it. An exhausted budget
is **not** by itself a NaN: wherever its value is in range it is returned,
because near the budget the partial value is usually the better answer -- the
conclusion the gamma family reached for its own continued fraction. Four tests
pin the whole rule.

An earlier revision of this change used a bare `v < 0 || v > 1`. A review round
showed that discarded correct answers: `f_cdf(1.0, 1e-20, 10.0)` returned
0.9999989 on the previous version, correct to 1.1e-6, and NaN under that guard.
A threshold-adjacent probe found 47 such inputs. The claim that accompanied it --
"only the budget-exhausted extreme reaches this" -- was false, and is gone.

## The range this holds over

> **Relative error below 2e-6 when every parameter is at least 1 and the largest
> is at most 1e8.**

| export | parameters |
|---|---|
| `beta_cdf` | `a`, `b` |
| `f_cdf` | `d1`, `d2` |
| `student_t_cdf` | `df` (its other beta parameter is structurally 0.5) |
| `binomial_cdf` | `n` (`n - k` and `k + 1` are at least 1 for any legal `k`) |

**No "worst measured" figure is published, deliberately.** Four rounds of review
falsified four successive versions of one:

- indexed on `min(a, b)`, which for `student_t_cdf` is permanently 0.5 and so
  described nothing;
- a 3e8 ceiling never evaluated at its own value, with grids a decade short and a
  unit test that accepted a case a decade down;
- a 1e8 ceiling false on the continued fraction's **branch threshold**
  `x = (a+1)/(a+b+2)`, a locus named elsewhere in this very change set and still
  not sampled;
- and then a figure understated by a parameter value sitting between two listed
  ones (`f_cdf` at `d2 = 2`, where the beta parameter is exactly 1).

Each refinement raised the number -- 5.7e-7, 1.21e-6, 1.45e-6 -- and that is not
a sequence of four mistakes but one fact about the quantity: **the error is
rounding-driven, so it oscillates in every parameter and its maximum over a
continuum is not reachable by evaluating finitely many points.** An independent
sweep of 7,652 adversarial cases found 1.45e-6 at a point 0.2% off the worst any
derived locus gives.

So the published contract is the **bound with headroom**, which a finite check can
defend, and `parity/check_beta_accuracy.py` is the record for the measurement.
That script now derives its hard cases rather than listing them -- the branch
threshold per parameter pair (`t^2 = 3df/(df+2)` for `student_t_cdf`,
`p* = (k+1)/(n+2)` for `binomial_cdf`, the inverted `u` for `f_cdf`), a
neighbourhood scaled by the distribution's own standard deviation rather than a
percentage, the mid-range region via `betaincinv`, and the hardest corner any
review has found. Five tests pin that coverage, including one for the locus,
which previously had none while the ceiling and floor each had one.

## What changed, measured

Through `chelis eval` on the real compiler, references from SciPy's `betainc`
taken at the f32 value of every argument, and from the symmetry and
standard-normal limits where no library can adjudicate:

- **`beta_cdf(0.5, a, a)` is exactly 0.5 by symmetry**, so it needs no
  reference: absolute error 0 at 1e2/1e3/1e6/1e7, 3.0e-8 at 1e4 and 1e5,
  1.5e-7 at 1e8. It was 8.5e-4 at 1e3, 38% at 1e5, 87% at 1e6, `-inf` at 1e8.
- **The old code cannot evaluate a large grid at all** -- an 885-case probe dies
  on `origin/main` with `fatal runtime error: stack overflow, aborting`.
- **`t_p_value_upper` / `t_p_value_two_sided`**: over a 406-point grid, worst
  relative error **1.2e-7** against 4.4e-5 before, and **no longer growing with
  `df`** (1.15e-7 at `df = 1`, 9.1e-8 at 2, 6.7e-8 at 10, 4.9e-8 at 100), with no
  row above 1e-6. The `df` dependence `docs/book/src/stats/testing.md` recorded
  *was* this defect, since the log-gammas grow with `df`. An earlier revision of
  this entry said 7.3e-8, from a 210-point grid; a denser grid raised it, so the
  flat-in-`df` shape is the robust claim and the digit is indicative. Nothing in
  the repo pins this sweep.
- **Which values move.** On the 567-case range the old code can also evaluate
  (its small parameter at most 2000), 299 values are bit-identical and 268
  change; of the 263 with a usable reference, **261 are closer to it and 2 are
  further**, both by one ulp.
- **scipy parity: 206 passed, 0 failed**, goldens unchanged.
- **The C lane**: a separate package builds against this one through host
  lowering, links, runs, and agrees with the eval lane on every value --
  including the NaN. `chelis reef build` does not enter host lowering, so it was
  no evidence at all about a consumer (nautilus#125 is that class in this repo).
  `scripts/check_beta_c_lane.py` is now that oracle, in CI.

## Iteration counts, f32 and f64

These are easy to mix up and were mixed up: the counts above for `origin/main`
are **f32**, and the shipped code's are **f64**. At the symmetric point the f64
counts are 72 / 156 / 337 / 726 / 1564 at `a` = 1e4 / 1e5 / 1e6 / 1e7 / 1e8,
growing as the cube root. The f32 counts are 64 / 162 / 261 / 542 / 1213. The
f32 budget of 200 first falls short near `a = 1.7e5` and is consistently short
only past about 4.2e5 -- the f32 count is **not monotone** in `a`, so there is no
single threshold, and a bisection for one lands wherever it starts. Both figures
are grid-dependent: they come from a step-500 scan, and a coarser step-5000 scan
reads the first shortfall as 3.15e5. Two bisections during review produced 3.45e5
and 3.074e5, both artifacts of the same non-monotonicity.

Addresses nautilus#143.
