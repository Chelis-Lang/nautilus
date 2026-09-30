# Precision Guide

Nautilus functions operate in f32 (IEEE 754 single precision), providing
approximately 6-7 significant decimal digits. `Nautilus.Special` is the
exception: its functions are generic over the `Float` family and can be called
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

Three cases are stated exactly, because they are measured and they are the ones
a caller is most likely to get wrong:

- `erf` is capped by Abramowitz & Stegun 7.1.26's own 1.5e-7 error. At x = 0.5
  an f64 `erf` measures 1.385e-7 against an f32 `erf`'s 1.861e-7; over the
  whole range the maxima are 1.3884e-7 and 4.438e-7.
- `airy_ai` and `airy_bi` above x = 5 use only the leading asymptotic term and
  gain nothing from f64 there; the two dtypes agree to three digits. Below
  x = 5 f64 is far better.
- `erfc` is the one place f64 changes what is computable rather than how
  precisely. f32 `erfc` underflows to exactly 0 from about x = 3.92 on; f64
  returns 1.546e-8 at x = 4 and stays usable to about x = 5.5. Its *relative* error is
  still poor (2.8e-3 at x = 4) because `1 - erf(x)` cancels against an
  absolutely-bounded `erf`. Use it for a tail that exists at all, not for
  a tail you need three good digits from.

## Precision by function family

| Family | Typical relative error | Notes |
|---|---|---|
| `erf` | ~1e-7 | Horner rational approximation |
| `erfc` | same absolute error as `erf` | `1 - erf(x)`, so relative error grows in the upper tail |
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
| `normal_cdf` | ~1e-7 | Delegates to `erf` |
| `normal_inv_cdf` | ~1e-7 | Acklam rational via `erfinv` |

## Known precision issues

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

When f32 precision is insufficient in `Nautilus.Special`, call it at f64
directly. Its functions are generic over the `Float` family. Read the
caveats above first, because several of them are coefficient-limited rather
than dtype-limited. The other modules remain f32-only.

## Comparison to scipy

SciPy operates in f64 (approximately 15 significant digits); f32 is roughly
nine orders of magnitude coarser. The 216 reviewed SciPy parity samples in
`parity/goldens/` therefore use absolute tolerances calibrated to f32,
between 5e-6 and 5e-2 and most often 5e-4 or 5e-3, depending on the
function and argument.
