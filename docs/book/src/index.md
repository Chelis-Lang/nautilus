# Nautilus

Nautilus is the numerical computing library for the Chelis programming
language. It includes special functions, distributions, linear algebra,
statistics, and numerical solvers.

Nautilus functions are Chelis code and compose with Chelis programs. Consult
each chapter for its accepted input types, numeric precision, and any
limitations on differentiation.

## Modules

- **Special functions**: erfinv, gamma, log_gamma, digamma, trigamma, beta, lbeta, Bessel, Airy, elliptic integrals. Chelis provides erf and erfc as builtins
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

## Precision

`Nautilus.Special` functions accept f32 or f64 inputs, with an explicit
`{f32, f64}` dtype bound. Most numerical modules use f32 (IEEE 754 single
precision), which carries about seven significant digits. `Nautilus.Rolling`
uses f64 series. See the
[precision guide](appendix/precision.md) for what f64 does and does not buy.
