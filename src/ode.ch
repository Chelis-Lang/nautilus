module Nautilus.ODE
export (
  euler_step, euler_solve,
  rk4_step, rk4_solve
)

def ode_zero_i() -> int64 = cast(0, int64)
def ode_one_i() -> int64 = cast(1, int64)
def ode_half_f() -> f32 = cast(0.5, f32)
def ode_two_f() -> f32 = cast(2.0, f32)
def ode_six_f() -> f32 = cast(6.0, f32)


def euler_step(f: f32 -> f32 -> f32, y: f32, t: f32, dt: f32) -> f32 = {
  k = f(y, t)
  add(y, mul(dt, k))
}

def euler_solve_rec(f: f32 -> f32 -> f32, y: f32, t: f32, dt: f32, k: int64) -> f32 =
  if lte(k, ode_zero_i()) then y
  else euler_solve_rec(f, euler_step(f, y, t, dt), add(t, dt), dt, sub(k, ode_one_i()))

def euler_solve(f: f32 -> f32 -> f32, y0: f32, t0: f32, t1: f32, n_steps: int64) -> f32 = {
  if lte(n_steps, cast(0, int64)) then div(cast(0.0, f32), cast(0.0, f32))
  else {
    n_f = cast(n_steps, f32)
    dt = div(sub(t1, t0), n_f)
    euler_solve_rec(f, y0, t0, dt, n_steps)
  }
}

def rk4_step(f: f32 -> f32 -> f32, y: f32, t: f32, dt: f32) -> f32 = {
  half_dt = mul(ode_half_f(), dt)
  t_mid = add(t, half_dt)
  t_end = add(t, dt)
  k1 = f(y, t)
  y_mid1 = add(y, mul(half_dt, k1))
  k2 = f(y_mid1, t_mid)
  y_mid2 = add(y, mul(half_dt, k2))
  k3 = f(y_mid2, t_mid)
  y_end = add(y, mul(dt, k3))
  k4 = f(y_end, t_end)
  two_k2 = mul(ode_two_f(), k2)
  two_k3 = mul(ode_two_f(), k3)
  sum1 = add(k1, two_k2)
  sum2 = add(two_k3, k4)
  sum_k = add(sum1, sum2)
  scale = div(dt, ode_six_f())
  add(y, mul(scale, sum_k))
}

def rk4_solve_rec(f: f32 -> f32 -> f32, y: f32, t: f32, dt: f32, k: int64) -> f32 =
  if lte(k, ode_zero_i()) then y
  else rk4_solve_rec(f, rk4_step(f, y, t, dt), add(t, dt), dt, sub(k, ode_one_i()))

def rk4_solve(f: f32 -> f32 -> f32, y0: f32, t0: f32, t1: f32, n_steps: int64) -> f32 = {
  if lte(n_steps, cast(0, int64)) then div(cast(0.0, f32), cast(0.0, f32))
  else {
    n_f = cast(n_steps, f32)
    dt = div(sub(t1, t0), n_f)
    rk4_solve_rec(f, y0, t0, dt, n_steps)
  }
}
