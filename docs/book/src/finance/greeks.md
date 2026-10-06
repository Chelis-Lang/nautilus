# Greeks via Automatic Differentiation

Chelis provides reverse-mode differentiation through `grad`.
`grad(f, wrt=x)` returns a function with the same parameters as `f` that
computes df/dx. With the pinned evaluator, this form differentiates
the Black-Scholes call formula through `normal_cdf`.

## The Greeks as derivatives

```chelis
module Nautilus.BookGreeks
import Nautilus.Distributions (normal_cdf)
export (black_scholes_call, delta, vega, theta, rho)
def black_scholes_call(s: f32, k: f32, r: f32, sigma: f32, t: f32) -> f32 = {
  sqrt_t = sqrt(t)
  d1_num = add(log(div(s, k)), mul(add(r, mul(0.5, mul(sigma, sigma))), t))
  d1 = div(d1_num, mul(sigma, sqrt_t))
  d2 = sub(d1, mul(sigma, sqrt_t))
  nd1 = normal_cdf(d1, 0.0, 1.0)
  nd2 = normal_cdf(d2, 0.0, 1.0)
  discount = exp(neg(mul(r, t)))
  sub(mul(s, nd1), mul(mul(k, discount), nd2))
}
def delta(s: f32, k: f32, r: f32, sigma: f32, t: f32) -> f32 = grad(black_scholes_call, wrt=s)(s, k, r, sigma, t)
def vega(s: f32, k: f32, r: f32, sigma: f32, t: f32) -> f32 = grad(black_scholes_call, wrt=sigma)(s, k, r, sigma, t)
def theta(s: f32, k: f32, r: f32, sigma: f32, t: f32) -> f32 = neg(grad(black_scholes_call, wrt=t)(s, k, r, sigma, t))
def rho(s: f32, k: f32, r: f32, sigma: f32, t: f32) -> f32 = grad(black_scholes_call, wrt=r)(s, k, r, sigma, t)
```

Each function names the parameter to differentiate with `wrt=` and passes
every argument through.

For an at-the-money call (S = K = 100, r = 5%, sigma = 20%, T = 1 year), the
evaluator (`chelis eval`) at Chelis 0.19.1 returns these first derivatives,
which agree with the closed-form Greeks to f32 precision:

| Greek | Value |
|---|---|
| Delta | 0.63683 |
| Vega | 37.524 |
| Theta | -6.4140 (per year) |
| Rho | 53.232 |

## Evaluation scope

The four values above are from `chelis eval` with Chelis 0.19.1. Nested
`grad` also gives Gamma, the second spot derivative: `grad(delta, wrt=s)`
returns 0.018762 at the same point, which agrees with the closed form. Use the
explicit `wrt=` argument as shown for a function with several parameters.
This chapter demonstrates evaluator behavior; it does not establish the
same result for generated C. Nautilus's test suite does not include a
gradient test for this pricing path.
