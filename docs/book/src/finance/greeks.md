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
every argument through. `theta` negates the time derivative, so it reports
the value lost per year as expiry approaches.

For an at-the-money call (S = K = 100, r = 5%, sigma = 20%, T = 1 year),
evaluating the four functions gives:

```chelis-fragment
call_delta = delta(100.0, 100.0, 0.05, 0.2, 1.0)
call_vega = vega(100.0, 100.0, 0.05, 0.2, 1.0)
call_theta = theta(100.0, 100.0, 0.05, 0.2, 1.0)
call_rho = rho(100.0, 100.0, 0.05, 0.2, 1.0)
```

```text
call_delta = 0.6368303
call_vega = 37.524048
call_theta = -6.414027
call_rho = 53.232445
```

These agree with the closed-form Greeks, `N(d1) = 0.63683` for Delta and
`S * phi(d1) * sqrt(T) = 37.524` for Vega, to f32 precision. Vega and Rho
are per unit of volatility and rate, so divide by 100 for a one-point move.

## Second derivatives

`grad` nests. Gamma is the spot derivative of `delta`:

```chelis-fragment
def gamma(s: f32, k: f32, r: f32, sigma: f32, t: f32) -> f32 = grad(delta, wrt=s)(s, k, r, sigma, t)
call_gamma = gamma(100.0, 100.0, 0.05, 0.2, 1.0)
```

```text
call_gamma = 0.018762024
```

## Limits

- `grad` needs a function whose parameters and result have a fixed
  floating type. Wrap a dtype-generic function, such as a `Nautilus.Special`
  export, in a definition with concrete types before differentiating it.
- The pricing function must avoid primitives without derivatives, such as
  `cast_trunc`, and loops whose length is known only at run time.
  Differentiating through `rk4_solve` or `gamma` fails when `grad` is
  lowered.
