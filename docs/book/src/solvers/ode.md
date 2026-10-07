# ODE solvers

The `Nautilus.Ode` module provides initial-value solvers for
dy/dt = f(y, t). Euler and RK4 are available in fixed-step scalar form,
`rk45_adaptive_solve` is an adaptive Dormand-Prince 5(4) scalar endpoint
solver, and `rk45_adaptive_solve_grid` applies the same method to a vector
state and reports it at caller-chosen times.

## Functions

| Function | Signature | Notes |
|---|---|---|
| `euler_step` | `(f: f32 -> f32 -> f32, y, t, dt: f32) -> f32` | Single forward Euler step |
| `euler_solve` | `(f: f32 -> f32 -> f32, y0, t0, t1: f32, n_steps: i64) -> f32` | Full Euler integration, returns y(t1) |
| `rk4_step` | `(f: f32 -> f32 -> f32, y, t, dt: f32) -> f32` | Single classical RK4 step |
| `rk4_solve` | `(f: f32 -> f32 -> f32, y0, t0, t1: f32, n_steps: i64) -> f32` | Full RK4 integration, returns y(t1) |
| `rk45_adaptive_solve` | `(f: f32 -> f32 -> f32, y0, t0, t_end, rtol, atol: f32) -> f32` | Adaptive Dormand-Prince 5(4), returns y(t_end) |
| `rk45_adaptive_solve_grid` | `[n, p](f: tensor[n, f32] -> f32 -> tensor[n, f32], t0: f32, y0: tensor[n, f32], t_end, rtol, atol: f32, t_out: &tensor[p, f32]) -> tensor[n, p, f32]` | Vector Dormand-Prince 5(4) with Hermite cubic dense output; column j is the state at `t_out[j]` |

The right-hand side `f` takes `(y, t)` as two separate arguments. For the
grid solver `y` is the state vector and the result has one column per entry
of `t_out`.

## Fixed-step and adaptive design

The Euler and RK4 solvers use a uniform step size
`dt = (t1 - t0) / n_steps` with no step control. The RK45 solvers instead
adjust the step size from an embedded 5th/4th-order error estimate, and
`rk45_adaptive_solve` is the better default when you only need the endpoint
value `y(t_end)`.

## Example: exponential decay and a forced ODE

```chelis
module Nautilus.BookOdeDecay
import Nautilus.Ode (rk4_solve, euler_solve, rk45_adaptive_solve)
export (rk4_decay, euler_decay, adaptive_decay, forced_response)
def decay(y: f32, t: f32) -> f32 = neg(y)
def forced(y: f32, t: f32) -> f32 = add(neg(y), cos(t))
def rk4_decay() -> f32 = rk4_solve(decay, cast(1.0, f32), cast(0.0, f32), cast(1.0, f32), cast(100, i64))
def euler_decay() -> f32 = euler_solve(decay, cast(1.0, f32), cast(0.0, f32), cast(1.0, f32), cast(1000, i64))
def adaptive_decay() -> f32 = rk45_adaptive_solve(decay, cast(1.0, f32), cast(0.0, f32), cast(1.0, f32), cast(1e-6, f32), cast(1e-8, f32))
def forced_response() -> f32 = rk4_solve(forced, cast(0.0, f32), cast(0.0, f32), cast(1.0, f32), cast(100, i64))
```

The three decay solves approximate e^{-1} = 0.367879. RK4 with 100 steps and
adaptive RK45 both agree with it to f32 rounding; Euler with 1000 steps is
off by about 2e-4. `forced_response` solves y' = -y + cos(t) from y(0) = 0,
whose exact value at t = 1 is (cos 1 + sin 1 - e^{-1}) / 2 ≈ 0.50695.

## Failure behavior

No solver raises an error. Each returns a value, and some of those values
look like results:

| Situation | Result |
|---|---|
| `n_steps <= 0` (Euler, RK4) | NaN |
| `t1 < t0` (Euler, RK4) | integrates backward with a negative step |
| `t_end = t0` (RK45) | `y0`, or an all-zero grid |
| `rtol <= 0` or `atol <= 0` | NaN from `rk45_adaptive_solve`; an all-zero tensor from `rk45_adaptive_solve_grid` |
| `t_end < t0` | `rk45_adaptive_solve` integrates backward; `rk45_adaptive_solve_grid` returns all zeros |
| a `t_out` entry outside `(t0, t_end]` | that column is all zeros |
| step budget exhausted | the state at the time reached, not at `t_end` |

`t_out` need not be sorted: each entry is filled from the accepted step that
contains it. Both RK45 solvers attempt at most 4096 steps, counting rejected
ones. A stiff problem can use them all on tiny steps. For
`y' = -1e5 * (y - cos(t))` from `y(0) = 0` to `t = 10`, `rk45_adaptive_solve`
returns `0.99999976`, a value of `cos(t)` near `t = 0`, while the true value
is `cos(10) = -0.839`. Nothing in the result marks the
shortfall, so check stiff problems against a second method or a shorter
interval. The scalar solver also stops early when an accepted step leaves `y`
unchanged.

## Grid output

```chelis-fragment
import Nautilus.Ode (rk45_adaptive_solve_grid)

def decay_v(y: tensor[2, f32], t: f32) -> tensor[2, f32] = neg(y)
grid = rk45_adaptive_solve_grid(decay_v, 0.0f32, to_tensor([1.0f32, 2.0f32]), 1.0f32, 1e-6f32, 1e-8f32, to_tensor([0.5f32, 1.0f32]))
grid_unsorted = rk45_adaptive_solve_grid(decay_v, 0.0f32, to_tensor([1.0f32, 2.0f32]), 1.0f32, 1e-6f32, 1e-8f32, to_tensor([1.0f32, 0.0f32, 0.5f32, 2.0f32]))
```

```text
grid = tensor(shape=[2, 2], data=[0.60652786, 0.36787948, 1.2130557, 0.73575896])
grid_unsorted = tensor(shape=[2, 4], data=[0.36787948, 0.0, 0.60652786, 0.0, 0.73575896, 0.0, 1.2130557, 0.0])
```

Row `i` is state component `i` and column `j` is time `t_out[j]`, so the first
row of `grid` is `exp(-0.5)` and `exp(-1)`. In `grid_unsorted`, the times 0.0
and 2.0 lie outside `(0, 1]` and their columns are zero.

## Notes

- The scalar solvers return only the final value; use
  `rk45_adaptive_solve_grid` when you need the trajectory.
- `grad` does not differentiate through these solvers. Their step loops
  recurse a number of times known only at run time, and lowering `grad`
  through `rk4_solve` fails with `recursive inlining of ... exceeded the
  static unroll limit of 512 levels`. Differentiate the right-hand side, or
  use finite differences of the solve.
