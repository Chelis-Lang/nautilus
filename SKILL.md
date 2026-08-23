# Nautilus SKILL.md

## 1. Identity

Nautilus is the numerical computing shell for Chelis. It replaces
numpy.linalg + numpy.random distributions + scipy.* (special, stats,
optimize, integrate, interpolate, spatial). The current surface has 192
exports: 185 numerical/library entries, 1 `Nautilus.Core.version` metadata
helper, and 6 explicit `Nautilus.Signal` stubs (`fftfreq` is functional).
The native gate `chelis test tests/` is 463/463 clean and the reviewed
`parity/run_parity.py --strict` subset is 216/216 against scipy. Nautilus is
pure Chelis throughout; AD is claimed only for surfaces with executable
gradient coverage, not automatically for every solver or decomposition.

## 2. Import Patterns

### Surf

```chelis-fragment
import Nautilus.Special (erf, erfc, erfinv, gamma, log_gamma, digamma, trigamma)
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
(import {} nautilus.special (erf erfinv log_gamma digamma))
(import {} nautilus.distributions (normal_cdf normal_inv_cdf gamma_cdf))
(import {} nautilus.linalg (solve_2x2 inv_2x2 cg_solve matvec))
(import {} nautilus.stats (mean_vec variance_vec median_vec))
(import {} nautilus.roots (brent bisection newton))
(import {} nautilus.ode (rk4_solve euler_solve))
```

After import, functions are available as bare names:

```deep-fragment
(app {} (var {} erf) (var {} x))
(app {} (var {} normal_cdf) (var {} z) (var {} mu) (var {} sigma))
(app {} (var {} solve_2x2) (var {} a) (var {} b))

## 3. Core Patterns

This section provides 15 standalone patterns covering Nautilus's major modules.
Each pattern was validated with `chelis check` (score 1.0 on all four components:
parse, structure, names, types) and lowered to Deep with `chelis deep`.

---

### Pattern 1: Special Function Evaluation

Evaluate the error function at a single point. `erf` uses the Abramowitz & Stegun
rational approximation and handles sign symmetry internally.

```chelis
module Nautilus.Pat01
import Nautilus.Special (erf)
export (main)

def main() -> f32 = erf(cast(0.5, f32))
```

```deep
(module {}
  nautilus.pat01
  (import {} nautilus.special (erf))
  (export {} main)
  (defsig {} main (t-fn {} (t-prim {} f32)))
  (def {}
    main
    (fn {}
      (params {})
      (app {}
        (var {} erf)
        (cast {} (lit {type: (t-prim {} f32)} 0.5) (t-prim {} f32))))))
```

Expected result: approximately 0.5205.

---

### Pattern 2: Normal CDF and Inverse

Compute `normal_cdf(1.96, 0, 1)` and then round-trip through `normal_inv_cdf`.
The CDF delegates to `erf`; the inverse uses Acklam's rational approximation.

```chelis
module Nautilus.Pat02
import Nautilus.Distributions (normal_cdf, normal_inv_cdf)
export (main)

def main() -> f32 = {
  p = normal_cdf(cast(1.96, f32), cast(0.0, f32), cast(1.0, f32))
  x = normal_inv_cdf(p, cast(0.0, f32), cast(1.0, f32))
  add(p, x)
}
```

```deep
(module {}
  nautilus.pat02
  (import {} nautilus.distributions (normal_cdf normal_inv_cdf))
  (export {} main)
  (defsig {} main (t-fn {} (t-prim {} f32)))
  (def {}
    main
    (fn {}
      (params {})
      (let {}
        (bind {}
          p
          (app {}
            (var {} normal_cdf)
            (cast {} (lit {type: (t-prim {} f32)} 1.96) (t-prim {} f32))
            (cast {} (lit {type: (t-prim {} f32)} 0.0) (t-prim {} f32))
            (cast {} (lit {type: (t-prim {} f32)} 1.0) (t-prim {} f32))))
        (let {}
          (bind {}
            x
            (app {}
              (var {} normal_inv_cdf)
              (var {} p)
              (cast {} (lit {type: (t-prim {} f32)} 0.0) (t-prim {} f32))
              (cast {} (lit {type: (t-prim {} f32)} 1.0) (t-prim {} f32))))
          (app {} (var {} add) (var {} p) (var {} x)))))))
```

Expected result: p is approximately 0.975; x round-trips to approximately 1.96;
sum is approximately 2.935.

---

### Pattern 3: Gamma CDF

Evaluate the regularized lower incomplete gamma function via the series expansion
in `gammap`. The `gamma_cdf` function divides by the scale before dispatching.

```chelis
module Nautilus.Pat03
import Nautilus.Distributions (gamma_cdf)
export (main)

def main() -> f32 = gamma_cdf(cast(2.0, f32), cast(1.0, f32), cast(3.0, f32))
```

```deep
(module {}
  nautilus.pat03
  (import {} nautilus.distributions (gamma_cdf))
  (export {} main)
  (defsig {} main (t-fn {} (t-prim {} f32)))
  (def {}
    main
    (fn {}
      (params {})
      (app {}
        (var {} gamma_cdf)
        (cast {} (lit {type: (t-prim {} f32)} 2.0) (t-prim {} f32))
        (cast {} (lit {type: (t-prim {} f32)} 1.0) (t-prim {} f32))
        (cast {} (lit {type: (t-prim {} f32)} 3.0) (t-prim {} f32))))))
```

Expected result: approximately 0.4866 (Gamma CDF with shape=1, scale=3, at x=2).

---

### Pattern 4: Black-Scholes Call Price

Compute a European call option price using the Black-Scholes formula. The pattern
composes `log`, `exp`, `sqrt`, and `normal_cdf` -- no `cos` builtin needed.

```chelis
module Nautilus.Pat04
import Nautilus.Distributions (normal_cdf)
export (main)

def black_scholes_call(s: f32, k: f32, r: f32, sigma: f32, t: f32) -> f32 = {
  sqrt_t = sqrt(t)
  d1_num = add(log(div(s, k)), mul(add(r, mul(cast(0.5, f32), mul(sigma, sigma))), t))
  d1 = div(d1_num, mul(sigma, sqrt_t))
  d2 = sub(d1, mul(sigma, sqrt_t))
  nd1 = normal_cdf(d1, cast(0.0, f32), cast(1.0, f32))
  nd2 = normal_cdf(d2, cast(0.0, f32), cast(1.0, f32))
  discount = exp(neg(mul(r, t)))
  sub(mul(s, nd1), mul(mul(k, discount), nd2))
}

def main() -> f32 = black_scholes_call(
  cast(100.0, f32), cast(100.0, f32),
  cast(0.05, f32), cast(0.2, f32), cast(1.0, f32)
)
```

```deep
(module {}
  nautilus.pat04
  (import {} nautilus.distributions (normal_cdf))
  (export {} main)
  (defsig {}
    black_scholes_call
    (t-fn {}
      (t-prim {} f32)
      (t-prim {} f32)
      (t-prim {} f32)
      (t-prim {} f32)
      (t-prim {} f32)
      (t-prim {} f32)))
  (def {}
    black_scholes_call
    (fn {}
      (params {}
        (s {type: (t-prim {} f32)})
        (k {type: (t-prim {} f32)})
        (r {type: (t-prim {} f32)})
        (sigma {type: (t-prim {} f32)})
        (t {type: (t-prim {} f32)}))
      (let {}
        (bind {} sqrt_t (app {} (var {} sqrt) (var {} t)))
        (let {}
          (bind {}
            d1_num
            (app {} (var {} add)
              (app {} (var {} log) (app {} (var {} div) (var {} s) (var {} k)))
              (app {} (var {} mul)
                (app {} (var {} add) (var {} r)
                  (app {} (var {} mul)
                    (cast {} (lit {type: (t-prim {} f32)} 0.5) (t-prim {} f32))
                    (app {} (var {} mul) (var {} sigma) (var {} sigma))))
                (var {} t))))
          (let {}
            (bind {} d1
              (app {} (var {} div) (var {} d1_num)
                (app {} (var {} mul) (var {} sigma) (var {} sqrt_t))))
            (let {}
              (bind {} d2
                (app {} (var {} sub) (var {} d1)
                  (app {} (var {} mul) (var {} sigma) (var {} sqrt_t))))
              (let {}
                (bind {} nd1
                  (app {} (var {} normal_cdf) (var {} d1)
                    (cast {} (lit {type: (t-prim {} f32)} 0.0) (t-prim {} f32))
                    (cast {} (lit {type: (t-prim {} f32)} 1.0) (t-prim {} f32))))
                (let {}
                  (bind {} nd2
                    (app {} (var {} normal_cdf) (var {} d2)
                      (cast {} (lit {type: (t-prim {} f32)} 0.0) (t-prim {} f32))
                      (cast {} (lit {type: (t-prim {} f32)} 1.0) (t-prim {} f32))))
                  (let {}
                    (bind {} discount
                      (app {} (var {} exp)
                        (app {} (var {} neg)
                          (app {} (var {} mul) (var {} r) (var {} t)))))
                    (app {} (var {} sub)
                      (app {} (var {} mul) (var {} s) (var {} nd1))
                      (app {} (var {} mul)
                        (app {} (var {} mul) (var {} k) (var {} discount))
                        (var {} nd2))))))))))))
  (defsig {} main (t-fn {} (t-prim {} f32)))
  (def {}
    main
    (fn {}
      (params {})
      (app {}
        (var {} black_scholes_call)
        (cast {} (lit {type: (t-prim {} f32)} 100.0) (t-prim {} f32))
        (cast {} (lit {type: (t-prim {} f32)} 100.0) (t-prim {} f32))
        (cast {} (lit {type: (t-prim {} f32)} 0.05) (t-prim {} f32))
        (cast {} (lit {type: (t-prim {} f32)} 0.2) (t-prim {} f32))
        (cast {} (lit {type: (t-prim {} f32)} 1.0) (t-prim {} f32))))))
```

Expected result: approximately 10.45 (ATM call, S=K=100, r=5%, sigma=20%, T=1y).

---

### Pattern 5: 2x2 Linear Solve

Solve a 2x2 system Ax = b using Cayley-Hamilton inversion. The function
takes tensor inputs and returns a scalar (the first element of the solution).

```chelis
module Nautilus.Pat05
import Nautilus.LinAlg (solve_2x2, l2_norm_vec)
export (main)

def demo_solve(a: tensor[2, 2, f32], b: tensor[2, f32]) -> f32 =
  l2_norm_vec(solve_2x2(a, b))

def main() -> f32 = cast(0.0, f32)
```

```deep
(module {}
  nautilus.pat05
  (import {} nautilus.linalg (solve_2x2 inner_product))
  (export {} main)
  (defsig {} main (t-fn {} (t-prim {} f32)))
  (def {}
    main
    (fn {}
      (params {})
      (let {}
        (bind {} a
          (app {} (var {} to_tensor)
            (app {} (var {} Cons)
              (app {} (var {} Cons)
                (cast {} (lit {type: (t-prim {} f32)} 2.0) (t-prim {} f32))
                (app {} (var {} Cons)
                  (cast {} (lit {type: (t-prim {} f32)} 1.0) (t-prim {} f32))
                  (var {} Nil)))
              (app {} (var {} Cons)
                (app {} (var {} Cons)
                  (cast {} (lit {type: (t-prim {} f32)} 1.0) (t-prim {} f32))
                  (app {} (var {} Cons)
                    (cast {} (lit {type: (t-prim {} f32)} 3.0) (t-prim {} f32))
                    (var {} Nil)))
                (var {} Nil)))))
        (let {}
          (bind {} b
            (app {} (var {} to_tensor)
              (app {} (var {} Cons)
                (cast {} (lit {type: (t-prim {} f32)} 5.0) (t-prim {} f32))
                (app {} (var {} Cons)
                  (cast {} (lit {type: (t-prim {} f32)} 7.0) (t-prim {} f32))
                  (var {} Nil)))))
          (let {}
            (bind {} x (app {} (var {} solve_2x2) (var {} a) (var {} b)))
            (let {}
              (bind {} e1
                (app {} (var {} to_tensor)
                  (app {} (var {} Cons)
                    (cast {} (lit {type: (t-prim {} f32)} 1.0) (t-prim {} f32))
                    (app {} (var {} Cons)
                      (cast {} (lit {type: (t-prim {} f32)} 0.0) (t-prim {} f32))
                      (var {} Nil)))))
              (app {} (var {} inner_product) (var {} x) (var {} e1)))))))))
```

Expected result: the first component of x is 1.6 (the system [[2,1],[1,3]]x = [5,7]
has solution x = [1.6, 1.8]).

---

### Pattern 6: Root Finding with Brent's Method

Find a root of x^3 - 2x - 5 on [2, 3] using Brent's method, which combines
inverse quadratic interpolation, secant, and bisection with superlinear convergence.

```chelis
module Nautilus.Pat06
import Nautilus.Roots (brent)
export (main)

def main() -> f32 = {
  f = fn (x: f32) -> sub(sub(mul(x, mul(x, x)), mul(cast(2.0, f32), x)), cast(5.0, f32))
  brent(f, cast(2.0, f32), cast(3.0, f32), cast(1.0e-8, f32), cast(100, int64))
}
```

```deep
(module {}
  nautilus.pat06
  (import {} nautilus.roots (brent))
  (export {} main)
  (defsig {} main (t-fn {} (t-prim {} f32)))
  (def {}
    main
    (fn {}
      (params {})
      (let {}
        (bind {} f
          (fn {}
            (params {} (x {type: (t-prim {} f32)}))
            (app {} (var {} sub)
              (app {} (var {} sub)
                (app {} (var {} mul) (var {} x)
                  (app {} (var {} mul) (var {} x) (var {} x)))
                (app {} (var {} mul)
                  (cast {} (lit {type: (t-prim {} f32)} 2.0) (t-prim {} f32))
                  (var {} x)))
              (cast {} (lit {type: (t-prim {} f32)} 5.0) (t-prim {} f32)))))
        (app {} (var {} brent) (var {} f)
          (cast {} (lit {type: (t-prim {} f32)} 2.0) (t-prim {} f32))
          (cast {} (lit {type: (t-prim {} f32)} 3.0) (t-prim {} f32))
          (cast {} (lit {type: (t-prim {} f32)} 0.00000001) (t-prim {} f32))
          (cast {} (lit {type: (t-prim {} int32)} 100) (t-prim {} int64)))))))
```

Expected result: approximately 2.09455 (the real root of x^3 - 2x - 5).

---

### Pattern 7: ODE Integration with RK4

Solve dy/dt = -y, y(0) = 1 over [0, 1] with 100 RK4 steps. The drift
function takes `(y: f32, t: f32) -> f32` with both arguments explicit.

```chelis
module Nautilus.Pat07
import Nautilus.Ode (rk4_solve)
export (main)

def decay(y: f32, t: f32) -> f32 = neg(y)

def main() -> f32 =
  rk4_solve(decay, cast(1.0, f32), cast(0.0, f32), cast(1.0, f32), cast(100, int64))
```

```deep
(module {}
  nautilus.pat07
  (import {} nautilus.ode (rk4_solve))
  (export {} main)
  (defsig {} main (t-fn {} (t-prim {} f32)))
  (def {}
    main
    (fn {}
      (params {})
      (let {}
        (bind {} dydt
          (fn {}
            (params {} (y {type: (t-prim {} f32)}))
            (fn {}
              (params {} (t {type: (t-prim {} f32)}))
              (app {} (var {} neg) (var {} y)))))
        (app {} (var {} rk4_solve) (var {} dydt)
          (cast {} (lit {type: (t-prim {} f32)} 1.0) (t-prim {} f32))
          (cast {} (lit {type: (t-prim {} f32)} 0.0) (t-prim {} f32))
          (cast {} (lit {type: (t-prim {} f32)} 1.0) (t-prim {} f32))
          (cast {} (lit {type: (t-prim {} int32)} 100) (t-prim {} int64)))))))
```

Expected result: approximately 0.36788 (e^{-1}, the exact solution at t=1).

---

### Pattern 8: Adaptive Simpson Integration

Integrate exp(-x^2) over [0, 1] using adaptive Simpson's rule with Richardson
extrapolation. The recursion halves the tolerance and subdivides until the error
estimate drops below 15 * tol.

```chelis
module Nautilus.Pat08
import Nautilus.Integrate (adaptive_simpson)
export (main)

def main() -> f32 = {
  f = fn (x: f32) -> exp(neg(mul(x, x)))
  adaptive_simpson(f, cast(0.0, f32), cast(1.0, f32), cast(1.0e-8, f32), cast(20, int64))
}
```

```deep
(module {}
  nautilus.pat08
  (import {} nautilus.integrate (adaptive_simpson))
  (export {} main)
  (defsig {} main (t-fn {} (t-prim {} f32)))
  (def {}
    main
    (fn {}
      (params {})
      (let {}
        (bind {} f
          (fn {}
            (params {} (x {type: (t-prim {} f32)}))
            (app {} (var {} exp)
              (app {} (var {} neg)
                (app {} (var {} mul) (var {} x) (var {} x))))))
        (app {} (var {} adaptive_simpson) (var {} f)
          (cast {} (lit {type: (t-prim {} f32)} 0.0) (t-prim {} f32))
          (cast {} (lit {type: (t-prim {} f32)} 1.0) (t-prim {} f32))
          (cast {} (lit {type: (t-prim {} f32)} 0.00000001) (t-prim {} f32))
          (cast {} (lit {type: (t-prim {} int32)} 20) (t-prim {} int64)))))))
```

Expected result: approximately 0.74682 (sqrt(pi)/2 * erf(1)).

---

### Pattern 9: Descriptive Statistics

Compute the mean and sample variance of a tensor. Both functions are polymorphic
over the tensor length `n`. The `copy(data)` is required because `mean_vec` and
`variance_vec` each consume the linear-typed tensor.

```chelis
module Nautilus.Pat09
import Nautilus.Stats (mean_vec, variance_vec)
export (main)

def demo_stats[n](data: tensor[n, f32]) -> f32 = {
  mu = mean_vec(copy(data))
  v = variance_vec(data, cast(1, int64))
  add(mu, v)
}

def main() -> f32 = cast(0.0, f32)
```

```deep
(module {}
  nautilus.pat09
  (import {} nautilus.stats (mean_vec variance_vec))
  (export {} main)
  (defsig {}
    demo_stats
    (t-fn {} (t-tensor {} (d-var {} n) (t-prim {} f32)) (t-prim {} f32)))
  (def {}
    demo_stats
    (fn {}
      (params {} (data {type: (t-tensor {} (d-var {} n) (t-prim {} f32))}))
      (let {}
        (bind {} mu (app {} (var {} mean_vec) (copy {} (var {} data))))
        (let {}
          (bind {} v
            (app {} (var {} variance_vec) (var {} data)
              (cast {} (lit {type: (t-prim {} int32)} 1) (t-prim {} int64))))
          (app {} (var {} add) (var {} mu) (var {} v))))))
  (defsig {} main (t-fn {} (t-prim {} f32)))
  (def {}
    main
    (fn {}
      (params {})
      (cast {} (lit {type: (t-prim {} f32)} 0.0) (t-prim {} f32)))))
```

Expected result: `demo_stats` returns mean + sample variance of its input tensor.
The standalone `main` returns 0.0 (dummy).

---

### Pattern 10: Hypothesis Testing (Z-test)

Compute a z-statistic and its two-sided p-value. The z-test composes
`z_statistic` (which computes (x_bar - mu) / (sigma / sqrt(n))) with
`z_p_value_two_sided` (which calls `normal_cdf` on the absolute value).

```chelis
module Nautilus.Pat10
import Nautilus.Testing (z_statistic, z_p_value_two_sided)
export (main)

def main() -> f32 = {
  z = z_statistic(cast(5.2, f32), cast(5.0, f32), cast(1.5, f32), cast(36.0, f32))
  p = z_p_value_two_sided(z)
  add(z, p)
}
```

```deep
(module {}
  nautilus.pat10
  (import {} nautilus.testing (z_statistic z_p_value_two_sided))
  (export {} main)
  (defsig {} main (t-fn {} (t-prim {} f32)))
  (def {}
    main
    (fn {}
      (params {})
      (let {}
        (bind {} z
          (app {} (var {} z_statistic)
            (cast {} (lit {type: (t-prim {} f32)} 5.2) (t-prim {} f32))
            (cast {} (lit {type: (t-prim {} f32)} 5.0) (t-prim {} f32))
            (cast {} (lit {type: (t-prim {} f32)} 1.5) (t-prim {} f32))
            (cast {} (lit {type: (t-prim {} f32)} 36.0) (t-prim {} f32))))
        (let {}
          (bind {} p (app {} (var {} z_p_value_two_sided) (var {} z)))
          (app {} (var {} add) (var {} z) (var {} p)))))))
```

Expected result: z is 0.8 (SE = 1.5/6 = 0.25, z = 0.2/0.25); p is approximately
0.4237; sum is approximately 1.2237.

---

### Pattern 11: Cubic Hermite Interpolation

Interpolate on a single interval [0, 1] with endpoint values y0=0, y1=1 and
slopes m0=m1=1. The Hermite basis functions ensure C1 continuity and exact
reproduction of linear data.

```chelis
module Nautilus.Pat11
import Nautilus.Interpolation (cubic_hermite)
export (main)

def main() -> f32 = {
  x0 = cast(0.0, f32)
  x1 = cast(1.0, f32)
  y0 = cast(0.0, f32)
  y1 = cast(1.0, f32)
  m0 = cast(1.0, f32)
  m1 = cast(1.0, f32)
  cubic_hermite(x0, x1, y0, y1, m0, m1, cast(0.5, f32))
}
```

```deep
(module {}
  nautilus.pat11
  (import {} nautilus.interpolation (cubic_hermite))
  (export {} main)
  (defsig {} main (t-fn {} (t-prim {} f32)))
  (def {}
    main
    (fn {}
      (params {})
      (let {}
        (bind {} x0
          (cast {} (lit {type: (t-prim {} f32)} 0.0) (t-prim {} f32)))
        (let {}
          (bind {} x1
            (cast {} (lit {type: (t-prim {} f32)} 1.0) (t-prim {} f32)))
          (let {}
            (bind {} y0
              (cast {} (lit {type: (t-prim {} f32)} 0.0) (t-prim {} f32)))
            (let {}
              (bind {} y1
                (cast {} (lit {type: (t-prim {} f32)} 1.0) (t-prim {} f32)))
              (let {}
                (bind {} m0
                  (cast {} (lit {type: (t-prim {} f32)} 1.0) (t-prim {} f32)))
                (let {}
                  (bind {} m1
                    (cast {} (lit {type: (t-prim {} f32)} 1.0) (t-prim {} f32)))
                  (app {} (var {} cubic_hermite)
                    (var {} x0) (var {} x1) (var {} y0) (var {} y1)
                    (var {} m0) (var {} m1)
                    (cast {} (lit {type: (t-prim {} f32)} 0.5) (t-prim {} f32))))))))))))
```

Expected result: 0.5 (with matching slopes, Hermite reduces to linear interpolation).

---

### Pattern 12: Curve Fitting (Levenberg-Marquardt, 1 Parameter)

Fit a linear model f(x, theta) = theta * x to data using the scalar
Levenberg-Marquardt optimizer. The derivative dmodel returns x (d/d_theta of
theta*x). The function is polymorphic over data length `n`.

```chelis
module Nautilus.Pat12
import Nautilus.CurveFit (lm_scalar_1param)
export (main)

def linear_model(x: f32, theta: f32) -> f32 = mul(theta, x)
def linear_dmodel(x: f32, theta: f32) -> f32 = x

def demo_fit[n](xs: tensor[n, f32], ys: tensor[n, f32]) -> f32 =
  lm_scalar_1param(linear_model, linear_dmodel, xs, ys,
    cast(0.0, f32), cast(0.01, f32), cast(1.0e-8, f32), cast(100, int64))

def main() -> f32 = cast(0.0, f32)
```

```deep
(module {}
  nautilus.pat12
  (import {} nautilus.curvefit (lm_scalar_1param))
  (export {} main)
  (defsig {}
    demo_fit
    (t-fn {}
      (t-tensor {} (d-var {} n) (t-prim {} f32))
      (t-tensor {} (d-var {} n) (t-prim {} f32))
      (t-prim {} f32)))
  (def {}
    demo_fit
    (fn {}
      (params {}
        (xs {type: (t-tensor {} (d-var {} n) (t-prim {} f32))})
        (ys {type: (t-tensor {} (d-var {} n) (t-prim {} f32))}))
      (let {}
        (bind {} model
          (fn {}
            (params {} (x {type: (t-prim {} f32)}))
            (fn {}
              (params {} (theta {type: (t-prim {} f32)}))
              (app {} (var {} mul) (var {} theta) (var {} x)))))
        (let {}
          (bind {} dmodel
            (fn {}
              (params {} (x {type: (t-prim {} f32)}))
              (fn {}
                (params {} (theta {type: (t-prim {} f32)}))
                (var {} x))))
          (app {} (var {} lm_scalar_1param)
            (var {} model) (var {} dmodel) (var {} xs) (var {} ys)
            (cast {} (lit {type: (t-prim {} f32)} 0.0) (t-prim {} f32))
            (cast {} (lit {type: (t-prim {} f32)} 0.01) (t-prim {} f32))
            (cast {} (lit {type: (t-prim {} f32)} 0.00000001) (t-prim {} f32))
            (cast {} (lit {type: (t-prim {} int32)} 100) (t-prim {} int64)))))))
  (defsig {} main (t-fn {} (t-prim {} f32)))
  (def {}
    main
    (fn {}
      (params {})
      (cast {} (lit {type: (t-prim {} f32)} 0.0) (t-prim {} f32)))))
```

Expected result: `demo_fit` converges to the least-squares slope. The standalone
`main` returns 0.0 (dummy).

---

### Pattern 13: SDE via Euler-Maruyama

Simulate the Ornstein-Uhlenbeck-like SDE dY = -Y dt + 0.1 dW using
`euler_maruyama_fixed`. The noise tensor is caller-supplied (enabling
reproducible paths). The function is polymorphic over the noise length `n`.

```chelis
module Nautilus.Pat13
import Nautilus.Sde (euler_maruyama_fixed)
export (main)

def em_drift(y: f32, t: f32) -> f32 = neg(y)
def em_diffusion(y: f32, t: f32) -> f32 = cast(0.1, f32)

def demo_em[n](noise: tensor[n, f32]) -> f32 =
  euler_maruyama_fixed(em_drift, em_diffusion,
    cast(1.0, f32), cast(0.0, f32), cast(1.0, f32), noise)

def main() -> f32 = cast(0.0, f32)
```

```deep
(module {}
  nautilus.pat13
  (import {} nautilus.sde (euler_maruyama_fixed))
  (export {} main)
  (defsig {}
    demo_em
    (t-fn {} (t-tensor {} (d-var {} n) (t-prim {} f32)) (t-prim {} f32)))
  (def {}
    demo_em
    (fn {}
      (params {} (noise {type: (t-tensor {} (d-var {} n) (t-prim {} f32))}))
      (let {}
        (bind {} drift
          (fn {}
            (params {} (y {type: (t-prim {} f32)}))
            (fn {}
              (params {} (t {type: (t-prim {} f32)}))
              (app {} (var {} neg) (var {} y)))))
        (let {}
          (bind {} diffusion
            (fn {}
              (params {} (y {type: (t-prim {} f32)}))
              (fn {}
                (params {} (t {type: (t-prim {} f32)}))
                (cast {} (lit {type: (t-prim {} f32)} 0.1) (t-prim {} f32)))))
          (app {} (var {} euler_maruyama_fixed)
            (var {} drift) (var {} diffusion)
            (cast {} (lit {type: (t-prim {} f32)} 1.0) (t-prim {} f32))
            (cast {} (lit {type: (t-prim {} f32)} 0.0) (t-prim {} f32))
            (cast {} (lit {type: (t-prim {} f32)} 1.0) (t-prim {} f32))
            (var {} noise))))))
  (defsig {} main (t-fn {} (t-prim {} f32)))
  (def {}
    main
    (fn {}
      (params {})
      (cast {} (lit {type: (t-prim {} f32)} 0.0) (t-prim {} f32)))))
```

Expected result: `demo_em` returns the terminal SDE value at t=1. With zero noise,
the result would be approximately e^{-1}. The standalone `main` returns 0.0 (dummy).

---

### Pattern 14: Euclidean Distance

Compute the L2 distance between two vectors. The function is polymorphic over
length `n` and delegates to `squared_euclidean` + `sqrt` internally.

```chelis
module Nautilus.Pat14
import Nautilus.Distance (euclidean)
export (main)

def demo_euclidean[n](a: tensor[n, f32], b: tensor[n, f32]) -> f32 =
  euclidean(a, b)

def main() -> f32 = cast(0.0, f32)
```

```deep
(module {}
  nautilus.pat14
  (import {} nautilus.distance (euclidean))
  (export {} main)
  (defsig {}
    demo_euclidean
    (t-fn {}
      (t-tensor {} (d-var {} n) (t-prim {} f32))
      (t-tensor {} (d-var {} n) (t-prim {} f32))
      (t-prim {} f32)))
  (def {}
    demo_euclidean
    (fn {}
      (params {}
        (a {type: (t-tensor {} (d-var {} n) (t-prim {} f32))})
        (b {type: (t-tensor {} (d-var {} n) (t-prim {} f32))}))
      (app {} (var {} euclidean) (var {} a) (var {} b))))
  (defsig {} main (t-fn {} (t-prim {} f32)))
  (def {}
    main
    (fn {}
      (params {})
      (cast {} (lit {type: (t-prim {} f32)} 0.0) (t-prim {} f32)))))
```

Expected result: `demo_euclidean` returns sqrt(sum((a_i - b_i)^2)). The standalone
`main` returns 0.0 (dummy).

---

### Pattern 15: Gauss-Legendre 10-Point Integration

Integrate sin(x) over [0, pi] using the 10-point Gauss-Legendre quadrature rule.
The pre-tabulated nodes and weights give high accuracy for smooth integrands
without adaptive subdivision.

```chelis
module Nautilus.Pat15
import Nautilus.Integrate (gauss_legendre_10)
export (main)

def main() -> f32 = {
  f = fn (x: f32) -> sin(x)
  pi = cast(3.141592653589793, f32)
  gauss_legendre_10(f, cast(0.0, f32), pi)
}
```

```deep
(module {}
  nautilus.pat15
  (import {} nautilus.integrate (gauss_legendre_10))
  (export {} main)
  (defsig {} main (t-fn {} (t-prim {} f32)))
  (def {}
    main
    (fn {}
      (params {})
      (let {}
        (bind {} f
          (fn {}
            (params {} (x {type: (t-prim {} f32)}))
            (app {} (var {} sin) (var {} x))))
        (let {}
          (bind {} pi
            (cast {}
              (lit {type: (t-prim {} f32)} 3.141592653589793)
              (t-prim {} f32)))
          (app {} (var {} gauss_legendre_10) (var {} f)
            (cast {} (lit {type: (t-prim {} f32)} 0.0) (t-prim {} f32))
            (var {} pi)))))))
```

Expected result: approximately 2.0 (the exact integral of sin(x) from 0 to pi).

(app {} (var {} rk4_solve) (var {} f) (var {} y0) (var {} t0) (var {} t1) (var {} n))
```

## 4. Module Quick Reference

### Nautilus.Special
Special mathematical functions. All pure, f32, no effects.
Key exports: `erf`, `erfc`, `erfinv`, `gamma`, `log_gamma`, `digamma`, `trigamma`, `beta`, `lbeta`.
Bessel: `bessel_j0`, `bessel_j1`, `bessel_y0`, `bessel_y1`, `bessel_i0`, `bessel_i1`, `bessel_k0`, `bessel_k1`.
Airy: `airy_ai`, `airy_bi`. Elliptic: `ellipk`, `ellipe`.
Precision varies by function (1e-9 for log_gamma to 1e-5 near Bessel zeros). See section 6 for per-function notes.

### Nautilus.Distributions
12 distribution families. Each provides some subset of: `pdf`, `cdf`, `inv_cdf`, `sample`.
Parameter conventions: Normal takes `(x, mean, std)`. Gamma takes `(x, shape, scale)` not rate.
`sample` variants carry `! { Random }` effect. Normal/LogNormal/Uniform/Exponential have all four.
Gamma/Chi-squared/Student-t have PDF+CDF (some have inv_cdf). Poisson/Binomial have PMF+CDF.
`normal_cdf` and `normal_inv_cdf` are the most commonly called for Black-Scholes, VaR, hypothesis testing.

### Nautilus.LinAlg
Fixed-size closed-form linear algebra: `inv_2x2`, `inv_3x3`, `solve_2x2`, `solve_3x3`,
`det_2x2`, `det_3x3`, `cholesky_2x2`, `eig_2x2_real`.
General-n (alpha): `cholesky_n`, `lu_solve`, `qr_decompose`, `svd_n`, `eig_n`.
`lu_solve[n](a, b)` — Doolittle LU, no pivoting; requires non-zero diagonal pivots.
`qr_decompose[n](a)` — Householder QR, returns `(Q, R)` tuple, Q orthogonal, R upper triangular.
`svd_n[n](a)` — Jacobi SVD, returns `(U, sigma, Vt)`, fixed 30n sweeps.
General-n solvers: `cg_solve` (conjugate gradient for SPD systems), `matvec`, `vecmat`, `matmul_wrap`.
Vector ops: `la_vec_add`, `la_vec_sub`, `la_vec_saxpy`, `scale_vec`, `l2_norm_vec`, `inner_product`.
Matrix ops: `gram`, `aat`, `transpose`, `diag`, `trace_mat`, `trace_scalar`, `frobenius_norm`, `frobenius_sq`.
All are pure Chelis tensor-op composition. Primitive adjoints remain available,
but do not assume every recursive or fold-based decomposition supports `grad`;
only surfaces with executable gradient coverage are advertised as differentiable.

### Nautilus.Stats
Descriptive statistics over `tensor[n, f32]` inputs. All return `f32`.
Central: `mean_vec`, `variance_vec(v, ddof)`, `std_vec(v, ddof)`.
Shape: `skewness_vec`, `kurtosis_vec` (Fisher convention, biased).
Order: `median_vec`, `min_vec`, `max_vec`, `range_vec`, `quantile_vec(v, q)`, `percentile_vec(v, p)`, `trimmed_mean_vec(v, proportion)`.
Two-sample: `covariance_scalar(a, b, ddof)`, `correlation_scalar(a, b)`.

### Nautilus.Roots
Three root-finders, all taking `f: f32 -> f32`:
`bisection(f, a, b, tol, max_iters)` for bracketed roots.
`newton(f, df, x0, tol, max_iters)` with user-supplied derivative.
`brent(f, a, b, tol, max_iters)` with full Brent-Dekker IQI.

### Nautilus.Ode
Fixed-step ODE solvers taking `f: f32 -> f32 -> f32` (dy/dt = f(y, t)):
`euler_step`, `euler_solve(f, y0, t0, t1, n_steps)`.
`rk4_step`, `rk4_solve(f, y0, t0, t1, n_steps)`.
Broad AD through the recursive solver surface is follow-up work, not a shipped
blanket guarantee; require an executable gradient oracle before relying on it.
`rk45_adaptive_solve_grid`: vector ODE solver returning state at caller-supplied output times. `t_out` must be sorted ascending with all values in `(t0, t_end]`. Uses Dormand-Prince Hermite cubic dense output for interpolation.

### Nautilus.Integrate
Quadrature taking `f: f32 -> f32`:
Fixed: `trapezoidal(f, a, b, n)`, `simpsons(f, a, b, n)`.
Gaussian: `gauss_legendre_5(f, a, b)`, `gauss_legendre_10(f, a, b)`.
Adaptive: `adaptive_simpson(f, a, b, tol, max_depth)`, `romberg_5(f, a, b)`.
Specialized: `gauss_hermite_10(f)` for integrals with `e^{-x^2}` weight, `gauss_laguerre_10(f)` for `e^{-x}` weight.

### Nautilus.Interpolation
`linear_interp_uniform(ys, x_min, x_max, x_query)` on a uniform grid.
`linear_interp_sorted(xs, ys, x_query)` on a sorted non-uniform grid.
`cubic_hermite(x0, x1, y0, y1, m0, m1, x)` single-interval Hermite cubic.
`spline_eval(xs, ys, x_query)` — natural cubic spline; clamped extrapolation outside [xs[0], xs[m-1]]. Every call recomputes the spline coefficients; cache xs/ys if calling repeatedly.
`spline_fit(xs, ys)` — returns the m second-derivative values M used by the spline. Not needed for evaluation; exposed for inspection or AD.

### Nautilus.Testing
Hypothesis test building blocks:
z-tests: `z_statistic`, `z_p_value_two_sided`, `z_p_value_upper`, `z_p_value_lower`, `normal_ci_half_width`.
t-tests: `t_statistic_one_sample`, `t_statistic_two_sample_pooled`, `welch_t_statistic`, `welch_t_df`.
p-values: `t_p_value_two_sided`, `t_p_value_upper`, `t_p_value_lower`.
Chi-squared: `chi_squared_p_value`.

### Nautilus.Optim
Scalar 1D optimization:
`golden_section_search(f, a, b, tol, max_iters)` for unimodal f on [a,b].
`brent_minimize(f, a, b, tol, max_iters)` safeguarded parabolic + golden section.
`gradient_descent_1d(f, df, x0, lr, max_iters)`.
`newton_minimize_1d(f, df, ddf, x0, tol, max_iters)` with strong-convexity check.

### Nautilus.Distance
Vector distance metrics taking two `tensor[n, f32]` inputs:
`squared_euclidean`, `euclidean`, `manhattan`, `chebyshev`.
`cosine_similarity`, `cosine_distance`.
`mahalanobis(a, b, cov_inv)`, `mahalanobis_squared(a, b, cov_inv)` with covariance-inverse matrix.

### Nautilus.Sde
Stochastic ODE solvers with caller-supplied noise tensor:
`euler_maruyama_fixed(drift, diffusion, y0, t0, t1, noise)`.
`milstein_fixed(drift, diffusion, dg_dy, y0, t0, t1, noise)`.
Both take `f32 -> f32 -> f32` drift and diffusion functions. Noise tensor length determines step count.

### Nautilus.CurveFit
`lm_scalar_1param(model, dmodel, xs, ys, theta0, lambda0, tol, max_iters)`.
Levenberg-Marquardt for single-parameter curve fitting. `model(x, theta) -> y` and `dmodel(x, theta) -> dy/dtheta`.

`lm_scalar_nparam(model, x, y, theta0, tol, max_iters)`.
Levenberg-Marquardt for multi-parameter curve fitting. `model` is curried: `model(theta)(x_data)` predicts the m-vector of y values. Uses a finite-difference Jacobian (eps=1e-5) while generic and concrete arbitrary-model AD wrappers remain blocked by `chelis#676`'s malformed backward-DAG layer. The `tol` parameter is accepted for API compatibility but convergence runs for exactly `max_iters` iterations. Damping lambda is fixed at 0.01.

### Nautilus.Signal
Six typed transform/filter stubs return NaN; `fftfreq` is functional. The dated deferral is `spec/phase3j.md` § Explicit Deferrals (accepted 2026-07-14) and remains gated on Phase 5f complex-number support.

## 5. Gotchas

- All Nautilus functions operate in f32. Do not pass f64 tensors.

- As of chelis v0.1.7, `cos`, `tan`, `abs`, `floor`, and `ceil` are builtins.
  Use them directly: `cos(x)`, `abs(x)`, `floor(x)`. Earlier versions required
  workarounds like `sin(add(x, pi/2))` for cos, but these are no longer needed.

- Distribution `sample` functions carry `! { Random }` effect. You must handle it
  or propagate it in your function's effect signature.

- `normal_cdf` takes `(x, mean, std)`, not just `(x)`. For the standard normal, pass `(x, cast(0.0, f32), cast(1.0, f32))`.

- `gamma_cdf` takes `(x, shape, scale)`, not `(x, shape, rate)`. This matches scipy's convention.

- `cg_solve` requires a symmetric positive-definite matrix. Non-SPD input diverges silently.

- LinAlg closed-forms (`inv_2x2`, `solve_3x3`, etc.) take fixed-size tensors.
  `inv_2x2(a_3x3)` is a dimension error (enforced by chelis check since v0.1.6).

- `adaptive_simpson` max_depth bounds recursion. Default to 15-20 for safety.

- Bessel `y1` has ~1e-3 drift near x in (7.5, 8) due to f32 coefficient precision at the branch seam.

- `euler_maruyama_fixed` and `milstein_fixed` take a caller-supplied noise tensor.
  The noise tensor's length determines the number of timesteps. These do NOT sample internally.

- Tensor arguments follow Chelis linear-use discipline. Use `copy(t)` when a tensor is consumed more than once.

- `lm_scalar_nparam` runs for exactly `max_iters` iterations — the `tol` parameter is accepted for API compatibility but does not trigger early exit. Damping `lambda` is fixed at `0.01`. For well-scaled problems with `theta0` near the optimum, 50–200 iterations converge. The finite-difference Jacobian is the cited temporary narrowing in `chelis#676`; it uses `eps=1e-5`. If model outputs or parameters are larger than ~100, scale inputs so that the model is O(1) — once a Jacobian column goes to zero in f32 due to ULP cancellation, increasing `max_iters` does not help and the solver stalls permanently; only rescaling the problem escapes this condition.

- `lu_solve` requires every leading principal submatrix of `A` to be nonsingular. A well-conditioned matrix that needs one row swap (e.g., `[[0,1],[1,0]]`) will divide by zero and return NaN. Matrices that are SPD or strictly diagonally dominant are safe. If in doubt, use `cg_solve` for SPD systems.

## 6. API Surface

### API Stability Labels

Every exported API row below carries an explicit `Stability` label per the cross-cutting
decision in `chelis/spec/design/chelis_canonical_reference.md`:

- `stable` — signature is treated as API-frozen for downstream use and corpus ingestion.
- `alpha` — signature or behavior caveats remain under active review; exclude or down-weight it.

The `Stability` column is the source of truth for row-level classification. Use
`dist/stability.json` when a downstream consumer needs the machine-readable surface.

### Nautilus.Special (21 exports)

| Function | Signature | Stability | Notes |
|---|---|---|---|
| `erf` | `(x: f32) -> f32` | `stable` | Horner rational approx, ~1e-7 relative, all reals |
| `erfc` | `(x: f32) -> f32` | `stable` | `1 - erf(x)`, same precision domain as `erf` |
| `erfinv` | `(x: f32) -> f32` | `stable` | Acklam inverse normal + rescale, ~1e-8, domain (-1, 1) |
| `gamma` | `(x: f32) -> f32` | `stable` | Lanczos (g=7) with reflection, ~1e-7 relative, +inf at non-positive integers |
| `log_gamma` | `(x: f32) -> f32` | `stable` | Lanczos (g=7) with reflection, ~1e-9, +inf at non-positive integers |
| `digamma` | `(x: f32) -> f32` | `stable` | Recurrence + asymptotic (x>=6), ~1e-7, NaN at non-positive integers |
| `beta` | `(a: f32, b: f32) -> f32` | `stable` | exp(lbeta(a,b)), a,b > 0 |
| `lbeta` | `(a: f32, b: f32) -> f32` | `stable` | Via log_gamma, a,b > 0, NaN otherwise |
| `trigamma` | `(x: f32) -> f32` | `stable` | Recurrence + asymptotic (x>=6), ~1e-6, x > 0 only |
| `bessel_i0` | `(x: f32) -> f32` | `stable` | Polynomial + asymptotic, crossover at 3.75, even function |
| `bessel_i1` | `(x: f32) -> f32` | `stable` | Polynomial + asymptotic, crossover at 3.75, odd function |
| `bessel_k0` | `(x: f32) -> f32` | `stable` | Polynomial/log + asymptotic, crossover at 2.0, x > 0, +inf at 0 |
| `bessel_k1` | `(x: f32) -> f32` | `stable` | Polynomial/log + asymptotic, crossover at 2.0, x > 0, +inf at 0 |
| `bessel_j0` | `(x: f32) -> f32` | `stable` | Rational polynomial + large-x trig, even function, ~1e-5 near zeros |
| `bessel_j1` | `(x: f32) -> f32` | `stable` | Rational polynomial + large-x trig, odd function, ~1e-5 near zeros |
| `bessel_y0` | `(x: f32) -> f32` | `stable` | Rational + log-singularity + large-x trig, x > 0, -inf at 0 |
| `bessel_y1` | `(x: f32) -> f32` | `stable` | Rational + log + large-x trig, x > 0, -inf at 0, large-x branch starts at 7.5 to avoid the old seam drift |
| `airy_ai` | `(x: f32) -> f32` | `alpha` | Power series (|x|<=5) + exponential asymptotic (x>5), oscillatory for large negative x |
| `airy_bi` | `(x: f32) -> f32` | `stable` | Power series (|x|<=5) + exponential asymptotic (x>5) |
| `ellipk` | `(m: f32) -> f32` | `stable` | AGM recurrence, ~1e-8, m in [0,1), +inf at m=1, NaN outside |
| `ellipe` | `(m: f32) -> f32` | `stable` | AGM recurrence, ~1e-8, m in [0,1], NaN for m>1 |

### Nautilus.Distributions (38 exports)

| Function | Signature | Stability | Notes |
|---|---|---|---|
| `uniform_pdf` | `(x: f32, lo: f32, hi: f32) -> f32` | `stable` |  |
| `uniform_cdf` | `(x: f32, lo: f32, hi: f32) -> f32` | `stable` |  |
| `uniform_inv_cdf` | `(q: f32, lo: f32, hi: f32) -> f32` | `stable` |  |
| `uniform_sample` | `[n](template: tensor[n, f32], lo: f32, hi: f32) -> tensor[n, f32] ! { Random }` | `alpha` | Effect: Random |
| `exponential_pdf` | `(x: f32, rate: f32) -> f32` | `stable` | rate param (not scale) |
| `exponential_cdf` | `(x: f32, rate: f32) -> f32` | `stable` | rate param |
| `exponential_inv_cdf` | `(q: f32, rate: f32) -> f32` | `stable` | rate param |
| `exponential_sample` | `[n](template: tensor[n, f32], rate: f32) -> tensor[n, f32] ! { Random }` | `alpha` | Effect: Random; rate param |
| `normal_pdf` | `(x: f32, mean: f32, std: f32) -> f32` | `stable` | (mean, std) parameterization |
| `normal_cdf` | `(x: f32, mean: f32, std: f32) -> f32` | `stable` | Via erf |
| `normal_inv_cdf` | `(q: f32, mean: f32, std: f32) -> f32` | `stable` | Acklam rational approx via erfinv |
| `normal_sample` | `[n](template: tensor[n, f32], mean: f32, std: f32) -> tensor[n, f32] ! { Random }` | `alpha` | Effect: Random; Box-Muller |
| `lognormal_pdf` | `(x: f32, mu: f32, sigma: f32) -> f32` | `stable` | (mu, sigma) of underlying normal |
| `lognormal_cdf` | `(x: f32, mu: f32, sigma: f32) -> f32` | `stable` | Via normal_cdf |
| `lognormal_inv_cdf` | `(q: f32, mu: f32, sigma: f32) -> f32` | `stable` | Via normal_inv_cdf + exp |
| `lognormal_sample` | `[n](template: tensor[n, f32], mu: f32, sigma: f32) -> tensor[n, f32] ! { Random }` | `alpha` | Effect: Random |
| `gamma_pdf` | `(x: f32, shape: f32, scale: f32) -> f32` | `stable` | (shape, scale) -- not (shape, rate) |
| `gamma_cdf` | `(x: f32, shape: f32, scale: f32) -> f32` | `stable` | Series (gammap) + continued fraction (gammaq) |
| `gamma_inv_cdf` | `(q: f32, shape: f32, scale: f32) -> f32` | `stable` | Wilson-Hilferty init + Newton refinement |
| `gamma_sample` | `[n](template: tensor[n, f32], shape: f32, scale: f32) -> tensor[n, f32] ! { Random }` | `alpha` | Effect: Random; Marsaglia-Tsang, shape >= 1 |
| `chi_squared_pdf` | `(x: f32, df: f32) -> f32` | `stable` | Via gamma_pdf(x, df/2, 2) |
| `chi_squared_cdf` | `(x: f32, df: f32) -> f32` | `stable` | Via gamma_cdf |
| `chi_squared_inv_cdf` | `(q: f32, df: f32) -> f32` | `stable` | Via gamma_inv_cdf |
| `chi_squared_sample` | `[n](template: tensor[n, f32], df: f32) -> tensor[n, f32] ! { Random }` | `alpha` | Effect: Random; via gamma_sample |
| `student_t_pdf` | `(x: f32, df: f32) -> f32` | `stable` | Via log_gamma |
| `student_t_cdf` | `(t: f32, df: f32) -> f32` | `stable` | Via regularized incomplete beta (betai) |
| `student_t_sample` | `[n](template: tensor[n, f32], df: f32) -> tensor[n, f32] ! { Random }` | `alpha` | Effect: Random; normal/chi-squared ratio |
| `poisson_pmf` | `(k: f32, lambda: f32) -> f32` | `stable` | k as f32 (integer-valued), discrete PMF |
| `poisson_cdf` | `(k: f32, lambda: f32) -> f32` | `stable` | Via gamma_cdf complement |
| `binomial_pmf` | `(k: f32, n: f32, p: f32) -> f32` | `stable` | k, n as f32 (integer-valued), discrete PMF |
| `binomial_cdf` | `(k: f32, n: f32, p: f32) -> f32` | `stable` | Via regularized incomplete beta (betai) |
| `beta_pdf` | `(x: f32, a: f32, b: f32) -> f32` | `stable` | a, b > 0 |
| `beta_cdf` | `(x: f32, a: f32, b: f32) -> f32` | `stable` | Via regularized incomplete beta (betai) |
| `f_pdf` | `(x: f32, d1: f32, d2: f32) -> f32` | `stable` | d1, d2 degrees of freedom |
| `f_cdf` | `(x: f32, d1: f32, d2: f32) -> f32` | `stable` | Via regularized incomplete beta (betai) |
| `weibull_pdf` | `(x: f32, shape: f32, scale: f32) -> f32` | `stable` | (shape, scale) parameterization |
| `weibull_cdf` | `(x: f32, shape: f32, scale: f32) -> f32` | `stable` | Closed-form |
| `weibull_inv_cdf` | `(q: f32, shape: f32, scale: f32) -> f32` | `stable` | Closed-form |

### Nautilus.LinAlg (30 exports)

| Function | Signature | Stability | Notes |
|---|---|---|---|
| `transpose` | `[m, n](a: tensor[m, n, f32]) -> tensor[n, m, f32]` | `stable` | General-n, returns tensor |
| `matmul_wrap` | `[m, k, n](a: tensor[m, k, f32], b: tensor[k, n, f32]) -> tensor[m, n, f32]` | `stable` | General-n, wraps builtin matmul |
| `gram` | `[m, n](a: tensor[m, n, f32]) -> tensor[n, n, f32]` | `stable` | General-n, returns A^T A |
| `aat` | `[m, n](a: tensor[m, n, f32]) -> tensor[m, m, f32]` | `stable` | General-n, returns A A^T |
| `diag` | `[n](a: tensor[n, n, f32]) -> tensor[n, f32]` | `stable` | General-n, returns vector |
| `trace_mat` | `[n](a: tensor[n, n, f32]) -> tensor[f32]` | `stable` | General-n, returns scalar tensor |
| `trace_scalar` | `[n](a: tensor[n, n, f32]) -> f32` | `stable` | General-n, returns scalar |
| `l2_norm_vec` | `[n](v: tensor[n, f32]) -> f32` | `stable` | General-n, returns scalar |
| `inner_product` | `[n](a: tensor[n, f32], b: tensor[n, f32]) -> f32` | `stable` | General-n, returns scalar |
| `frobenius_sq` | `[m, n](a: tensor[m, n, f32]) -> f32` | `stable` | General-n, returns scalar |
| `frobenius_norm` | `[m, n](a: tensor[m, n, f32]) -> f32` | `stable` | General-n, returns scalar |
| `scale_vec` | `[n](v: tensor[n, f32], s: f32) -> tensor[n, f32]` | `stable` | General-n, returns tensor |
| `matvec` | `[m, n](a: tensor[m, n, f32], v: tensor[n, f32]) -> tensor[m, f32]` | `stable` | General-n via einsum, returns vector |
| `vecmat` | `[m, n](v: tensor[m, f32], a: tensor[m, n, f32]) -> tensor[n, f32]` | `stable` | General-n via einsum, returns vector |
| `det_2x2` | `(a: tensor[2, 2, f32]) -> f32` | `stable` | Fixed 2x2, returns scalar |
| `det_3x3` | `(a: tensor[3, 3, f32]) -> f32` | `stable` | Fixed 3x3, returns scalar |
| `la_vec_add` | `[n](a: tensor[n, f32], b: tensor[n, f32]) -> tensor[n, f32]` | `stable` | General-n elementwise add |
| `la_vec_sub` | `[n](a: tensor[n, f32], b: tensor[n, f32]) -> tensor[n, f32]` | `stable` | General-n elementwise sub |
| `la_vec_saxpy` | `[n](alpha: f32, x: tensor[n, f32], y: tensor[n, f32]) -> tensor[n, f32]` | `stable` | General-n, computes x + alpha*y |
| `cg_solve` | `[n](a_mat: tensor[n, n, f32], b: tensor[n, f32], x0: tensor[n, f32], tol: f32, max_iters: int64) -> tensor[n, f32]` | `stable` | General-n conjugate gradient for SPD systems |
| `inv_2x2` | `(a: tensor[2, 2, f32]) -> tensor[2, 2, f32]` | `stable` | Fixed 2x2, Cayley-Hamilton, NaN on singular |
| `inv_3x3` | `(a: tensor[3, 3, f32]) -> tensor[3, 3, f32]` | `stable` | Fixed 3x3, Cayley-Hamilton, NaN on singular |
| `solve_2x2` | `(a: tensor[2, 2, f32], b: tensor[2, f32]) -> tensor[2, f32]` | `stable` | Fixed 2x2, via inv_2x2 + matvec |
| `solve_3x3` | `(a: tensor[3, 3, f32], b: tensor[3, f32]) -> tensor[3, f32]` | `stable` | Fixed 3x3, via inv_3x3 + matvec |
| `eig_2x2_real` | `(a: tensor[2, 2, f32]) -> (f32, f32)` | `stable` | Fixed 2x2, returns tuple of eigenvalues, NaN if complex |
| `cholesky_2x2` | `(a: tensor[2, 2, f32]) -> tensor[2, 2, f32]` | `stable` | Fixed 2x2, lower-triangular, NaN if not SPD |
| `cholesky_n` | `[n](a: tensor[n, n, f32]) -> tensor[n, n, f32]` | `alpha` | General-n column-by-column Cholesky, lower-triangular, SPD assumed (no explicit check) |
| `lu_solve` | `[n](a: tensor[n, n, f32], b: tensor[n, f32]) -> tensor[n, f32]` | `alpha` | General-n Doolittle LU, no partial pivoting. Requires all leading submatrices of A to be nonsingular; well-conditioned matrices needing row swaps produce NaN. AD: gradients treat pivot choices as fixed. |
| `qr_decompose` | `[n](a: tensor[n, n, f32]) -> (tensor[n, n, f32], tensor[n, n, f32])` | `alpha` | General-n Householder QR (square). Returns (Q, R): Q orthogonal, R upper triangular. AD: Householder sign choices are piecewise-smooth, not globally smooth. |
| `svd_n` | `[n](a: tensor[n, n, f32]) -> (tensor[n, n, f32], tensor[n, f32], tensor[n, n, f32])` | `alpha` | General-n square Jacobi SVD. Returns (U, sigma, Vt). Fixed 30n sweeps; poorly-separated singular values may not fully converge. U is orthogonal only for full-rank A. AD: singular-vector bases are discontinuous at repeated singular values. |
| `eig_n` | `[n](a: tensor[n, n, f32]) -> (tensor[n, f32], tensor[n, n, f32])` | `alpha` | Symmetric Jacobi eigendecomposition. Returns (eigenvalues, Q) where Q[:,i] is eigenvector for eigenvalue i. Fixed 30n sweeps. Requires symmetric input — non-symmetric matrices produce wrong results silently. No sorting of eigenvalues guaranteed. |

### Nautilus.Stats (24 exports)

| Function | Signature | Stability | Notes |
|---|---|---|---|
| `mean_vec` | `[n](v: tensor[n, f32]) -> f32` | `stable` |  |
| `variance_vec` | `[n](v: tensor[n, f32], ddof: int64) -> f32` | `stable` | ddof=0 for population, ddof=1 for sample |
| `std_vec` | `[n](v: tensor[n, f32], ddof: int64) -> f32` | `stable` | sqrt(variance_vec) |
| `skewness_vec` | `[n](v: tensor[n, f32]) -> f32` | `stable` | Population skewness (not adjusted) |
| `kurtosis_vec` | `[n](v: tensor[n, f32]) -> f32` | `stable` | Excess kurtosis (subtracts 3) |
| `median_vec` | `[n](v: tensor[n, f32]) -> f32` | `stable` | Sorts internally |
| `covariance_scalar` | `[n](a: tensor[n, f32], b: tensor[n, f32], ddof: int64) -> f32` | `stable` | Returns scalar covariance |
| `correlation_scalar` | `[n](a: tensor[n, f32], b: tensor[n, f32]) -> f32` | `stable` | Pearson r, uses ddof=0 |
| `min_vec` | `[n](v: tensor[n, f32]) -> f32` | `stable` |  |
| `max_vec` | `[n](v: tensor[n, f32]) -> f32` | `stable` |  |
| `range_vec` | `[n](v: tensor[n, f32]) -> f32` | `stable` | max - min |
| `quantile_vec` | `[n](v: tensor[n, f32], q: f32) -> f32` | `stable` | q in [0,1], linear interpolation, sorts internally |
| `percentile_vec` | `[n](v: tensor[n, f32], p: f32) -> f32` | `stable` | p in [0,100], delegates to quantile_vec |
| `trimmed_mean_vec` | `[n](v: tensor[n, f32], proportion: f32) -> f32` | `stable` | Trims proportion from each tail, NaN if proportion >= 0.5 |
| `bonferroni_adjust` | `[n](p_values: tensor[n, f32]) -> tensor[n, f32]` | `alpha` | Multiplies each p-value by m (number of tests), clamped to 1 |
| `stat_holm_adjust` | `[n](p_values: tensor[n, f32]) -> tensor[n, f32]` | `alpha` | Holm step-down adjustment over sorted p-values |
| `benjamini_hochberg_adjust` | `[n](p_values: tensor[n, f32]) -> tensor[n, f32]` | `alpha` | Benjamini-Hochberg FDR adjustment |
| `fdr_adjust` | `[n](p_values: tensor[n, f32]) -> tensor[n, f32]` | `alpha` | Alias for benjamini_hochberg_adjust |
| `likelihood_ratio_stat` | `(log_likelihood_null: f32, log_likelihood_alt: f32) -> f32` | `alpha` | 2 * (log L_alt - log L_null) |
| `likelihood_ratio_p_value` | `(log_likelihood_null: f32, log_likelihood_alt: f32, df: f32) -> f32` | `alpha` | Upper-tail chi-squared p-value of LR statistic |
| `covariance_2x2` | `[n](a: tensor[n, f32], b: tensor[n, f32], ddof: int64) -> tensor[2, 2, f32]` | `alpha` | 2x2 covariance matrix for (a, b) |
| `correlation_2x2` | `[n](a: tensor[n, f32], b: tensor[n, f32]) -> tensor[2, 2, f32]` | `alpha` | 2x2 Pearson correlation matrix for (a, b) |
| `covariance_matrix_2` | `[n](a: tensor[n, f32], b: tensor[n, f32], ddof: int64) -> tensor[2, 2, f32]` | `alpha` | Alias for covariance_2x2 |
| `correlation_matrix_2` | `[n](a: tensor[n, f32], b: tensor[n, f32]) -> tensor[2, 2, f32]` | `alpha` | Alias for correlation_2x2 |

### Nautilus.Distance (8 exports)

| Function | Signature | Stability | Notes |
|---|---|---|---|
| `squared_euclidean` | `[n](a: tensor[n, f32], b: tensor[n, f32]) -> f32` | `stable` |  |
| `euclidean` | `[n](a: tensor[n, f32], b: tensor[n, f32]) -> f32` | `stable` | sqrt(squared_euclidean) |
| `manhattan` | `[n](a: tensor[n, f32], b: tensor[n, f32]) -> f32` | `stable` | L1 norm of difference |
| `chebyshev` | `[n](a: tensor[n, f32], b: tensor[n, f32]) -> f32` | `stable` | L-inf norm of difference |
| `cosine_similarity` | `[n](a: tensor[n, f32], b: tensor[n, f32]) -> f32` | `stable` | dot / (norm_a * norm_b) |
| `cosine_distance` | `[n](a: tensor[n, f32], b: tensor[n, f32]) -> f32` | `stable` | 1 - cosine_similarity |
| `mahalanobis_squared` | `[n](a: tensor[n, f32], b: tensor[n, f32], cov_inv: tensor[n, n, f32]) -> f32` | `stable` | Caller supplies inverse covariance |
| `mahalanobis` | `[n](a: tensor[n, f32], b: tensor[n, f32], cov_inv: tensor[n, n, f32]) -> f32` | `stable` | sqrt(mahalanobis_squared) |

### Nautilus.Roots (3 exports)

| Function | Signature | Stability | Notes |
|---|---|---|---|
| `bisection` | `(f: f32 -> f32, lo: f32, hi: f32, tol: f32, max_iters: int64) -> f32` | `stable` | Takes function-typed `f`; requires sign change in [lo,hi], NaN if none |
| `newton` | `(f: f32 -> f32, df: f32 -> f32, x0: f32, tol: f32, max_iters: int64) -> f32` | `stable` | Takes function-typed `f` and `df`; NaN on zero derivative or non-convergence |
| `brent` | `(f: f32 -> f32, lo: f32, hi: f32, tol: f32, max_iters: int64) -> f32` | `stable` | Takes function-typed `f`; Brent's method with IQI/secant/bisection fallback |

### Nautilus.Ode (5 exports)

| Function | Signature | Stability | Notes |
|---|---|---|---|
| `euler_step` | `(f: f32 -> f32 -> f32, y: f32, t: f32, dt: f32) -> f32` | `stable` | Single Euler step; `f` takes (y, t) via curried args |
| `euler_solve` | `(f: f32 -> f32 -> f32, y0: f32, t0: f32, t1: f32, n_steps: int64) -> f32` | `stable` | Fixed-step Euler; `f` takes (y, t), returns final y |
| `rk4_step` | `(f: f32 -> f32 -> f32, y: f32, t: f32, dt: f32) -> f32` | `stable` | Single RK4 step; `f` takes (y, t) |
| `rk4_solve` | `(f: f32 -> f32 -> f32, y0: f32, t0: f32, t1: f32, n_steps: int64) -> f32` | `stable` | Fixed-step RK4; `f` takes (y, t), returns final y |
| `rk45_adaptive_solve` | `(f: f32 -> f32 -> f32, y0: f32, t0: f32, t_end: f32, rtol: f32, atol: f32) -> f32` | `alpha` | Scalar Dormand-Prince 5(4) endpoint solve with adaptive step control; returns final y only |
| `rk45_adaptive_solve_grid` | `[n, p](f: tensor[n, f32] -> f32 -> tensor[n, f32], t0: f32, y0: tensor[n, f32], t_end: f32, rtol: f32, atol: f32, t_out: tensor[p, f32]) -> tensor[n, p, f32]` | `alpha` | Vector Dormand-Prince 5(4) with Hermite cubic dense output. Returns state at each t_out point. t_out must be sorted ascending, all in (t0, t_end]. f takes (state, t) curried. |

### Nautilus.Integrate (8 exports)

| Function | Signature | Stability | Notes |
|---|---|---|---|
| `trapezoidal` | `(f: f32 -> f32, a: f32, b: f32, n_steps: int64) -> f32` | `stable` | Takes function-typed `f`; composite trapezoidal rule |
| `simpsons` | `(f: f32 -> f32, a: f32, b: f32, n_steps: int64) -> f32` | `stable` | Takes function-typed `f`; n_steps must be even, NaN otherwise |
| `gauss_legendre_5` | `(f: f32 -> f32, a: f32, b: f32, n_points: int64) -> f32` | `stable` | Takes function-typed `f`; 5-point Gauss-Legendre (n_points ignored) |
| `adaptive_simpson` | `(f: f32 -> f32, a: f32, b: f32, tol: f32, max_depth: int64) -> f32` | `stable` | Takes function-typed `f`; recursive adaptive Simpson with Richardson correction |
| `romberg_5` | `(f: f32 -> f32, a: f32, b: f32) -> f32` | `stable` | Takes function-typed `f`; 5-level Romberg (16-panel trapezoidal base) |
| `gauss_legendre_10` | `(f: f32 -> f32, a: f32, b: f32) -> f32` | `stable` | Takes function-typed `f`; 10-point Gauss-Legendre |
| `gauss_hermite_10` | `(f: f32 -> f32) -> f32` | `stable` | Takes function-typed `f`; 10-point Gauss-Hermite, integrates f(x)*exp(-x^2) over (-inf,inf) |
| `gauss_laguerre_10` | `(f: f32 -> f32) -> f32` | `stable` | Takes function-typed `f`; 10-point Gauss-Laguerre, integrates f(x)*exp(-x) over [0,inf) |

### Nautilus.Testing (13 exports)

| Function | Signature | Stability | Notes |
|---|---|---|---|
| `z_statistic` | `(sample_mean: f32, pop_mean: f32, pop_std: f32, sample_n: f32) -> f32` | `stable` |  |
| `z_p_value_two_sided` | `(z: f32) -> f32` | `stable` | Via normal_cdf |
| `z_p_value_upper` | `(z: f32) -> f32` | `stable` | Upper-tail p-value |
| `z_p_value_lower` | `(z: f32) -> f32` | `stable` | Lower-tail p-value |
| `normal_ci_half_width` | `(confidence: f32, pop_std: f32, sample_n: f32) -> f32` | `stable` | Returns margin of error |
| `chi_squared_p_value` | `(statistic: f32, df: f32) -> f32` | `stable` | Upper-tail via chi_squared_cdf |
| `t_statistic_one_sample` | `(sample_mean: f32, sample_std: f32, sample_n: f32, pop_mean: f32) -> f32` | `stable` |  |
| `t_statistic_two_sample_pooled` | `(mean1: f32, std1: f32, n1: f32, mean2: f32, std2: f32, n2: f32) -> f32` | `stable` | Equal-variance pooled t |
| `t_p_value_two_sided` | `(t: f32, df: f32) -> f32` | `stable` | Via student_t_cdf |
| `t_p_value_upper` | `(t: f32, df: f32) -> f32` | `stable` | Upper-tail |
| `t_p_value_lower` | `(t: f32, df: f32) -> f32` | `stable` | Lower-tail |
| `welch_t_statistic` | `(mean1: f32, std1: f32, n1: f32, mean2: f32, std2: f32, n2: f32) -> f32` | `stable` | Unequal-variance Welch's t |
| `welch_t_df` | `(std1: f32, n1: f32, std2: f32, n2: f32) -> f32` | `stable` | Welch-Satterthwaite degrees of freedom |

### Nautilus.Optim (4 exports)

| Function | Signature | Stability | Notes |
|---|---|---|---|
| `golden_section_search` | `(f: f32 -> f32, lo: f32, hi: f32, tol: f32, max_iters: int64) -> f32` | `stable` | Takes function-typed `f`; finds minimizer in [lo,hi] |
| `brent_minimize` | `(f: f32 -> f32, lo: f32, hi: f32, tol: f32, max_iters: int64) -> f32` | `stable` | Takes function-typed `f`; Brent's minimization with parabolic interpolation |
| `gradient_descent_1d` | `(f: f32 -> f32, df: f32 -> f32, x0: f32, lr: f32, max_iters: int64) -> f32` | `stable` | Takes function-typed `f` and `df`; fixed learning rate, NaN on divergence |
| `newton_minimize_1d` | `(f: f32 -> f32, df: f32 -> f32, ddf: f32 -> f32, x0: f32, tol: f32, max_iters: int64) -> f32` | `alpha` | Takes function-typed `f`, `df`, `ddf`; requires positive curvature at minimum |

### Nautilus.Interpolation (5 exports)

| Function | Signature | Stability | Notes |
|---|---|---|---|
| `linear_interp_uniform` | `[n](ys: tensor[n, f32], x_min: f32, x_max: f32, x_query: f32) -> f32` | `stable` | Uniformly-spaced knots, clamped extrapolation |
| `linear_interp_sorted` | `[n](xs: tensor[n, f32], ys: tensor[n, f32], x_query: f32) -> f32` | `stable` | Arbitrary sorted knots, flat extrapolation outside range |
| `cubic_hermite` | `(x0: f32, x1: f32, y0: f32, y1: f32, m0: f32, m1: f32, x_query: f32) -> f32` | `stable` | Single-interval cubic Hermite spline, caller supplies tangents m0/m1 |
| `spline_eval` | `[m](xs: tensor[m, f32], ys: tensor[m, f32], x_query: f32) -> f32` | `alpha` | Natural cubic spline fit + eval in one call. Clamped extrapolation (returns ys[0] or ys[m-1] outside range). xs must be sorted ascending. Every call recomputes M; avoid in tight loops. |
| `spline_fit` | `[m](xs: tensor[m, f32], ys: tensor[m, f32]) -> tensor[m, f32]` | `alpha` | Returns second-derivative vector M (length m). Natural BCs: M[0]=M[m-1]=0. Exposed for inspection; use spline_eval for evaluation. |

### Nautilus.Sde (2 exports)

| Function | Signature | Stability | Notes |
|---|---|---|---|
| `euler_maruyama_fixed` | `[n](f: f32 -> f32 -> f32, g: f32 -> f32 -> f32, y0: f32, t0: f32, t1: f32, noise: tensor[n, f32]) -> f32` | `alpha` | Caller supplies pre-drawn N(0,1) noise tensor; `f` is drift, `g` is diffusion, both take (y, t) |
| `milstein_fixed` | `[n](f: f32 -> f32 -> f32, g: f32 -> f32 -> f32, dg_dy: f32 -> f32 -> f32, y0: f32, t0: f32, t1: f32, noise: tensor[n, f32]) -> f32` | `alpha` | Caller supplies noise + diffusion derivative `dg_dy`; Milstein correction term included |

### Nautilus.CurveFit (2 exports)

| Function | Signature | Stability | Notes |
|---|---|---|---|
| `lm_scalar_1param` | `[n](model: f32 -> f32 -> f32, dmodel: f32 -> f32 -> f32, xs: tensor[n, f32], ys: tensor[n, f32], theta0: f32, lambda0: f32, tol: f32, max_iters: int64) -> f32` | `alpha` | Levenberg-Marquardt for single-parameter models; `model(x, theta)` and `dmodel(x, theta)` are function-typed |
| `lm_scalar_nparam` | `[n, m](model: tensor[n, f32] -> tensor[m, f32] -> tensor[m, f32], x: tensor[m, f32], y: tensor[m, f32], theta0: tensor[n, f32], tol: f32, max_iters: int64) -> tensor[n, f32]` | `alpha` | Multi-parameter LM via finite-difference Jacobian (eps=1e-5); `tol` accepted but unused (runs full `max_iters`); lambda fixed at 0.01; AD replacement pinned by `chelis#676` |

### Nautilus.Signal (7 exports -- 6 stubs + `fftfreq`)

The six NaN-returning rows share the dated `spec/phase3j.md` § Explicit Deferrals citation.

| Function | Signature | Stability | Notes |
|---|---|---|---|
| `fft_magnitude_stub` | `[n](x: tensor[n, f32]) -> tensor[n, f32]` | `alpha` | Stub: returns NaN tensor. Blocked on upstream complex-number support (Phase 5f) |
| `ifft_magnitude_stub` | `[n](x: tensor[n, f32]) -> tensor[n, f32]` | `alpha` | Stub: returns NaN tensor |
| `stft_magnitude_stub` | `[n](x: tensor[n, f32], window_size: int64, hop_size: int64) -> tensor[n, f32]` | `alpha` | Stub: returns NaN tensor |
| `lowpass_stub` | `[n](x: tensor[n, f32], cutoff_hz: f32, sample_rate: f32) -> tensor[n, f32]` | `alpha` | Stub: returns NaN tensor |
| `highpass_stub` | `[n](x: tensor[n, f32], cutoff_hz: f32, sample_rate: f32) -> tensor[n, f32]` | `alpha` | Stub: returns NaN tensor |
| `bandpass_stub` | `[n](x: tensor[n, f32], low_hz: f32, high_hz: f32, sample_rate: f32) -> tensor[n, f32]` | `alpha` | Stub: returns NaN tensor |
| `fftfreq` | `[n](x: tensor[n, f32], sample_rate: f32) -> tensor[n, f32]` | `alpha` | Functional: computes FFT frequency bins (no complex math needed) |

### Nautilus.Info (3 exports)

| Function | Signature | Stability | Notes |
|---|---|---|---|
| `entropy` | `[n](p: tensor[n, f32]) -> f32` | `alpha` | Shannon entropy of a probability vector; zero-probability terms contribute 0 |
| `cross_entropy` | `[n](p: tensor[n, f32], q: tensor[n, f32]) -> f32` | `alpha` | Cross-entropy H(p, q); zero-probability terms in p contribute 0 |
| `kl_divergence` | `[n](p: tensor[n, f32], q: tensor[n, f32]) -> f32` | `alpha` | Kullback-Leibler divergence KL(p || q); zero-probability terms in p contribute 0 |

### Nautilus.Optimize (3 exports)

| Function | Signature | Stability | Notes |
|---|---|---|---|
| `minimize` | `(f: f32 -> f32, lo: f32, hi: f32, tol: f32, max_iters: int64) -> f32` | `alpha` | Bracketed 1D minimizer; delegates to brent_minimize |
| `root` | `(f: f32 -> f32, lo: f32, hi: f32, tol: f32, max_iters: int64) -> f32` | `alpha` | Bracketed 1D root finder; delegates to brent |
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

### Nautilus.TimeSeries (7 exports)

| Function | Signature | Stability | Notes |
|---|---|---|---|
| `ts_ewma_next` | `[n](values: tensor[n, f32], alpha: f32, initial: f32) -> f32` | `alpha` | Exponentially weighted moving average; returns final level |
| `ts_ewma_series` | `[n](values: tensor[n, f32], alpha: f32, initial: f32) -> tensor[n, f32]` | `alpha` | EWMA over the full series; returns per-step levels |
| `exponential_smoothing_next` | `[n](values: tensor[n, f32], alpha: f32, initial_level: f32) -> f32` | `alpha` | Simple exponential smoothing; delegates to ts_ewma_next |
| `exponential_smoothing_series` | `[n](values: tensor[n, f32], alpha: f32, initial_level: f32) -> tensor[n, f32]` | `alpha` | Simple exponential smoothing series; delegates to ts_ewma_series |
| `ar1_predict_next` | `[n](values: tensor[n, f32], intercept: f32, phi: f32) -> f32` | `alpha` | AR(1) one-step-ahead point forecast |
| `arma11_predict_next` | `[n](values: tensor[n, f32], intercept: f32, phi: f32, theta: f32, last_error: f32) -> f32` | `alpha` | ARMA(1,1) one-step-ahead point forecast |
| `arima110_predict_next` | `[n](values: tensor[n, f32], drift: f32, phi: f32, theta: f32, last_error: f32) -> f32` | `alpha` | ARIMA(1,1,0) one-step-ahead point forecast on first-differenced series |
