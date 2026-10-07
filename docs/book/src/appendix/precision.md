# Precision Guide

Nautilus functions operate in f32 (IEEE 754 single precision), providing
approximately 6-7 significant decimal digits. `Nautilus.Special` is the
exception: its functions are generic over the `{f32, f64}` dtype set and can be called
at f64.

**The table below is an f32 table, and f64 does not scale it by a constant.**
Six functions (`gamma`, `log_gamma`, `beta`, `lbeta`, `ellipk`, and `ellipe`)
are limited by f32 rounding rather than by their own coefficients, so at f64
they land far below whatever their row says. The rest are limited by their
approximations and improve by less, by amounts that differ per function and per
argument. The `bessel_y1` figure below is a single measurement near a
branch boundary. Measure the argument range you care about.

Treat the table as an f32 guide. It has no figure for `beta` or `lbeta`, and
`bessel_y1` errs by about 1.2e-4 at either dtype just below its large-x seam
at x = 7.5, well away from any zero.

Two cases merit separate guidance:

- Chelis's `erf` and `erfc` builtins are correctly rounded at f32 and f64.
  `erfc` computes the positive tail directly, avoiding cancellation in
  `1 - erf(x)`.
- `airy_ai` and `airy_bi` above x = 5 use only the leading asymptotic term and
  gain nothing from f64 there; the two dtypes agree to three digits. Below
  x = 5 f64 is far better.

## Precision by function family

| Family | Typical relative error | Notes |
|---|---|---|
| Chelis `erf`, `erfc` | correctly rounded | Builtins, not Nautilus exports |
| `erfinv` | ~1e-8 | Acklam rational approximation via `norminv` |
| `gamma` | ~1e-7 | Lanczos (g=7) with reflection |
| `log_gamma` | ~1e-9 | Lanczos (g=7) with reflection |
| `digamma` | ~1e-7 | Recurrence + asymptotic (x >= 6) |
| `trigamma` | ~1e-6 | Recurrence + asymptotic (x >= 6) |
| `ellipk`, `ellipe` | ~1e-8 | AGM recurrence (quadratic convergence) |
| `bessel_j0`, `j1` | ~1e-5 near zeros | Rational polynomial + large-x trig |
| `bessel_y0` | ~1e-5 near zeros | Rational + log-singularity |
| `bessel_y1` | ~1e-5 near zeros | Large-x branch from x = 7.5; ~1.2e-4 absolute just below it |
| `bessel_i0`, `i1` | f32 | Polynomial + asymptotic, crossover 3.75 |
| `bessel_k0`, `k1` | f32 | Polynomial/log + asymptotic, crossover 2.0 |
| `airy_ai`, `airy_bi` | f32 for \|x\| <= 5 | See large-negative-x note below |
| Distribution CDFs | ~1e-5 to 1e-7 | Depends on underlying special functions |
| Beta-family CDFs | below 2e-6 over a stated range | `beta_cdf`, `f_cdf`, `student_t_cdf`, `binomial_cdf`; incomplete beta evaluated in f64. **The range matters** — read the note below before relying on a figure |
| `normal_cdf` | sub-ulp standardized; grows with the shift, see the tail note below | Chelis `standard_normal_cdf` on `(x-mean)/std` |
| `normal_inv_cdf` | ~1e-7 | Acklam rational via `erfinv` |

## Known precision issues

### The normal CDF's left tail depends on how you parameterise it

`normal_cdf` and `normal_cdf_t` call Chelis's `standard_normal_cdf` on the
standardized point `w = (x - mean) / std`. The builtin holds about 1.5 units in
the last place, but Nautilus rounds `w` before the builtin sees it, and §12.3 of
the Chelis `correctly_rounded_math` design note shows a relative error `d` in
that argument is amplified to about `w^2 d` in `Phi`. So the error of these
three-argument entry points depends on whether the quotient is exact:

| parameterisation | worst over `w` in [-12.6, -3] |
|---|---|
| `mean = 0`, `std = 1` | below 1 ulp |
| exactly representable shift, power-of-two scale | below 1 ulp |
| `mean = 0.2`, `std = 1.4` | order 10^2 ulp |

Measured at f32 against mpmath at 60 decimal digits, with the reference taken on
the exact real quotient of the f32 inputs.

The first two rows are not merely well-sampled, they are **structural**: for
`mean = 0, std = 1` the quotient is `x` itself, and for an exactly representable
shift with a power-of-two scale both the subtraction and the division are exact,
so no argument error exists to amplify and all that remains is the builtin's own
accuracy. The third row has a real argument error of about half an ulp, which
`w^2` amplifies; enumerating every f32 in the interval puts its worst case near
215 ulp. Size a tolerance from that mechanism -- it grows with `|w|` -- rather
than from any single sampled figure.

The residual is inherent to the `(x, mean, std)` signature, not to the builtin:
standardize first if you need the stable figure.

For scale, the previous `0.5 * (1 + erf(z))` spelling returned **exactly zero**
for every `w <= -6` at all three parameterisations, because its absolute error
was about `0.5 * ulp(1.0)` however accurate `erf` was.

### Bessel function zeros

`bessel_j0`, `bessel_j1`, `bessel_y0`, and `bessel_y1` all use rational
polynomial approximations that are most accurate away from function
zeros. Near zeros (e.g., j0 near x=2.4048, j1 near x=3.8317), the
absolute error can reach ~1e-5 because the function value itself is
near zero while the approximation error is roughly constant in relative
terms. This is inherent to f32 polynomial evaluation.

### Airy functions at large negative x

`airy_ai` uses a power series for |x| <= 5 and an exponential asymptotic
for x > 5. For large negative x, only the power series is available (no
asymptotic oscillatory branch is implemented). The function enters an
oscillatory regime for x < 0 and the power series degrades for |x| much
larger than 5. `airy_bi` has the same limitation but is less affected
because it grows exponentially for positive x where the asymptotic
branch covers it.

### Cancellation in subtraction-heavy expressions

Any computation involving subtraction of nearly-equal f32 values will
suffer catastrophic cancellation. This affects:

- `cosine_distance` when vectors are nearly parallel (1 - sim near 0)
- `variance_vec` for data with very small variance relative to the mean
- `gamma_cdf` for extreme shape/scale ratios

`gamma_cdf` has a second, unrelated limit at large `shape`. Its power series
accumulates in f32 across a number of terms that grows with `shape`. Relative
error against the regularised incomplete gamma at 60 decimal digits, measured at
`x = shape`: 1.9e-6 at `shape = 100`, 2.8e-4 at 1000, 6.5e-4 at 2000, 1.6e-3 at
2338, 16% at 20000 and 26% at 30000. Nothing signals the transition from a
converged value to an abandoned one, which at `x = shape` happens at
`shape = 2339` and at the branch's worst `x` -- just below `shape + 1` -- at
`shape = 2311`. `chi_squared_cdf(x, df)` inherits it at `df / 2` and
`poisson_cdf` at `shape = k + 1`.

The sharpest form of this is `1 - cdf` for an upper tail. The subtraction
carries absolute error of about `0.5 * ulp(1.0)` -- 6e-8 in f32 -- however
accurate the CDF is, so it returns exactly `0.0` once the true tail falls
below that, and carries no significant digits for some way above it. Do not
write it. The upper tail is available directly: `normal_cdf(neg(z), 0, 1)` and
`student_t_cdf(neg(t), df)` by symmetry, and `gamma_sf` and `chi_squared_sf` as
their own functions. Every *upper-tail and two-sided* p-value in
`Nautilus.Testing` uses one of those; the two `_lower` functions take the CDF
directly, which is already the tail they want. nautilus#137 is the instance
that produced this paragraph; nautilus#113 is its left-tail twin.

Two cases of `1 - exp(..)` in the CDFs themselves have the same shape at the
*left* edge, and are equally total rather than merely imprecise:
`exponential_cdf(1e-8, 1.0)` and `weibull_cdf(1e-8, 1.0, 1.0)` both return
**exactly 0.0** where the answer is 1e-8. The fix is `expm1`, not a survival
function -- a survival function cannot help an edge where the CDF itself is the
small quantity -- and it is not fixed or tracked.

### The beta family is accurate well past where f32 arithmetic would be

`beta_cdf`, `f_cdf`, `student_t_cdf` and `binomial_cdf` all route through the
regularized incomplete beta, whose front factor is
`exp(lgamma(a+b) - lgamma(a) - lgamma(b) + a*ln x + b*ln(1-x))`. That exponent is
a difference of large quantities: at `a = b = 1e5` the individual log-gammas are
about 2.2e6, where a single f32 rounding is an absolute error of 0.25 in the
exponent and therefore a *multiplicative* error in the result. Evaluated in f32
the family was wrong by 38% at `beta_cdf(0.5, 1e5, 1e5)` and by 87% at
`beta_cdf(0.5, 1e6, 1e6)`, and the error was not monotone in the parameters,
because its size and sign depended on which way the rounding fell.

The incomplete beta is now evaluated in f64 and returned as f32. The public
signatures are unchanged and remain f32; this is an internal working precision,
not an f64 surface.

**The range has two edges, and both are part of the contract.** A ceiling,
because the front factor's log-gamma cancellation grows with the large parameter;
and a floor, because a small shape parameter amplifies the same error — stating
only the ceiling was wrong, since `beta_cdf(0.9, 0.5, 1e-4)` errs 1.9e-6 with a
largest parameter of merely 0.5.

> **Relative error below 2e-6 when every parameter you pass is at least 1 and the
> largest is at most 1e8.**

| export | parameters the range applies to |
|---|---|
| `beta_cdf` | `a`, `b` |
| `f_cdf` | `d1`, `d2` |
| `student_t_cdf` | `df` (its other beta parameter is structurally 0.5) |
| `binomial_cdf` | `n` (`n - k` and `k + 1` are at least 1 for any legal `k`) |

**This page deliberately does not publish a "worst measured" figure.** Four
rounds of review falsified four successive versions of one, each time because the
grid behind it had missed a corner — a range indexed on the wrong parameter, a
ceiling never evaluated at its own value, a known worst-case locus left unsampled,
and then a parameter value between two listed ones. Every refinement raised the
number (5.7e-7, 1.21e-6, 1.45e-6), so any figure printed here is a fresh
falsifiable claim with a short shelf life, and no caller needs it: what a caller
needs is the bound and the range, which are stated above and enforced.

`scripts/check_beta_accuracy.py` is the record. It prints the current worst, both
inside and outside the range, and fails the build if the implementation exceeds
the bound. Run it for the measurement; the number it prints is as of its own grid
and nothing else.

There is a reason no grid settles this. The error is rounding-driven, so it
oscillates in every parameter, and the maximum over a continuum is not reachable
by evaluating finitely many points — an independent review sweep of 7,652 cases
found 1.45e-6 at a point 0.2% away from the worst any derived locus gives. The
bound with headroom is therefore the only form of this claim a finite check can
actually defend, which is why it is the form stated.

**Why 2e-6 and not the measured worst.** The bound carries deliberate headroom for
the same reason, so a further refinement of the grid reports a number inside the
claim instead of falsifying it again.

Both worst cases sit on the continued fraction's **branch threshold**,
`x = (a+1)/(a+b+2)`, which is where it converges slowest and so where the error
peaks. `scripts/check_beta_accuracy.py` now *derives* that locus from the
parameters for every grid point — `t² = 3df/(df+2)` for `student_t_cdf`, the
equivalent `x` for `f_cdf` — rather than sampling hand-listed points, which is
what let the corner hide. It evaluates each export **at** both edges of the range,
reports the in-range worst separately from the overall worst, and fails the build
if the implementation drifts. It does not read this page, so keeping the two in
step is a reviewer's job; a hand-transcribed table in the script pins the values
so they cannot move silently.

References come from SciPy's `betainc` at the f32 value of every argument, except
where no library can adjudicate — `beta_cdf(0.5, a, a)` and `f_cdf(1, d, d)` are
0.5 exactly by symmetry, and past `df = 1e15` SciPy's own `betainc` saturates
exactly as Nautilus does, so `student_t_cdf` is checked against the standard
normal limit there instead.

**Outside either edge the error grows quickly.** Above the ceiling,
`f_cdf(0.5, 2e8, 0.5)` errs 1.7e-6 and `binomial_cdf(1.5e8, 3e8, 0.5)` errs
1.3e-6 — both above 1e-6 but still inside the 2e-6 the range claims, which is why
the ceiling is stated separately from the bound rather than inferred from it. Below the floor, with `a = 0.5` fixed and `b` shrinking,
`beta_cdf(0.9, 0.5, b)` errs 6.1e-7 at `b = 3e-4`, 1.9e-6 at 1e-4, 1.8e-5 at
1e-5 and **183%** at 1e-10; `f_cdf(0.5, 1e8, 1e-3)` errs 2.5e-5, because a large
and a small parameter together are worse than either alone. A previous version of
this page stated a 3e8 ceiling and no floor, and was false in both directions.

Beyond that range the error grows, and nothing in the result says so. Two
different mechanisms do it, so the two worst cases are tabulated separately.

The iteration budget is 4096, and the count needed grows roughly as the cube
root of the smaller parameter: about 160 at 1e5, 340 at 1e6 and 1560 at 1e8.
Past the budget, on `beta_cdf(0.5, a, a)`, whose true value is exactly 0.5:

| `a = b` | 3e8 | 1e9 | 1e10 | 1e11 | 1e12 |
|---|---|---|---|---|---|
| relative error | 4.8e-7 | 8.0e-6 | 1.2e-3 | 2.1e-1 | NaN |

`student_t_cdf` degrades earlier and for the other reason — the front factor's
log-gamma cancellation, driven by `df` alone — and it degrades badly:

| `df` | 3e8 | 1e9 | 1e11 | 1e12 | 1e13 | 1e14 | 1e16 and up |
|---|---|---|---|---|---|---|---|
| relative error | 2.9e-7 | 1.7e-6 | 3.8e-5 | 3.8e-4 | 5.7e-2 | **51%** | returns 0.5 or 1.0 |

At `df = 1e16` and beyond, `student_t_cdf(1, df)` returns exactly **0.5**, which
is also its value at `t = 0`. The explicit complement moved that from `df = 2^24`
on the previous version to about `2^53`; it did not remove it. **If your `df`
exceeds about 1e9, use `normal_cdf` instead** — the t distribution is within
1e-9 of the standard normal there anyway, which is the same fact that makes the
normal a valid reference above.

A regularized incomplete beta also lies in [0, 1], and a computed value outside
that range gets one of two treatments:

- A **converged** continued fraction can overshoot by a rounding, because the
  front factor's exponent is a difference of log-gammas. For a small `a` with a
  large `b` the true value is 1.0 and the computation lands up to about four f32
  ulps above it. That is the right answer with a rounding on it, so it is
  **clamped to the boundary**.
- An **abandoned** one that lands outside has produced nothing:
  `beta_cdf(0.5, 1e12, 1e12)` reaches -0.416 that way, and becomes **NaN**.

Convergence is the separator rather than a tolerance, because the overshoot
grows with the cancellation and no fixed epsilon bounds it. An exhausted budget
is *not* by itself a NaN: wherever its value is in range it is returned, because
near the budget the partial value is usually the better answer — the same
conclusion the gamma family reached for its own continued fraction.

So from about `max(a, b) = 1e9` upward the family returns an in-range value that
is wrong without saying so: `beta_cdf(0.5, 1e11, 1e11)` returns 0.394 against a
true 0.5, and `beta_cdf(0.5, 3e38, 3e38)` returns a confident **1.0** against a
true 0.5. The NaN guard catches only the subset that leaves [0, 1] — for
`beta_cdf(0.5, a, a)` that is 1e12 but not 3e38, and `f_cdf` is a different mix
again. **Do not read a number from these functions when the largest parameter
exceeds about 1e9.**

When f32 precision is insufficient in `Nautilus.Special`, call it at f64
directly. Its functions are generic over the `{f32, f64}` dtype set. Read the
caveats above first, because several of them are coefficient-limited rather
than dtype-limited. The other modules remain f32-only.

The `{f32, f64}` dtype-set bound rejects `f16` and `bf16` at checking;
the approximation coefficients are tuned for f32 and f64. See nautilus#75.

## Comparison to scipy

SciPy operates in f64 (approximately 15 significant digits); f32 is roughly
nine orders of magnitude coarser. The 206 reviewed SciPy parity samples in
`parity/goldens/` therefore use absolute tolerances calibrated to f32,
between 5e-6 and 5e-2 and most often 5e-4 or 5e-3, depending on the
function and argument.
