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

**Indexed on the LARGE parameter**, because for `student_t_cdf` the small one is
always 0.5 and a range stated in terms of it would describe nothing. Measured
through `chelis eval` by the new `scripts/check_beta_accuracy.py`, which is the
oracle for every number here and fails the build if one drifts:

| export | governing parameter | holds to | worst measured inside |
|---|---|---|---|
| `beta_cdf` | `max(a, b)` | 3e8 | 4.8e-7 |
| `f_cdf` | `max(d1, d2)` | 3e8 | 9.3e-7 |
| `student_t_cdf` | `df` | 3e8 | 2.9e-7 |
| `binomial_cdf` | `n` | 3e8 | 1.9e-7 |

Beyond it the error grows and nothing in the result says so. `beta_cdf(0.5,a,a)`
is 8.0e-6 at 1e9, 1.2e-3 at 1e10, 2.1e-1 at 1e11 and NaN at 1e12;
`beta_cdf(0.5, 3e38, 3e38)` returns a confident **1.0** against a true 0.5, which
the NaN guard does not catch. `student_t_cdf` degrades earlier and harder --
1.7e-6 at `df = 1e9`, 3.8e-4 at 1e12, **51%** at 1e14, and exactly 0.5 from 1e16
-- so above `df` of about 1e9, use `normal_cdf`.

An earlier revision of this entry claimed a flat "~6e-7" bound indexed on
`min(a, b)`. Both halves were wrong: `f_cdf(0.5, 1e8, 0.5)` errs 9.3e-7 and
`student_t_cdf(-1, 1e10)` errs 1.3e-6, and both have a small parameter of 0.5 or
less, so they sat inside the band as it was written.

## What changed, measured

Through `chelis eval` on the real compiler, references from SciPy's `betainc`
taken at the f32 value of every argument, and from the symmetry and
standard-normal limits where no library can adjudicate:

- **`beta_cdf(0.5, a, a)` is exactly 0.5 by symmetry**, so it needs no
  reference: absolute error 0 at 1e2/1e3/1e6/1e7, 3.0e-8 at 1e4 and 1e5,
  1.5e-7 at 1e8. It was 8.5e-4 at 1e3, 38% at 1e5, 87% at 1e6, `-inf` at 1e8.
- **The old code cannot evaluate a large grid at all** -- an 885-case probe dies
  on `origin/main` with `fatal runtime error: stack overflow, aborting`.
- **`t_p_value_upper` / `t_p_value_two_sided`**: worst relative error 7.3e-8
  against 4.4e-5 before, and no longer growing with `df` (6.3e-8 at `df = 1`,
  3.9e-8 at 30, 4.9e-8 at 100). The `df` dependence
  `docs/book/src/stats/testing.md` recorded *was* this defect, since the
  log-gammas grow with `df`.
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
single threshold, and a bisection for one lands wherever it starts.

Addresses nautilus#143.
