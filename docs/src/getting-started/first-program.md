# Your First Nautilus Program

This chapter walks through a complete program that uses Nautilus to
compute a Black-Scholes option price.

## The program

Create a file called `src/my_first.ch` in your project:

```chelis
module Nautilus.ExampleFirstProgram
import Nautilus.Distributions (normal_cdf)
export (main)

def black_scholes_call(spot: f32, strike: f32, rate: f32, vol: f32, t_years: f32) -> f32 = {
  ln_ratio = log(div(spot, strike))
  half_vol_sq = mul(cast(0.5, f32), mul(vol, vol))
  d1_num = add(ln_ratio, mul(add(rate, half_vol_sq), t_years))
  vol_sqrt_t = mul(vol, sqrt(t_years))
  d1 = div(d1_num, vol_sqrt_t)
  d2 = sub(d1, vol_sqrt_t)
  zero = cast(0.0, f32)
  one = cast(1.0, f32)
  nd1 = normal_cdf(d1, zero, one)
  nd2 = normal_cdf(d2, zero, one)
  neg_rt = neg(mul(rate, t_years))
  discount = exp(neg_rt)
  sub(mul(spot, nd1), mul(mul(strike, discount), nd2))
}

def main() -> f32 = {
  spot = cast(100.0, f32)
  strike = cast(100.0, f32)
  rate = cast(0.05, f32)
  vol = cast(0.2, f32)
  t_years = cast(1.0, f32)
  black_scholes_call(spot, strike, rate, vol, t_years)
}
```

## What this does

The program computes the Black-Scholes call option price for:
- Spot price: 100
- Strike price: 100 (at-the-money)
- Risk-free rate: 5%
- Volatility: 20%
- Time to expiry: 1 year

It imports `normal_cdf` from `Nautilus.Distributions` to evaluate the
cumulative normal distribution, which is the core of the Black-Scholes
formula.

## Type-check it

```sh
chelis check src/my_first.ch
```

You should see `"score": 1` with zero errors.

## Build and run it

```sh
chelis build src/my_first.ch -o /tmp/my_first_out
```

This generates C code in `/tmp/my_first_out/`. The expected result is
approximately 10.45 (the BS call price for ATM, 1yr, 5% rate, 20% vol).

## Key things to notice

1. **Imports are explicit.** You import exactly the functions you need
   from each Nautilus module. No wildcard imports.

2. **Everything is f32.** Numeric literals must be wrapped in
   `cast(value, f32)`. This is Chelis's explicit-precision policy.

3. **Math uses named functions.** `add(a, b)` not `a + b`, `mul(a, b)`
   not `a * b`, `log(x)` not `math.log(x)`. Chelis has no operator
   overloading.

4. **`normal_cdf` takes three arguments.** `(x, mean, std)`, not just
   `(x)`. For the standard normal, pass `(x, 0.0, 1.0)`.

5. **AD is free.** To compute delta (dPrice/dSpot), wrap the call in
   `grad`: `grad(fn (s: f32) -> black_scholes_call(s, strike, rate, vol, t))(spot)`.
