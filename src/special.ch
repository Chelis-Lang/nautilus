module Nautilus.Special
export (erf, erfc, erfinv, gamma, log_gamma, digamma, beta, lbeta, trigamma, bessel_i0, bessel_i1, bessel_k0, bessel_k1, bessel_j0, bessel_j1, bessel_y0, bessel_y1, airy_ai, airy_bi, ellipk, ellipe)
def abs_f32(x: f32) -> f32 = if lt(x, cast(0.0, f32)) then neg(x) else x
def is_nonpositive_integer(x: f32) -> bool = {
  zero = cast(0.0, f32)
  if gt(x, zero) then false else {
    xi_i = cast(x, int64)
    xi = cast(xi_i, f32)
    eq(x, xi)
  }
}
def pos_inf() -> f32 = div(cast(1.0, f32), cast(0.0, f32))
def neg_inf() -> f32 = div(cast(-1.0, f32), cast(0.0, f32))
def nan_f32() -> f32 = div(cast(0.0, f32), cast(0.0, f32))
def erf(x: f32) -> f32 = {
  a1 = cast(0.254829592, f32)
  a2 = cast(-0.284496736, f32)
  a3 = cast(1.421413741, f32)
  a4 = cast(-1.453152027, f32)
  a5 = cast(1.061405429, f32)
  p = cast(0.3275911, f32)
  one = cast(1.0, f32)
  ax = abs_f32(x)
  small = cast(0.00001, f32)
  __borrow_migration_out_0 = if lt(ax, small) then {
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
  _ = drop(a2)
  _ = drop(a3)
  __borrow_migration_out_0
}
def erfc(x: f32) -> f32 = sub(cast(1.0, f32), erf(x))
def lanczos_sum(x: f32) -> f32 = {
  c0 = cast(0.9999999999998099, f32)
  c1 = cast(676.5203681218851, f32)
  c2 = cast(-1259.1392167224028, f32)
  c3 = cast(771.3234287776531, f32)
  c4 = cast(-176.6150291621406, f32)
  c5 = cast(12.507343278686905, f32)
  c6 = cast(-0.13857109526572012, f32)
  c7 = cast(0.000009984369578019572, f32)
  c8 = cast(0.00000015056327351493116, f32)
  one = cast(1.0, f32)
  t1 = div(c1, add(x, one))
  t2 = div(c2, add(x, cast(2.0, f32)))
  t3 = div(c3, add(x, cast(3.0, f32)))
  t4 = div(c4, add(x, cast(4.0, f32)))
  t5 = div(c5, add(x, cast(5.0, f32)))
  t6 = div(c6, add(x, cast(6.0, f32)))
  t7 = div(c7, add(x, cast(7.0, f32)))
  t8 = div(c8, add(x, cast(8.0, f32)))
  __borrow_migration_out_0 = add(add(add(add(add(add(add(add(c0, t1), t2), t3), t4), t5), t6), t7), t8)
  _ = drop(t1)
  _ = drop(t2)
  _ = drop(t3)
  _ = drop(t4)
  __borrow_migration_out_0
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
  pi = cast(3.141592653589793, f32)
  log_pi = cast(1.1447298858494002, f32)
  if is_nonpositive_integer(x) then pos_inf() else if lt(x, half) then {
    pix = mul(pi, x)
    spix = sin(pix)
    aspix = abs_f32(spix)
    log_aspix = log(aspix)
    one_minus_x = sub(cast(1.0, f32), x)
    lgc = log_gamma_core(one_minus_x)
    sub(sub(log_pi, log_aspix), lgc)
  } else log_gamma_core(x)
}
def gamma(x: f32) -> f32 = {
  half = cast(0.5, f32)
  pi = cast(3.141592653589793, f32)
  if is_nonpositive_integer(x) then pos_inf() else if lt(x, half) then {
    pix = mul(pi, x)
    spix = sin(pix)
    one_minus_x = sub(cast(1.0, f32), x)
    g1 = exp(log_gamma_core(one_minus_x))
    div(pi, mul(spix, g1))
  } else exp(log_gamma_core(x))
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
  if gte(x, six) then add(digamma_asymptotic(x), acc) else digamma_rec(add(x, one), sub(acc, div(one, x)))
}
def digamma(x: f32) -> f32 = { if is_nonpositive_integer(x) then nan_f32() else digamma_rec(x, cast(0.0, f32)) }
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
  __borrow_migration_out_1 = div(num, den)
  _ = drop(a2)
  _ = drop(b1)
  _ = drop(a3)
  __borrow_migration_out_1
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
  } else if lte(q, phigh) then acklam_central(q) else {
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
  if or(lte(a, zero), lte(b, zero)) then nan_f32() else {
    la = log_gamma(a)
    lb = log_gamma(b)
    lab = log_gamma(add(a, b))
    sub(add(la, lb), lab)
  }
}
def beta(a: f32, b: f32) -> f32 = {
  zero = cast(0.0, f32)
  if or(lte(a, zero), lte(b, zero)) then nan_f32() else {
    lb = lbeta(a, b)
    exp(lb)
  }
}
def trigamma_asymptotic(x: f32) -> f32 = {
  one = cast(1.0, f32)
  inv_x = div(one, x)
  inv_x2 = mul(inv_x, inv_x)
  inv_x3 = mul(inv_x2, inv_x)
  inv_x5 = mul(inv_x3, inv_x2)
  inv_x7 = mul(inv_x5, inv_x2)
  half = cast(0.5, f32)
  c3 = cast(0.16666666666666666, f32)
  c5 = cast(0.03333333333333333, f32)
  c7 = cast(0.023809523809523808, f32)
  t1 = inv_x
  t2 = mul(half, inv_x2)
  t3 = mul(c3, inv_x3)
  t4 = mul(c5, inv_x5)
  t5 = mul(c7, inv_x7)
  __borrow_migration_out_1 = add(sub(add(add(t1, t2), t3), t4), t5)
  _ = drop(t1)
  _ = drop(t2)
  _ = drop(t3)
  _ = drop(t4)
  __borrow_migration_out_1
}
def trigamma_rec(x: f32, acc: f32) -> f32 = {
  six = cast(6.0, f32)
  one = cast(1.0, f32)
  if gte(x, six) then add(trigamma_asymptotic(x), acc) else {
    inv_x = div(one, x)
    inv_x2 = mul(inv_x, inv_x)
    trigamma_rec(add(x, one), add(acc, inv_x2))
  }
}
def trigamma(x: f32) -> f32 = {
  zero = cast(0.0, f32)
  if lte(x, zero) then nan_f32() else trigamma_rec(x, zero)
}
def bessel_i0_small(ax: f32) -> f32 = {
  t = div(ax, cast(3.75, f32))
  y = mul(t, t)
  a0 = cast(1.0, f32)
  a1 = cast(3.5156229, f32)
  a2 = cast(3.0899424, f32)
  a3 = cast(1.2067492, f32)
  a4 = cast(0.2659732, f32)
  a5 = cast(0.0360768, f32)
  a6 = cast(0.0045813, f32)
  __borrow_migration_out_2 = add(a0, mul(y, add(a1, mul(y, add(a2, mul(y, add(a3, mul(y, add(a4, mul(y, add(a5, mul(y, a6))))))))))))
  _ = drop(a2)
  _ = drop(a3)
  __borrow_migration_out_2
}
def bessel_i0_large(ax: f32) -> f32 = {
  t = div(cast(3.75, f32), ax)
  a0 = cast(0.39894228, f32)
  a1 = cast(0.01328592, f32)
  a2 = cast(0.00225319, f32)
  a3 = cast(-0.00157565, f32)
  a4 = cast(0.00916281, f32)
  a5 = cast(-0.02057706, f32)
  a6 = cast(0.02635537, f32)
  a7 = cast(-0.01647633, f32)
  a8 = cast(0.00392377, f32)
  poly = add(a0, mul(t, add(a1, mul(t, add(a2, mul(t, add(a3, mul(t, add(a4, mul(t, add(a5, mul(t, add(a6, mul(t, add(a7, mul(t, a8))))))))))))))))
  e = exp(ax)
  s = sqrt(ax)
  __borrow_migration_out_3 = div(mul(e, poly), s)
  _ = drop(a2)
  _ = drop(a3)
  __borrow_migration_out_3
}
def bessel_i0(x: f32) -> f32 = {
  ax = abs_f32(x)
  if lt(ax, cast(3.75, f32)) then bessel_i0_small(ax) else bessel_i0_large(ax)
}
def bessel_i1_small(ax: f32) -> f32 = {
  t = div(ax, cast(3.75, f32))
  y = mul(t, t)
  a0 = cast(0.5, f32)
  a1 = cast(0.87890594, f32)
  a2 = cast(0.51498869, f32)
  a3 = cast(0.15084934, f32)
  a4 = cast(0.02658733, f32)
  a5 = cast(0.00301532, f32)
  a6 = cast(0.00032411, f32)
  poly = add(a0, mul(y, add(a1, mul(y, add(a2, mul(y, add(a3, mul(y, add(a4, mul(y, add(a5, mul(y, a6))))))))))))
  __borrow_migration_out_4 = mul(ax, poly)
  _ = drop(a2)
  _ = drop(a3)
  __borrow_migration_out_4
}
def bessel_i1_large(ax: f32) -> f32 = {
  t = div(cast(3.75, f32), ax)
  a0 = cast(0.39894228, f32)
  a1 = cast(-0.03988024, f32)
  a2 = cast(-0.00362018, f32)
  a3 = cast(0.00163801, f32)
  a4 = cast(-0.01031555, f32)
  a5 = cast(0.02282967, f32)
  a6 = cast(-0.02895312, f32)
  a7 = cast(0.01787654, f32)
  a8 = cast(-0.00420059, f32)
  poly = add(a0, mul(t, add(a1, mul(t, add(a2, mul(t, add(a3, mul(t, add(a4, mul(t, add(a5, mul(t, add(a6, mul(t, add(a7, mul(t, a8))))))))))))))))
  e = exp(ax)
  s = sqrt(ax)
  __borrow_migration_out_5 = div(mul(e, poly), s)
  _ = drop(a2)
  _ = drop(a3)
  __borrow_migration_out_5
}
def bessel_i1(x: f32) -> f32 = {
  ax = abs_f32(x)
  ans = if lt(ax, cast(3.75, f32)) then bessel_i1_small(ax) else bessel_i1_large(ax)
  if lt(x, cast(0.0, f32)) then neg(ans) else ans
}
def bessel_k0_small(x: f32) -> f32 = {
  half_x = mul(x, cast(0.5, f32))
  y = mul(half_x, half_x)
  a0 = cast(-0.57721566, f32)
  a1 = cast(0.4227842, f32)
  a2 = cast(0.23069756, f32)
  a3 = cast(0.0348859, f32)
  a4 = cast(0.00262698, f32)
  a5 = cast(0.0001075, f32)
  a6 = cast(0.0000074, f32)
  poly = add(a0, mul(y, add(a1, mul(y, add(a2, mul(y, add(a3, mul(y, add(a4, mul(y, add(a5, mul(y, a6))))))))))))
  lhx = log(half_x)
  i0 = bessel_i0(x)
  __borrow_migration_out_6 = sub(poly, mul(lhx, i0))
  _ = drop(a2)
  _ = drop(a3)
  __borrow_migration_out_6
}
def bessel_k0_large(x: f32) -> f32 = {
  t = div(cast(2.0, f32), x)
  a0 = cast(1.25331414, f32)
  a1 = cast(-0.07832358, f32)
  a2 = cast(0.02189568, f32)
  a3 = cast(-0.01062446, f32)
  a4 = cast(0.00587872, f32)
  a5 = cast(-0.0025154, f32)
  a6 = cast(0.00053208, f32)
  poly = add(a0, mul(t, add(a1, mul(t, add(a2, mul(t, add(a3, mul(t, add(a4, mul(t, add(a5, mul(t, a6))))))))))))
  nx = neg(x)
  e = exp(nx)
  s = sqrt(x)
  __borrow_migration_out_7 = div(mul(e, poly), s)
  _ = drop(a2)
  _ = drop(a3)
  __borrow_migration_out_7
}
def bessel_k0(x: f32) -> f32 = {
  zero = cast(0.0, f32)
  if lt(x, zero) then nan_f32() else if eq(x, zero) then pos_inf() else if lte(x, cast(2.0, f32)) then bessel_k0_small(x) else bessel_k0_large(x)
}
def bessel_k1_small(x: f32) -> f32 = {
  half_x = mul(x, cast(0.5, f32))
  y = mul(half_x, half_x)
  a0 = cast(1.0, f32)
  a1 = cast(0.15443144, f32)
  a2 = cast(-0.67278579, f32)
  a3 = cast(-0.18156897, f32)
  a4 = cast(-0.01919402, f32)
  a5 = cast(-0.00110404, f32)
  a6 = cast(-0.00004686, f32)
  poly = add(a0, mul(y, add(a1, mul(y, add(a2, mul(y, add(a3, mul(y, add(a4, mul(y, add(a5, mul(y, a6))))))))))))
  lhx = log(half_x)
  i1 = bessel_i1(x)
  inv_x = div(cast(1.0, f32), x)
  __borrow_migration_out_8 = add(mul(lhx, i1), mul(inv_x, poly))
  _ = drop(a2)
  _ = drop(a3)
  __borrow_migration_out_8
}
def bessel_k1_large(x: f32) -> f32 = {
  t = div(cast(2.0, f32), x)
  a0 = cast(1.25331414, f32)
  a1 = cast(0.23498619, f32)
  a2 = cast(-0.0365562, f32)
  a3 = cast(0.01504268, f32)
  a4 = cast(-0.00780353, f32)
  a5 = cast(0.00325614, f32)
  a6 = cast(-0.00068245, f32)
  poly = add(a0, mul(t, add(a1, mul(t, add(a2, mul(t, add(a3, mul(t, add(a4, mul(t, add(a5, mul(t, a6))))))))))))
  nx = neg(x)
  e = exp(nx)
  s = sqrt(x)
  __borrow_migration_out_9 = div(mul(e, poly), s)
  _ = drop(a2)
  _ = drop(a3)
  __borrow_migration_out_9
}
def bessel_k1(x: f32) -> f32 = {
  zero = cast(0.0, f32)
  if lt(x, zero) then nan_f32() else if eq(x, zero) then pos_inf() else if lte(x, cast(2.0, f32)) then bessel_k1_small(x) else bessel_k1_large(x)
}
def bessel_j0_small(ax: f32) -> f32 = {
  y = mul(ax, ax)
  n0 = cast(57568490574.0, f32)
  n1 = cast(-13362590354.0, f32)
  n2 = cast(651619640.7, f32)
  n3 = cast(-11214424.18, f32)
  n4 = cast(77392.33017, f32)
  n5 = cast(-184.9052456, f32)
  d0 = cast(57568490411.0, f32)
  d1 = cast(1029532985.0, f32)
  d2 = cast(9494680.718, f32)
  d3 = cast(59272.64853, f32)
  d4 = cast(267.8532712, f32)
  d5 = cast(1.0, f32)
  num = add(n0, mul(y, add(n1, mul(y, add(n2, mul(y, add(n3, mul(y, add(n4, mul(y, n5))))))))))
  den = add(d0, mul(y, add(d1, mul(y, add(d2, mul(y, add(d3, mul(y, add(d4, mul(y, d5))))))))))
  div(num, den)
}
def bessel_j0_large(ax: f32) -> f32 = {
  z = div(cast(8.0, f32), ax)
  y = mul(z, z)
  p0 = cast(1.0, f32)
  p1 = cast(-0.001098628627, f32)
  p2 = cast(0.00002734510407, f32)
  p3 = cast(-0.000002073370639, f32)
  p4 = cast(0.0000002093887211, f32)
  q0 = cast(-0.01562499995, f32)
  q1 = cast(0.0001430488765, f32)
  q2 = cast(-0.000006911147651, f32)
  q3 = cast(0.0000007621095161, f32)
  q4 = cast(-0.0000000934935152, f32)
  pp = add(p0, mul(y, add(p1, mul(y, add(p2, mul(y, add(p3, mul(y, p4))))))))
  qq = add(q0, mul(y, add(q1, mul(y, add(q2, mul(y, add(q3, mul(y, q4))))))))
  phi = cast(0.785398163397448, f32)
  xx = sub(ax, phi)
  half_pi = cast(1.5707963267948966, f32)
  cos_xx = sin(add(xx, half_pi))
  sin_xx = sin(xx)
  two_over_pi = cast(0.6366197723675814, f32)
  pre = sqrt(div(two_over_pi, ax))
  body = sub(mul(cos_xx, pp), mul(mul(z, sin_xx), qq))
  mul(pre, body)
}
def bessel_j0(x: f32) -> f32 = {
  ax = abs_f32(x)
  if lt(ax, cast(8.0, f32)) then bessel_j0_small(ax) else bessel_j0_large(ax)
}
def bessel_j1_small(ax: f32) -> f32 = {
  y = mul(ax, ax)
  n0 = cast(72362614232.0, f32)
  n1 = cast(-7895059235.0, f32)
  n2 = cast(242396853.1, f32)
  n3 = cast(-2972611.439, f32)
  n4 = cast(15704.4826, f32)
  n5 = cast(-30.16036606, f32)
  d0 = cast(144725228442.0, f32)
  d1 = cast(2300535178.0, f32)
  d2 = cast(18583304.74, f32)
  d3 = cast(99447.43394, f32)
  d4 = cast(376.9991397, f32)
  d5 = cast(1.0, f32)
  num = add(n0, mul(y, add(n1, mul(y, add(n2, mul(y, add(n3, mul(y, add(n4, mul(y, n5))))))))))
  den = add(d0, mul(y, add(d1, mul(y, add(d2, mul(y, add(d3, mul(y, add(d4, mul(y, d5))))))))))
  mul(ax, div(num, den))
}
def bessel_j1_large(ax: f32) -> f32 = {
  z = div(cast(8.0, f32), ax)
  y = mul(z, z)
  p0 = cast(1.0, f32)
  p1 = cast(0.00183105, f32)
  p2 = cast(-0.00003516396496, f32)
  p3 = cast(0.000002457520174, f32)
  p4 = cast(-0.000000240337019, f32)
  q0 = cast(0.04687499995, f32)
  q1 = cast(-0.0002002690873, f32)
  q2 = cast(0.000008449199096, f32)
  q3 = cast(-0.00000088228987, f32)
  q4 = cast(0.000000105787412, f32)
  pp = add(p0, mul(y, add(p1, mul(y, add(p2, mul(y, add(p3, mul(y, p4))))))))
  qq = add(q0, mul(y, add(q1, mul(y, add(q2, mul(y, add(q3, mul(y, q4))))))))
  phi = cast(2.356194490192345, f32)
  xx = sub(ax, phi)
  half_pi = cast(1.5707963267948966, f32)
  cos_xx = sin(add(xx, half_pi))
  sin_xx = sin(xx)
  two_over_pi = cast(0.6366197723675814, f32)
  pre = sqrt(div(two_over_pi, ax))
  body = sub(mul(cos_xx, pp), mul(mul(z, sin_xx), qq))
  mul(pre, body)
}
def bessel_j1(x: f32) -> f32 = {
  ax = abs_f32(x)
  ans = if lt(ax, cast(8.0, f32)) then bessel_j1_small(ax) else bessel_j1_large(ax)
  if lt(x, cast(0.0, f32)) then neg(ans) else ans
}
def bessel_y0_small(x: f32) -> f32 = {
  y = mul(x, x)
  n0 = cast(-2957821389.0, f32)
  n1 = cast(7062834065.0, f32)
  n2 = cast(-512359803.6, f32)
  n3 = cast(10879881.29, f32)
  n4 = cast(-86327.92757, f32)
  n5 = cast(228.4622733, f32)
  d0 = cast(40076544269.0, f32)
  d1 = cast(745249964.8, f32)
  d2 = cast(7189466.438, f32)
  d3 = cast(47447.2647, f32)
  d4 = cast(226.1030244, f32)
  d5 = cast(1.0, f32)
  num = add(n0, mul(y, add(n1, mul(y, add(n2, mul(y, add(n3, mul(y, add(n4, mul(y, n5))))))))))
  den = add(d0, mul(y, add(d1, mul(y, add(d2, mul(y, add(d3, mul(y, add(d4, mul(y, d5))))))))))
  rat = div(num, den)
  two_over_pi = cast(0.6366197723675814, f32)
  j0v = bessel_j0(x)
  lx = log(x)
  add(rat, mul(two_over_pi, mul(j0v, lx)))
}
def bessel_y0_large(x: f32) -> f32 = {
  z = div(cast(8.0, f32), x)
  y = mul(z, z)
  p0 = cast(1.0, f32)
  p1 = cast(-0.001098628627, f32)
  p2 = cast(0.00002734510407, f32)
  p3 = cast(-0.000002073370639, f32)
  p4 = cast(0.0000002093887211, f32)
  q0 = cast(-0.01562499995, f32)
  q1 = cast(0.0001430488765, f32)
  q2 = cast(-0.000006911147651, f32)
  q3 = cast(0.0000007621095161, f32)
  q4 = cast(-0.0000000934935152, f32)
  pp = add(p0, mul(y, add(p1, mul(y, add(p2, mul(y, add(p3, mul(y, p4))))))))
  qq = add(q0, mul(y, add(q1, mul(y, add(q2, mul(y, add(q3, mul(y, q4))))))))
  phi = cast(0.785398163397448, f32)
  xx = sub(x, phi)
  half_pi = cast(1.5707963267948966, f32)
  cos_xx = sin(add(xx, half_pi))
  sin_xx = sin(xx)
  two_over_pi = cast(0.6366197723675814, f32)
  pre = sqrt(div(two_over_pi, x))
  body = add(mul(sin_xx, pp), mul(mul(z, cos_xx), qq))
  mul(pre, body)
}
def bessel_y0(x: f32) -> f32 = {
  zero = cast(0.0, f32)
  if lt(x, zero) then nan_f32() else if eq(x, zero) then neg_inf() else if lt(x, cast(8.0, f32)) then bessel_y0_small(x) else bessel_y0_large(x)
}
def bessel_y1_small(x: f32) -> f32 = {
  y = mul(x, x)
  n0 = cast(-49006049430000.0, f32)
  n1 = cast(12752743900000.0, f32)
  n2 = cast(-515343813900.0, f32)
  n3 = cast(7349264551.0, f32)
  n4 = cast(-42379227.26, f32)
  n5 = cast(85119.37935, f32)
  d0 = cast(249958057000000.0, f32)
  d1 = cast(4244419664000.0, f32)
  d2 = cast(37336503670.0, f32)
  d3 = cast(224590400.2, f32)
  d4 = cast(1020426.05, f32)
  d5 = cast(3549.632885, f32)
  d6 = cast(1.0, f32)
  num = add(n0, mul(y, add(n1, mul(y, add(n2, mul(y, add(n3, mul(y, add(n4, mul(y, n5))))))))))
  den = add(d0, mul(y, add(d1, mul(y, add(d2, mul(y, add(d3, mul(y, add(d4, mul(y, add(d5, mul(y, d6))))))))))))
  rat = mul(x, div(num, den))
  two_over_pi = cast(0.6366197723675814, f32)
  j1v = bessel_j1(x)
  lx = log(x)
  inv_x = div(cast(1.0, f32), x)
  add(rat, mul(two_over_pi, sub(mul(j1v, lx), inv_x)))
}
def bessel_y1_large(x: f32) -> f32 = {
  z = div(cast(8.0, f32), x)
  y = mul(z, z)
  p0 = cast(1.0, f32)
  p1 = cast(0.00183105, f32)
  p2 = cast(-0.00003516396496, f32)
  p3 = cast(0.000002457520174, f32)
  p4 = cast(-0.000000240337019, f32)
  q0 = cast(0.04687499995, f32)
  q1 = cast(-0.0002002690873, f32)
  q2 = cast(0.000008449199096, f32)
  q3 = cast(-0.00000088228987, f32)
  q4 = cast(0.000000105787412, f32)
  pp = add(p0, mul(y, add(p1, mul(y, add(p2, mul(y, add(p3, mul(y, p4))))))))
  qq = add(q0, mul(y, add(q1, mul(y, add(q2, mul(y, add(q3, mul(y, q4))))))))
  phi = cast(2.356194490192345, f32)
  xx = sub(x, phi)
  half_pi = cast(1.5707963267948966, f32)
  cos_xx = sin(add(xx, half_pi))
  sin_xx = sin(xx)
  two_over_pi = cast(0.6366197723675814, f32)
  pre = sqrt(div(two_over_pi, x))
  body = add(mul(sin_xx, pp), mul(mul(z, cos_xx), qq))
  mul(pre, body)
}
def bessel_y1(x: f32) -> f32 = {
  zero = cast(0.0, f32)
  if lt(x, zero) then nan_f32() else if eq(x, zero) then neg_inf() else if lt(x, cast(7.5, f32)) then bessel_y1_small(x) else bessel_y1_large(x)
}
def airy_f_rec(x3: f32, term: f32, acc: f32, k: f32, iters: int64) -> f32 = {
  zero_i = cast(0, int64)
  one_i = cast(1, int64)
  one_f = cast(1.0, f32)
  three = cast(3.0, f32)
  if lte(iters, zero_i) then acc else {
    k3 = mul(three, k)
    denom = mul(add(k3, cast(2.0, f32)), add(k3, three))
    term_next = div(mul(term, x3), denom)
    acc_next = add(acc, term_next)
    abs_term = abs_f32(term_next)
    abs_acc = abs_f32(acc_next)
    floor = one_f
    scale = if gt(abs_acc, floor) then abs_acc else floor
    tol = cast(0.00000001, f32)
    converged = lt(abs_term, mul(tol, scale))
    __borrow_migration_out_10 = if converged then acc_next else airy_f_rec(x3, term_next, acc_next, add(k, one_f), sub(iters, one_i))
    _ = drop(k3)
    __borrow_migration_out_10
  }
}
def airy_g_rec(x3: f32, term: f32, acc: f32, k: f32, iters: int64) -> f32 = {
  zero_i = cast(0, int64)
  one_i = cast(1, int64)
  one_f = cast(1.0, f32)
  three = cast(3.0, f32)
  if lte(iters, zero_i) then acc else {
    k3 = mul(three, k)
    denom = mul(add(k3, three), add(k3, cast(4.0, f32)))
    term_next = div(mul(term, x3), denom)
    acc_next = add(acc, term_next)
    abs_term = abs_f32(term_next)
    abs_acc = abs_f32(acc_next)
    floor = one_f
    scale = if gt(abs_acc, floor) then abs_acc else floor
    tol = cast(0.00000001, f32)
    converged = lt(abs_term, mul(tol, scale))
    __borrow_migration_out_11 = if converged then acc_next else airy_g_rec(x3, term_next, acc_next, add(k, one_f), sub(iters, one_i))
    _ = drop(k3)
    __borrow_migration_out_11
  }
}
def airy_fg(x: f32) -> f32 = {
  x2 = mul(x, x)
  x3 = mul(x2, x)
  airy_f_rec(x3, cast(1.0, f32), cast(1.0, f32), cast(0.0, f32), cast(50, int64))
}
def airy_gg(x: f32) -> f32 = {
  x2 = mul(x, x)
  x3 = mul(x2, x)
  airy_g_rec(x3, x, x, cast(0.0, f32), cast(50, int64))
}
def airy_ai_asymptotic_pos(x: f32) -> f32 = {
  sqrt_x = sqrt(x)
  x_to_1_5 = mul(x, sqrt_x)
  xi = mul(cast(0.6666666666666666, f32), x_to_1_5)
  neg_xi = neg(xi)
  exp_neg_xi = exp(neg_xi)
  x_to_0_25 = sqrt(sqrt_x)
  inv_x_0_25 = div(cast(1.0, f32), x_to_0_25)
  two_sqrt_pi = cast(3.5449077018110318, f32)
  pre = div(inv_x_0_25, two_sqrt_pi)
  mul(pre, exp_neg_xi)
}
def airy_bi_asymptotic_pos(x: f32) -> f32 = {
  sqrt_x = sqrt(x)
  x_to_1_5 = mul(x, sqrt_x)
  xi = mul(cast(0.6666666666666666, f32), x_to_1_5)
  exp_xi = exp(xi)
  x_to_0_25 = sqrt(sqrt_x)
  inv_x_0_25 = div(cast(1.0, f32), x_to_0_25)
  sqrt_pi = cast(1.7724538509055159, f32)
  pre = div(inv_x_0_25, sqrt_pi)
  mul(pre, exp_xi)
}
def airy_ai(x: f32) -> f32 = {
  c1 = cast(0.3550280538878172, f32)
  c2 = cast(0.2588194037928068, f32)
  if gt(x, cast(5.0, f32)) then airy_ai_asymptotic_pos(x) else {
    f = airy_fg(x)
    g = airy_gg(x)
    sub(mul(c1, f), mul(c2, g))
  }
}
def airy_bi(x: f32) -> f32 = {
  c1 = cast(0.3550280538878172, f32)
  c2 = cast(0.2588194037928068, f32)
  sqrt3 = cast(1.7320508075688772, f32)
  if gt(x, cast(5.0, f32)) then airy_bi_asymptotic_pos(x) else {
    f = airy_fg(x)
    g = airy_gg(x)
    mul(sqrt3, add(mul(c1, f), mul(c2, g)))
  }
}
def ellip_agm_a_rec(a: f32, b: f32, iters: int64) -> f32 = {
  zero_i = cast(0, int64)
  one_i = cast(1, int64)
  two = cast(2.0, f32)
  if lte(iters, zero_i) then a else {
    a_next = div(add(a, b), two)
    b_next = sqrt(mul(a, b))
    c_next = div(sub(a, b), two)
    tol = cast(0.00000001, f32)
    converged = lt(abs_f32(c_next), mul(tol, a_next))
    if converged then a_next else ellip_agm_a_rec(a_next, b_next, sub(iters, one_i))
  }
}
def ellip_agm_csum_rec(a: f32, b: f32, c_sum: f32, weight: f32, iters: int64) -> f32 = {
  zero_i = cast(0, int64)
  one_i = cast(1, int64)
  two = cast(2.0, f32)
  if lte(iters, zero_i) then c_sum else {
    a_next = div(add(a, b), two)
    b_next = sqrt(mul(a, b))
    c_next = div(sub(a, b), two)
    w_next = mul(weight, two)
    c2 = mul(c_next, c_next)
    c_sum_next = add(c_sum, mul(w_next, c2))
    tol = cast(0.00000001, f32)
    converged = lt(abs_f32(c_next), mul(tol, a_next))
    if converged then c_sum_next else ellip_agm_csum_rec(a_next, b_next, c_sum_next, w_next, sub(iters, one_i))
  }
}
def ellipk(m: f32) -> f32 = {
  zero = cast(0.0, f32)
  one = cast(1.0, f32)
  if lt(m, zero) then nan_f32() else if gt(m, one) then nan_f32() else if eq(m, one) then pos_inf() else {
    half_pi = cast(1.5707963267948966, f32)
    om = sub(one, m)
    b0 = sqrt(om)
    a_inf = ellip_agm_a_rec(one, b0, cast(50, int64))
    __borrow_migration_out_12 = div(half_pi, a_inf)
    _ = drop(b0)
    __borrow_migration_out_12
  }
}
def ellipe(m: f32) -> f32 = {
  zero = cast(0.0, f32)
  one = cast(1.0, f32)
  if lt(m, zero) then nan_f32() else if gt(m, one) then nan_f32() else if eq(m, one) then one else {
    half_pi = cast(1.5707963267948966, f32)
    om = sub(one, m)
    b0 = sqrt(om)
    c0 = sqrt(m)
    c0_sq = mul(c0, c0)
    init_sum = mul(cast(0.5, f32), c0_sq)
    a_inf = ellip_agm_a_rec(one, b0, cast(50, int64))
    c_sum = ellip_agm_csum_rec(one, b0, init_sum, cast(0.5, f32), cast(50, int64))
    k = div(half_pi, a_inf)
    __borrow_migration_out_13 = mul(k, sub(one, c_sum))
    _ = drop(b0)
    __borrow_migration_out_13
  }
}
