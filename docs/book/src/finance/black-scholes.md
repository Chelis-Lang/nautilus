# Black-Scholes pricing

The Black-Scholes formula for a European call option composes `log`,
`exp`, `sqrt`, and `normal_cdf`. All are available in Nautilus without any
special imports beyond `Nautilus.Distributions`.

## The formula

For a European call with spot price S, strike K, risk-free rate r,
volatility sigma, and time to expiry T:

    d1 = [ln(S/K) + (r + sigma^2/2) * T] / (sigma * sqrt(T))
    d2 = d1 - sigma * sqrt(T)
    C  = S * N(d1) - K * exp(-rT) * N(d2)

where N(x) is the standard normal CDF.

S and K must be positive, sigma and T positive, and r is an annual rate as a
fraction (0.05 for 5%). The function below checks none of them. At the edges
it returns the arithmetic limit: with S = 110 and K = 100, `T = 0` gives
`10.0` (the intrinsic value) and `sigma = 0` gives `14.877052`
(`S - K * exp(-rT)`), and `S = 0` gives `0.0`. When S = K and T = 0, `d1` is
`0 / 0` and the price is NaN.

## Chelis implementation

```chelis
module Nautilus.BookBlackScholes
import Nautilus.Distributions (normal_cdf)
export (black_scholes_call)
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
```

`normal_cdf` takes three arguments `(x, mean, std)`. For the
standard normal, pass `(x, 0.0, 1.0)`.

## Example: ATM call

S = K = 100, r = 5%, sigma = 20%, T = 1 year:

```chelis-fragment
atm_call = black_scholes_call(100.0f32, 100.0f32, 0.05f32, 0.2f32, 1.0f32)
```

```text
atm_call = 10.450577
```

This matches the closed-form f64 value, 10.4506, to f32 precision.

Use `grad` to calculate first-order sensitivities of this function, as shown
in [Greeks](greeks.md).

## Put-call parity

For a European put, use put-call parity rather than re-deriving:

```chelis-fragment
def black_scholes_put(s: f32, k: f32, r: f32, sigma: f32, t: f32) -> f32 = {
  call = black_scholes_call(s, k, r, sigma, t)
  discount = exp(neg(mul(r, t)))
  -- P = C - S + K * exp(-rT)
  add(sub(call, s), mul(k, discount))
}
atm_put = black_scholes_put(100.0f32, 100.0f32, 0.05f32, 0.2f32, 1.0f32)
```

```text
atm_put = 5.5735245
```

Check: `10.450577 - 100 + 100 * exp(-0.05) = 5.5735`.
