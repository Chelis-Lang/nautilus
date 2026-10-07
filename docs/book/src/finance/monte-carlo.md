# Monte Carlo pricing

Use `normal_sample` to generate noise and `euler_maruyama_fixed` to simulate
terminal prices, then average and discount the option payoffs.

## The pattern

1. Generate N paths of the underlying asset price under the risk-neutral
   measure.
2. Compute the payoff for each path.
3. Average the payoffs and discount to present value.

## Geometric Brownian motion paths

Under the risk-neutral measure, a stock price follows:

    dS = r * S * dt + sigma * S * dW

This is a GBM SDE. Nautilus can simulate it using `euler_maruyama_fixed`
from `Nautilus.Sde`:

```chelis-fragment
import Nautilus.Sde (euler_maruyama_fixed)

def gbm_drift(y: f32, t: f32) -> f32 = mul(cast(0.05, f32), y)   -- r * S
def gbm_diff(y: f32, t: f32) -> f32 = mul(cast(0.2, f32), y)     -- sigma * S

def simulate_path[n](s0: f32, noise: tensor[n, f32]) -> f32 =
  euler_maruyama_fixed(gbm_drift, gbm_diff, s0,
    cast(0.0, f32), cast(1.0, f32), noise)
```

The `noise` tensor contains pre-drawn N(0,1) samples. Its length
determines the number of timesteps.

## Generating noise

The `normal_sample` function takes a key:

```chelis-fragment
import Nautilus.Distributions (normal_sample)

def draw_noise[n](k: key, template: tensor[n, f32]) -> tensor[n, f32] =
  normal_sample(k, template, cast(0.0, f32), cast(1.0, f32))
```

The key fixes the underlying uniform stream:
`draw_noise(key_from_seed(42i64), template)` returns the same draws on every
run, and a different seed gives different draws. To draw several independent
noise tensors, derive a child key per draw with `split_key` or
`split_keys` rather than passing one key twice.

## Computing the price

The program below prices a one-year at-the-money European call (spot and
strike 100, rate 5%, volatility 20%) from 2,000 Euler-Maruyama paths of 50
steps each. `fold` carries the key: each iteration splits it, spends one child
on a path, and passes the other to the next iteration, so no key is used
twice. The accumulator also sums squared payoffs for the standard error.

```chelis-fragment
import Nautilus.Distributions (normal_sample)
import Nautilus.Sde (euler_maruyama_fixed)

def gbm_drift(y: f32, t: f32) -> f32 = mul(0.05f32, y)
def gbm_diff(y: f32, t: f32) -> f32 = mul(0.2f32, y)
def discounted_payoff(k: key, strike: f32) -> f32 = {
  steps = to_tensor(map(fn (i: i64) -> 0.0f32, range(0i64, 50i64)))
  noise = normal_sample(k, steps, 0.0f32, 1.0f32)
  s_t = euler_maruyama_fixed(gbm_drift, gbm_diff, 100.0f32, 0.0f32, 1.0f32, noise)
  payoff = if gt(s_t, strike) then sub(s_t, strike) else 0.0f32
  mul(payoff, exp(neg(0.05f32)))
}
def mc_call(seed: i64, n_paths: i64) -> (f32, f32) = {
  totals = fold(fn (acc: (key, f32, f32), i: i64) -> {
    ks = split_key(acc.0)
    v = discounted_payoff(ks.0, 100.0f32)
    (ks.1, add(acc.1, v), add(acc.2, mul(v, v)))
  }, (key_from_seed(seed), 0.0f32, 0.0f32), range(0i64, n_paths))
  n = cast(n_paths, f32)
  mean = div(totals.1, n)
  sample_var = div(sub(totals.2, mul(n, mul(mean, mean))), sub(n, 1.0f32))
  (mean, sqrt(div(sample_var, n)))
}
estimate = mc_call(7i64, 2000i64)
```

```text
estimate.0 = 10.738255
estimate.1 = 0.336055
```

The estimate is 10.738 with a standard error of 0.336. The
[Black-Scholes price](black-scholes.md) for the same
contract is 10.450577, within one standard error. The same seed reproduces
the same estimate; quadrupling the path count halves the standard error.

`euler_maruyama_fixed` returns only the terminal value. A path-dependent
payoff, such as an Asian or barrier option, needs the intermediate values, so
step the state yourself with a `fold` over the noise.

## Practical considerations

- **Key control.** Reuse a seed to replay a calculation and derive child
  keys for distinct paths. For variance reduction (antithetic variates,
  control variates), structure the noise generation accordingly.
- **Path count.** Sampling error scales approximately as
  `payoff standard deviation / sqrt(N)`. Measure the payoff variance to
  choose a path count; a fixed path count does not guarantee a fixed
  relative error.
- **Euler vs Milstein.** Milstein's correction, 0.5 * g * g' * (dW^2 - dt),
  vanishes only for additive noise (g' = 0). For GBM, g = sigma * S and
  g' = sigma, so `milstein_fixed` (with `dg_dy` returning sigma) raises the
  strong order from 0.5 to 1. Terminal-price payoffs depend only on weak
  accuracy, where the two schemes are both order 1.
