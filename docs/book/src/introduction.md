# Nautilus

Nautilus is the numerical computing library for the Chelis programming
language. It provides the functions you need for scientific computing,
statistics, and optimization, comparable to scipy and numpy in Python.

Everything in Nautilus is written in pure Chelis. There is no C FFI,
nalgebra bridge, or hand-written adjoint registry. Linear algebra composes
Chelis tensor primitives (`matmul`, `permute`, `trace`, `einsum`, and
elementwise operations), but composition alone is not a blanket AD guarantee:
Nautilus advertises differentiability only where an executable gradient test
exists.

## What Nautilus provides

- **Special functions**: erf, erfc, erfinv, gamma, log_gamma, digamma, trigamma, beta, lbeta, Bessel, Airy, elliptic integrals
- **Probability distributions**: 12 families (Normal, Gamma, Student-t, Poisson, Binomial, etc.) with PDF, CDF, inverse CDF, and sampling
- **Linear algebra**: fixed-size formulas plus general square CG, LU, QR, Cholesky, SVD, and symmetric eigendecomposition
- **Statistics and information**: descriptive/inferential statistics, adjustments, entropy, cross-entropy, and KL divergence
- **Root finding**: bisection, Newton, Brent-Dekker
- **ODE solvers**: Euler, RK4, and adaptive RK45 endpoint/grid solves
- **SDE solvers**: Euler-Maruyama and Milstein with caller-supplied noise
- **Numerical integration**: trapezoidal, Simpson, Gauss-Legendre, adaptive Simpson, Romberg, Gauss-Hermite, Gauss-Laguerre
- **Optimization**: golden section, Brent minimization, gradient descent, Newton minimization, and stable scalar wrappers
- **Interpolation**: linear, cubic Hermite, and natural cubic splines
- **Distance metrics**: Euclidean, Manhattan, Chebyshev, cosine, Mahalanobis
- **Curve fitting**: Levenberg-Marquardt (single- and multi-parameter)
- **Hypothesis testing**: z-tests, t-tests, chi-squared p-values, confidence intervals
- **State-space and time series**: scalar Kalman/local-level models, smoothing, and AR/ARMA/ARIMA point forecasts

## Verification

Nautilus has two complementary numerical gates. `chelis test tests/` runs 463
native identity, invariant, solver, tensor-path, and edge tests;
`parity/run_parity.py` validates a reviewed scipy/numpy subset and currently
passes 216/216 samples. External parity intentionally does not duplicate every
native claim. `Nautilus.Core.version` is package metadata rather than part of
the numerical harness.

## Precision

All Nautilus functions operate in f32 (32-bit floating point). This
gives approximately 6-7 significant digits of precision. If you need
f64 precision, Nautilus is not the right choice today.
