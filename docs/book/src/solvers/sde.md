# SDE solvers

The `Nautilus.Sde` module provides two fixed-step stochastic
differential equation integrators: Euler-Maruyama (strong order 0.5)
and Milstein (strong order 1.0).

## Functions

| Function | Signature |
|---|---|
| `euler_maruyama_fixed` | `[n](f, g: f32 -> f32 -> f32, y0, t0, t1: f32, noise: tensor[n, f32]) -> f32` |
| `milstein_fixed` | `[n](f, g, dg_dy: f32 -> f32 -> f32, y0, t0, t1: f32, noise: tensor[n, f32]) -> f32` |

**Parameters:**

- `f(y, t)` -- drift coefficient (deterministic part).
- `g(y, t)` -- diffusion coefficient (stochastic part).
- `dg_dy(y, t)` -- derivative of g with respect to y (Milstein only).
- `y0, t0, t1` -- initial value and time interval.
- `noise` -- pre-drawn N(0,1) samples as a tensor.

## Noise tensor convention

The noise tensor is **caller-supplied**. Its length determines the
number of timesteps: `dt = (t1 - t0) / numel(noise)`. The solvers
scale each noise element by `sqrt(dt)` internally to produce the
Brownian increment dW.

The interval must run forward, `t1 > t0`. Neither solver checks it:

| Interval | Result |
|---|---|
| `t1 > t0` | the simulated `y(t1)` |
| `t1 = t0` | `y0`, since every increment is zero |
| `t1 < t0` | NaN, from `sqrt` of the negative step |

With `f(y, t) = -y`, `g(y, t) = 0.1`, `y0 = 1`, and the noise
`[0.5, -1.0, 0.25, 1.0]`, `euler_maruyama_fixed` returns `0.3582031` over
`[0, 1]`, `1.0` over `[1, 1]`, and `NaN` over `[1, 0]`.

This design makes paths reproducible and keeps keys out of the solver
signature entirely. Generate noise separately using `normal_sample` with its
own key, or pass a fixed tensor for testing.

## Example: Euler-Maruyama and Milstein

```chelis
module Nautilus.BookSdePaths
import Nautilus.Sde (euler_maruyama_fixed, milstein_fixed)
export (euler_maruyama_path, milstein_path)
def drift(y: f32, t: f32) -> f32 = neg(y)
def diffusion(y: f32, t: f32) -> f32 = cast(0.1, f32)
def scaled_diffusion(y: f32, t: f32) -> f32 = mul(cast(0.3, f32), y)
def scale_slope(y: f32, t: f32) -> f32 = cast(0.3, f32)
def euler_maruyama_path[n](noise: tensor[n, f32]) -> f32 = euler_maruyama_fixed(drift, diffusion, cast(1.0, f32), cast(0.0, f32), cast(1.0, f32), noise)
def milstein_path[n](noise: tensor[n, f32]) -> f32 = milstein_fixed(drift, scaled_diffusion, scale_slope, cast(1.0, f32), cast(0.0, f32), cast(1.0, f32), noise)
```

`euler_maruyama_path` simulates dY = -Y dt + 0.1 dW from Y(0) = 1 to t = 1;
with an all-zero noise tensor it reduces to Euler's method on exponential
decay. `milstein_path` uses the multiplicative diffusion g(y) = 0.3y, whose
derivative with respect to y is the constant 0.3. With four fixed noise
values:

```chelis-fragment
em = euler_maruyama_path(to_tensor([0.5f32, -1.0f32, 0.25f32, 1.0f32]))
mil = milstein_path(to_tensor([0.5f32, -1.0f32, 0.25f32, 1.0f32]))
```

```text
em = 0.3582031
mil = 0.34259263
```

## Milstein correction

Milstein adds the term `0.5 * g(y,t) * g'(y,t) * (dW^2 - dt)`, which
improves the strong convergence order from 0.5 to 1.0. The user must
supply `dg_dy` analytically, as `scale_slope` does in the module above.

## Notes

- An empty noise tensor (length 0) returns NaN.
- A NaN or infinite noise element propagates to the result.
- Both solvers return only the terminal value y(t1). Intermediate path
  values are not stored.
- Call drift and diffusion functions with both arguments at once:
  `f(y, t)` and `g(y, t)`.
