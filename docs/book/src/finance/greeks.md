# Greeks via automatic differentiation

Chelis provides reverse-mode differentiation through `grad`.
`grad(f, wrt=x)` returns a function with the same parameters as `f` that
computes df/dx. The example applies it to a Black-Scholes call formula and
the `normal_cdf` function.

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
