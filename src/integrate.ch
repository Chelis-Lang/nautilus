module Nautilus.Integrate
export (trapezoidal, simpsons, gauss_legendre_5)

def trap_rec(
  f: f32 -> f32,
  x: f32,
  h: f32,
  k: int64,
  acc: f32
) -> f32 = {
  zero_i = cast(0, int64)
  one_i = cast(1, int64)
  if lte(k, zero_i) then acc
  else {
    fx = f(x)
    acc_next = add(acc, fx)
    x_next = add(x, h)
    trap_rec(f, x_next, h, sub(k, one_i), acc_next)
  }
}

def trapezoidal(f: f32 -> f32, a: f32, b: f32, n_steps: int64) -> f32 = {
  if lte(n_steps, cast(0, int64)) then div(cast(0.0, f32), cast(0.0, f32))
  else {
    n_f = cast(n_steps, f32)
    h = div(sub(b, a), n_f)
    fa = f(a)
    fb = f(b)
    endpoint_sum = mul(cast(0.5, f32), add(fa, fb))
    x1 = add(a, h)
    inner_count = sub(n_steps, cast(1, int64))
    inner_sum = trap_rec(f, x1, h, inner_count, cast(0.0, f32))
    total = add(endpoint_sum, inner_sum)
    mul(h, total)
  }
}

def simpson_rec(
  f: f32 -> f32,
  x: f32,
  h: f32,
  k: int64,
  is_odd_step: bool,
  acc: f32
) -> f32 = {
  zero_i = cast(0, int64)
  one_i = cast(1, int64)
  if lte(k, zero_i) then acc
  else {
    fx = f(x)
    weight = if is_odd_step then cast(4.0, f32) else cast(2.0, f32)
    term = mul(weight, fx)
    acc_next = add(acc, term)
    x_next = add(x, h)
    simpson_rec(f, x_next, h, sub(k, one_i), not(is_odd_step), acc_next)
  }
}

def simpsons(f: f32 -> f32, a: f32, b: f32, n_steps: int64) -> f32 = {
  zero_i = cast(0, int64)
  two_i = cast(2, int64)
  if lte(n_steps, zero_i) then div(cast(0.0, f32), cast(0.0, f32))
  else {
    parity = mod(n_steps, two_i)
    if neq(parity, zero_i) then div(cast(0.0, f32), cast(0.0, f32))
    else {
      n_f = cast(n_steps, f32)
      h = div(sub(b, a), n_f)
      fa = f(a)
      fb = f(b)
      endpoint_sum = add(fa, fb)
      x1 = add(a, h)
      inner_count = sub(n_steps, cast(1, int64))
      inner_sum = simpson_rec(f, x1, h, inner_count, true, cast(0.0, f32))
      total = add(endpoint_sum, inner_sum)
      mul(div(h, cast(3.0, f32)), total)
    }
  }
}

def gauss_legendre_5(f: f32 -> f32, a: f32, b: f32, n_points: int64) -> f32 = {
  ignore_n = n_points
  half_range = mul(cast(0.5, f32), sub(b, a))
  mid = mul(cast(0.5, f32), add(a, b))
  x1_t = mul(half_range, cast(-0.9061798459386640, f32))
  x1 = add(mid, x1_t)
  x2_t = mul(half_range, cast(-0.5384693101056831, f32))
  x2 = add(mid, x2_t)
  x3 = mid
  x4_t = mul(half_range, cast(0.5384693101056831, f32))
  x4 = add(mid, x4_t)
  x5_t = mul(half_range, cast(0.9061798459386640, f32))
  x5 = add(mid, x5_t)
  f1 = f(x1)
  f2 = f(x2)
  f3 = f(x3)
  f4 = f(x4)
  f5 = f(x5)
  w1 = cast(0.2369268850561891, f32)
  w2 = cast(0.4786286704993665, f32)
  w3 = cast(0.5688888888888889, f32)
  w4 = cast(0.4786286704993665, f32)
  w5 = cast(0.2369268850561891, f32)
  s1 = mul(w1, f1)
  s2 = mul(w2, f2)
  s3 = mul(w3, f3)
  s4 = mul(w4, f4)
  s5 = mul(w5, f5)
  sum12 = add(s1, s2)
  sum34 = add(s3, s4)
  sum1234 = add(sum12, sum34)
  total = add(sum1234, s5)
  mul(half_range, total)
}
