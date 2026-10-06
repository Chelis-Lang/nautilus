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
