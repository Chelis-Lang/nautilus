# ODE Solvers

The `Nautilus.Ode` module provides scalar initial-value solvers for
dy/dt = f(y, t). Euler and RK4 are available in fixed-step form, and
`rk45_adaptive_solve` provides an adaptive Dormand-Prince 5(4) endpoint
solver.

## Functions

| Function | Signature | Notes |
|---|---|---|
| `euler_step` | `(f: f32 -> f32 -> f32, y, t, dt: f32) -> f32` | Single forward Euler step |
| `euler_solve` | `(f: f32 -> f32 -> f32, y0, t0, t1: f32, n_steps: i64) -> f32` | Full Euler integration, returns y(t1) |
| `rk4_step` | `(f: f32 -> f32 -> f32, y, t, dt: f32) -> f32` | Single classical RK4 step |
| `rk4_solve` | `(f: f32 -> f32 -> f32, y0, t0, t1: f32, n_steps: i64) -> f32` | Full RK4 integration, returns y(t1) |
| `rk45_adaptive_solve` | `(f: f32 -> f32 -> f32, y0, t0, t_end, rtol, atol: f32) -> f32` | Adaptive Dormand-Prince 5(4), returns y(t_end) |

The drift function `f` is curried: it takes `(y: f32, t: f32)` as two
separate arguments and returns `f32`.

## Fixed-step and adaptive design

Both solvers use a uniform step size `dt = (t1 - t0) / n_steps`. There
is no adaptive step control. `rk45_adaptive_solve` instead adjusts the
step size from an embedded 5th/4th-order error estimate and is the
better default when you only need the endpoint value `y(t_end)`.

## Example: exponential decay

```chelis-fragment
import Nautilus.Ode (rk4_solve, euler_solve, rk45_adaptive_solve)

def decay(y: f32, t: f32) -> f32 = neg(y)

def demo_rk4() -> f32 =
  rk4_solve(decay, cast(1.0, f32), cast(0.0, f32),
            cast(1.0, f32), cast(100, i64))

def demo_euler() -> f32 =
  euler_solve(decay, cast(1.0, f32), cast(0.0, f32),
              cast(1.0, f32), cast(1000, i64))

def demo_rk45() -> f32 =
  rk45_adaptive_solve(decay, cast(1.0, f32), cast(0.0, f32),
                      cast(1.0, f32), cast(1.0e-6, f32), cast(1.0e-8, f32))
```

Both approximate e^{-1} = 0.36788. RK4 with 100 steps is accurate to
roughly 1e-10; Euler needs ~1000 steps for 1e-3 accuracy; adaptive
RK45 reaches similar endpoint accuracy without a user-chosen `n_steps`.

## Example: forced ODE

```chelis-fragment
import Nautilus.Ode (rk4_solve)

def forced(y: f32, t: f32) -> f32 = {
  half_pi = cast(1.5707963267948966, f32)
  cos_t = sin(add(t, half_pi))
  add(neg(y), cos_t)
}

def demo_forced() -> f32 =
  rk4_solve(forced, cast(0.0, f32), cast(0.0, f32),
            cast(1.0, f32), cast(100, i64))
```

## Notes

- `n_steps <= 0` returns NaN for the fixed-step solvers.
- `rk45_adaptive_solve` returns NaN if `rtol <= 0` or `atol <= 0`.
- AD via `grad` flows through `rk4_solve`, enabling neural ODE
  composition.
- Chelis has no `cos` builtin. Use `sin(add(x, half_pi))` where
  `half_pi = cast(1.5707963267948966, f32)`.
- Only the final value y(t1) is returned. Intermediate trajectory points
  are not stored.
