module Nautilus.Special
export (erf, erfinv, log_gamma, digamma, beta, lbeta)

def abs_f32(x: f32) -> f32 = if lt(x, cast(0.0, f32)) then neg(x) else x

def is_nonpositive_integer(x: f32) -> bool = {
  zero = cast(0.0, f32)
  if gt(x, zero) then false
  else {
    xi_i = cast(x, int64)
    xi = cast(xi_i, f32)
    eq(x, xi)
  }
}

def pos_inf() -> f32 = div(cast(1.0, f32), cast(0.0, f32))
def nan_f32() -> f32 = div(cast(0.0, f32), cast(0.0, f32))

def erf(x: f32) -> f32 = {
  a1 = cast(0.254829592, f32)
  a2 = cast(-0.284496736, f32)
  a3 = cast(1.421413741, f32)
  a4 = cast(-1.453152027, f32)
  a5 = cast(1.061405429, f32)
  p  = cast(0.3275911, f32)
  one = cast(1.0, f32)
  ax = abs_f32(x)
  small = cast(1.0e-5, f32)
  if lt(ax, small) then {
    two_over_sqrt_pi = cast(1.1283791670955126, f32)
    mul(x, two_over_sqrt_pi)
  } else {
    t = div(one, add(one, mul(p, ax)))
    poly = mul(t, add(a1, mul(t, add(a2, mul(t, add(a3, mul(t, add(a4, mul(t, a5)))))))))
    x2 = mul(ax, ax)
    nx2 = neg(x2)
    e = exp(nx2)
    y = sub(one, mul(poly, e))
    if lt(x, cast(0.0, f32)) then neg(y) else y
  }
}

def lanczos_sum(x: f32) -> f32 = {
  c0 = cast(0.99999999999980993, f32)
  c1 = cast(676.5203681218851, f32)
  c2 = cast(-1259.1392167224028, f32)
  c3 = cast(771.32342877765313, f32)
  c4 = cast(-176.61502916214059, f32)
  c5 = cast(12.507343278686905, f32)
  c6 = cast(-0.13857109526572012, f32)
  c7 = cast(9.9843695780195716e-6, f32)
  c8 = cast(1.5056327351493116e-7, f32)
  one = cast(1.0, f32)
  t1 = div(c1, add(x, one))
  t2 = div(c2, add(x, cast(2.0, f32)))
  t3 = div(c3, add(x, cast(3.0, f32)))
  t4 = div(c4, add(x, cast(4.0, f32)))
  t5 = div(c5, add(x, cast(5.0, f32)))
  t6 = div(c6, add(x, cast(6.0, f32)))
  t7 = div(c7, add(x, cast(7.0, f32)))
  t8 = div(c8, add(x, cast(8.0, f32)))
  add(add(add(add(add(add(add(add(c0, t1), t2), t3), t4), t5), t6), t7), t8)
}

def log_gamma_core(x: f32) -> f32 = {
  half = cast(0.5, f32)
  log_sqrt_2pi = cast(0.9189385332046727, f32)
  g_plus_half = cast(7.5, f32)
  xm1 = sub(x, cast(1.0, f32))
  a = lanczos_sum(xm1)
  t = add(xm1, g_plus_half)
  log_t = log(t)
  log_a = log(a)
  add(add(log_sqrt_2pi, mul(add(xm1, half), log_t)), sub(log_a, t))
}

def log_gamma(x: f32) -> f32 = {
  half = cast(0.5, f32)
  pi = cast(3.1415926535897932, f32)
  log_pi = cast(1.1447298858494002, f32)
  if is_nonpositive_integer(x) then pos_inf()
  else if lt(x, half) then {
    pix = mul(pi, x)
    spix = sin(pix)
    aspix = abs_f32(spix)
    log_aspix = log(aspix)
    one_minus_x = sub(cast(1.0, f32), x)
    lgc = log_gamma_core(one_minus_x)
    sub(sub(log_pi, log_aspix), lgc)
  } else log_gamma_core(x)
}

def digamma_asymptotic(x: f32) -> f32 = {
  one = cast(1.0, f32)
  inv_x = div(one, x)
  inv_x2 = mul(inv_x, inv_x)
  inv_x4 = mul(inv_x2, inv_x2)
  inv_x6 = mul(inv_x4, inv_x2)
  c2 = cast(0.5, f32)
  c12 = cast(0.08333333333333333, f32)
  c120 = cast(0.008333333333333333, f32)
  c252 = cast(0.003968253968253968, f32)
  log_x = log(x)
  sub(sub(add(sub(log_x, mul(c2, inv_x)), mul(c120, inv_x4)), mul(c12, inv_x2)), mul(c252, inv_x6))
}

def digamma_rec(x: f32, acc: f32) -> f32 = {
  six = cast(6.0, f32)
  one = cast(1.0, f32)
  if gte(x, six) then add(digamma_asymptotic(x), acc)
  else digamma_rec(add(x, one), sub(acc, div(one, x)))
}

def digamma(x: f32) -> f32 = {
  if is_nonpositive_integer(x) then nan_f32()
  else digamma_rec(x, cast(0.0, f32))
}

def acklam_central(q: f32) -> f32 = {
  a1 = cast(-39.69683028665376, f32)
  a2 = cast(220.9460984245205, f32)
  a3 = cast(-275.9285104469687, f32)
  a4 = cast(138.357751867269, f32)
  a5 = cast(-30.66479806614716, f32)
  a6 = cast(2.506628277459239, f32)
  b1 = cast(-54.47609879822406, f32)
  b2 = cast(161.5858368580409, f32)
  b3 = cast(-155.6989798598866, f32)
  b4 = cast(66.80131188771972, f32)
  b5 = cast(-13.28068155288572, f32)
  one = cast(1.0, f32)
  half = cast(0.5, f32)
  u = sub(q, half)
  r = mul(u, u)
  num = mul(add(mul(r, add(mul(r, add(mul(r, add(mul(r, add(mul(r, a1), a2)), a3)), a4)), a5)), a6), u)
  den = add(mul(r, add(mul(r, add(mul(r, add(mul(r, add(mul(r, b1), b2)), b3)), b4)), b5)), one)
  div(num, den)
}

def acklam_tail(u: f32) -> f32 = {
  c1 = cast(-0.007784894002430293, f32)
  c2 = cast(-0.3223964580411365, f32)
  c3 = cast(-2.400758277161838, f32)
  c4 = cast(-2.549732539343734, f32)
  c5 = cast(4.374664141464968, f32)
  c6 = cast(2.938163982698783, f32)
  d1 = cast(0.007784695709041462, f32)
  d2 = cast(0.3224671290700398, f32)
  d3 = cast(2.445134137142996, f32)
  d4 = cast(3.754408661907416, f32)
  one = cast(1.0, f32)
  num = add(mul(u, add(mul(u, add(mul(u, add(mul(u, add(mul(u, c1), c2)), c3)), c4)), c5)), c6)
  den = add(mul(u, add(mul(u, add(mul(u, add(mul(u, d1), d2)), d3)), d4)), one)
  div(num, den)
}

def norminv(q: f32) -> f32 = {
  plow = cast(0.02425, f32)
  one = cast(1.0, f32)
  phigh = sub(one, plow)
  two = cast(2.0, f32)
  if lt(q, plow) then {
    lq = log(q)
    mlq = neg(mul(two, lq))
    u = sqrt(mlq)
    acklam_tail(u)
  }
  else if lte(q, phigh) then acklam_central(q)
  else {
    omq = sub(one, q)
    lomq = log(omq)
    mlomq = neg(mul(two, lomq))
    u = sqrt(mlomq)
    neg(acklam_tail(u))
  }
}

def erfinv(x: f32) -> f32 = {
  half = cast(0.5, f32)
  sqrt_half = cast(0.7071067811865476, f32)
  q = mul(add(x, cast(1.0, f32)), half)
  mul(norminv(q), sqrt_half)
}

def lbeta(a: f32, b: f32) -> f32 = {
  zero = cast(0.0, f32)
  if or(lte(a, zero), lte(b, zero)) then nan_f32()
  else {
    la = log_gamma(a)
    lb = log_gamma(b)
    lab = log_gamma(add(a, b))
    sub(add(la, lb), lab)
  }
}

def beta(a: f32, b: f32) -> f32 = {
  zero = cast(0.0, f32)
  if or(lte(a, zero), lte(b, zero)) then nan_f32()
  else {
    lb = lbeta(a, b)
    exp(lb)
  }
}
