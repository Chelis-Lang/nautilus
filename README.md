# Nautilus

Numerical methods, statistics, and optimization for the
[Chelis](https://github.com/Chelis-Lang/chelis) programming language.
Ships as a reef package under the `Nautilus` module prefix.

Everything is implemented in pure Chelis. No C FFI, no hand-written
adjoints. Automatic differentiation flows through tensor-op composition.

## Modules

| Module | What it provides |
|---|---|
| `Nautilus.Special` | erf, erfinv, log_gamma, digamma, trigamma, beta, lbeta, Bessel (J0/J1/Y0/Y1/I0/I1/K0/K1), Airy (Ai/Bi), elliptic integrals (K/E) |
| `Nautilus.Distributions` | Normal, LogNormal, Uniform, Exponential, Gamma, Chi-squared, Student-t, Poisson, Binomial, Beta, F, Weibull. PDF, CDF, inverse CDF, and sampling where applicable |
| `Nautilus.LinAlg` | transpose, matmul, gram, aat, det (2x2, 3x3), inv, solve, eigenvalues, Cholesky (2x2), conjugate gradient (general-n SPD), vector ops |
| `Nautilus.Stats` | mean, variance, std, skewness, kurtosis, median, min, max, range, quantile, percentile, trimmed mean, covariance, correlation |
| `Nautilus.Distance` | Euclidean, Manhattan, Chebyshev, cosine, Mahalanobis |
| `Nautilus.Roots` | bisection, Newton, Brent |
| `Nautilus.ODE` | Euler and RK4 (step and solve), adaptive RK45 endpoint solve |
| `Nautilus.Integrate` | trapezoidal, Simpson, Gauss-Legendre, adaptive Simpson, Romberg, Gauss-Hermite, Gauss-Laguerre |
| `Nautilus.Testing` | z/t/chi-squared statistics and p-values, confidence intervals |
| `Nautilus.Optim` | golden section, Brent minimize, gradient descent, Newton minimize (scalar 1D) |
| `Nautilus.Interpolation` | linear (uniform and sorted grids), cubic Hermite |
| `Nautilus.SDE` | Euler-Maruyama, Milstein (caller-supplied noise) |
| `Nautilus.CurveFit` | Levenberg-Marquardt single-parameter fitting |
| `Nautilus.Signal` | typed stubs (real implementations pending complex-number support) |

## Getting started

Requires the latest validated Chelis release, currently
[chelis v0.1.18](https://github.com/Chelis-Lang/chelis/releases/tag/v0.1.18).

```sh
gh release download v0.1.18 \
  --repo Chelis-Lang/chelis \
  --pattern 'chelis-v0.1.18-linux-x86_64.tar.gz'
tar xzf chelis-v0.1.18-linux-x86_64.tar.gz
export PATH="$PWD/chelis-v0.1.18-linux-x86_64/bin:$PATH"

chelis reef build
python tests/run_numeric_tests.py    # 895 scipy-parity assertions
```

## Tests

The test harness compiles Nautilus source through the chelis C backend,
links against `libchelis_runtime.a`, and compares outputs against
scipy/numpy reference values checked into `tests/goldens/`.

```sh
python tests/run_numeric_tests.py      # 895 numerical assertions
python scripts/gen_goldens.py --check  # verify goldens match scipy
python tests/run_static_checks.py      # export consistency
python scripts/extract_stability.py --check
```

## Benchmarks

See [docs/BENCHMARK_FINDINGS.md](docs/BENCHMARK_FINDINGS.md). Highlights
at n=100k on a single core:

| Kernel | vs scipy | Throughput |
|---|---|---|
| erfinv | 6.5x faster | 450M evals/s |
| normal_inv_cdf | 6.8x | 370M/s |
| Fused compounds | 3x numpy | 150M/s |

## Project docs

- [spec/phase3j.md](spec/phase3j.md) for scope and acceptance criteria
- [spec/next_up.md](spec/next_up.md) for the post-v0.1.0 roadmap
- [docs/NAUTILUS_STATUS.md](docs/NAUTILUS_STATUS.md) for the full status report
- [docs/UPSTREAM_BUGS.md](docs/UPSTREAM_BUGS.md) for upstream compiler bug history

## License

MIT
