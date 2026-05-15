# Nautilus

Numerical methods, statistics, and optimization for the
[Chelis](https://github.com/Chelis-Lang/chelis) programming language.
Ships as a reef package under the `Nautilus` module prefix.

Everything is implemented in pure Chelis. No C FFI, no hand-written
adjoints. Automatic differentiation flows through tensor-op composition.

## Modules

| Module | What it provides |
|---|---|
| `Nautilus.Special` | erf, erfc, erfinv, gamma, log_gamma, digamma, trigamma, beta, lbeta, Bessel (J0/J1/Y0/Y1/I0/I1/K0/K1), Airy (Ai/Bi), elliptic integrals (K/E) |
| `Nautilus.Distributions` | Normal, LogNormal, Uniform, Exponential, Gamma, Chi-squared, Student-t, Poisson, Binomial, Beta, F, Weibull. PDF, CDF, inverse CDF, and sampling where applicable |
| `Nautilus.LinAlg` | transpose, matmul, gram, aat, det (2x2, 3x3), inv, solve, eigenvalues, Cholesky (2x2 + general-n), conjugate gradient (general-n SPD), vector ops |
| `Nautilus.Stats` | mean, variance, std, skewness, kurtosis, median, min, max, range, quantile, percentile, trimmed mean, covariance, correlation |
| `Nautilus.Distance` | Euclidean, Manhattan, Chebyshev, cosine, Mahalanobis |
| `Nautilus.Roots` | bisection, Newton, Brent |
| `Nautilus.Ode` | Euler and RK4 (step and solve), adaptive RK45 endpoint solve |
| `Nautilus.Integrate` | trapezoidal, Simpson, Gauss-Legendre, adaptive Simpson, Romberg, Gauss-Hermite, Gauss-Laguerre |
| `Nautilus.Testing` | z/t/chi-squared statistics and p-values, confidence intervals |
| `Nautilus.Optim` | golden section, Brent minimize, gradient descent, Newton minimize (scalar 1D) |
| `Nautilus.Interpolation` | linear (uniform and sorted grids), cubic Hermite |
| `Nautilus.Sde` | Euler-Maruyama, Milstein (caller-supplied noise) |
| `Nautilus.CurveFit` | Levenberg-Marquardt single-parameter fitting |
| `Nautilus.Signal` | typed stubs (real implementations pending complex-number support) |

## Getting started

Requires the latest validated Chelis release, currently
[chelis 0.7.6](https://github.com/Chelis-Lang/chelis/releases/tag/v0.7.6).

```sh
gh release download v0.7.6 \
  --repo Chelis-Lang/chelis \
  --pattern 'chelis-v0.7.6-linux-x86_64.tar.gz'
tar xzf chelis-v0.7.6-linux-x86_64.tar.gz
export PATH="$PWD/chelis-v0.7.6-linux-x86_64/bin:$PATH"

chelis reef build
chelis test tests/ --jobs auto         # 438 native identity / structural tests
python parity/run_parity.py --strict   # 216 scipy-parity samples
```

## Tests

Internal correctness lives in native `tests/*.ch` files run by
`chelis test`; scipy parity lives in `parity/run_parity.py`. Goldens
under `tests_legacy/goldens/` are reused by both the legacy harness
(scheduled nightly) and the parity script.

```sh
chelis test tests/ --jobs auto              # 438 native identity / structural tests
chelis test tests/ --jobs 1                 # serial fallback for debugging
python parity/run_parity.py --strict        # scipy oracle (216 samples)
python scripts/gen_goldens.py --check       # verify checked-in goldens match scipy
python scripts/extract_stability.py --check # SKILL.md stability column gate
```

## Benchmarks

See [docs/benchmark-findings.md](docs/benchmark-findings.md). Highlights
at n=100k on a single core:

| Kernel | vs scipy | Throughput |
|---|---|---|
| erfinv | 6.5x faster | 450M evals/s |
| normal_inv_cdf | 6.8x | 370M/s |
| Fused compounds | 3x numpy | 150M/s |

## Project docs

- [spec/phase3j.md](spec/phase3j.md) for scope and acceptance criteria
- [spec/next_up.md](spec/next_up.md) for the post-v0.1.0 roadmap
- [docs/nautilus-status.md](docs/nautilus-status.md) for the full status report
- [docs/upstream-bugs.md](docs/upstream-bugs.md) for upstream compiler bug history

## License

MIT
