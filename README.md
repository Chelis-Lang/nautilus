# Nautilus

Numerical methods, statistics, and optimization shell for the
[Chelis](https://github.com/Chelis-Lang/chelis) programming language.
Ships as a reef package under the `Nautilus` module prefix.

Phase 3j P0 surface (`Nautilus.Special`, `Nautilus.Distributions`,
`Nautilus.LinAlg`) is implemented in pure Chelis — no FFI, no upstream
runtime additions required.

## Toolchain

Pinned to `chelis v0.1.3` in `reef.toml`:

```toml
compiler = "=0.1.3"
```

## Build

Download and extract the pinned tarball, then check, build, and test:

```sh
gh release download v0.1.3 \
  --repo Chelis-Lang/chelis \
  --pattern 'chelis-v0.1.3-linux-x86_64.tar.gz'
tar xzf chelis-v0.1.3-linux-x86_64.tar.gz
export PATH="$PWD/chelis-v0.1.3-linux-x86_64:$PATH"

# 1. Type-check every module in the package.
for f in src/*.ch; do chelis check "$f"; done

# 2. Build the reef package shell (.chb + .tar.zst archive).
chelis reef build

# 3. Verify scipy goldens haven't drifted (requires numpy + scipy).
python scripts/gen_goldens.py --check

# 4. End-to-end numerical parity test against scipy
#    (compiles Special + Distributions through the chelis C backend
#    and compares 331 scalar values against checked-in scipy goldens).
python tests/run_numeric_tests.py

# 5. Static export-cross-check (catches API drift between modules).
python tests/run_static_checks.py
```

CI runs all five steps. It authenticates to the sibling private
`Chelis-Lang/chelis` releases via the repo secret `CHELIS_RELEASE_TOKEN`
(a PAT with `contents: read`).

## Shipped Surface

| Module | Functions | Status |
|---|---|---|
| `Nautilus.Special` | `erf`, `erfinv`, `log_gamma`, `digamma`, `beta`, `lbeta` | scipy-parity, runtime-tested |
| `Nautilus.Distributions` | Normal, LogNormal, Uniform, Exponential, Gamma, Chi-squared, Student-t, Poisson, Binomial, Beta, F, Weibull — `pdf` / `cdf` / `inv_cdf` / `sample` where applicable | scipy-parity, runtime-tested |
| `Nautilus.LinAlg` | `transpose`, `matmul_wrap`, `gram`, `aat`, `diag`, `trace_mat`, `trace_scalar`, `l2_norm_vec`, `inner_product`, `frobenius_sq`, `frobenius_norm`, `scale_vec`, `matvec`, `vecmat`, `det_2x2`, `det_3x3`, `la_vec_add`, `la_vec_sub`, `la_vec_saxpy`, `cg_solve`, `inv_2x2`, `inv_3x3`, `solve_2x2`, `solve_3x3`, `eig_2x2_real`, `cholesky_2x2` | type-checked + reef-built; runtime numerical verification deferred until upstream ships `libchelis_runtime.a` |
| `Nautilus.Roots` | `bisection`, `newton`, `brent` over `f: f32 -> f32` | scipy-parity, runtime-tested |
| `Nautilus.ODE` | `euler_step` / `euler_solve`, `rk4_step` / `rk4_solve` over `f: f32 -> f32 -> f32` | runtime-tested vs analytic decay (RK4 ~4e-15 error at n=1000) |
| `Nautilus.Stats` | `mean_vec`, `variance_vec`, `std_vec`, `skewness_vec`, `kurtosis_vec`, `median_vec`, `covariance_scalar`, `correlation_scalar`, `min_vec`, `max_vec`, `range_vec`, `quantile_vec`, `percentile_vec`, `trimmed_mean_vec` | type-checked; runtime verification deferred with LinAlg |
| `Nautilus.Integrate` | `trapezoidal`, `simpsons`, `gauss_legendre_5`, `adaptive_simpson`, `romberg_5`, `gauss_legendre_10`, `gauss_hermite_10`, `gauss_laguerre_10` over `f: f32 -> f32` | 28 analytic-integral assertions runtime-tested |
| `Nautilus.CurveFit` | `lm_scalar_1param` — single-parameter damped Gauss-Newton curve fitting with caller-supplied model + derivative and a caller-supplied dataset | type-checked + reef-built |
| `Nautilus.Testing` | `z_statistic`, `z_p_value_*`, `normal_ci_half_width`, `chi_squared_p_value`, `t_statistic_one_sample`, `t_statistic_two_sample_pooled`, `welch_t_statistic`, `welch_t_df`, `t_p_value_two_sided`, `t_p_value_upper`, `t_p_value_lower` | runtime-tested against scipy |
| `Nautilus.Distributions` (P2.5 add) | `student_t_cdf`, `betai` / `betacf` (regularized incomplete beta via Lentz continued fraction) | runtime-tested against scipy |
| `Nautilus.Distance` | `squared_euclidean`, `euclidean`, `manhattan`, `chebyshev`, `cosine_similarity`, `cosine_distance`, `mahalanobis`, `mahalanobis_squared` | type-checked; runtime verification deferred with LinAlg |
| `Nautilus.Signal` | Typed API stubs — `fft_magnitude_stub`, `ifft_magnitude_stub`, `stft_magnitude_stub`, `lowpass_stub`, `highpass_stub`, `bandpass_stub`, `fftfreq` | spec-stub; real implementations blocked on complex numbers (Phase 5f) |
| `Nautilus.Optim` | `golden_section_search`, `brent_minimize`, `gradient_descent_1d`, `newton_minimize_1d` | runtime-tested against scipy (parabola argmin, quartic argmin) |
| `Nautilus.Interpolation` | `linear_interp_uniform`, `linear_interp_sorted`, `cubic_hermite` | `cubic_hermite` runtime-tested against scipy CubicHermiteSpline; tensor-input variants type-checked |
| `Nautilus.SDE` | `euler_maruyama_fixed`, `milstein_fixed` over scalar drift/diffusion + caller-supplied noise tensor | type-checked + reef-built; runtime verification deferred with the other tensor-input modules. The `_fixed` suffix reserves the clean `euler_maruyama` / `milstein` names for a future autonomous-sampling version once upstream exposes a scalar `Random` primitive. |

See `spec/phase3j.md` for the authoritative scope and acceptance criteria.

## License

MIT
