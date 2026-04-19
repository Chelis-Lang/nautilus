module Nautilus.ODE
export (
  euler_step, euler_solve,
  rk4_step, rk4_solve,
  rk45_adaptive_solve
)

def ode_zero_f() -> f32 = cast(0.0, f32)
def ode_one_f() -> f32 = cast(1.0, f32)
def ode_nan_f() -> f32 = div(cast(0.0, f32), cast(0.0, f32))
def ode_zero_i() -> int64 = cast(0, int64)
def ode_one_i() -> int64 = cast(1, int64)
def ode_half_f() -> f32 = cast(0.5, f32)
def ode_two_f() -> f32 = cast(2.0, f32)
def ode_six_f() -> f32 = cast(6.0, f32)
def ode_abs_f(x: f32) -> f32 = if lt(x, ode_zero_f()) then neg(x) else x
def ode_min_f(a: f32, b: f32) -> f32 = if lt(a, b) then a else b
def ode_max_f(a: f32, b: f32) -> f32 = if gt(a, b) then a else b
def ode_clamp_f(x: f32, lo: f32, hi: f32) -> f32 = ode_max_f(lo, ode_min_f(x, hi))


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

def rk45_dopri_step(
  f: f32 -> f32 -> f32,
  y: f32,
  t: f32,
  h: f32
) -> (f32, f32) = {
  c2 = cast(0.2, f32)
  c3 = cast(0.3, f32)
  c4 = cast(0.8, f32)
  c5 = cast(0.8888888888888888, f32)

  a21 = cast(0.2, f32)
  a31 = cast(0.075, f32)
  a32 = cast(0.225, f32)
  a41 = cast(0.9777777777777777, f32)
  a42 = cast(-3.7333333333333334, f32)
  a43 = cast(3.5555555555555554, f32)
  a51 = cast(2.9525986892242035, f32)
  a52 = cast(-11.595793324188385, f32)
  a53 = cast(9.822892851699436, f32)
  a54 = cast(-0.2908093278463649, f32)
  a61 = cast(2.8462752525252526, f32)
  a62 = cast(-10.757575757575758, f32)
  a63 = cast(8.906422717743473, f32)
  a64 = cast(0.2784090909090909, f32)
  a65 = cast(-0.2735313036020583, f32)

  b1 = cast(0.09114583333333333, f32)
  b3 = cast(0.44923629829290207, f32)
  b4 = cast(0.6510416666666666, f32)
  b5 = cast(-0.322376179245283, f32)
  b6 = cast(0.13095238095238096, f32)

  bs1 = cast(0.08991319444444444, f32)
  bs3 = cast(0.4534890685834082, f32)
  bs4 = cast(0.6140625, f32)
  bs5 = cast(-0.2715123820754717, f32)
  bs6 = cast(0.08904761904761904, f32)
  bs7 = cast(0.025, f32)

  k1 = f(y, t)
  y2 = add(y, mul(h, mul(a21, k1)))
  k2 = f(y2, add(t, mul(c2, h)))

  y3 = add(y, mul(h, add(mul(a31, k1), mul(a32, k2))))
  k3 = f(y3, add(t, mul(c3, h)))

  y4 = add(y, mul(h, add(add(mul(a41, k1), mul(a42, k2)), mul(a43, k3))))
  k4 = f(y4, add(t, mul(c4, h)))

  y5i = add(y, mul(h, add(add(add(mul(a51, k1), mul(a52, k2)), mul(a53, k3)), mul(a54, k4))))
  k5 = f(y5i, add(t, mul(c5, h)))

  y6 = add(y, mul(h, add(add(add(add(mul(a61, k1), mul(a62, k2)), mul(a63, k3)), mul(a64, k4)), mul(a65, k5))))
  k6 = f(y6, add(t, h))

  y_high = add(y, mul(h, add(add(add(add(mul(b1, k1), mul(b3, k3)), mul(b4, k4)), mul(b5, k5)), mul(b6, k6))))
  k7 = f(y_high, add(t, h))
  y_low = add(y, mul(h, add(add(add(add(add(mul(bs1, k1), mul(bs3, k3)), mul(bs4, k4)), mul(bs5, k5)), mul(bs6, k6)), mul(bs7, k7))))
  err = ode_abs_f(sub(y_high, y_low))
  (y_high, err)
}

def rk45_next_step(h: f32, err_ratio: f32) -> f32 = {
  tiny = cast(1.0e-8, f32)
  safety = cast(0.9, f32)
  grow_max = cast(5.0, f32)
  shrink_min = cast(0.2, f32)
  ratio_safe = if lt(err_ratio, tiny) then tiny else err_ratio
  raw = mul(safety, exp(mul(cast(-0.2, f32), log(ratio_safe))))
  factor = if lt(err_ratio, tiny) then grow_max else ode_clamp_f(raw, shrink_min, grow_max)
  mul(h, factor)
}

def rk45_adaptive_rec(
  f: f32 -> f32 -> f32,
  y: f32,
  t: f32,
  t_end: f32,
  h: f32,
  rtol: f32,
  atol: f32,
  steps_left: int64
) -> f32 = {
  if lte(steps_left, ode_zero_i()) then y
  else {
    remaining = sub(t_end, t)
    abs_remaining = ode_abs_f(remaining)
    tiny_h = cast(1.0e-6, f32)
    if lt(abs_remaining, tiny_h) then rk4_step(f, y, t, remaining)
    else {
      abs_h = ode_abs_f(h)
      h_capped = if gt(abs_h, abs_remaining) then remaining else h
      step = rk45_dopri_step(f, y, t, h_capped)
      y_next = step.0
      err = step.1
      scale = add(atol, mul(rtol, ode_max_f(ode_abs_f(y), ode_abs_f(y_next))))
      scale_safe = if lt(scale, cast(1.0e-8, f32)) then cast(1.0e-8, f32) else scale
      err_ratio = div(err, scale_safe)
      next_h = rk45_next_step(h_capped, err_ratio)
      if lte(err_ratio, ode_one_f()) then {
        t_next = add(t, h_capped)
        if lt(ode_abs_f(sub(t_end, t_next)), tiny_h) then y_next
        else rk45_adaptive_rec(f, y_next, t_next, t_end, next_h, rtol, atol, sub(steps_left, ode_one_i()))
      } else {
        rk45_adaptive_rec(f, y, t, t_end, next_h, rtol, atol, sub(steps_left, ode_one_i()))
      }
    }
  }
}

def rk45_adaptive_solve(
  f: f32 -> f32 -> f32,
  y0: f32,
  t0: f32,
  t_end: f32,
  rtol: f32,
  atol: f32
) -> f32 = {
  span = sub(t_end, t0)
  abs_span = ode_abs_f(span)
  if eq(abs_span, ode_zero_f()) then y0
  else if or(lte(rtol, ode_zero_f()), lte(atol, ode_zero_f())) then ode_nan_f()
  else {
    h0 = mul(cast(0.1, f32), span)
    rk45_adaptive_rec(f, y0, t0, t_end, h0, rtol, atol, cast(4096, int64))
  }
}
