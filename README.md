# Nautilus

Numerical methods, statistics, and optimization for the
[Chelis](https://github.com/Chelis-Lang/chelis) programming language.
Nautilus is a Reef package (Chelis's package format) published under the
`Nautilus` module prefix.

Nautilus is written entirely in Chelis, with no C FFI and no hand-written
adjoints. Chelis's automatic differentiation can trace through any of it, but
Nautilus advertises a function as differentiable only when a gradient test
covers it. See [`spec/scope.md`](spec/scope.md) for the design principles,
acceptance rules, known limitations, and what is deliberately out of scope.

## Modules

| Module | What it provides |
|---|---|
| `Nautilus.Special` | `erf`, `erfc`, `erfinv`, `gamma`, `log_gamma`, `digamma`, `trigamma`, `beta`, `lbeta`, Bessel (J0/J1/Y0/Y1/I0/I1/K0/K1), Airy (Ai/Bi), complete elliptic integrals (K/E); generic over f32 and f64 |
| `Nautilus.Distributions` | Normal, LogNormal, Uniform, Exponential, Gamma, Chi-squared, Student-t, Poisson, Binomial, Beta, F, Weibull: PDF, CDF, inverse CDF, and sampling where applicable |
| `Nautilus.LinAlg` | transpose, matmul, Gram matrices, fixed-size det/inv/solve/eig/Cholesky, general square conjugate-gradient/LU/QR/Cholesky/SVD/symmetric eig, vector ops |
| `Nautilus.Stats` | descriptive statistics, quantiles, ranks and z-scores, covariance/correlation matrices, multiple-testing adjustments, likelihood-ratio helpers |
| `Nautilus.Info` | entropy, cross-entropy, KL divergence |
| `Nautilus.Distance` | Euclidean, Manhattan, Chebyshev, cosine, Mahalanobis |
| `Nautilus.Roots` | bisection, Newton, Brent |
| `Nautilus.Ode` | Euler and RK4 (step and solve), adaptive Dormand–Prince RK45 with endpoint or dense-output solves |
| `Nautilus.Integrate` | trapezoidal, Simpson, Gauss–Legendre, adaptive Simpson, Romberg, Gauss–Hermite, Gauss–Laguerre |
| `Nautilus.Testing` | z, t, Welch, and chi-squared statistics and p-values, confidence intervals |
| `Nautilus.Optim` | golden-section search, Brent minimization, gradient descent, Newton minimization (scalar) |
| `Nautilus.Optimize` | stable scalar `minimize` and `root` entry points |
| `Nautilus.Interpolation` | linear (uniform and sorted grids), cubic Hermite, natural cubic spline |
| `Nautilus.Sde` | Euler–Maruyama and Milstein with caller-supplied noise |
| `Nautilus.CurveFit` | Levenberg–Marquardt fitting for one or many parameters |
| `Nautilus.StateSpace` | scalar Kalman filter and local-level model |
| `Nautilus.TimeSeries` | EWMA, exponential smoothing, and AR(1)/ARMA(1,1)/ARIMA(1,1,0) point forecasts |
| `Nautilus.Signal` | `fftfreq`; FFT, STFT, and filters are typed stubs until Chelis supports complex numbers |
| `Nautilus.Core` | package version metadata |

Every export carries a `stable` or `alpha` label. [`SKILL.md`](SKILL.md) §6
has the full signature-level inventory, and the
[book](docs/book/src/SUMMARY.md) has worked examples and per-function
precision tables.

## Using Nautilus

Install the Chelis toolchain with `chelisup` (see the
[Chelis installation guide](https://github.com/Chelis-Lang/chelis)), then
install a Nautilus release into your local Reef registry and declare it as a
dependency:

```sh
chelis reef install --from-github Chelis-Lang/nautilus@v0.7.46
```

```toml
# your project's reef.toml
[dependencies]
nautilus = { version = "0.7.46" }
```

```chelis
module MyProject.Demo
import Nautilus.Special (erf)
import Nautilus.Distributions (normal_cdf)
export (main)
def main() -> f32 = {
  zero = cast(0.0, f32)
  one = cast(1.0, f32)
  p = normal_cdf(cast(1.96, f32), zero, one)
  e = erf(cast(0.5, f32))
  add(p, e)
}
```

The book's [first program](docs/book/src/getting-started/first-program.md)
walks through a complete Black–Scholes example.

Each release is built against one exact Chelis version, recorded as the
`compiler` pin in [`reef.toml`](reef.toml). [`docs/releases.md`](docs/releases.md)
describes the release artifacts and how to verify them.
The v0.7.46 install example above is the last published Nautilus package.
This source checkout pins Chelis 0.18.12 and uses explicit keys for sampling;
the published package retains the API and compiler pin of its own tag.

## Developing

With `chelisup` installed, `chelis reef setup` provisions the pinned compiler
and dependencies for a fresh clone. The main checks are:

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
| `tests_blocked/` | reproducers for open upstream compiler issues (see its README) |
| `parity/` | SciPy/NumPy parity checks, an isolated uv project with reviewed goldens |
| `docs/book/` | the Nautilus book (mdBook) |
| `docs/` | benchmarks, release notes, the Chelis capability inventory, and upstream issue tracking |
| `spec/scope.md` | intent, architecture, acceptance rules, limitations, deferrals |
| `scripts/` | CI and validation tooling (Python, standard library only) |
| `provenance/` | requirement-to-code provenance records (advisory) |
| `agent-skills/`, `AGENTS.md` | instructions for AI coding agents, managed by the Chelis toolchain |

## License

[MIT](LICENSE)
