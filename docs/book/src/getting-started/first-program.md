# Your first Nautilus program

Start in the `demo` project from [Installation](installation.md). Its
`reef.toml` pins Chelis 0.19.0 and lists Nautilus 0.7.49 as a dependency.
Replace `src/main.ch` with this program:

```chelis-fragment
module Demo.Main
import Nautilus.Distributions (normal_cdf)
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
price = black_scholes_call(cast(100.0, f32), cast(100.0, f32), cast(0.05, f32), cast(0.2, f32), cast(1.0, f32))
```

The inputs are a spot and strike of 100, a 5% annual rate, 20% volatility,
and one year to expiry. `normal_cdf(d1, zero, one)` evaluates the standard
normal distribution at `d1`; it takes the value, mean, and standard deviation.

## Check and evaluate

From the `demo` directory, run:

```sh
chelis fmt --inplace src/main.ch
chelis check src/main.ch
chelis eval --file src/main.ch
```

`chelis check` should report a score of `1` and an empty error list. The
evaluator prints `price = 10.450577` for this example. Formatting
comes first because both `check` and `eval --file` enforce Chelis's source
style gate.

For machine-readable output, add `--json` to the evaluation command.
Its `roots` array contains the `price` result; the `f32` value is
encoded in the `bits` field.

To build the Reef package, run `chelis reef build`. To compile the program for
the C target, run `chelis build src/main.ch --target c --output out/`. The
command creates the `out/main` executable and retains the generated C and
runtime files under `out/`; it does not run the calculation.

## Reading the program

- The file is `src/main.ch`, so its module name is `Demo.Main`. The import
  names the Nautilus module and the one function this program uses.
- Unsuffixed floating literals have `f32` precision. The explicit `cast`
  calls make that choice visible here; Chelis does not promote a value to
  `f64` implicitly.
- Math uses named functions such as `add`, `mul`, and `log`.
- `price` is a top-level value, which gives `chelis eval` a result to print.
  Defining a function alone does not evaluate it.

For the pricing formula and its domain, see [Black-Scholes pricing](../finance/black-scholes.md).
