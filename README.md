# Nautilus

Numerical methods, statistics, and optimization for the
[Chelis](https://github.com/Chelis-Lang/chelis) programming language.
Nautilus is a Reef package (Chelis's package format) published under the
`Nautilus` module prefix. It is written entirely in Chelis, with no C FFI and
no hand-written adjoints.

**Documentation:** the Nautilus book at
[chelis.ch/docs/nautilus](https://chelis.ch/docs/nautilus/) gives signatures,
worked examples with their output, contracts, and precision guidance. The
mdBook in [`docs/book`](docs/book) is rendered from those chelis.ch pages.

## Modules

| Module | What it provides |
|---|---|
| `Nautilus.Special` | `erfinv`, `gamma`, `log_gamma`, `digamma`, `trigamma`, `beta`, `lbeta`, Bessel (J0/J1/Y0/Y1/I0/I1/K0/K1), Airy (Ai/Bi), complete elliptic integrals (K/E); generic over f32 and f64 |
| `Nautilus.Distributions` | Normal, LogNormal, Uniform, Exponential, Gamma, Chi-squared, Student-t, Poisson, Binomial, Beta, F, Weibull: PDF or PMF and CDF, with survival, inverse CDF and sampling where available |
| `Nautilus.LinAlg` | transpose, matmul, Gram matrices, fixed-size det/inv/solve/eig/Cholesky, general square conjugate-gradient/LU/QR/Cholesky/SVD/symmetric eig, vector ops |
| `Nautilus.Stats` | descriptive statistics, quantiles, ranks and z-scores, covariance/correlation matrices, multiple-testing adjustments, likelihood-ratio helpers |
| `Nautilus.Info` | entropy, cross-entropy, KL divergence |
| `Nautilus.Distance` | Euclidean, Manhattan, Chebyshev, cosine, Mahalanobis |
| `Nautilus.Roots` | bisection, Newton, Brent |
| `Nautilus.Ode` | Euler and RK4 (step and solve), adaptive Dormand–Prince RK45 with endpoint or dense-output solves |
| `Nautilus.Integrate` | trapezoidal, Simpson, Gauss–Legendre, adaptive Simpson, Romberg, Gauss–Hermite, Gauss–Laguerre |
| `Nautilus.Testing` | z, t, Welch, and chi-squared statistics and p-values, confidence intervals |
| `Nautilus.Optim` | golden-section search, Brent minimization, gradient descent, Newton minimization (scalar) |
| `Nautilus.Optimize` | scalar `minimize` and `root` entry points |
| `Nautilus.Interpolation` | linear (uniform and sorted grids), cubic Hermite, natural cubic spline |
| `Nautilus.Sde` | Euler–Maruyama and Milstein with caller-supplied noise |
| `Nautilus.CurveFit` | Levenberg–Marquardt fitting for one or many parameters |
| `Nautilus.StateSpace` | scalar Kalman filter and local-level model |
| `Nautilus.TimeSeries` | EWMA, exponential smoothing, and AR(1)/ARMA(1,1)/ARIMA(1,1,0) point forecasts |
| `Nautilus.Rolling` | f64 rolling and expanding windows over `List[f64]` -- `rolling_mean`, `rolling_std`, `expanding_var` and their siblings -- plus `shift`, `shift_fill`, `shift_clamped`, `diff` and `pct_change` |
| `Nautilus.Signal` | `fftfreq` (frequency labels for DFT bins) |
| `Nautilus.Core` | exact package version as a string |

## Install

Nautilus 0.7.50 is built for Chelis 0.19.1. Install Chelis from the
[official releases](https://chelis.ch/docs/chelis/install/), then install the
Nautilus release into your local Reef registry. The release is public, so no
token is needed:

```sh
chelis reef install --from-github Chelis-Lang/nautilus@v0.7.50
```

Add Nautilus to your project's `reef.toml`, set the project's `compiler` pin
to `"=0.19.1"`, and run `chelis reef build` from the project directory:

```toml
[dependencies]
nautilus = { version = "0.7.50" }
```

The book's
[installation page](https://chelis.ch/docs/nautilus/getting-started/installation/)
and [first program](https://chelis.ch/docs/nautilus/getting-started/first-program/)
continue from there.

## License

[MIT](LICENSE)
