# f32 Precision Guide

All Nautilus functions operate in f32 (IEEE 754 single precision),
providing approximately 6-7 significant decimal digits. This page
documents the precision characteristics of each function family and
known trouble spots.

## Precision by function family

| Family | Typical relative error | Notes |
|---|---|---|
| `erf` | ~1e-7 | Horner rational approximation |
| `erfinv` | ~1e-8 | Acklam rational approximation via `norminv` |
| `log_gamma` | ~1e-9 | Lanczos (g=7) with reflection |
| `digamma` | ~1e-7 | Recurrence + asymptotic (x >= 6) |
| `trigamma` | ~1e-6 | Recurrence + asymptotic (x >= 6) |
| `ellipk`, `ellipe` | ~1e-8 | AGM recurrence (quadratic convergence) |
| `bessel_j0`, `j1` | ~1e-5 near zeros | Rational polynomial + large-x trig |
| `bessel_y0` | ~1e-5 near zeros | Rational + log-singularity |
| `bessel_y1` | ~1e-5 near zeros | Large-x branch now starts at 7.5 to avoid the old seam drift |
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

When f32 precision is insufficient, the recommended path is to wait for
upstream f64 type support in Chelis. There is no f64 promotion available
in the current toolchain.

## Comparison to scipy

scipy operates in f64 (approximately 15 significant digits). Nautilus's
f32 is roughly 8-9 orders of magnitude less precise. The 890
scipy-parity assertions in the test suite use tolerances calibrated to
f32: typically 1e-4 to 1e-6 relative error, depending on the function.
