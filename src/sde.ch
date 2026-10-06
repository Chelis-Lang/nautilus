module Nautilus.Sde
export (euler_maruyama_fixed, milstein_fixed)
def sde_zero_f() -> f32 = cast(0.0, f32)
def sde_nan_f() -> f32 = cast(0.0, f32) |> div(cast(0.0, f32))
def euler_maruyama_fixed[n](f: f32 -> f32 -> f32, g: f32 -> f32 -> f32, y0: f32, t0: f32, t1: f32, noise: tensor[n, f32]) -> f32 = {
  n_i = numel(noise)
  if lte(n_i, cast(0, i64)) then sde_nan_f() else {
    n_f = cast(n_i, f32)
    dt = t1 |> sub(t0) |> div(n_f)
    sqrt_dt = sqrt(dt)
    final_state = fold(fn (acc: (f32, f32), z: f32) -> {
      y = acc.0
      t = acc.1
      fy = f(y, t)
      gy = g(y, t)
      drift = mul(fy, dt)
      diff = mul(gy, mul(sqrt_dt, z))
      y_next = add(y, add(drift, diff))
      t_next = add(t, dt)
      pair = (y_next, t_next)
      pair
    }, (y0, t0), to_list(noise))
    final_state.0
  }
}
def milstein_fixed[n](f: f32 -> f32 -> f32, g: f32 -> f32 -> f32, dg_dy: f32 -> f32 -> f32, y0: f32, t0: f32, t1: f32, noise: tensor[n, f32]) -> f32 = {
  n_i = numel(noise)
  if lte(n_i, cast(0, i64)) then sde_nan_f() else {
    n_f = cast(n_i, f32)
    dt = t1 |> sub(t0) |> div(n_f)
    sqrt_dt = sqrt(dt)
    half = cast(0.5, f32)
    final_state = fold(fn (acc: (f32, f32), z: f32) -> {
      y = acc.0
      t = acc.1
      fy = f(y, t)
      gy = g(y, t)
      dgy = dg_dy(y, t)
      dW = mul(sqrt_dt, z)
      drift = mul(fy, dt)
      diff = mul(gy, dW)
      dW_sq = mul(dW, dW)
      correction_term = sub(dW_sq, dt)
      correction = mul(half, mul(gy, mul(dgy, correction_term)))
      y_next = add(y, drift |> add(diff) |> add(correction))
      t_next = add(t, dt)
      pair = (y_next, t_next)
      pair
    }, (y0, t0), to_list(noise))
    final_state.0
  }
}
