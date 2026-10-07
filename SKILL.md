# Nautilus SKILL.md

## 1. Identity

Nautilus is a numerical computing package for the Chelis language, written
entirely in Chelis with no foreign-function layer. It covers the ground of
`numpy.linalg`, the `numpy.random` distributions, and SciPy's `special`,
`stats`, `optimize`, `integrate`, `interpolate`, and `spatial.distance`.
`Nautilus.Special` has a `{f32, f64}` dtype-set bound and accepts f32 or
f64, and `Nautilus.Rolling` is f64 over `List[f64]`; every other module works
in f32. Section 6 lists every export with its
signature and a stability label. The one export outside those tables,
`Nautilus.Core.version`, returns the exact package-version string
(`"0.7.50"` in this source checkout).

## 2. Import Patterns

Chelis has two syntaxes. Surf is the human-facing syntax of `.ch` files. Deep
is the canonical s-expression form that Surf desugars to, printed by
`chelis deep FILE`. Imports name each function explicitly; there are no
wildcard imports.

### Surf

```chelis-fragment
import Nautilus.Special (erfinv, gamma, log_gamma, digamma, trigamma)
import Nautilus.Distributions (normal_cdf, normal_inv_cdf, normal_pdf, gamma_cdf)
import Nautilus.LinAlg (solve_2x2, inv_2x2, det_2x2, cg_solve, matvec)
import Nautilus.Stats (mean_vec, variance_vec, median_vec, covariance_scalar)
import Nautilus.Roots (brent, bisection, newton)
import Nautilus.Ode (rk4_solve, euler_solve)
import Nautilus.Integrate (adaptive_simpson, gauss_legendre_10, romberg_5)
import Nautilus.Interpolation (linear_interp_sorted, cubic_hermite)
import Nautilus.Testing (z_statistic, t_p_value_two_sided)
import Nautilus.Optim (brent_minimize, golden_section_search)
import Nautilus.Distance (euclidean, cosine_distance, mahalanobis)
import Nautilus.Sde (euler_maruyama_fixed, milstein_fixed)
import Nautilus.CurveFit (lm_scalar_1param)
```

### Deep

```deep-fragment
(import {} nautilus.special (erfinv log_gamma digamma))
(import {} nautilus.distributions (normal_cdf normal_inv_cdf gamma_cdf))
(import {} nautilus.linalg (solve_2x2 inv_2x2 cg_solve matvec))
(import {} nautilus.roots (brent bisection newton))
```

Imported functions and Chelis builtins are called by their bare names:

```deep-fragment
(app {} (var {} erf) (var {} x))
(app {} (var {} normal_cdf) (var {} z) (var {} mu) (var {} sigma))
(app {} (var {} solve_2x2) (var {} a) (var {} b))
```

## 3. Core Patterns

Four standalone modules covering the most common call shapes. Each passes
`chelis check` at score 1.0 and is byte-identical to `chelis fmt` output;
nightly CI re-checks both. The book under `docs/book/src/` has complete
examples for most of the other modules.

### Pattern 1: A special function at two precisions

Chelis provides correctly rounded `erf` and `erfc` builtins. They need no
import and accept f32 and f64 callers.

```chelis
module Nautilus.SkillSpecial
export (main, main_f64)
def main() -> f32 = erf(cast(0.5, f32))
def main_f64() -> f64 = erf(cast(0.5, f64))
```

Expected result: both return approximately 0.5205, rounded at their
respective dtypes.

The Deep form of this module, as printed by `chelis deep` with source-span
metadata removed:

```deep
(module {}
  nautilus.skillspecial
  (export {} main main_f64)
  (defsig {} main (t-fn {} (t-prim {} f32)))
  (def {}
    main
    (fn {}
      (params {})
      (app {}
        (var {} erf)
        (cast {}
          (lit {type: (t-prim {} f32)} 0.5)
          (t-prim {} f32)))))
  (defsig {} main_f64 (t-fn {} (t-prim {} f64)))
  (def {}
    main_f64
    (fn {}
      (params {})
      (app {}
        (var {} erf)
        (cast {}
          (lit {type: (t-prim {} f64)} 0.5)
          (t-prim {} f64))))))
```

### Pattern 2: Normal CDF and its inverse

`normal_cdf` delegates to `erf`; `normal_inv_cdf` uses Acklam's rational
approximation. Both take `(value, mean, std)`.

```chelis
module Nautilus.SkillNormal
import Nautilus.Distributions (normal_cdf, normal_inv_cdf)
export (main)
def main() -> f32 = {
  p = normal_cdf(cast(1.96, f32), cast(0.0, f32), cast(1.0, f32))
  x = normal_inv_cdf(p, cast(0.0, f32), cast(1.0, f32))
  add(p, x)
}
```

Expected result: `p` is approximately 0.975, `x` round-trips to approximately
1.96, and the sum is approximately 2.935.

### Pattern 3: A solver that takes a function

Brent's method finds the real root of x^3 - 2x - 5 on [2, 3]. Every solver in
Roots, Optim, Integrate, Ode, Sde, and CurveFit takes the function as an
ordinary argument: a closure `fn (x: f32) -> ...` as here, or the name of a
top-level `def`. ODE and SDE right-hand sides take two arguments, `f(y, t)`.

```chelis
module Nautilus.SkillBrent
import Nautilus.Roots (brent)
export (main)
def main() -> f32 = {
  f = fn (x: f32) -> sub(sub(mul(x, mul(x, x)), mul(cast(2.0, f32), x)), cast(5.0, f32))
  brent(f, cast(2.0, f32), cast(3.0, f32), cast(1e-8, f32), cast(100, i64))
}
```

Expected result: approximately 2.09455.

### Pattern 4: A 2x2 linear solve

`to_tensor` builds a tensor from a nested list literal. `solve_2x2` inverts
the matrix in closed form (Cayley-Hamilton) and multiplies.

```chelis
module Nautilus.SkillSolve
import Nautilus.LinAlg (solve_2x2, l2_norm_vec)
export (main)
def main() -> f32 = {
  a = to_tensor([[cast(2.0, f32), cast(1.0, f32)], [cast(1.0, f32), cast(3.0, f32)]])
  b = to_tensor([cast(5.0, f32), cast(7.0, f32)])
  l2_norm_vec(solve_2x2(a, b))
}
```

Expected result: the solution is x = [1.6, 1.8], so `main` returns its norm,
approximately 2.408.

## 4. Gotchas

- **Literals and casts.** Unsuffixed float literals are `f32` and unsuffixed
  integer literals are `i32`; there is no implicit promotion. Iteration counts
  and depths are `i64`, so write `cast(100, i64)` or `100i64`.
- **Argument conventions.** Normal distributions take `(x, mean, std)`, even
  for the standard normal. Gamma and Weibull take `(x, shape, scale)`, the
  SciPy convention. Exponential takes a `rate`, unlike SciPy's `scale`.
  Poisson and binomial counts are integer-valued `f32`.
- **Borrowed and owned tensors.** Most tensor parameters are read-only borrows
  (`&tensor` in Section 6), so one tensor can be passed to several functions
  without `copy`. A parameter written without `&` (the sampling templates,
  `cg_solve`'s inputs, `la_tridiag_solve`, the SDE noise tensor, the ODE
  grid's `y0`, `lm_scalar_nparam`'s `theta0`) takes ownership. If your
  argument is a borrowed `&tensor`, write `copy(t)` to pass a fresh owner.
- **Sampling.** The `*_sample` functions take a `key` as their first
  argument; Chelis has no randomness effect. `key_from_seed(42i64)` makes a
  reproducible root key. Each bound key has one consuming use; using it twice
  is a type error. Derive distinct children with `split_key`, `split_keys`, or
  `fold_in` for separate draws. Two fresh keys made from the same seed replay
  the same draw. The template supplies the output shape. `gamma_sample`
  requires `shape >= 1` and assigns separate keys to each element and each
  of its 64 candidate trials. It returns NaN for an element if every trial
  rejects. `chi_squared_sample` and `student_t_sample` require `df >= 2`.
- **Math builtins.** `cos`, `tan`, `atan`, `abs`, `floor`, and `ceil` are
  Chelis builtins alongside `exp`, `log`, `sin`, and `sqrt`.
- **Fixed-size LinAlg.** `inv_2x2`, `solve_3x3`, and the other closed forms
  take fixed-size tensors, so passing a 3x3 to `inv_2x2` is a type error at
  `chelis check`. The inverses and solves return NaN entries for singular
  input.
- **General-n LinAlg.** `cg_solve` needs a symmetric positive-definite matrix,
  does not check for one, and compares `tol` against the squared residual
  norm. `lu_solve` does not pivot, so a well-conditioned matrix that needs a
  row swap (for example `[[0,1],[1,0]]`) returns NaN; use it for SPD or
  strictly diagonally dominant matrices. `eig_n` assumes a symmetric input and
  does not guarantee eigenvalue order.
- **Quadrature.** `adaptive_simpson` caps `max_depth` at 30 and never halves
  the tolerance below 1e-7.
- **SDE noise.** `euler_maruyama_fixed` and `milstein_fixed` do not sample:
  the caller supplies N(0,1) noise, and its length sets the step count.
- **`lm_scalar_nparam`.** It runs exactly `max_iters` iterations (`tol` is
  accepted but unused), keeps the damping at 0.01, and builds its Jacobian by
  forward differences with `eps = 1e-5`. Scale the problem so parameters and
  predictions are roughly O(1); otherwise the perturbation can fall below one
  f32 ULP, zero a Jacobian column, and stall the fit for good.
- **`rank_vec` and NaN.** A NaN element ranks as 0.5 and the result is
  finite and wrong. Screen NaN before ranking.
- **`bessel_y1` near its seam.** It switches to the large-x form at
  x = 7.5. Just below, around x = 7.4, the absolute error is about 1.2e-4 at
  either dtype, well above the ~1e-5 quoted near its zeros.
- **Signal.** Six `Nautilus.Signal` functions named `*_stub` return NaN
  tensors until Chelis supports complex numbers
  ([`spec/scope.md`](spec/scope.md#deferrals)); `fftfreq` works.

## 5. Precision and Differentiability

**Dtypes.** `Nautilus.Special` functions have signatures like
`[prec: {f32, f64}](x: prec) -> prec`: the type parameter `prec` ranges over
exactly f32 and f64, and one call uses one dtype throughout, so
`beta(a: f32, b: f64)` is a precision mismatch. The bound rejects f16 and
bf16 at checking before their f32-tuned approximations can give wrong values
(nautilus#75). Every other module is f32-only.

**Precision.** f32 carries about seven significant digits; the Notes column in
Section 6 and `docs/book/src/appendix/precision.md` give per-function figures.
Calling Special at f64 widens the arithmetic, not the approximations. `gamma`,
`log_gamma`, `beta`, `lbeta`, `ellipk`, and `ellipe` are limited by f32
rounding and reach f64 grade. Chelis's `erf` and `erfc` are correctly rounded
builtins; they are not Nautilus exports. `airy_ai` and `airy_bi` above x = 5 gain
nothing.

**Differentiability.** `grad` is claimed only where a test exercises it:
`erf` through a concrete-dtype wrapper at f32 and f64
(`tests/special_f64.ch`) and the CurveFit Jacobian rows. A generic function
has no fixed dtype, so the point-free `grad(erf)` does not type-check; wrap it
as `def erf_at(x: f64) -> f64 = erf(x)` and take `grad(erf_at)`. Solvers built
on recursion or `fold` are not differentiable in general: with the pinned compiler,
`grad` through `rk4_solve` fails to lower because its step count is a runtime
value. `lm_scalar_nparam` keeps a finite-difference Jacobian because exact AD
through the full solver fails upstream (chelis#2370). The book's Greeks
chapter shows `grad(f, wrt=x)(args...)` working through `normal_cdf` in the
evaluator; a `grad` of a closure that captures its enclosing function's
parameters fails there with `missing required input`, so prefer the `wrt=`
form. No test yet covers that chapter.

## 6. API Surface

### API Stability Labels

Every exported function below carries a `Stability` label:

- `stable`: the signature is frozen for downstream use.
- `alpha`: the signature or behavior may still change; treat it with care.

The `Stability` column is the source of truth, and `dist/stability.json` is
the same map in machine-readable form, generated from these tables by
`scripts/extract_stability.py`. A `&` before a tensor type marks a read-only
borrow (see Section 4). `Nautilus.Core.version`, which returns the exact
package-version string, is the one export not listed here.

### Nautilus.Special (20 exports)

| Function | Signature | Stability | Notes |
|---|---|---|---|
| `erfinv` | `[prec: {f32, f64}](x: prec) -> prec` | `stable` | Acklam inverse normal + rescale, ~1e-8, domain (-1, 1) |
| `erfinv_t` | `[n, prec: {f32, f64}](x: &tensor[n, prec]) -> tensor[n, prec]` | `stable` | tensor-lane erfinv without the host List round-trip |
| `gamma` | `[prec: {f32, f64}](x: prec) -> prec` | `stable` | Lanczos (g=7) with reflection, ~1e-7 relative, +inf at non-positive integers |
| `log_gamma` | `[prec: {f32, f64}](x: prec) -> prec` | `stable` | Lanczos (g=7) with reflection, ~1e-9, +inf at non-positive integers |
| `digamma` | `[prec: {f32, f64}](x: prec) -> prec` | `stable` | Recurrence + asymptotic (x>=6), ~1e-7, NaN at non-positive integers |
| `beta` | `[prec: {f32, f64}](a: prec, b: prec) -> prec` | `stable` | exp(lbeta(a,b)), a,b > 0 |
| `lbeta` | `[prec: {f32, f64}](a: prec, b: prec) -> prec` | `stable` | Via log_gamma, a,b > 0, NaN otherwise |
| `trigamma` | `[prec: {f32, f64}](x: prec) -> prec` | `stable` | Recurrence + asymptotic (x>=6), ~1e-6, x > 0 only |
| `bessel_i0` | `[prec: {f32, f64}](x: prec) -> prec` | `stable` | Polynomial + asymptotic, crossover at 3.75, even function |
| `bessel_i1` | `[prec: {f32, f64}](x: prec) -> prec` | `stable` | Polynomial + asymptotic, crossover at 3.75, odd function |
| `bessel_k0` | `[prec: {f32, f64}](x: prec) -> prec` | `stable` | Polynomial/log + asymptotic, crossover at 2.0, x > 0, +inf at 0 |
| `bessel_k1` | `[prec: {f32, f64}](x: prec) -> prec` | `stable` | Polynomial/log + asymptotic, crossover at 2.0, x > 0, +inf at 0 |
| `bessel_j0` | `[prec: {f32, f64}](x: prec) -> prec` | `stable` | Rational polynomial + large-x trig, even function, ~1e-5 near zeros |
| `bessel_j1` | `[prec: {f32, f64}](x: prec) -> prec` | `stable` | Rational polynomial + large-x trig, odd function, ~1e-5 near zeros |
| `bessel_y0` | `[prec: {f32, f64}](x: prec) -> prec` | `stable` | Rational + log-singularity + large-x trig, x > 0, -inf at 0 |
| `bessel_y1` | `[prec: {f32, f64}](x: prec) -> prec` | `stable` | Rational + log + large-x trig, x > 0, -inf at 0, large-x branch from x = 7.5; ~1.2e-4 absolute error just below it |
| `airy_ai` | `[prec: {f32, f64}](x: prec) -> prec` | `alpha` | Power series (|x|<=5) + exponential asymptotic (x>5), oscillatory for large negative x |
| `airy_bi` | `[prec: {f32, f64}](x: prec) -> prec` | `stable` | Power series (|x|<=5) + exponential asymptotic (x>5) |
| `ellipk` | `[prec: {f32, f64}](m: prec) -> prec` | `stable` | AGM recurrence, ~1e-8, m in [0,1), +inf at m=1, NaN outside |
| `ellipe` | `[prec: {f32, f64}](m: prec) -> prec` | `stable` | AGM recurrence, ~1e-8, m in [0,1], NaN for m>1 |

### Nautilus.Distributions (43 exports)

| Function | Signature | Stability | Notes |
|---|---|---|---|
| `uniform_pdf` | `(x: f32, lo: f32, hi: f32) -> f32` | `stable` |  |
| `uniform_cdf` | `(x: f32, lo: f32, hi: f32) -> f32` | `stable` |  |
| `uniform_inv_cdf` | `(q: f32, lo: f32, hi: f32) -> f32` | `stable` |  |
| `uniform_sample` | `[n](k: key, template: tensor[n, f32], lo: f32, hi: f32) -> tensor[n, f32]` | `alpha` | Explicit key |
| `exponential_pdf` | `(x: f32, rate: f32) -> f32` | `stable` | rate param (not scale) |
| `exponential_cdf` | `(x: f32, rate: f32) -> f32` | `stable` | rate param |
| `exponential_inv_cdf` | `(q: f32, rate: f32) -> f32` | `stable` | rate param |
| `exponential_sample` | `[n](k: key, template: tensor[n, f32], rate: f32) -> tensor[n, f32]` | `alpha` | Explicit key; rate param |
| `normal_pdf` | `(x: f32, mean: f32, std: f32) -> f32` | `stable` | (mean, std) parameterization |
| `normal_cdf` | `(x: f32, mean: f32, std: f32) -> f32` | `stable` | Via erf |
| `normal_inv_cdf` | `(q: f32, mean: f32, std: f32) -> f32` | `stable` | Acklam rational approx via erfinv |
| `normal_cdf_t` | `[n](x: &tensor[n, f32], mean: f32, std: f32) -> tensor[n, f32]` | `stable` | tensor-lane normal CDF via Chelis `erf` |
| `normal_pdf_t` | `[n](x: &tensor[n, f32], mean: f32, std: f32) -> tensor[n, f32]` | `stable` | tensor-lane normal PDF |
| `normal_inv_cdf_t` | `[n](q: &tensor[n, f32], mean: f32, std: f32) -> tensor[n, f32]` | `stable` | tensor-lane inverse CDF via erfinv_t |
| `normal_sample` | `[n](k: key, template: tensor[n, f32], mean: f32, std: f32) -> tensor[n, f32]` | `alpha` | Explicit key; Box-Muller, splits its key |
| `lognormal_pdf` | `(x: f32, mu: f32, sigma: f32) -> f32` | `stable` | (mu, sigma) of underlying normal |
| `lognormal_cdf` | `(x: f32, mu: f32, sigma: f32) -> f32` | `stable` | Via normal_cdf |
| `lognormal_inv_cdf` | `(q: f32, mu: f32, sigma: f32) -> f32` | `stable` | Via normal_inv_cdf + exp |
| `lognormal_sample` | `[n](k: key, template: tensor[n, f32], mu: f32, sigma: f32) -> tensor[n, f32]` | `alpha` | Explicit key |
| `gamma_pdf` | `(x: f32, shape: f32, scale: f32) -> f32` | `stable` | (shape, scale) -- not (shape, rate) |
| `gamma_cdf` | `(x: f32, shape: f32, scale: f32) -> f32` | `stable` | Series (gammap) + continued fraction (gammaq); NaN for shape <= 0, scale <= 0 or NaN x; 1.0 at x = +inf; at and past shape 2339 at x = shape (2311 at the branch's worst x) the 200-iteration budget stops converging and the value is an unconverged partial sum (16% wrong at shape 20000) |
| `gamma_sf` | `(x: f32, shape: f32, scale: f32) -> f32` | `stable` | Survival function `1 - gamma_cdf`, computed without the cancelling subtraction; same parameter guards as `gamma_cdf`, 0.0 at x = +inf |
| `gamma_inv_cdf` | `(q: f32, shape: f32, scale: f32) -> f32` | `stable` | Wilson-Hilferty init + Newton refinement |
| `gamma_sample` | `[n](k: key, template: tensor[n, f32], shape: f32, scale: f32) -> tensor[n, f32]` | `alpha` | Explicit per-element and per-attempt keys; shape >= 1; NaN if 64 trials reject |
| `chi_squared_pdf` | `(x: f32, df: f32) -> f32` | `stable` | Via gamma_pdf(x, df/2, 2) |
| `chi_squared_cdf` | `(x: f32, df: f32) -> f32` | `stable` | Via gamma_cdf; NaN for df <= 0; inherits gamma_cdf's large-shape accuracy limit at df/2 |
| `chi_squared_sf` | `(x: f32, df: f32) -> f32` | `stable` | Via gamma_sf; keeps the right tail that `1 - chi_squared_cdf` loses; NaN for df <= 0 |
| `chi_squared_inv_cdf` | `(q: f32, df: f32) -> f32` | `stable` | Via gamma_inv_cdf |
| `chi_squared_sample` | `[n](k: key, template: tensor[n, f32], df: f32) -> tensor[n, f32]` | `alpha` | Explicit key; gamma sample with shape df/2 and scale 2; df >= 2 |
| `student_t_pdf` | `(x: f32, df: f32) -> f32` | `stable` | Via log_gamma |
| `student_t_cdf` | `(t: f32, df: f32) -> f32` | `stable` | Via regularized incomplete beta (betai), evaluated in f64 internally; relative error below 2e-6 for `df` in [1, 1e8] (worst measured 1.2e-6, at the branch boundary t = -sqrt(3)), then degrades to 51% by 1e14 and returns 0.5 from 1e16 — use `normal_cdf` above `df` ~1e9 |
| `student_t_sample` | `[n](k: key, template: tensor[n, f32], df: f32) -> tensor[n, f32]` | `alpha` | Explicit key; independent normal and chi-squared tensors; df >= 2 |
| `poisson_pmf` | `(k: f32, lambda: f32) -> f32` | `stable` | k as f32 (integer-valued), discrete PMF |
| `poisson_cdf` | `(k: f32, lambda: f32) -> f32` | `stable` | Via gamma_cdf complement, which calls the series with shape k+1 at x = lambda; inherits its large-shape accuracy limit there |
| `binomial_pmf` | `(k: f32, n: f32, p: f32) -> f32` | `stable` | k, n as f32 (integer-valued), discrete PMF |
| `binomial_cdf` | `(k: f32, n: f32, p: f32) -> f32` | `stable` | Via regularized incomplete beta (betai), evaluated in f64 internally; `n-k` and `k+1` formed in f64; relative error below 2e-6 for `n` up to 1e8 (worst measured 1.9e-7) |
| `beta_pdf` | `(x: f32, a: f32, b: f32) -> f32` | `stable` | a, b > 0 |
| `beta_cdf` | `(x: f32, a: f32, b: f32) -> f32` | `stable` | Via regularized incomplete beta (betai), evaluated in f64 internally; relative error below 2e-6 for `a` and `b` both in [1, 1e8] (worst measured 3.2e-7); it grows below 1 as well as above 1e8. A converged overshoot is clamped to [0, 1]; an exhausted budget that leaves [0, 1] returns NaN |
| `f_pdf` | `(x: f32, d1: f32, d2: f32) -> f32` | `stable` | d1, d2 degrees of freedom |
| `f_cdf` | `(x: f32, d1: f32, d2: f32) -> f32` | `stable` | Via regularized incomplete beta (betai), evaluated in f64 internally; relative error below 2e-6 for `d1` and `d2` both in [1, 1e8] (worst measured 1.2e-6, on the branch threshold) |
| `weibull_pdf` | `(x: f32, shape: f32, scale: f32) -> f32` | `stable` | (shape, scale) parameterization |
| `weibull_cdf` | `(x: f32, shape: f32, scale: f32) -> f32` | `stable` | Closed-form |
| `weibull_inv_cdf` | `(q: f32, shape: f32, scale: f32) -> f32` | `stable` | Closed-form |

### Nautilus.LinAlg (34 exports)

| Function | Signature | Stability | Notes |
|---|---|---|---|
| `transpose` | `[m, n](a: &tensor[m, n, f32]) -> tensor[n, m, f32]` | `stable` | General-n, returns tensor |
| `matmul_wrap` | `[m, k, n](a: &tensor[m, k, f32], b: &tensor[k, n, f32]) -> tensor[m, n, f32]` | `stable` | General-n, wraps builtin matmul |
| `gram` | `[m, n](a: &tensor[m, n, f32]) -> tensor[n, n, f32]` | `stable` | General-n, returns A^T A |
| `aat` | `[m, n](a: &tensor[m, n, f32]) -> tensor[m, m, f32]` | `stable` | General-n, returns A A^T |
| `diag` | `[n](a: &tensor[n, n, f32]) -> tensor[n, f32]` | `stable` | General-n, returns vector |
| `trace_mat` | `[n](a: &tensor[n, n, f32]) -> tensor[f32]` | `stable` | General-n, returns scalar tensor |
| `trace_scalar` | `[n](a: &tensor[n, n, f32]) -> f32` | `stable` | General-n, returns scalar |
| `l2_norm_vec` | `[n](v: &tensor[n, f32]) -> f32` | `stable` | General-n, returns scalar |
| `inner_product` | `[n](a: &tensor[n, f32], b: &tensor[n, f32]) -> f32` | `stable` | General-n, returns scalar |
| `frobenius_sq` | `[m, n](a: &tensor[m, n, f32]) -> f32` | `stable` | General-n, returns scalar |
| `frobenius_norm` | `[m, n](a: &tensor[m, n, f32]) -> f32` | `stable` | General-n, returns scalar |
| `scale_vec` | `[n](v: &tensor[n, f32], s: f32) -> tensor[n, f32]` | `stable` | General-n, returns tensor |
| `matvec` | `[m, n](a: &tensor[m, n, f32], v: &tensor[n, f32]) -> tensor[m, f32]` | `stable` | General-n via einsum, returns vector |
| `vecmat` | `[m, n](v: &tensor[m, f32], a: &tensor[m, n, f32]) -> tensor[n, f32]` | `stable` | General-n via einsum, returns vector |
| `det_2x2` | `(a: &tensor[2, 2, f32]) -> f32` | `stable` | Fixed 2x2, returns scalar |
| `det_3x3` | `(a: &tensor[3, 3, f32]) -> f32` | `stable` | Fixed 3x3, returns scalar |
| `la_vec_add` | `[n](a: &tensor[n, f32], b: &tensor[n, f32]) -> tensor[n, f32]` | `stable` | General-n elementwise add |
| `la_vec_sub` | `[n](a: &tensor[n, f32], b: &tensor[n, f32]) -> tensor[n, f32]` | `stable` | General-n elementwise sub |
| `la_vec_saxpy` | `[n](alpha: f32, x: &tensor[n, f32], y: &tensor[n, f32]) -> tensor[n, f32]` | `stable` | General-n, computes x + alpha*y |
| `la_basis_n_f32` | `[n](k: i64, s: f32, template: &tensor[n, f32]) -> tensor[n, f32]` | `alpha` | Basis vector scaled by `s`, using the template length; shared by CurveFit and Ode. |
| `la_zeros_mat_like` | `[n](a: &tensor[n, n, f32]) -> tensor[n, n, f32]` | `alpha` | Elementwise `a - a`; a zero matrix for finite input, preserving IEEE behavior for non-finite values. |
| `la_tridiag_solve` | `[n](lower: tensor[n, f32], diag: tensor[n, f32], upper: tensor[n, f32], b: tensor[n, f32]) -> tensor[n, f32]` | `alpha` | Shared tridiagonal solver used by cubic spline interpolation. Intended for finite inputs with elimination pivots of magnitude at least `1e-30`; smaller pivots are replaced by `1.0` without a singularity diagnostic. |
| `cg_solve` | `[n](a_mat: tensor[n, n, f32], b: tensor[n, f32], x0: tensor[n, f32], tol: f32, max_iters: i64) -> tensor[n, f32]` | `stable` | General-n conjugate gradient for SPD systems |
| `inv_2x2` | `(a: &tensor[2, 2, f32]) -> tensor[2, 2, f32]` | `stable` | Fixed 2x2, Cayley-Hamilton, NaN on singular |
| `inv_3x3` | `(a: &tensor[3, 3, f32]) -> tensor[3, 3, f32]` | `stable` | Fixed 3x3, Cayley-Hamilton, NaN on singular |
| `solve_2x2` | `(a: &tensor[2, 2, f32], b: &tensor[2, f32]) -> tensor[2, f32]` | `stable` | Fixed 2x2, via inv_2x2 + matvec |
| `solve_3x3` | `(a: &tensor[3, 3, f32], b: &tensor[3, f32]) -> tensor[3, f32]` | `stable` | Fixed 3x3, via inv_3x3 + matvec |
| `eig_2x2_real` | `(a: &tensor[2, 2, f32]) -> (f32, f32)` | `stable` | Fixed 2x2, returns tuple of eigenvalues, NaN if complex |
| `cholesky_2x2` | `(a: &tensor[2, 2, f32]) -> tensor[2, 2, f32]` | `stable` | Fixed 2x2, lower-triangular, NaN if not SPD |
| `cholesky_n` | `[n](a: &tensor[n, n, f32]) -> tensor[n, n, f32]` | `alpha` | General-n column-by-column Cholesky, lower-triangular, SPD assumed (no explicit check) |
| `lu_solve` | `[n](a: tensor[n, n, f32], b: tensor[n, f32]) -> tensor[n, f32]` | `alpha` | General-n Doolittle LU, no partial pivoting. Requires all leading submatrices of A to be nonsingular; well-conditioned matrices needing row swaps produce NaN. AD: gradients treat pivot choices as fixed. |
| `qr_decompose` | `[n](a: &tensor[n, n, f32]) -> (tensor[n, n, f32], tensor[n, n, f32])` | `alpha` | General-n Householder QR (square). Returns (Q, R): Q orthogonal, R upper triangular. AD: Householder sign choices are piecewise-smooth, not globally smooth. |
| `svd_n` | `[n](a: &tensor[n, n, f32]) -> (tensor[n, n, f32], tensor[n, f32], tensor[n, n, f32])` | `alpha` | General-n square Jacobi SVD. Returns (U, sigma, Vt). Fixed 30n sweeps; poorly-separated singular values may not fully converge. U is orthogonal only for full-rank A. AD: singular-vector bases are discontinuous at repeated singular values. |
| `eig_n` | `[n](a: &tensor[n, n, f32]) -> (tensor[n, f32], tensor[n, n, f32])` | `alpha` | Symmetric Jacobi eigendecomposition. Returns (eigenvalues, Q) where Q[:,i] is eigenvector for eigenvalue i. Fixed 30n sweeps. Requires symmetric input — non-symmetric matrices produce wrong results silently. No sorting of eigenvalues guaranteed. |

### Nautilus.Stats (28 exports)

| Function | Signature | Stability | Notes |
|---|---|---|---|
| `mean_vec` | `[n](v: &tensor[n, f32]) -> f32` | `stable` |  |
| `variance_vec` | `[n](v: &tensor[n, f32], ddof: i64) -> f32` | `stable` | ddof=0 for population, ddof=1 for sample |
| `std_vec` | `[n](v: &tensor[n, f32], ddof: i64) -> f32` | `stable` | sqrt(variance_vec) |
| `skewness_vec` | `[n](v: &tensor[n, f32]) -> f32` | `stable` | Population skewness (not adjusted) |
| `kurtosis_vec` | `[n](v: &tensor[n, f32]) -> f32` | `stable` | Excess kurtosis (subtracts 3) |
| `median_vec` | `[n](v: &tensor[n, f32]) -> f32` | `stable` | Sorts internally |
| `covariance_scalar` | `[n](a: &tensor[n, f32], b: &tensor[n, f32], ddof: i64) -> f32` | `stable` | Returns scalar covariance |
| `correlation_scalar` | `[n](a: &tensor[n, f32], b: &tensor[n, f32]) -> f32` | `stable` | Pearson r, uses ddof=0 |
| `min_vec` | `[n](v: &tensor[n, f32]) -> f32` | `stable` |  |
| `max_vec` | `[n](v: &tensor[n, f32]) -> f32` | `stable` |  |
| `range_vec` | `[n](v: &tensor[n, f32]) -> f32` | `stable` | max - min |
| `quantile_vec` | `[n](v: &tensor[n, f32], q: f32) -> f32` | `stable` | q in [0,1], linear interpolation, sorts internally |
| `percentile_vec` | `[n](v: &tensor[n, f32], p: f32) -> f32` | `stable` | p in [0,100], delegates to quantile_vec |
| `trimmed_mean_vec` | `[n](v: &tensor[n, f32], proportion: f32) -> f32` | `stable` | Trims proportion from each tail, NaN if proportion >= 0.5 |
| `rank_vec` | `[n](v: &tensor[n, f32]) -> tensor[n, f32]` | `stable` | 1-based ranks; ties share the average of the ranks they span (scipy method=average). O(n^2) pairwise counting, much slower than the sort-based reductions. Does NOT propagate NaN: a NaN element ranks 0.5 and the result is silently wrong, unlike scipy which returns all-NaN |
| `zscore_vec` | `[n](v: &tensor[n, f32], ddof: i64) -> tensor[n, f32]` | `stable` | (x - mean) / std; NaN for a constant vector |
| `bonferroni_adjust` | `[n](p_values: &tensor[n, f32]) -> tensor[n, f32]` | `alpha` | Multiplies each p-value by m (number of tests), clamped to 1 |
| `stat_holm_adjust` | `[n](p_values: &tensor[n, f32]) -> tensor[n, f32]` | `alpha` | Holm step-down adjustment over sorted p-values |
| `benjamini_hochberg_adjust` | `[n](p_values: &tensor[n, f32]) -> tensor[n, f32]` | `alpha` | Benjamini-Hochberg FDR adjustment |
| `fdr_adjust` | `[n](p_values: &tensor[n, f32]) -> tensor[n, f32]` | `alpha` | Alias for benjamini_hochberg_adjust |
| `likelihood_ratio_stat` | `(log_likelihood_null: f32, log_likelihood_alt: f32) -> f32` | `alpha` | 2 * (log L_alt - log L_null) |
| `likelihood_ratio_p_value` | `(log_likelihood_null: f32, log_likelihood_alt: f32, df: f32) -> f32` | `alpha` | Upper-tail chi-squared p-value of LR statistic |
| `covariance_2x2` | `[n](a: &tensor[n, f32], b: &tensor[n, f32], ddof: i64) -> tensor[2, 2, f32]` | `alpha` | 2x2 covariance matrix for (a, b) |
| `correlation_2x2` | `[n](a: &tensor[n, f32], b: &tensor[n, f32]) -> tensor[2, 2, f32]` | `alpha` | 2x2 Pearson correlation matrix for (a, b) |
| `covariance_matrix_2` | `[n](a: &tensor[n, f32], b: &tensor[n, f32], ddof: i64) -> tensor[2, 2, f32]` | `alpha` | Alias for covariance_2x2 |
| `correlation_matrix_2` | `[n](a: &tensor[n, f32], b: &tensor[n, f32]) -> tensor[2, 2, f32]` | `alpha` | Alias for correlation_2x2 |
| `covariance_matrix` | `[m, n](x: &tensor[m, n, f32], ddof: i64) -> tensor[m, m, f32]` | `alpha` | m variables by n observations, rows are variables (numpy.cov default) |
| `correlation_matrix` | `[m, n](x: &tensor[m, n, f32]) -> tensor[m, m, f32]` | `alpha` | Pearson correlation over m variables; a constant row gives NaN |

### Nautilus.Distance (8 exports)

| Function | Signature | Stability | Notes |
|---|---|---|---|
| `squared_euclidean` | `[n](a: &tensor[n, f32], b: &tensor[n, f32]) -> f32` | `stable` |  |
| `euclidean` | `[n](a: &tensor[n, f32], b: &tensor[n, f32]) -> f32` | `stable` | sqrt(squared_euclidean) |
| `manhattan` | `[n](a: &tensor[n, f32], b: &tensor[n, f32]) -> f32` | `stable` | L1 norm of difference |
| `chebyshev` | `[n](a: &tensor[n, f32], b: &tensor[n, f32]) -> f32` | `stable` | L-inf norm of difference |
| `cosine_similarity` | `[n](a: &tensor[n, f32], b: &tensor[n, f32]) -> f32` | `stable` | dot / (norm_a * norm_b) |
| `cosine_distance` | `[n](a: &tensor[n, f32], b: &tensor[n, f32]) -> f32` | `stable` | 1 - cosine_similarity |
| `mahalanobis_squared` | `[n](a: &tensor[n, f32], b: &tensor[n, f32], cov_inv: &tensor[n, n, f32]) -> f32` | `stable` | Caller supplies inverse covariance |
| `mahalanobis` | `[n](a: &tensor[n, f32], b: &tensor[n, f32], cov_inv: &tensor[n, n, f32]) -> f32` | `stable` | sqrt(mahalanobis_squared) |

### Nautilus.Roots (3 exports)

| Function | Signature | Stability | Notes |
|---|---|---|---|
| `bisection` | `(f: f32 -> f32, lo: f32, hi: f32, tol: f32, max_iters: i64) -> f32` | `stable` | Takes function-typed `f`; requires sign change in [lo,hi], NaN if none |
| `newton` | `(f: f32 -> f32, df: f32 -> f32, x0: f32, tol: f32, max_iters: i64) -> f32` | `stable` | Takes function-typed `f` and `df`; NaN on zero derivative or non-convergence |
| `brent` | `(f: f32 -> f32, lo: f32, hi: f32, tol: f32, max_iters: i64) -> f32` | `stable` | Takes function-typed `f`; Brent's method with IQI/secant/bisection fallback |

### Nautilus.Ode (6 exports)

| Function | Signature | Stability | Notes |
|---|---|---|---|
| `euler_step` | `(f: f32 -> f32 -> f32, y: f32, t: f32, dt: f32) -> f32` | `stable` | Single Euler step; `f` takes (y, t) via curried args |
| `euler_solve` | `(f: f32 -> f32 -> f32, y0: f32, t0: f32, t1: f32, n_steps: i64) -> f32` | `stable` | Fixed-step Euler; `f` takes (y, t), returns final y |
| `rk4_step` | `(f: f32 -> f32 -> f32, y: f32, t: f32, dt: f32) -> f32` | `stable` | Single RK4 step; `f` takes (y, t) |
| `rk4_solve` | `(f: f32 -> f32 -> f32, y0: f32, t0: f32, t1: f32, n_steps: i64) -> f32` | `stable` | Fixed-step RK4; `f` takes (y, t), returns final y |
| `rk45_adaptive_solve` | `(f: f32 -> f32 -> f32, y0: f32, t0: f32, t_end: f32, rtol: f32, atol: f32) -> f32` | `alpha` | Scalar Dormand-Prince 5(4) endpoint solve with adaptive step control; returns final y only |
| `rk45_adaptive_solve_grid` | `[n, p](f: tensor[n, f32] -> f32 -> tensor[n, f32], t0: f32, y0: tensor[n, f32], t_end: f32, rtol: f32, atol: f32, t_out: &tensor[p, f32]) -> tensor[n, p, f32]` | `alpha` | Vector Dormand-Prince 5(4) with Hermite cubic dense output. Returns state at each t_out point. t_out must be sorted ascending, all in (t0, t_end]. f takes (state, t) curried. |

### Nautilus.Integrate (8 exports)

| Function | Signature | Stability | Notes |
|---|---|---|---|
| `trapezoidal` | `(f: f32 -> f32, a: f32, b: f32, n_steps: i64) -> f32` | `stable` | Takes function-typed `f`; composite trapezoidal rule |
| `simpsons` | `(f: f32 -> f32, a: f32, b: f32, n_steps: i64) -> f32` | `stable` | Takes function-typed `f`; n_steps must be even, NaN otherwise |
| `gauss_legendre_5` | `(f: f32 -> f32, a: f32, b: f32, n_points: i64) -> f32` | `stable` | Takes function-typed `f`; 5-point Gauss-Legendre; `n_points` selects the order and must be 5, traps otherwise |
| `adaptive_simpson` | `(f: f32 -> f32, a: f32, b: f32, tol: f32, max_depth: i64) -> f32` | `stable` | Takes function-typed `f`; recursive adaptive Simpson with Richardson correction |
| `romberg_5` | `(f: f32 -> f32, a: f32, b: f32) -> f32` | `stable` | Takes function-typed `f`; 5-level Romberg (16-panel trapezoidal base) |
| `gauss_legendre_10` | `(f: f32 -> f32, a: f32, b: f32) -> f32` | `stable` | Takes function-typed `f`; 10-point Gauss-Legendre |
| `gauss_hermite_10` | `(f: f32 -> f32) -> f32` | `stable` | Takes function-typed `f`; 10-point Gauss-Hermite, integrates f(x)*exp(-x^2) over (-inf,inf) |
| `gauss_laguerre_10` | `(f: f32 -> f32) -> f32` | `stable` | Takes function-typed `f`; 10-point Gauss-Laguerre, integrates f(x)*exp(-x) over [0,inf) |

### Nautilus.Testing (13 exports)

| Function | Signature | Stability | Notes |
|---|---|---|---|
| `z_statistic` | `(sample_mean: f32, pop_mean: f32, pop_std: f32, sample_n: f32) -> f32` | `stable` |  |
| `z_p_value_two_sided` | `(z: f32) -> f32` | `stable` | `2 * Phi(-|z|)`, not `2 * (1 - Phi(|z|))` |
| `z_p_value_upper` | `(z: f32) -> f32` | `stable` | Upper-tail p-value, as `Phi(-z)` |
| `z_p_value_lower` | `(z: f32) -> f32` | `stable` | Lower-tail p-value |
| `normal_ci_half_width` | `(confidence: f32, pop_std: f32, sample_n: f32) -> f32` | `stable` | Returns margin of error |
| `chi_squared_p_value` | `(statistic: f32, df: f32) -> f32` | `stable` | Upper-tail via chi_squared_sf |
| `t_statistic_one_sample` | `(sample_mean: f32, sample_std: f32, sample_n: f32, pop_mean: f32) -> f32` | `stable` |  |
| `t_statistic_two_sample_pooled` | `(mean1: f32, std1: f32, n1: f32, mean2: f32, std2: f32, n2: f32) -> f32` | `stable` | Equal-variance pooled t |
| `t_p_value_two_sided` | `(t: f32, df: f32) -> f32` | `stable` | `2 * F(-|t|)` via student_t_cdf |
| `t_p_value_upper` | `(t: f32, df: f32) -> f32` | `stable` | Upper-tail, as `F(-t)` via student_t_cdf |
| `t_p_value_lower` | `(t: f32, df: f32) -> f32` | `stable` | Lower-tail |
| `welch_t_statistic` | `(mean1: f32, std1: f32, n1: f32, mean2: f32, std2: f32, n2: f32) -> f32` | `stable` | Unequal-variance Welch's t |
| `welch_t_df` | `(std1: f32, n1: f32, std2: f32, n2: f32) -> f32` | `stable` | Welch-Satterthwaite degrees of freedom |

### Nautilus.Optim (4 exports)

| Function | Signature | Stability | Notes |
|---|---|---|---|
| `golden_section_search` | `(f: f32 -> f32, lo: f32, hi: f32, tol: f32, max_iters: i64) -> f32` | `stable` | Takes function-typed `f`; finds minimizer in [lo,hi] |
| `brent_minimize` | `(f: f32 -> f32, lo: f32, hi: f32, tol: f32, max_iters: i64) -> f32` | `stable` | Takes function-typed `f`; Brent's minimization with parabolic interpolation |
| `gradient_descent_1d` | `(f: f32 -> f32, df: f32 -> f32, x0: f32, lr: f32, max_iters: i64) -> f32` | `stable` | Takes function-typed `f` and `df`; fixed learning rate, NaN on divergence |
| `newton_minimize_1d` | `(f: f32 -> f32, df: f32 -> f32, ddf: f32 -> f32, x0: f32, tol: f32, max_iters: i64) -> f32` | `alpha` | Takes function-typed `f`, `df`, `ddf`; requires certifiable positive curvature at the point it stops on |

### Nautilus.Interpolation (5 exports)

| Function | Signature | Stability | Notes |
|---|---|---|---|
| `linear_interp_uniform` | `[n](ys: &tensor[n, f32], x_min: f32, x_max: f32, x_query: f32) -> f32` | `stable` | Uniformly-spaced knots, clamped extrapolation |
| `linear_interp_sorted` | `[n](xs: &tensor[n, f32], ys: &tensor[n, f32], x_query: f32) -> f32` | `stable` | Arbitrary sorted knots, flat extrapolation outside range |
| `cubic_hermite` | `(x0: f32, x1: f32, y0: f32, y1: f32, m0: f32, m1: f32, x_query: f32) -> f32` | `stable` | Single-interval cubic Hermite spline, caller supplies tangents m0/m1 |
| `spline_eval` | `[m](xs: &tensor[m, f32], ys: &tensor[m, f32], x_query: f32) -> f32` | `alpha` | Natural cubic spline fit + eval in one call. Clamped extrapolation (returns ys[0] or ys[m-1] outside range). xs must be sorted ascending. Every call recomputes M; avoid in tight loops. |
| `spline_fit` | `[m](xs: &tensor[m, f32], ys: &tensor[m, f32]) -> tensor[m, f32]` | `alpha` | Returns second-derivative vector M (length m). Natural BCs: M[0]=M[m-1]=0. Exposed for inspection; use spline_eval for evaluation. |

### Nautilus.Sde (2 exports)

| Function | Signature | Stability | Notes |
|---|---|---|---|
| `euler_maruyama_fixed` | `[n](f: f32 -> f32 -> f32, g: f32 -> f32 -> f32, y0: f32, t0: f32, t1: f32, noise: tensor[n, f32]) -> f32` | `alpha` | Caller supplies pre-drawn N(0,1) noise tensor; `f` is drift, `g` is diffusion, both take (y, t) |
| `milstein_fixed` | `[n](f: f32 -> f32 -> f32, g: f32 -> f32 -> f32, dg_dy: f32 -> f32 -> f32, y0: f32, t0: f32, t1: f32, noise: tensor[n, f32]) -> f32` | `alpha` | Caller supplies noise + diffusion derivative `dg_dy`; Milstein correction term included |

### Nautilus.CurveFit (2 exports)

| Function | Signature | Stability | Notes |
|---|---|---|---|
| `lm_scalar_1param` | `[n](model: f32 -> f32 -> f32, dmodel: f32 -> f32 -> f32, xs: &tensor[n, f32], ys: &tensor[n, f32], theta0: f32, lambda0: f32, tol: f32, max_iters: i64) -> f32` | `alpha` | Levenberg-Marquardt for single-parameter models; `model(x, theta)` and `dmodel(x, theta)` are function-typed |
| `lm_scalar_nparam` | `[n, m](model: &tensor[n, f32] -> &tensor[m, f32] -> tensor[m, f32], x: &tensor[m, f32], y: &tensor[m, f32], theta0: tensor[n, f32], tol: f32, max_iters: i64) -> tensor[n, f32]` | `alpha` | Multi-parameter LM via finite-difference Jacobian (eps=1e-5); `tol` accepted but unused (runs full `max_iters`); lambda fixed at 0.01; full AD replacement is tracked by `chelis#2370` |

### Nautilus.Signal (7 exports -- 6 stubs + `fftfreq`)

The six `*_stub` rows return NaN tensors until Chelis supports complex numbers; see
[`spec/scope.md`](spec/scope.md#deferrals).

| Function | Signature | Stability | Notes |
|---|---|---|---|
| `fft_magnitude_stub` | `[n](x: &tensor[n, f32]) -> tensor[n, f32]` | `alpha` | Stub: returns NaN tensor |
| `ifft_magnitude_stub` | `[n](x: &tensor[n, f32]) -> tensor[n, f32]` | `alpha` | Stub: returns NaN tensor |
| `stft_magnitude_stub` | `[n](x: &tensor[n, f32], window_size: i64, hop_size: i64) -> tensor[n, f32]` | `alpha` | Stub: returns NaN tensor |
| `lowpass_stub` | `[n](x: &tensor[n, f32], cutoff_hz: f32, sample_rate: f32) -> tensor[n, f32]` | `alpha` | Stub: returns NaN tensor |
| `highpass_stub` | `[n](x: &tensor[n, f32], cutoff_hz: f32, sample_rate: f32) -> tensor[n, f32]` | `alpha` | Stub: returns NaN tensor |
| `bandpass_stub` | `[n](x: &tensor[n, f32], low_hz: f32, high_hz: f32, sample_rate: f32) -> tensor[n, f32]` | `alpha` | Stub: returns NaN tensor |
| `fftfreq` | `[n](x: &tensor[n, f32], sample_rate: f32) -> tensor[n, f32]` | `alpha` | Functional: computes FFT frequency bins (no complex math needed) |

### Nautilus.Info (3 exports)

| Function | Signature | Stability | Notes |
|---|---|---|---|
| `entropy` | `[n](p: &tensor[n, f32]) -> f32` | `alpha` | Shannon entropy of a probability vector; zero-probability terms contribute 0 |
| `distribution_cross_entropy` | `[n](p: &tensor[n, f32], q: &tensor[n, f32]) -> f32` | `alpha` | Cross-entropy H(p, q); zero-probability terms in p contribute 0 |
| `kl_divergence` | `[n](p: &tensor[n, f32], q: &tensor[n, f32]) -> f32` | `alpha` | Kullback-Leibler divergence KL(p || q); zero-probability terms in p contribute 0 |

### Nautilus.Optimize (3 exports)

| Function | Signature | Stability | Notes |
|---|---|---|---|
| `minimize` | `(f: f32 -> f32, lo: f32, hi: f32, tol: f32, max_iters: i64) -> f32` | `alpha` | Bracketed 1D minimizer; delegates to brent_minimize |
| `root` | `(f: f32 -> f32, lo: f32, hi: f32, tol: f32, max_iters: i64) -> f32` | `alpha` | Bracketed 1D root finder; delegates to brent |
| `optimize_ad_smoke` | `(x: f32) -> f32` | `alpha` | Smoke target (x - 2)^2 used to exercise AD through Nautilus.Optimize |

### Nautilus.StateSpace (6 exports)

| Function | Signature | Stability | Notes |
|---|---|---|---|
| `kalman_predict_scalar` | `(mean: f32, covariance: f32, transition: f32, process_var: f32, control: f32, control_input: f32) -> (f32, f32)` | `alpha` | Scalar Kalman predict step; returns (predicted_mean, predicted_covariance) |
| `kalman_update_scalar` | `(predicted_mean: f32, predicted_covariance: f32, observation: f32, observation_matrix: f32, observation_var: f32) -> (f32, f32, f32)` | `alpha` | Scalar Kalman update; returns (updated_mean, updated_covariance, gain) |
| `kalman_step_scalar` | `(mean: f32, covariance: f32, observation: f32, transition: f32, process_var: f32, observation_matrix: f32, observation_var: f32) -> (f32, f32, f32)` | `alpha` | Predict + update fused into one scalar step |
| `local_level_predict` | `(mean: f32, covariance: f32, process_var: f32) -> (f32, f32)` | `alpha` | Local-level model predict (transition=1, no control) |
| `local_level_update` | `(predicted_mean: f32, predicted_covariance: f32, observation: f32, observation_var: f32) -> (f32, f32, f32)` | `alpha` | Local-level model update (observation_matrix=1) |
| `local_level_step` | `(mean: f32, covariance: f32, observation: f32, process_var: f32, observation_var: f32) -> (f32, f32, f32)` | `alpha` | Local-level predict+update step |

### Nautilus.Rolling (34 exports)

The one f64 module, and the one that answers "no value here" with `Option`
rather than a NaN sentinel. Warm-up and `min_periods` match pandas for
NaN-free, finite input -- a non-finite input value is a value here and
propagates, where pandas treats NaN as missing; the
`shift`, `diff` and `pct_change` family is defined at every `k` the index
arithmetic can represent, where a negative `k` is pandas' lead. `parity/goldens/rolling.json` records what pandas answers
and `scripts/check_rolling_parity.py` replays it. Reductions re-reduce each
window rather than carrying a running accumulator, so a variance stays exact
on a large mean with a small spread at O(window) per position.

| Function | Signature | Stability | Notes |
|---|---|---|---|
| `rolling_sum` | `(xs: List[f64], window: i64, min_periods: i64) -> List[Option[f64]]` | `alpha` | Rolling sum; `None` while fewer than `min_periods` observations |
| `rolling_mean` | `(xs: List[f64], window: i64, min_periods: i64) -> List[Option[f64]]` | `alpha` | Rolling arithmetic mean over the available window |
| `rolling_var` | `(xs: List[f64], window: i64, min_periods: i64, ddof: i64) -> List[Option[f64]]` | `alpha` | Rolling variance about the window mean; `ddof` 1 is pandas' default. A window whose observation count is not above `ddof` is `Some(NaN)`, as in pandas |
| `rolling_std` | `(xs: List[f64], window: i64, min_periods: i64, ddof: i64) -> List[Option[f64]]` | `alpha` | Square root of `rolling_var` at the same arguments |
| `rolling_min` | `(xs: List[f64], window: i64, min_periods: i64) -> List[Option[f64]]` | `alpha` | Rolling minimum; O(window) per position, not a monotonic deque |
| `rolling_max` | `(xs: List[f64], window: i64, min_periods: i64) -> List[Option[f64]]` | `alpha` | Rolling maximum; O(window) per position, not a monotonic deque |
| `expanding_sum` | `(xs: List[f64], min_periods: i64) -> List[Option[f64]]` | `alpha` | Sum of every observation up to each position |
| `expanding_mean` | `(xs: List[f64], min_periods: i64) -> List[Option[f64]]` | `alpha` | Mean of every observation up to each position |
| `expanding_var` | `(xs: List[f64], min_periods: i64, ddof: i64) -> List[Option[f64]]` | `alpha` | Expanding variance about the running mean; a count not above `ddof` is `Some(NaN)`, as in pandas |
| `expanding_std` | `(xs: List[f64], min_periods: i64, ddof: i64) -> List[Option[f64]]` | `alpha` | Square root of `expanding_var` at the same arguments |
| `expanding_min` | `(xs: List[f64], min_periods: i64) -> List[Option[f64]]` | `alpha` | Running minimum |
| `expanding_max` | `(xs: List[f64], min_periods: i64) -> List[Option[f64]]` | `alpha` | Running maximum |
| `shift` | `(xs: List[f64], k: i64) -> List[Option[f64]]` | `alpha` | `out[i] = xs[i - k]`; `None` off either end. Defined except for the `len(xs)` most negative `k`, which overflow the index |
| `shift_fill` | `(xs: List[f64], k: i64, fill: f64) -> List[f64]` | `alpha` | `shift` with a named pad value, so the result carries no `Option` |
| `shift_clamped` | `(xs: List[f64], k: i64) -> List[f64]` | `alpha` | `shift` clamped to the first and last observation |
| `diff` | `(xs: List[f64], k: i64) -> List[Option[f64]]` | `alpha` | `out[i] = xs[i] - xs[i - k]`; a negative `k` is a forward difference |
| `pct_change` | `(xs: List[f64], k: i64) -> List[Option[f64]]` | `alpha` | `(xs[i] - xs[i - k]) / xs[i - k]`; a zero base is a present infinity, or NaN when the numerator is zero too |
| `tensor_rolling_sum` | `[n](xs: &tensor[n, f64], window: i64, min_periods: i64) -> List[Option[f64]]` | `alpha` | Converts with `to_list` and delegates to `rolling_sum` |
| `tensor_rolling_mean` | `[n](xs: &tensor[n, f64], window: i64, min_periods: i64) -> List[Option[f64]]` | `alpha` | Converts with `to_list` and delegates to `rolling_mean` |
| `tensor_rolling_var` | `[n](xs: &tensor[n, f64], window: i64, min_periods: i64, ddof: i64) -> List[Option[f64]]` | `alpha` | Converts with `to_list` and delegates to `rolling_var` |
| `tensor_rolling_std` | `[n](xs: &tensor[n, f64], window: i64, min_periods: i64, ddof: i64) -> List[Option[f64]]` | `alpha` | Converts with `to_list` and delegates to `rolling_std` |
| `tensor_rolling_min` | `[n](xs: &tensor[n, f64], window: i64, min_periods: i64) -> List[Option[f64]]` | `alpha` | Converts with `to_list` and delegates to `rolling_min` |
| `tensor_rolling_max` | `[n](xs: &tensor[n, f64], window: i64, min_periods: i64) -> List[Option[f64]]` | `alpha` | Converts with `to_list` and delegates to `rolling_max` |
| `tensor_expanding_sum` | `[n](xs: &tensor[n, f64], min_periods: i64) -> List[Option[f64]]` | `alpha` | Converts with `to_list` and delegates to `expanding_sum` |
| `tensor_expanding_mean` | `[n](xs: &tensor[n, f64], min_periods: i64) -> List[Option[f64]]` | `alpha` | Converts with `to_list` and delegates to `expanding_mean` |
| `tensor_expanding_var` | `[n](xs: &tensor[n, f64], min_periods: i64, ddof: i64) -> List[Option[f64]]` | `alpha` | Converts with `to_list` and delegates to `expanding_var` |
| `tensor_expanding_std` | `[n](xs: &tensor[n, f64], min_periods: i64, ddof: i64) -> List[Option[f64]]` | `alpha` | Converts with `to_list` and delegates to `expanding_std` |
| `tensor_expanding_min` | `[n](xs: &tensor[n, f64], min_periods: i64) -> List[Option[f64]]` | `alpha` | Converts with `to_list` and delegates to `expanding_min` |
| `tensor_expanding_max` | `[n](xs: &tensor[n, f64], min_periods: i64) -> List[Option[f64]]` | `alpha` | Converts with `to_list` and delegates to `expanding_max` |
| `tensor_shift` | `[n](xs: &tensor[n, f64], k: i64) -> List[Option[f64]]` | `alpha` | Converts with `to_list` and delegates to `shift` |
| `tensor_shift_fill` | `[n](xs: &tensor[n, f64], k: i64, fill: f64) -> tensor[n, f64]` | `alpha` | Delegates to `shift_fill`; returns a tensor because the result has no absent position |
| `tensor_shift_clamped` | `[n](xs: &tensor[n, f64], k: i64) -> tensor[n, f64]` | `alpha` | Delegates to `shift_clamped`; returns a tensor because the result has no absent position |
| `tensor_diff` | `[n](xs: &tensor[n, f64], k: i64) -> List[Option[f64]]` | `alpha` | Converts with `to_list` and delegates to `diff` |
| `tensor_pct_change` | `[n](xs: &tensor[n, f64], k: i64) -> List[Option[f64]]` | `alpha` | Converts with `to_list` and delegates to `pct_change` |

### Nautilus.TimeSeries (7 exports)

| Function | Signature | Stability | Notes |
|---|---|---|---|
| `ts_ewma_next` | `[n](values: &tensor[n, f32], alpha: f32, initial: f32) -> f32` | `alpha` | Exponentially weighted moving average; returns final level |
| `ts_ewma_series` | `[n](values: &tensor[n, f32], alpha: f32, initial: f32) -> tensor[n, f32]` | `alpha` | EWMA over the full series; returns per-step levels |
| `exponential_smoothing_next` | `[n](values: &tensor[n, f32], alpha: f32, initial_level: f32) -> f32` | `alpha` | Simple exponential smoothing; delegates to ts_ewma_next |
| `exponential_smoothing_series` | `[n](values: &tensor[n, f32], alpha: f32, initial_level: f32) -> tensor[n, f32]` | `alpha` | Simple exponential smoothing series; delegates to ts_ewma_series |
| `ar1_predict_next` | `[n](values: &tensor[n, f32], intercept: f32, phi: f32) -> f32` | `alpha` | AR(1) one-step-ahead point forecast |
| `arma11_predict_next` | `[n](values: &tensor[n, f32], intercept: f32, phi: f32, theta: f32, last_error: f32) -> f32` | `alpha` | ARMA(1,1) one-step-ahead point forecast |
| `arima110_predict_next` | `[n](values: &tensor[n, f32], drift: f32, phi: f32, theta: f32, last_error: f32) -> f32` | `alpha` | ARIMA(1,1,0) one-step-ahead point forecast on first-differenced series |
