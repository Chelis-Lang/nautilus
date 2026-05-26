# Black-Scholes Pricing

The Black-Scholes formula for a European call option composes `log`,
`exp`, `sqrt`, and `normal_cdf` -- all available in Nautilus without any
special imports beyond `Nautilus.Distributions`.

## The formula

For a European call with spot price S, strike K, risk-free rate r,
volatility sigma, and time to expiry T:

    d1 = [ln(S/K) + (r + sigma^2/2) * T] / (sigma * sqrt(T))
    d2 = d1 - sigma * sqrt(T)
    C  = S * N(d1) - K * exp(-rT) * N(d2)

where N(x) is the standard normal CDF.

## Chelis implementation

```chelis-fragment
import Nautilus.Distributions (normal_cdf)

def black_scholes_call(s: f32, k: f32, r: f32, sigma: f32, t: f32) -> f32 = {
  sqrt_t = sqrt(t)
  d1_num = add(log(div(s, k)),
               mul(add(r, mul(cast(0.5, f32), mul(sigma, sigma))), t))
  d1 = div(d1_num, mul(sigma, sqrt_t))
  d2 = sub(d1, mul(sigma, sqrt_t))
  nd1 = normal_cdf(d1, cast(0.0, f32), cast(1.0, f32))
  nd2 = normal_cdf(d2, cast(0.0, f32), cast(1.0, f32))
  discount = exp(neg(mul(r, t)))
  sub(mul(s, nd1), mul(mul(k, discount), nd2))
}
```

Note that `normal_cdf` takes three arguments `(x, mean, std)`. For the
standard normal, pass `(x, 0.0, 1.0)`.

## Example: ATM call

```chelis-fragment
def main() -> f32 = black_scholes_call(
  cast(100.0, f32),   // S = 100
  cast(100.0, f32),   // K = 100 (at-the-money)
  cast(0.05, f32),    // r = 5%
  cast(0.2, f32),     // sigma = 20%
  cast(1.0, f32)      // T = 1 year
)
// Expected result: approximately 10.45
```

The ATM call price of ~10.45 matches the scipy/numpy reference to within
f32 precision (~1e-5 relative error). This is Pattern 4 in SKILL.md.

## How it works

The entire computation is a single composed expression over Chelis
primitives (`log`, `exp`, `sqrt`, `div`, `mul`, `add`, `sub`, `neg`) plus
the `normal_cdf` library function. Because Nautilus is pure Chelis with
no FFI, this composition is transparent to the AD system: `grad` can
differentiate through `black_scholes_call` to produce Greeks (see the
[Greeks chapter](greeks.md)).

## Put-call parity

For a European put, use put-call parity rather than re-deriving:

```chelis-fragment
def black_scholes_put(s: f32, k: f32, r: f32, sigma: f32, t: f32) -> f32 = {
  call = black_scholes_call(s, k, r, sigma, t)
  discount = exp(neg(mul(r, t)))
  // P = C - S + K * exp(-rT)
  add(sub(call, s), mul(k, discount))
}
```
