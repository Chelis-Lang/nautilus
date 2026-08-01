# Nautilus

Numerical methods, statistics, and optimization for the
[Chelis](https://github.com/Chelis-Lang/chelis) programming language.
Ships as a reef package under the `Nautilus` module prefix.

Everything is implemented in pure Chelis, with no C FFI or hand-written
adjoint registry. Tensor composition exposes Chelis's primitive adjoints, but
Nautilus claims differentiability only for surfaces with executable gradient
coverage; it does not promise blanket AD through every iterative solver or
decomposition.

## Modules

| Module | What it provides |
|---|---|
| `Nautilus.Special` | erf, erfc, erfinv, gamma, log_gamma, digamma, trigamma, beta, lbeta, Bessel (J0/J1/Y0/Y1/I0/I1/K0/K1), Airy (Ai/Bi), elliptic integrals (K/E) |
| `Nautilus.Distributions` | Normal, LogNormal, Uniform, Exponential, Gamma, Chi-squared, Student-t, Poisson, Binomial, Beta, F, Weibull. PDF, CDF, inverse CDF, and sampling where applicable |
| `Nautilus.LinAlg` | transpose, matmul, gram, aat, fixed-size det/inv/solve/eig/Cholesky, general square CG/LU/QR/Cholesky/SVD/symmetric eig, vector ops |
| `Nautilus.Stats` | descriptive statistics, quantiles, covariance/correlation, multiple-testing adjustments, likelihood-ratio helpers |
| `Nautilus.Info` | entropy, cross-entropy, KL divergence |
| `Nautilus.Distance` | Euclidean, Manhattan, Chebyshev, cosine, Mahalanobis |
| `Nautilus.Roots` | bisection, Newton, Brent |
| `Nautilus.Ode` | Euler and RK4 (step and solve), adaptive RK45 endpoint solve |
| `Nautilus.Integrate` | trapezoidal, Simpson, Gauss-Legendre, adaptive Simpson, Romberg, Gauss-Hermite, Gauss-Laguerre |
| `Nautilus.Testing` | z/t/chi-squared statistics and p-values, confidence intervals |
| `Nautilus.Optim` | golden section, Brent minimize, gradient descent, Newton minimize (scalar 1D) |
| `Nautilus.Optimize` | stable scalar minimize/root wrappers and a smooth AD smoke target |
| `Nautilus.Interpolation` | linear (uniform and sorted grids), cubic Hermite |
| `Nautilus.Sde` | Euler-Maruyama, Milstein (caller-supplied noise) |
| `Nautilus.CurveFit` | Levenberg-Marquardt single- and multi-parameter fitting |
| `Nautilus.StateSpace` | scalar Kalman prediction/update and local-level models |
| `Nautilus.TimeSeries` | EWMA/exponential smoothing and AR/ARMA/ARIMA point forecasts |
| `Nautilus.Signal` | six typed transform/filter stubs under the [Phase 5f deferral](spec/phase3j.md#explicit-deferrals), plus functional `fftfreq` |
| `Nautilus.Core` | package-version metadata |

## Getting started

Targets the published
[Chelis v0.18.1 release](https://github.com/Chelis-Lang/chelis/releases/tag/v0.18.1).
Install it through `chelisup`; do not replace the pin-resolving shim with a
version-specific symlink.

```sh
chelisup install 0.18.1
chelis reef setup
chelis reef build
chelis test tests/ --jobs auto
uv sync --project parity --frozen
uv run --project parity --frozen python parity/run_parity.py --strict
```

## Tests

Internal correctness lives in native `tests/*.ch` files run by
`chelis test`; reviewed SciPy parity lives in `parity/`. The active golden
corpus is checked in under `parity/goldens/`; normal CI validation never
regenerates it.

```sh
chelis test tests/ --jobs auto                         # 463 native tests
chelis test tests_neg/ --expect neg                    # rejection contracts
chelis test tests_blocked/ --expect blocked            # upstream blocker probes
chelis test tests/ --jobs 1                            # serial fallback
uv sync --project parity --frozen                      # locked oracle project
uv run --project parity --frozen python parity/run_parity.py --strict # 216 samples
python scripts/extract_stability.py --check            # stability metadata
```

## Benchmarks

See [docs/benchmark_findings.md](docs/benchmark_findings.md). Highlights
at n=100k on a single core:

| Kernel | vs scipy | Throughput |
|---|---|---|
| erfinv | 6.5x faster | 450M evals/s |
| normal_inv_cdf | 6.8x | 370M/s |
| Fused compounds | 3x numpy | 150M/s |

## Project docs

- [spec/phase3j.md](spec/phase3j.md) for scope and acceptance criteria
- [spec/next_up.md](spec/next_up.md) for the post-v0.1.0 roadmap
- [docs/nautilus_status.md](docs/nautilus_status.md) for the full status report
- [docs/UPSTREAM_BUGS.md](docs/UPSTREAM_BUGS.md) for upstream compiler bug history

## License

MIT
