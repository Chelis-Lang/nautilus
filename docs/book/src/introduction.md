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
- **Optimization**: golden section, Brent minimization, gradient descent, Newton minimization, and bracketed minimize/root wrappers
- **Interpolation**: linear, cubic Hermite, and natural cubic splines
- **Distance metrics**: Euclidean, Manhattan, Chebyshev, cosine, Mahalanobis
- **Curve fitting**: Levenberg-Marquardt (single- and multi-parameter)
- **Hypothesis testing**: z-tests, t-tests, chi-squared p-values, confidence intervals
- **State-space and time series**: scalar Kalman/local-level models, smoothing, and AR/ARMA/ARIMA point forecasts

## Verification

Two complementary gates check the numbers. `chelis test tests/` runs the
native suite of identity, invariant, solver, tensor-path, and edge-case tests.
`parity/run_parity.py --strict` compares 216 reviewed samples against SciPy
and NumPy reference values. The external comparison deliberately does not
duplicate every native test.

## Precision

`Nautilus.Special` is generic over the `Float` dtype family, so its functions
run at f32 or f64. Every other module works in f32 (IEEE 754 single
precision), which carries about seven significant digits. See the
[precision guide](appendix/precision.md) for what f64 does and does not buy.
