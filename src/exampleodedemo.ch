module Nautilus.Exampleodedemo
import Nautilus.ODE (rk4_solve, euler_solve)
export (example_decay_rk4, example_decay_euler, example_forced_rk4)

def eo_decay(y: f32, t: f32) -> f32 = neg(y)

def eo_forced(y: f32, t: f32) -> f32 = {
  half_pi = cast(1.5707963267948966, f32)
  c = sin(add(t, half_pi))
  add(neg(y), c)
}

def example_decay_rk4() -> f32 =
  rk4_solve(eo_decay, cast(1.0, f32), cast(0.0, f32), cast(1.0, f32), cast(100, int64))

def example_decay_euler() -> f32 =
  euler_solve(eo_decay, cast(1.0, f32), cast(0.0, f32), cast(1.0, f32), cast(1000, int64))

def example_forced_rk4() -> f32 =
  rk4_solve(eo_forced, cast(0.0, f32), cast(0.0, f32), cast(1.0, f32), cast(100, int64))
