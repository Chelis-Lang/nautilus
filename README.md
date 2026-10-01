# Nautilus

Numerical methods, statistics, and optimization for the
[Chelis](https://github.com/Chelis-Lang/chelis) programming language.
Nautilus is a Reef package (Chelis's package format) published under the
`Nautilus` module prefix.

Nautilus is written entirely in Chelis, with no C FFI and no hand-written
adjoints. Differentiation is supported only on tested paths; pure Chelis
source alone does not guarantee that `grad` lowers for every function.
See [`spec/scope.md`](spec/scope.md) for the library's
scope and numerical acceptance rules.

## Modules

| Module | What it provides |
|---|---|
| `Nautilus.Special` | `erf`, `erfc`, `erfinv`, `gamma`, `log_gamma`, `digamma`, `trigamma`, `beta`, `lbeta`, Bessel (J0/J1/Y0/Y1/I0/I1/K0/K1), Airy (Ai/Bi), complete elliptic integrals (K/E); generic over f32 and f64 |
| `Nautilus.Distributions` | Normal, LogNormal, Uniform, Exponential, Gamma, Chi-squared, Student-t, Poisson, Binomial, Beta, F, Weibull: PDF or PMF and CDF, with inverse CDF and sampling where available; see [sampling limits](docs/book/src/distributions/sampling.md) |
| `Nautilus.LinAlg` | transpose, matmul, Gram matrices, fixed-size det/inv/solve/eig/Cholesky, general square conjugate-gradient/LU/QR/Cholesky/SVD/symmetric eig, vector ops |
| `Nautilus.Stats` | descriptive statistics, quantiles, ranks and z-scores, covariance/correlation matrices, multiple-testing adjustments, likelihood-ratio helpers |
| `Nautilus.Info` | entropy, cross-entropy, KL divergence |
| `Nautilus.Distance` | Euclidean, Manhattan, Chebyshev, cosine, Mahalanobis |
| `Nautilus.Roots` | bisection, Newton, Brent |
| `Nautilus.Ode` | Euler and RK4 (step and solve), adaptive Dormand–Prince RK45 with endpoint or dense-output solves |
| `Nautilus.Integrate` | trapezoidal, Simpson, Gauss–Legendre, adaptive Simpson, Romberg, Gauss–Hermite, Gauss–Laguerre |
| `Nautilus.Testing` | z, t, Welch, and chi-squared statistics and p-values, confidence intervals |
| `Nautilus.Optim` | golden-section search, Brent minimization, gradient descent, Newton minimization (scalar) |
| `Nautilus.Optimize` | scalar `minimize` and `root` entry points (`alpha`) |
| `Nautilus.Interpolation` | linear (uniform and sorted grids), cubic Hermite, natural cubic spline |
| `Nautilus.Sde` | Euler–Maruyama and Milstein with caller-supplied noise |
| `Nautilus.CurveFit` | Levenberg–Marquardt fitting for one or many parameters |
| `Nautilus.StateSpace` | scalar Kalman filter and local-level model |
| `Nautilus.TimeSeries` | EWMA, exponential smoothing, and AR(1)/ARMA(1,1)/ARIMA(1,1,0) point forecasts |
| `Nautilus.Signal` | `fftfreq`; FFT, STFT, and filter names ending in `_stub` return NaN tensors |
| `Nautilus.Core` | exact package version as a string |

The [stability inventory](SKILL.md) labels library exports `stable` or
`alpha`; the package metadata export `Nautilus.Core.version` is outside that
inventory. The
[book](docs/book/src/SUMMARY.md) provides signatures, worked examples, and
precision guidance; its [API map](docs/book/src/appendix/api.md) lists modules.

## Using Nautilus

The Chelis and Nautilus releases require access to their GitHub repositories.
Install `chelisup`, then install the Chelis version pinned by this release
and Nautilus itself. [Installation](docs/book/src/getting-started/installation.md)
gives the `chelisup` bootstrap and GitHub sign-in steps.

```sh
chelisup install 0.18.12
chelis reef install --from-github Chelis-Lang/nautilus@v0.7.47
chelis reef init demo --module-prefix Demo --output demo
cd demo
```

Add this line under `[dependencies]` in the generated `reef.toml`:

```toml
nautilus = { version = "0.7.47" }
```

Use the book's [first program](docs/book/src/getting-started/first-program.md)
as `src/main.ch`, then run `chelis fmt --inplace src/main.ch` and
`chelis eval --file src/main.ch`. Run `chelis reef build` to build
the package.

Each release is built against one exact Chelis version, recorded as the
`compiler` pin in [`reef.toml`](reef.toml). [`docs/releases.md`](docs/releases.md)
describes the release artifacts and how to verify them.

## Developing

From a fresh home, sign in to GitHub, install `chelisup`, and install the
compiler pinned by Nautilus before running `chelis` in the clone:

```sh
gh auth login
gh release download --repo Chelis-Lang/chelis --pattern chelisup.sh --output - | sh
export PATH="$HOME/.chelis/bin:$PATH"
git clone https://github.com/Chelis-Lang/nautilus.git
cd nautilus
chelisup install 0.18.12
chelis reef setup
```

The `chelis` shim reads this checkout's compiler pin before it can start
`reef setup`, so the explicit `chelisup install` is required. The
[installation guide](docs/book/src/getting-started/installation.md) has more
detail. The main checks are:

```sh
chelis reef build
chelis test tests/ --timeout 600 --suite-timeout 2400 --jobs auto
chelis test tests_neg/ --expect neg
uv run --project parity --frozen python parity/run_parity.py --strict
```

[`CONTRIBUTING.md`](CONTRIBUTING.md) covers the full local gate, the test
layout, and how compiler upgrades are handled.

## Repository layout

| Path | Contents |
|---|---|
| `src/` | the library, one file per module, plus runnable example programs |
| `tests/` | native Chelis tests (`chelis test tests/`) |
| `tests_neg/` | programs that must fail to compile, each with the diagnostic it must produce |
| `tests_blocked/` | compiler compatibility fixtures |
| `parity/` | SciPy/NumPy parity checks, an isolated uv project with reviewed goldens |
| `docs/book/` | the Nautilus book (mdBook) |
| `docs/` | benchmarks, release notes, and the Chelis capability inventory |
| `spec/scope.md` | intent, architecture, acceptance rules, limitations, deferrals |
| `scripts/` | CI and validation tooling (Python, standard library only) |
| `provenance/` | requirement-to-code provenance records (advisory) |

## License

[MIT](LICENSE)
