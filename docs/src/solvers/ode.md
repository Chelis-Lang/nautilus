# ODE Solvers

The `Nautilus.ODE` module provides fixed-step ODE integrators for scalar
initial-value problems dy/dt = f(y, t). Both Euler and RK4 methods are
included, each with a single-step and a full-solve variant.

## Functions

| Function | Signature | Notes |
|---|---|---|
| `euler_step` | `(f: f32 -> f32 -> f32, y, t, dt: f32) -> f32` | Single forward Euler step |
| `euler_solve` | `(f: f32 -> f32 -> f32, y0, t0, t1: f32, n_steps: int64) -> f32` | Full Euler integration, returns y(t1) |
| `rk4_step` | `(f: f32 -> f32 -> f32, y, t, dt: f32) -> f32` | Single classical RK4 step |
| `rk4_solve` | `(f: f32 -> f32 -> f32, y0, t0, t1: f32, n_steps: int64) -> f32` | Full RK4 integration, returns y(t1) |

The drift function `f` is curried: it takes `(y: f32, t: f32)` as two
separate arguments and returns `f32`.

## Fixed-step design

Both solvers use a uniform step size `dt = (t1 - t0) / n_steps`. There
is no adaptive step control. For problems requiring tight error bounds,
increase `n_steps` or use RK4 (which has fourth-order accuracy versus
first-order for Euler).

## Example: exponential decay

```chelis-fragment
import Nautilus.ODE (rk4_solve, euler_solve)

def decay(y: f32, t: f32) -> f32 = neg(y)

def demo_rk4() -> f32 =
  rk4_solve(decay, cast(1.0, f32), cast(0.0, f32),
            cast(1.0, f32), cast(100, int64))

def demo_euler() -> f32 =
  euler_solve(decay, cast(1.0, f32), cast(0.0, f32),
              cast(1.0, f32), cast(1000, int64))
```

Both approximate e^{-1} = 0.36788. RK4 with 100 steps is accurate to
roughly 1e-10; Euler needs ~1000 steps for 1e-3 accuracy.

## Example: forced ODE

```chelis-fragment
import Nautilus.ODE (rk4_solve)

def forced(y: f32, t: f32) -> f32 = {
  half_pi = cast(1.5707963267948966, f32)
  cos_t = sin(add(t, half_pi))
  add(neg(y), cos_t)
}

def demo_forced() -> f32 =
  rk4_solve(forced, cast(0.0, f32), cast(0.0, f32),
            cast(1.0, f32), cast(100, int64))
```

## Notes

- `n_steps <= 0` returns NaN.
- AD via `grad` flows through `rk4_solve`, enabling neural ODE
  composition.
- Chelis has no `cos` builtin. Use `sin(add(x, half_pi))` where
  `half_pi = cast(1.5707963267948966, f32)`.
- Only the final value y(t1) is returned. Intermediate trajectory points
  are not stored.
