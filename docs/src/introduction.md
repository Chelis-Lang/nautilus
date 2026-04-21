# Nautilus

Nautilus is the numerical computing library for the Chelis programming
language. It provides the functions you need for scientific computing,
statistics, and optimization, comparable to scipy and numpy in Python.

Everything in Nautilus is written in pure Chelis. There is no C FFI
and no hand-written adjoints. Because all linear algebra is built from
Chelis tensor primitives (`matmul`, `permute`, `trace`, `einsum`, and
elementwise ops), automatic differentiation via `grad` flows through
every function in the library.

## What Nautilus provides

- **Special functions**: erf, Bessel, Airy, elliptic integrals, gamma, beta, digamma
- **Probability distributions**: 12 families (Normal, Gamma, Student-t, Poisson, Binomial, etc.) with PDF, CDF, inverse CDF, and sampling
- **Linear algebra**: determinants, inverses, solves, eigenvalues (2x2/3x3), conjugate gradient (general-n)
- **Statistics**: mean, variance, skewness, kurtosis, median, quantiles, covariance, correlation
- **Root finding**: bisection, Newton, Brent-Dekker
- **ODE solvers**: Euler, RK4, and adaptive RK45 endpoint solves
- **SDE solvers**: Euler-Maruyama and Milstein with caller-supplied noise
- **Numerical integration**: trapezoidal, Simpson, Gauss-Legendre, adaptive Simpson, Romberg, Gauss-Hermite, Gauss-Laguerre
- **Optimization**: golden section, Brent minimize, gradient descent, Newton minimize (scalar 1D)
- **Interpolation**: linear (uniform and sorted grids), cubic Hermite
- **Distance metrics**: Euclidean, Manhattan, Chebyshev, cosine, Mahalanobis
- **Curve fitting**: Levenberg-Marquardt (single parameter)
- **Hypothesis testing**: z-tests, t-tests, chi-squared p-values, confidence intervals

## Verification

Nautilus is tested against scipy reference values. The test suite runs
895 numerical assertions comparing Nautilus output to scipy/numpy at
documented tolerances. Every non-stub exported function is
runtime-verified on clean `HEAD`; `Nautilus.Core.version` is package
metadata rather than part of the numerical harness.

## Precision

All Nautilus functions operate in f32 (32-bit floating point). This
gives approximately 6-7 significant digits of precision. If you need
f64 precision, Nautilus is not the right choice today.
