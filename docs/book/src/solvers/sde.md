# SDE Solvers

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

This design makes paths reproducible and avoids effect annotations
(`! { Random }`) on the solver itself. Generate noise separately using
`normal_sample` or pass a fixed tensor for testing.

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
derivative with respect to y is the constant 0.3.

## Milstein correction

Milstein adds the term `0.5 * g(y,t) * g'(y,t) * (dW^2 - dt)`, which
improves the strong convergence order from 0.5 to 1.0. The user must
supply `dg_dy` analytically, as `scale_slope` does in the module above.

## Notes

- An empty noise tensor (length 0) returns NaN.
- Both solvers return only the terminal value y(t1). Intermediate path
  values are not stored.
- Call drift and diffusion functions with both arguments at once:
  `f(y, t)` and `g(y, t)`.
