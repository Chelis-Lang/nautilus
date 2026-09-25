# Greeks via Automatic Differentiation

Chelis provides reverse-mode differentiation as a language transform, `grad`.
`grad(f, wrt=x)` returns a function with the same parameters as `f` that
computes df/dx. Because `black_scholes_call` is an ordinary composition of
Chelis primitives and `normal_cdf`, with no foreign-function calls, `grad`
can differentiate through it to produce the option Greeks.

## The Greeks as derivatives

```chelis
module Nautilus.BookGreeks
import Nautilus.Distributions (normal_cdf)
export (black_scholes_call, delta, vega, theta, rho, gamma)
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
def gamma(s: f32, k: f32, r: f32, sigma: f32, t: f32) -> f32 = grad(delta, wrt=s)(s, k, r, sigma, t)
```

Each Greek names the parameter to differentiate with `wrt=` and passes every
argument through. Gamma, the second derivative in the spot price, is `grad`
applied to `delta`, which is itself a `grad`.

For an at-the-money call (S = K = 100, r = 5%, sigma = 20%, T = 1 year), the
evaluator (`chelis eval`) at Chelis 0.18.11 returns these values, which agree
with the closed-form Greeks to f32 precision:

| Greek | Value |
|---|---|
| Delta | 0.63683 |
| Vega | 37.524 |
| Theta | -6.4140 (per year) |
| Rho | 53.232 |
| Gamma | 0.018761 |

## Caveats

- **Use `wrt=`, not a closure over the other parameters.** At Chelis 0.18.11,
  writing delta as `grad(fn (s_: f32) -> black_scholes_call(s_, k, r, sigma, t))(s)`
  type-checks but fails in the evaluator with `missing required input` for
  the captured parameters. The `wrt=` form above works.
- **No test covers these values.** Nautilus's test suite does not yet
  include a gradient test through `normal_cdf`, so this chapter is a worked
  example rather than an advertised, regression-tested surface.
