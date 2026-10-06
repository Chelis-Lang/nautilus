# Nautilus

Nautilus is the numerical computing library for the Chelis programming
language. It includes special functions, distributions, linear algebra,
statistics, and numerical solvers. The chapters show which operations are
available and where their inputs or precision need care.

Everything in Nautilus is written in pure Chelis. There is no C FFI,
nalgebra bridge, or hand-written adjoint registry. Linear algebra composes
Chelis tensor primitives (`matmul`, `permute`, `trace`, `einsum`, and
elementwise operations), but composition alone does not guarantee that
`grad` lowers. Follow each chapter's differentiation notes and tests for
the path you use.

## What Nautilus provides

- **Special functions**: erfinv, gamma, log_gamma, digamma, trigamma, beta, lbeta, Bessel, Airy, elliptic integrals; Chelis provides erf and erfc as builtins
- **Probability distributions**: 12 families (Normal, Gamma, Student-t, Poisson, Binomial, etc.) with PDF or PMF and CDF; inverse CDF and sampling for selected families
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
`parity/run_parity.py --strict` compares 206 reviewed samples against SciPy
and NumPy reference values. The external comparison deliberately does not
duplicate every native test.

## Precision

`Nautilus.Special` accepts f32 and f64 through an explicit dtype set.
`Nautilus.Rolling` uses f64; the other numerical modules use f32 (IEEE 754
single precision), which carries about seven significant digits. See the
[precision guide](appendix/precision.md) for what f64 does and does not buy.
