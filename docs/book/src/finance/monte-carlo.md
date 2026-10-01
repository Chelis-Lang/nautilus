# Monte Carlo Pricing

Monte Carlo simulation is the standard approach for pricing path-dependent
options and options with multiple underlying assets. Nautilus provides the
building blocks: `normal_sample` for generating random draws and
`euler_maruyama_fixed` for simulating SDEs.

## The pattern

1. Generate N paths of the underlying asset price under the risk-neutral
   measure.
2. Compute the payoff for each path.
3. Average the payoffs and discount to present value.

## Geometric Brownian Motion paths

Under the risk-neutral measure, a stock price follows:

    dS = r * S * dt + sigma * S * dW

This is a GBM SDE. Nautilus can simulate it using `euler_maruyama_fixed`
from `Nautilus.Sde`:

```chelis-fragment
import Nautilus.Sde (euler_maruyama_fixed)

def gbm_drift(y: f32, t: f32) -> f32 = mul(cast(0.05, f32), y)   // r * S
def gbm_diff(y: f32, t: f32) -> f32 = mul(cast(0.2, f32), y)     // sigma * S

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

For a European call with strike K:

```chelis-fragment
// After simulating terminal price s_T:
payoff = if gt(s_T, k) then sub(s_T, k) else cast(0.0, f32)
discounted = mul(payoff, exp(neg(mul(r, t))))
```

The Monte Carlo estimate is the average of `discounted` over all paths.
With enough paths (typically 10,000-100,000), the estimate converges to
the Black-Scholes price for European options, and extends naturally to
exotic payoffs (Asian, barrier, lookback) where no closed-form exists.

## Practical considerations

- **Seed control.** The `seed` handler determines reproducibility. For
  variance reduction (antithetic variates, control variates), the caller
  must structure the noise generation accordingly.
- **Path count.** Monte Carlo error scales as 1/sqrt(N). For ~1% relative
  error on a $10 option, expect to need ~10,000 paths.
- **Euler vs Milstein.** Milstein's correction, 0.5 * g * g' * (dW^2 - dt),
  vanishes only for additive noise (g' = 0). For GBM, g = sigma * S and
  g' = sigma, so `milstein_fixed` (with `dg_dy` returning sigma) raises the
  strong order from 0.5 to 1. Terminal-price payoffs depend only on weak
  accuracy, where the two schemes are both order 1.
