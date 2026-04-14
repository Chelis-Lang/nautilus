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
| `Nautilus.Distributions` | Normal, LogNormal, Uniform, Exponential, Gamma, Chi-squared, Student-t — `pdf` / `cdf` / `inv_cdf` / `sample` | scipy-parity, runtime-tested |
| `Nautilus.LinAlg` | `transpose`, `matmul_wrap`, `gram`, `aat`, `diag`, `trace_mat`, `trace_scalar`, `l2_norm_vec`, `inner_product`, `frobenius_sq`, `frobenius_norm`, `scale_vec`, `matvec`, `vecmat`, `det_2x2`, `det_3x3` | type-checked + reef-built; runtime numerical verification deferred until upstream ships `libchelis_runtime.a` |
| `Nautilus.Roots` | `bisection`, `newton`, `brent` over `f: f32 -> f32` | scipy-parity, runtime-tested |
| `Nautilus.ODE` | `euler_step` / `euler_solve`, `rk4_step` / `rk4_solve` over `f: f32 -> f32 -> f32` | runtime-tested vs analytic decay (RK4 ~4e-15 error at n=1000) |
| `Nautilus.Stats` | `mean_vec`, `variance_vec`, `std_vec`, `skewness_vec`, `kurtosis_vec`, `median_vec`, `covariance_scalar`, `correlation_scalar` | type-checked; runtime verification deferred with LinAlg |
| `Nautilus.Optim` | — | deferred to P1.5 (needs general-n solve — candidate: `cg_solve` via LinAlg) |

See `spec/phase3j.md` for the authoritative scope and acceptance criteria.

## License

MIT
