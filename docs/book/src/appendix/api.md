# API map

Each module below is imported as `import Nautilus.<Module> (names)`. The
linked chapter gives each function's signature, input domain, and failure
behavior.

| Module | Start here |
|---|---|
| `Nautilus.Special` | [Special functions](../special/overview.md) |
| `Nautilus.Distributions` | [Distributions](../distributions/overview.md) and [sampling limits](../distributions/sampling.md#sampling-limits) |
| `Nautilus.LinAlg` | [Linear algebra](../linalg/overview.md) and [conjugate gradient](../linalg/cg-solve.md) |
| `Nautilus.Stats` | [Descriptive statistics](../stats/descriptive.md) |
| `Nautilus.Testing` | [Hypothesis testing](../stats/testing.md) |
| `Nautilus.Rolling` | [Rolling and expanding windows](../stats/rolling.md) |
| `Nautilus.Integrate` | [Numerical quadrature](../solvers/integrate.md) |
| `Nautilus.Distance` | [Distance metrics](../other/distance.md) |
| `Nautilus.Ode` | [ODE solvers](../solvers/ode.md) |
| `Nautilus.Optim` | [Scalar optimization](../solvers/optim.md) |
| `Nautilus.Roots` | [Root finding](../solvers/roots.md) |
| `Nautilus.Interpolation` | [Interpolation](../other/interpolation.md) |
| `Nautilus.Sde` | [SDE solvers](../solvers/sde.md) |
| `Nautilus.CurveFit` | [Curve fitting](../other/curvefit.md) |
| `Nautilus.Signal` | [`fftfreq`](../other/signal.md) |

## Smaller modules

These modules are a few formulas each and are documented here in full. All
are f32 and check no arguments.

### Nautilus.Info

| Function | Signature | Returns |
|---|---|---|
| `entropy` | `[n](p: &tensor[n, f32]) -> f32` | `-sum(p_i * ln(p_i))` in nats, skipping `p_i <= 0` |
| `distribution_cross_entropy` | `[n](p: &tensor[n, f32], q: &tensor[n, f32]) -> f32` | `-sum(p_i * ln(q_i))`, skipping `p_i <= 0` |
| `kl_divergence` | `[n](p: &tensor[n, f32], q: &tensor[n, f32]) -> f32` | `sum(p_i * ln(p_i / q_i))`, skipping `p_i <= 0` |

The inputs are not normalized for you; pass probability vectors whose entries
are non-negative and sum to 1. A `q_i = 0` where `p_i > 0` gives `inf`.

### Nautilus.StateSpace

Scalar Kalman filter steps. Each returns a tuple; read fields with `.0`,
`.1`, `.2`.

| Function | Signature | Returns |
|---|---|---|
| `kalman_predict_scalar` | `(mean, covariance, transition, process_var, control, control_input: f32) -> (f32, f32)` | predicted `(mean, covariance)`: `transition * mean + control * control_input` and `transition^2 * covariance + process_var` |
| `kalman_update_scalar` | `(predicted_mean, predicted_covariance, observation, observation_matrix, observation_var: f32) -> (f32, f32, f32)` | updated `(mean, covariance, gain)` |
| `kalman_step_scalar` | `(mean, covariance, observation, transition, process_var, observation_matrix, observation_var: f32) -> (f32, f32, f32)` | predict with no control input, then update |
| `local_level_predict` | `(mean, covariance, process_var: f32) -> (f32, f32)` | predict with `transition = 1` |
| `local_level_update` | `(predicted_mean, predicted_covariance, observation, observation_var: f32) -> (f32, f32, f32)` | update with `observation_matrix = 1` |
| `local_level_step` | `(mean, covariance, observation, process_var, observation_var: f32) -> (f32, f32, f32)` | one local-level (random walk plus noise) step |

The gain is `predicted_covariance * observation_matrix / innovation_covariance`.
Variances must be non-negative; a zero innovation covariance divides by zero.

### Nautilus.TimeSeries

One-step point forecasts. `values` is the history, oldest first.

| Function | Signature | Returns |
|---|---|---|
| `ts_ewma_next` | `[n](values: &tensor[n, f32], alpha: f32, initial: f32) -> f32` | the final EWMA, `s = alpha * x + (1 - alpha) * s` from `s = initial` |
| `ts_ewma_series` | `[n](values: &tensor[n, f32], alpha: f32, initial: f32) -> tensor[n, f32]` | the EWMA after each value |
| `exponential_smoothing_next`, `exponential_smoothing_series` | same arguments, with `initial_level` | identical to the two EWMA functions |
| `ar1_predict_next` | `[n](values: &tensor[n, f32], intercept: f32, phi: f32) -> f32` | `intercept + phi * last` |
| `arma11_predict_next` | `[n](values: &tensor[n, f32], intercept: f32, phi: f32, theta: f32, last_error: f32) -> f32` | `intercept + phi * last + theta * last_error` |
| `arima110_predict_next` | `[n](values: &tensor[n, f32], drift: f32, phi: f32, theta: f32, last_error: f32) -> f32` | `last + drift + phi * (last - previous) + theta * last_error` |

These functions apply given coefficients; they do not estimate `phi`,
`theta`, or `alpha` from data. `alpha` belongs in [0, 1]. On an empty
history `last` is 0, and on a one-value history `previous` is 0.

### Nautilus.Optimize

| Function | Signature | Same as |
|---|---|---|
| `minimize` | `(f: f32 -> f32, lo, hi, tol: f32, max_iters: i64) -> f32` | `brent_minimize` in [Scalar optimization](../solvers/optim.md) |
| `root` | `(f: f32 -> f32, lo, hi, tol: f32, max_iters: i64) -> f32` | `brent` in [Root finding](../solvers/roots.md) |

### Nautilus.Core

`version() -> string` returns the installed Nautilus version string.
