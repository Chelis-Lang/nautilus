module Nautilus.Special
export (erfinv, erfinv_t, gamma, log_gamma, digamma, beta, lbeta, trigamma, bessel_i0, bessel_i1, bessel_k0, bessel_k1, bessel_j0, bessel_j1, bessel_y0, bessel_y1, airy_ai, airy_bi, ellipk, ellipe)
def sp_abs[prec: {f32, f64}](x: prec) -> prec = if lt(x, cast(0.0, prec)) then neg(x) else x
def is_nonpositive_integer[prec: {f32, f64}](x: prec) -> bool = {
  zero = cast(0.0, prec)
  if gt(x, zero) then false else {
    xi_i = cast_trunc(x, i64)
    xi = cast(xi_i, prec)
    eq(x, xi)
  }
}
def pos_inf[prec: {f32, f64}]() -> prec = cast(1.0, prec) |> div(cast(0.0, prec))
def neg_inf[prec: {f32, f64}]() -> prec = cast(-1.0, prec) |> div(cast(0.0, prec))
def sp_nan[prec: {f32, f64}]() -> prec = cast(0.0, prec) |> div(cast(0.0, prec))
def lanczos_sum[prec: {f32, f64}](x: prec) -> prec = {
  c0 = cast(0.9999999999998099, prec)
  c1 = cast(676.5203681218851, prec)
  c2 = cast(-1259.1392167224028, prec)
  c3 = cast(771.3234287776531, prec)
  c4 = cast(-176.6150291621406, prec)
  c5 = cast(12.507343278686905, prec)
  c6 = cast(-0.13857109526572012, prec)
  c7 = cast(9.984369578019572e-6, prec)
  c8 = cast(1.5056327351493116e-7, prec)
  one = cast(1.0, prec)
  t1 = div(c1, add(x, one))
  t2 = div(c2, add(x, cast(2.0, prec)))
  t3 = div(c3, add(x, cast(3.0, prec)))
  t4 = div(c4, add(x, cast(4.0, prec)))
  t5 = div(c5, add(x, cast(5.0, prec)))
  t6 = div(c6, add(x, cast(6.0, prec)))
  t7 = div(c7, add(x, cast(7.0, prec)))
  t8 = div(c8, add(x, cast(8.0, prec)))
  add(add(add(add(add(add(add(add(c0, t1), t2), t3), t4), t5), t6), t7), t8)
}
def log_gamma_core[prec: {f32, f64}](x: prec) -> prec = {
  half = cast(0.5, prec)
  log_sqrt_2pi = cast(0.9189385332046727, prec)
  g_plus_half = cast(7.5, prec)
  xm1 = sub(x, cast(1.0, prec))
  a = lanczos_sum(xm1)
  t = add(xm1, g_plus_half)
  log_t = log(t)
  log_a = log(a)
  log_sqrt_2pi |> add(mul(add(xm1, half), log_t)) |> add(sub(log_a, t))
}
def log_gamma[prec: {f32, f64}](x: prec) -> prec = {
  half = cast(0.5, prec)
  pi = cast(3.141592653589793, prec)
  log_pi = cast(1.1447298858494002, prec)
  if is_nonpositive_integer(x) then pos_inf() else if lt(x, half) then {
    pix = mul(pi, x)
    spix = sin(pix)
    aspix = sp_abs(spix)
    log_aspix = log(aspix)
    one_minus_x = cast(1.0, prec) |> sub(x)
    lgc = log_gamma_core(one_minus_x)
    log_pi |> sub(log_aspix) |> sub(lgc)
  } else log_gamma_core(x)
}
def gamma[prec: {f32, f64}](x: prec) -> prec = {
  half = cast(0.5, prec)
  pi = cast(3.141592653589793, prec)
  if is_nonpositive_integer(x) then pos_inf() else if lt(x, half) then {
    pix = mul(pi, x)
    spix = sin(pix)
    one_minus_x = cast(1.0, prec) |> sub(x)
    g1 = one_minus_x |> log_gamma_core |> exp
    div(pi, mul(spix, g1))
  } else (x |> log_gamma_core |> exp)
}
def digamma_asymptotic[prec: {f32, f64}](x: prec) -> prec = {
  one = cast(1.0, prec)
  inv_x = div(one, x)
  inv_x2 = mul(inv_x, inv_x)
  inv_x4 = mul(inv_x2, inv_x2)
  inv_x6 = mul(inv_x4, inv_x2)
  c2 = cast(0.5, prec)
  c12 = cast(0.08333333333333333, prec)
  c120 = cast(0.008333333333333333, prec)
  c252 = cast(0.003968253968253968, prec)
  log_x = log(x)
  sub(sub(add(sub(log_x, mul(c2, inv_x)), mul(c120, inv_x4)), mul(c12, inv_x2)), mul(c252, inv_x6))
}
def digamma_rec[prec: {f32, f64}](x: prec, acc: prec) -> prec = {
  six = cast(6.0, prec)
  one = cast(1.0, prec)
  if gte(x, six) then (x |> digamma_asymptotic |> add(acc)) else (x |> add(one) |> digamma_rec(sub(acc, div(one, x))))
}
def digamma[prec: {f32, f64}](x: prec) -> prec = if is_nonpositive_integer(x) then sp_nan() else digamma_rec(x, cast(0.0, prec))
def acklam_central[prec: {f32, f64}](q: prec) -> prec = {
  a1 = cast(-39.69683028665376, prec)
  a2 = cast(220.9460984245205, prec)
  a3 = cast(-275.9285104469687, prec)
  a4 = cast(138.357751867269, prec)
  a5 = cast(-30.66479806614716, prec)
  a6 = cast(2.506628277459239, prec)
  b1 = cast(-54.47609879822406, prec)
  b2 = cast(161.5858368580409, prec)
  b3 = cast(-155.6989798598866, prec)
  b4 = cast(66.80131188771972, prec)
  b5 = cast(-13.28068155288572, prec)
  one = cast(1.0, prec)
  half = cast(0.5, prec)
  u = sub(q, half)
  r = mul(u, u)
  num = mul(add(mul(r, add(mul(r, add(mul(r, add(mul(r, add(mul(r, a1), a2)), a3)), a4)), a5)), a6), u)
  den = add(mul(r, add(mul(r, add(mul(r, add(mul(r, add(mul(r, b1), b2)), b3)), b4)), b5)), one)
  div(num, den)
}
def acklam_tail[prec: {f32, f64}](u: prec) -> prec = {
  c1 = cast(-0.007784894002430293, prec)
  c2 = cast(-0.3223964580411365, prec)
  c3 = cast(-2.400758277161838, prec)
  c4 = cast(-2.549732539343734, prec)
  c5 = cast(4.374664141464968, prec)
  c6 = cast(2.938163982698783, prec)
  d1 = cast(0.007784695709041462, prec)
  d2 = cast(0.3224671290700398, prec)
  d3 = cast(2.445134137142996, prec)
  d4 = cast(3.754408661907416, prec)
  one = cast(1.0, prec)
  num = add(mul(u, add(mul(u, add(mul(u, add(mul(u, add(mul(u, c1), c2)), c3)), c4)), c5)), c6)
  den =
    u
    |> mul(add(mul(u, add(mul(u, add(mul(u, d1), d2)), d3)), d4))
    |> add(one)
  div(num, den)
}
def norminv[prec: {f32, f64}](q: prec) -> prec = {
  plow = cast(0.02425, prec)
  one = cast(1.0, prec)
  phigh = sub(one, plow)
  two = cast(2.0, prec)
  if lt(q, plow) then {
    lq = log(q)
    mlq = two |> mul(lq) |> neg
    u = sqrt(mlq)
    acklam_tail(u)
  } else if lte(q, phigh) then acklam_central(q) else {
    omq = sub(one, q)
    lomq = log(omq)
    mlomq = two |> mul(lomq) |> neg
    u = sqrt(mlomq)
    u |> acklam_tail |> neg
  }
}
def erfinv[prec: {f32, f64}](x: prec) -> prec = {
  half = cast(0.5, prec)
  sqrt_half = cast(0.7071067811865476, prec)
  q = x |> add(cast(1.0, prec)) |> mul(half)
  q |> norminv |> mul(sqrt_half)
}
def lbeta[prec: {f32, f64}](a: prec, b: prec) -> prec = {
  zero = cast(0.0, prec)
  if (a |> lte(zero) |> or(lte(b, zero))) then sp_nan() else {
    la = log_gamma(a)
    lb = log_gamma(b)
    lab = a |> add(b) |> log_gamma
    la |> add(lb) |> sub(lab)
  }
}
def beta[prec: {f32, f64}](a: prec, b: prec) -> prec = {
  zero = cast(0.0, prec)
  if (a |> lte(zero) |> or(lte(b, zero))) then sp_nan() else {
    lb = lbeta(a, b)
    exp(lb)
  }
}
def trigamma_asymptotic[prec: {f32, f64}](x: prec) -> prec = {
  one = cast(1.0, prec)
  inv_x = div(one, x)
  inv_x2 = mul(inv_x, inv_x)
  inv_x3 = mul(inv_x2, inv_x)
  inv_x5 = mul(inv_x3, inv_x2)
  inv_x7 = mul(inv_x5, inv_x2)
  half = cast(0.5, prec)
  c3 = cast(0.16666666666666666, prec)
  c5 = cast(0.03333333333333333, prec)
  c7 = cast(0.023809523809523808, prec)
  t1 = inv_x
  t2 = mul(half, inv_x2)
  t3 = mul(c3, inv_x3)
  t4 = mul(c5, inv_x5)
  t5 = mul(c7, inv_x7)
  add(sub(add(add(t1, t2), t3), t4), t5)
}
def trigamma_rec[prec: {f32, f64}](x: prec, acc: prec) -> prec = {
  six = cast(6.0, prec)
  one = cast(1.0, prec)
  if gte(x, six) then (x |> trigamma_asymptotic |> add(acc)) else {
    inv_x = div(one, x)
    inv_x2 = mul(inv_x, inv_x)
    x |> add(one) |> trigamma_rec(add(acc, inv_x2))
  }
}
def trigamma[prec: {f32, f64}](x: prec) -> prec = {
  zero = cast(0.0, prec)
  if lte(x, zero) then sp_nan() else trigamma_rec(x, zero)
}
def bessel_i0_small[prec: {f32, f64}](ax: prec) -> prec = {
  t = div(ax, cast(3.75, prec))
  y = mul(t, t)
  a0 = cast(1.0, prec)
  a1 = cast(3.5156229, prec)
  a2 = cast(3.0899424, prec)
  a3 = cast(1.2067492, prec)
  a4 = cast(0.2659732, prec)
  a5 = cast(0.0360768, prec)
  a6 = cast(0.0045813, prec)
  add(a0, mul(y, add(a1, mul(y, add(a2, mul(y, add(a3, mul(y, add(a4, mul(y, add(a5, mul(y, a6))))))))))))
}
def bessel_i0_large[prec: {f32, f64}](ax: prec) -> prec = {
  t = cast(3.75, prec) |> div(ax)
  a0 = cast(0.39894228, prec)
  a1 = cast(0.01328592, prec)
  a2 = cast(0.00225319, prec)
  a3 = cast(-0.00157565, prec)
  a4 = cast(0.00916281, prec)
  a5 = cast(-0.02057706, prec)
  a6 = cast(0.02635537, prec)
  a7 = cast(-0.01647633, prec)
  a8 = cast(0.00392377, prec)
  poly = add(a0, mul(t, add(a1, mul(t, add(a2, mul(t, add(a3, mul(t, add(a4, mul(t, add(a5, mul(t, add(a6, mul(t, add(a7, mul(t, a8))))))))))))))))
  e = exp(ax)
  s = sqrt(ax)
  e |> mul(poly) |> div(s)
}
def bessel_i0[prec: {f32, f64}](x: prec) -> prec = {
  ax = sp_abs(x)
  if lt(ax, cast(3.75, prec)) then bessel_i0_small(ax) else bessel_i0_large(ax)
}
def bessel_i1_small[prec: {f32, f64}](ax: prec) -> prec = {
  t = div(ax, cast(3.75, prec))
  y = mul(t, t)
  a0 = cast(0.5, prec)
  a1 = cast(0.87890594, prec)
  a2 = cast(0.51498869, prec)
  a3 = cast(0.15084934, prec)
  a4 = cast(0.02658733, prec)
  a5 = cast(0.00301532, prec)
  a6 = cast(0.00032411, prec)
  poly = add(a0, mul(y, add(a1, mul(y, add(a2, mul(y, add(a3, mul(y, add(a4, mul(y, add(a5, mul(y, a6))))))))))))
  mul(ax, poly)
}
def bessel_i1_large[prec: {f32, f64}](ax: prec) -> prec = {
  t = cast(3.75, prec) |> div(ax)
  a0 = cast(0.39894228, prec)
  a1 = cast(-0.03988024, prec)
  a2 = cast(-0.00362018, prec)
  a3 = cast(0.00163801, prec)
  a4 = cast(-0.01031555, prec)
  a5 = cast(0.02282967, prec)
  a6 = cast(-0.02895312, prec)
  a7 = cast(0.01787654, prec)
  a8 = cast(-0.00420059, prec)
  poly = add(a0, mul(t, add(a1, mul(t, add(a2, mul(t, add(a3, mul(t, add(a4, mul(t, add(a5, mul(t, add(a6, mul(t, add(a7, mul(t, a8))))))))))))))))
  e = exp(ax)
  s = sqrt(ax)
  e |> mul(poly) |> div(s)
}
def bessel_i1[prec: {f32, f64}](x: prec) -> prec = {
  ax = sp_abs(x)
  ans = if lt(ax, cast(3.75, prec)) then bessel_i1_small(ax) else bessel_i1_large(ax)
  if lt(x, cast(0.0, prec)) then neg(ans) else ans
}
def bessel_k0_small[prec: {f32, f64}](x: prec) -> prec = {
  half_x = mul(x, cast(0.5, prec))
  y = mul(half_x, half_x)
  a0 = cast(-0.57721566, prec)
  a1 = cast(0.4227842, prec)
  a2 = cast(0.23069756, prec)
  a3 = cast(0.0348859, prec)
  a4 = cast(0.00262698, prec)
  a5 = cast(0.0001075, prec)
  a6 = cast(7.4e-6, prec)
  poly = add(a0, mul(y, add(a1, mul(y, add(a2, mul(y, add(a3, mul(y, add(a4, mul(y, add(a5, mul(y, a6))))))))))))
  lhx = log(half_x)
  i0 = bessel_i0(x)
  sub(poly, mul(lhx, i0))
}
def bessel_k0_large[prec: {f32, f64}](x: prec) -> prec = {
  t = cast(2.0, prec) |> div(x)
  a0 = cast(1.25331414, prec)
  a1 = cast(-0.07832358, prec)
  a2 = cast(0.02189568, prec)
  a3 = cast(-0.01062446, prec)
  a4 = cast(0.00587872, prec)
  a5 = cast(-0.0025154, prec)
  a6 = cast(0.00053208, prec)
  poly = add(a0, mul(t, add(a1, mul(t, add(a2, mul(t, add(a3, mul(t, add(a4, mul(t, add(a5, mul(t, a6))))))))))))
  nx = neg(x)
  e = exp(nx)
  s = sqrt(x)
  e |> mul(poly) |> div(s)
}
def bessel_k0[prec: {f32, f64}](x: prec) -> prec = {
  zero = cast(0.0, prec)
  if lt(x, zero) then sp_nan() else if eq(x, zero) then pos_inf() else if lte(x, cast(2.0, prec)) then bessel_k0_small(x) else bessel_k0_large(x)
}
def bessel_k1_small[prec: {f32, f64}](x: prec) -> prec = {
  half_x = mul(x, cast(0.5, prec))
  y = mul(half_x, half_x)
  a0 = cast(1.0, prec)
  a1 = cast(0.15443144, prec)
  a2 = cast(-0.67278579, prec)
  a3 = cast(-0.18156897, prec)
  a4 = cast(-0.01919402, prec)
  a5 = cast(-0.00110404, prec)
  a6 = cast(-0.00004686, prec)
  poly = add(a0, mul(y, add(a1, mul(y, add(a2, mul(y, add(a3, mul(y, add(a4, mul(y, add(a5, mul(y, a6))))))))))))
  lhx = log(half_x)
  i1 = bessel_i1(x)
  inv_x = cast(1.0, prec) |> div(x)
  lhx |> mul(i1) |> add(mul(inv_x, poly))
}
def bessel_k1_large[prec: {f32, f64}](x: prec) -> prec = {
  t = cast(2.0, prec) |> div(x)
  a0 = cast(1.25331414, prec)
  a1 = cast(0.23498619, prec)
  a2 = cast(-0.0365562, prec)
  a3 = cast(0.01504268, prec)
  a4 = cast(-0.00780353, prec)
  a5 = cast(0.00325614, prec)
  a6 = cast(-0.00068245, prec)
  poly = add(a0, mul(t, add(a1, mul(t, add(a2, mul(t, add(a3, mul(t, add(a4, mul(t, add(a5, mul(t, a6))))))))))))
  nx = neg(x)
  e = exp(nx)
  s = sqrt(x)
  e |> mul(poly) |> div(s)
}
def bessel_k1[prec: {f32, f64}](x: prec) -> prec = {
  zero = cast(0.0, prec)
  if lt(x, zero) then sp_nan() else if eq(x, zero) then pos_inf() else if lte(x, cast(2.0, prec)) then bessel_k1_small(x) else bessel_k1_large(x)
}
def bessel_j0_small[prec: {f32, f64}](ax: prec) -> prec = {
  y = mul(ax, ax)
  n0 = cast(57568490574.0f64, prec)
  n1 = cast(-13362590354.0f64, prec)
  n2 = cast(651619640.7f64, prec)
  n3 = cast(-11214424.18f64, prec)
  n4 = cast(77392.33017f64, prec)
  n5 = cast(-184.9052456, prec)
  d0 = cast(57568490411.0f64, prec)
  d1 = cast(1029532985.0f64, prec)
  d2 = cast(9494680.718f64, prec)
  d3 = cast(59272.64853, prec)
  d4 = cast(267.8532712, prec)
  d5 = cast(1.0, prec)
  num = add(n0, mul(y, add(n1, mul(y, add(n2, mul(y, add(n3, mul(y, add(n4, mul(y, n5))))))))))
  den = add(d0, mul(y, add(d1, mul(y, add(d2, mul(y, add(d3, mul(y, add(d4, mul(y, d5))))))))))
  div(num, den)
}
def bessel_j0_large[prec: {f32, f64}](ax: prec) -> prec = {
  z = cast(8.0, prec) |> div(ax)
  y = mul(z, z)
  p0 = cast(1.0, prec)
  p1 = cast(-0.001098628627, prec)
  p2 = cast(0.00002734510407, prec)
  p3 = cast(-2.073370639e-6, prec)
  p4 = cast(2.093887211e-7, prec)
  q0 = cast(-0.01562499995, prec)
  q1 = cast(0.0001430488765, prec)
  q2 = cast(-6.911147651e-6, prec)
  q3 = cast(7.621095161e-7, prec)
  q4 = cast(-9.34935152e-8, prec)
  pp = add(p0, mul(y, add(p1, mul(y, add(p2, mul(y, add(p3, mul(y, p4))))))))
  qq = add(q0, mul(y, add(q1, mul(y, add(q2, mul(y, add(q3, mul(y, q4))))))))
  phi = cast(0.785398163397448, prec)
  xx = sub(ax, phi)
  half_pi = cast(1.5707963267948966, prec)
  cos_xx = xx |> add(half_pi) |> sin
  sin_xx = sin(xx)
  two_over_pi = cast(0.6366197723675814, prec)
  pre = two_over_pi |> div(ax) |> sqrt
  body = cos_xx |> mul(pp) |> sub(mul(mul(z, sin_xx), qq))
  mul(pre, body)
}
def bessel_j0[prec: {f32, f64}](x: prec) -> prec = {
  ax = sp_abs(x)
  if lt(ax, cast(8.0, prec)) then bessel_j0_small(ax) else bessel_j0_large(ax)
}
def bessel_j1_small[prec: {f32, f64}](ax: prec) -> prec = {
  y = mul(ax, ax)
  n0 = cast(72362614232.0f64, prec)
  n1 = cast(-7895059235.0f64, prec)
  n2 = cast(242396853.1f64, prec)
  n3 = cast(-2972611.439f64, prec)
  n4 = cast(15704.4826, prec)
  n5 = cast(-30.16036606, prec)
  d0 = cast(144725228442.0f64, prec)
  d1 = cast(2300535178.0f64, prec)
  d2 = cast(18583304.74f64, prec)
  d3 = cast(99447.43394f64, prec)
  d4 = cast(376.9991397, prec)
  d5 = cast(1.0, prec)
  num = add(n0, mul(y, add(n1, mul(y, add(n2, mul(y, add(n3, mul(y, add(n4, mul(y, n5))))))))))
  den = add(d0, mul(y, add(d1, mul(y, add(d2, mul(y, add(d3, mul(y, add(d4, mul(y, d5))))))))))
  mul(ax, div(num, den))
}
def bessel_j1_large[prec: {f32, f64}](ax: prec) -> prec = {
  z = cast(8.0, prec) |> div(ax)
  y = mul(z, z)
  p0 = cast(1.0, prec)
  p1 = cast(0.00183105, prec)
  p2 = cast(-0.00003516396496, prec)
  p3 = cast(2.457520174e-6, prec)
  p4 = cast(-2.40337019e-7, prec)
  q0 = cast(0.04687499995, prec)
  q1 = cast(-0.0002002690873, prec)
  q2 = cast(8.449199096e-6, prec)
  q3 = cast(-8.8228987e-7, prec)
  q4 = cast(1.05787412e-7, prec)
  pp = add(p0, mul(y, add(p1, mul(y, add(p2, mul(y, add(p3, mul(y, p4))))))))
  qq = add(q0, mul(y, add(q1, mul(y, add(q2, mul(y, add(q3, mul(y, q4))))))))
  phi = cast(2.356194490192345, prec)
  xx = sub(ax, phi)
  half_pi = cast(1.5707963267948966, prec)
  cos_xx = xx |> add(half_pi) |> sin
  sin_xx = sin(xx)
  two_over_pi = cast(0.6366197723675814, prec)
  pre = two_over_pi |> div(ax) |> sqrt
  body = cos_xx |> mul(pp) |> sub(mul(mul(z, sin_xx), qq))
  mul(pre, body)
}
def bessel_j1[prec: {f32, f64}](x: prec) -> prec = {
  ax = sp_abs(x)
  ans = if lt(ax, cast(8.0, prec)) then bessel_j1_small(ax) else bessel_j1_large(ax)
  if lt(x, cast(0.0, prec)) then neg(ans) else ans
}
def bessel_y0_small[prec: {f32, f64}](x: prec) -> prec = {
  y = mul(x, x)
  n0 = cast(-2957821389.0f64, prec)
  n1 = cast(7062834065.0f64, prec)
  n2 = cast(-512359803.6f64, prec)
  n3 = cast(10879881.29f64, prec)
  n4 = cast(-86327.92757f64, prec)
  n5 = cast(228.4622733, prec)
  d0 = cast(40076544269.0f64, prec)
  d1 = cast(745249964.8f64, prec)
  d2 = cast(7189466.438f64, prec)
  d3 = cast(47447.2647, prec)
  d4 = cast(226.1030244, prec)
  d5 = cast(1.0, prec)
  num = add(n0, mul(y, add(n1, mul(y, add(n2, mul(y, add(n3, mul(y, add(n4, mul(y, n5))))))))))
  den = add(d0, mul(y, add(d1, mul(y, add(d2, mul(y, add(d3, mul(y, add(d4, mul(y, d5))))))))))
  rat = div(num, den)
  two_over_pi = cast(0.6366197723675814, prec)
  j0v = bessel_j0(x)
  lx = log(x)
  add(rat, mul(two_over_pi, mul(j0v, lx)))
}
def bessel_y0_large[prec: {f32, f64}](x: prec) -> prec = {
  z = cast(8.0, prec) |> div(x)
  y = mul(z, z)
  p0 = cast(1.0, prec)
  p1 = cast(-0.001098628627, prec)
  p2 = cast(0.00002734510407, prec)
  p3 = cast(-2.073370639e-6, prec)
  p4 = cast(2.093887211e-7, prec)
  q0 = cast(-0.01562499995, prec)
  q1 = cast(0.0001430488765, prec)
  q2 = cast(-6.911147651e-6, prec)
  q3 = cast(7.621095161e-7, prec)
  q4 = cast(-9.34935152e-8, prec)
  pp = add(p0, mul(y, add(p1, mul(y, add(p2, mul(y, add(p3, mul(y, p4))))))))
  qq = add(q0, mul(y, add(q1, mul(y, add(q2, mul(y, add(q3, mul(y, q4))))))))
  phi = cast(0.785398163397448, prec)
  xx = sub(x, phi)
  half_pi = cast(1.5707963267948966, prec)
  cos_xx = xx |> add(half_pi) |> sin
  sin_xx = sin(xx)
  two_over_pi = cast(0.6366197723675814, prec)
  pre = two_over_pi |> div(x) |> sqrt
  body = sin_xx |> mul(pp) |> add(mul(mul(z, cos_xx), qq))
  mul(pre, body)
}
def bessel_y0[prec: {f32, f64}](x: prec) -> prec = {
  zero = cast(0.0, prec)
  if lt(x, zero) then sp_nan() else if eq(x, zero) then neg_inf() else if lt(x, cast(8.0, prec)) then bessel_y0_small(x) else bessel_y0_large(x)
}
def bessel_y1_small[prec: {f32, f64}](x: prec) -> prec = {
  y = mul(x, x)
  n0 = cast(-49006049430000.0f64, prec)
  n1 = cast(12752743900000.0f64, prec)
  n2 = cast(-515343813900.0f64, prec)
  n3 = cast(7349264551.0f64, prec)
  n4 = cast(-42379227.26f64, prec)
  n5 = cast(85119.37935f64, prec)
  d0 = cast(249958057000000.0f64, prec)
  d1 = cast(4244419664000.0f64, prec)
  d2 = cast(37336503670.0f64, prec)
  d3 = cast(224590400.2f64, prec)
  d4 = cast(1020426.05f64, prec)
  d5 = cast(3549.632885, prec)
  d6 = cast(1.0, prec)
  num = add(n0, mul(y, add(n1, mul(y, add(n2, mul(y, add(n3, mul(y, add(n4, mul(y, n5))))))))))
  den = add(d0, mul(y, add(d1, mul(y, add(d2, mul(y, add(d3, mul(y, add(d4, mul(y, add(d5, mul(y, d6))))))))))))
  rat = mul(x, div(num, den))
  two_over_pi = cast(0.6366197723675814, prec)
  j1v = bessel_j1(x)
  lx = log(x)
  inv_x = cast(1.0, prec) |> div(x)
  add(rat, mul(two_over_pi, j1v |> mul(lx) |> sub(inv_x)))
}
def bessel_y1_large[prec: {f32, f64}](x: prec) -> prec = {
  z = cast(8.0, prec) |> div(x)
  y = mul(z, z)
  p0 = cast(1.0, prec)
  p1 = cast(0.00183105, prec)
  p2 = cast(-0.00003516396496, prec)
  p3 = cast(2.457520174e-6, prec)
  p4 = cast(-2.40337019e-7, prec)
  q0 = cast(0.04687499995, prec)
  q1 = cast(-0.0002002690873, prec)
  q2 = cast(8.449199096e-6, prec)
  q3 = cast(-8.8228987e-7, prec)
  q4 = cast(1.05787412e-7, prec)
  pp = add(p0, mul(y, add(p1, mul(y, add(p2, mul(y, add(p3, mul(y, p4))))))))
  qq = add(q0, mul(y, add(q1, mul(y, add(q2, mul(y, add(q3, mul(y, q4))))))))
  phi = cast(2.356194490192345, prec)
  xx = sub(x, phi)
  half_pi = cast(1.5707963267948966, prec)
  cos_xx = xx |> add(half_pi) |> sin
  sin_xx = sin(xx)
  two_over_pi = cast(0.6366197723675814, prec)
  pre = two_over_pi |> div(x) |> sqrt
  body = sin_xx |> mul(pp) |> add(mul(mul(z, cos_xx), qq))
  mul(pre, body)
}
def bessel_y1[prec: {f32, f64}](x: prec) -> prec = {
  zero = cast(0.0, prec)
  if lt(x, zero) then sp_nan() else if eq(x, zero) then neg_inf() else if lt(x, cast(7.5, prec)) then bessel_y1_small(x) else bessel_y1_large(x)
}
def airy_f_rec[prec: {f32, f64}](x3: prec, term: prec, acc: prec, k: prec, iters: i64) -> prec = {
  zero_i = cast(0, i64)
  one_i = cast(1, i64)
  one_f = cast(1.0, prec)
  three = cast(3.0, prec)
  if lte(iters, zero_i) then acc else {
    k3 = mul(three, k)
    denom = k3 |> add(cast(2.0, prec)) |> mul(add(k3, three))
    term_next = term |> mul(x3) |> div(denom)
    acc_next = add(acc, term_next)
    abs_term = sp_abs(term_next)
    abs_acc = sp_abs(acc_next)
    floor = one_f
    scale = if gt(abs_acc, floor) then abs_acc else floor
    tol = cast(1e-8, prec)
    converged = lt(abs_term, mul(tol, scale))
    if converged then acc_next else airy_f_rec(x3, term_next, acc_next, add(k, one_f), sub(iters, one_i))
  }
}
def airy_g_rec[prec: {f32, f64}](x3: prec, term: prec, acc: prec, k: prec, iters: i64) -> prec = {
  zero_i = cast(0, i64)
  one_i = cast(1, i64)
  one_f = cast(1.0, prec)
  three = cast(3.0, prec)
  if lte(iters, zero_i) then acc else {
    k3 = mul(three, k)
    denom = k3 |> add(three) |> mul(add(k3, cast(4.0, prec)))
    term_next = term |> mul(x3) |> div(denom)
    acc_next = add(acc, term_next)
    abs_term = sp_abs(term_next)
    abs_acc = sp_abs(acc_next)
    floor = one_f
    scale = if gt(abs_acc, floor) then abs_acc else floor
    tol = cast(1e-8, prec)
    converged = lt(abs_term, mul(tol, scale))
    if converged then acc_next else airy_g_rec(x3, term_next, acc_next, add(k, one_f), sub(iters, one_i))
  }
}
def airy_fg[prec: {f32, f64}](x: prec) -> prec = {
  x2 = mul(x, x)
  x3 = mul(x2, x)
  airy_f_rec(x3, cast(1.0, prec), cast(1.0, prec), cast(0.0, prec), cast(50, i64))
}
def airy_gg[prec: {f32, f64}](x: prec) -> prec = {
  x2 = mul(x, x)
  x3 = mul(x2, x)
  airy_g_rec(x3, x, x, cast(0.0, prec), cast(50, i64))
}
def airy_ai_asymptotic_pos[prec: {f32, f64}](x: prec) -> prec = {
  sqrt_x = sqrt(x)
  x_to_1_5 = mul(x, sqrt_x)
  xi = cast(0.6666666666666666, prec) |> mul(x_to_1_5)
  neg_xi = neg(xi)
  exp_neg_xi = exp(neg_xi)
  x_to_0_25 = sqrt(sqrt_x)
  inv_x_0_25 = cast(1.0, prec) |> div(x_to_0_25)
  two_sqrt_pi = cast(3.5449077018110318, prec)
  pre = div(inv_x_0_25, two_sqrt_pi)
  mul(pre, exp_neg_xi)
}
def airy_bi_asymptotic_pos[prec: {f32, f64}](x: prec) -> prec = {
  sqrt_x = sqrt(x)
  x_to_1_5 = mul(x, sqrt_x)
  xi = cast(0.6666666666666666, prec) |> mul(x_to_1_5)
  exp_xi = exp(xi)
  x_to_0_25 = sqrt(sqrt_x)
  inv_x_0_25 = cast(1.0, prec) |> div(x_to_0_25)
  sqrt_pi = cast(1.7724538509055159, prec)
  pre = div(inv_x_0_25, sqrt_pi)
  mul(pre, exp_xi)
}
def airy_ai[prec: {f32, f64}](x: prec) -> prec = {
  c1 = cast(0.3550280538878172, prec)
  c2 = cast(0.2588194037928068, prec)
  if gt(x, cast(5.0, prec)) then airy_ai_asymptotic_pos(x) else {
    f = airy_fg(x)
    g = airy_gg(x)
    c1 |> mul(f) |> sub(mul(c2, g))
  }
}
def airy_bi[prec: {f32, f64}](x: prec) -> prec = {
  c1 = cast(0.3550280538878172, prec)
  c2 = cast(0.2588194037928068, prec)
  sqrt3 = cast(1.7320508075688772, prec)
  if gt(x, cast(5.0, prec)) then airy_bi_asymptotic_pos(x) else {
    f = airy_fg(x)
    g = airy_gg(x)
    mul(sqrt3, c1 |> mul(f) |> add(mul(c2, g)))
  }
}
def ellip_agm_a_rec[prec: {f32, f64}](a: prec, b: prec, iters: i64) -> prec = {
  zero_i = cast(0, i64)
  one_i = cast(1, i64)
  two = cast(2.0, prec)
  if lte(iters, zero_i) then a else {
    a_next = a |> add(b) |> div(two)
    b_next = a |> mul(b) |> sqrt
    c_next = a |> sub(b) |> div(two)
    tol = cast(1e-8, prec)
    stalled = a_next |> eq(a) |> or(eq(b_next, b))
    converged = or(lt(sp_abs(c_next), mul(tol, a_next)), stalled)
    if converged then a_next else ellip_agm_a_rec(a_next, b_next, sub(iters, one_i))
  }
}
def ellip_agm_csum_rec[prec: {f32, f64}](a: prec, b: prec, c_sum: prec, weight: prec, iters: i64) -> prec = {
  zero_i = cast(0, i64)
  one_i = cast(1, i64)
  two = cast(2.0, prec)
  if lte(iters, zero_i) then c_sum else {
    a_next = a |> add(b) |> div(two)
    b_next = a |> mul(b) |> sqrt
    c_next = a |> sub(b) |> div(two)
    w_next = mul(weight, two)
    c2 = mul(c_next, c_next)
    c_sum_next = add(c_sum, mul(w_next, c2))
    tol = cast(1e-8, prec)
    stalled = a_next |> eq(a) |> or(eq(b_next, b))
    converged = or(lt(sp_abs(c_next), mul(tol, a_next)), stalled)
    if converged then c_sum_next else ellip_agm_csum_rec(a_next, b_next, c_sum_next, w_next, sub(iters, one_i))
  }
}
def ellipk[prec: {f32, f64}](m: prec) -> prec = {
  zero = cast(0.0, prec)
  one = cast(1.0, prec)
  if lt(m, zero) then sp_nan() else if gt(m, one) then sp_nan() else if eq(m, one) then pos_inf() else {
    half_pi = cast(1.5707963267948966, prec)
    om = sub(one, m)
    b0 = sqrt(om)
    a_inf = ellip_agm_a_rec(one, b0, cast(50, i64))
    div(half_pi, a_inf)
  }
}
def ellipe[prec: {f32, f64}](m: prec) -> prec = {
  zero = cast(0.0, prec)
  one = cast(1.0, prec)
  if lt(m, zero) then sp_nan() else if gt(m, one) then sp_nan() else if eq(m, one) then one else {
    half_pi = cast(1.5707963267948966, prec)
    om = sub(one, m)
    b0 = sqrt(om)
    c0 = sqrt(m)
    c0_sq = mul(c0, c0)
    init_sum = cast(0.5, prec) |> mul(c0_sq)
    a_inf = ellip_agm_a_rec(one, b0, cast(50, i64))
    c_sum = ellip_agm_csum_rec(one, b0, init_sum, cast(0.5, prec), cast(50, i64))
    k = div(half_pi, a_inf)
    mul(k, sub(one, c_sum))
  }
}
-- Tensor-domain special functions (nautilus PR 45).
--
-- Scalar `erfinv` above is the reference; the tensor implementation computes
-- the same approximation without leaving tensor rank. Chelis has no implicit
-- tensor-scalar broadcasting, so every constant is lifted to rank `n` with
-- `sp_lift_t`, and every scalar `if` becomes an elementwise `where`.
def sp_lift_t[n, prec: {f32, f64}](template: &tensor[n, prec], c: prec) -> tensor[n, prec] = c |> scalar_to_tensor |> insert(0, shape(template, cast(0, i32)))
def acklam_central_t[n, prec: {f32, f64}](q: &tensor[n, prec]) -> tensor[n, prec] = {
  a1 = sp_lift_t(q, cast(-39.69683028665376, prec))
  a2 = sp_lift_t(q, cast(220.9460984245205, prec))
  a3 = sp_lift_t(q, cast(-275.9285104469687, prec))
  a4 = sp_lift_t(q, cast(138.357751867269, prec))
  a5 = sp_lift_t(q, cast(-30.66479806614716, prec))
  a6 = sp_lift_t(q, cast(2.506628277459239, prec))
  b1 = sp_lift_t(q, cast(-54.47609879822406, prec))
  b2 = sp_lift_t(q, cast(161.5858368580409, prec))
  b3 = sp_lift_t(q, cast(-155.6989798598866, prec))
  b4 = sp_lift_t(q, cast(66.80131188771972, prec))
  b5 = sp_lift_t(q, cast(-13.28068155288572, prec))
  one = sp_lift_t(q, cast(1.0, prec))
  half = sp_lift_t(q, cast(0.5, prec))
  u = sub(q, half)
  r = mul(u, u)
  num = mul(add(mul(r, add(mul(r, add(mul(r, add(mul(r, add(mul(r, a1), a2)), a3)), a4)), a5)), a6), u)
  den = add(mul(r, add(mul(r, add(mul(r, add(mul(r, add(mul(r, b1), b2)), b3)), b4)), b5)), one)
  div(num, den)
}
def acklam_tail_t[n, prec: {f32, f64}](u: &tensor[n, prec]) -> tensor[n, prec] = {
  c1 = sp_lift_t(u, cast(-0.007784894002430293, prec))
  c2 = sp_lift_t(u, cast(-0.3223964580411365, prec))
  c3 = sp_lift_t(u, cast(-2.400758277161838, prec))
  c4 = sp_lift_t(u, cast(-2.549732539343734, prec))
  c5 = sp_lift_t(u, cast(4.374664141464968, prec))
  c6 = sp_lift_t(u, cast(2.938163982698783, prec))
  d1 = sp_lift_t(u, cast(0.007784695709041462, prec))
  d2 = sp_lift_t(u, cast(0.3224671290700398, prec))
  d3 = sp_lift_t(u, cast(2.445134137142996, prec))
  d4 = sp_lift_t(u, cast(3.754408661907416, prec))
  one = sp_lift_t(u, cast(1.0, prec))
  num = add(mul(u, add(mul(u, add(mul(u, add(mul(u, add(mul(u, c1), c2)), c3)), c4)), c5)), c6)
  den = add(one, mul(u, u |> mul(add(mul(u, add(mul(u, d1), d2)), d3)) |> add(d4)))
  div(num, den)
}
def norminv_t[n, prec: {f32, f64}](q: &tensor[n, prec]) -> tensor[n, prec] = {
  plow = sp_lift_t(q, cast(0.02425, prec))
  one = sp_lift_t(q, cast(1.0, prec))
  two = sp_lift_t(q, cast(2.0, prec))
  phigh = sub(one, plow)
  -- Every lane computes all three branches and `where` discards two. For any
  -- `q` in (0, 1) both `log(q)` and `log(1 - q)` are finite and negative, so
  -- neither discarded lane can contaminate the selected one; at the domain
  -- edges both forms degenerate exactly as the scalar `norminv` does.
  low_u = sqrt(neg(mul(two, log(q))))
  low = acklam_tail_t(low_u)
  high_u = sqrt(neg(mul(two, log(sub(one, q)))))
  high = high_u |> acklam_tail_t |> neg
  central = acklam_central_t(q)
  upper = q |> lte(phigh) |> where(central, high)
  q |> lt(plow) |> where(low, upper)
}
def erfinv_t[n, prec: {f32, f64}](x: &tensor[n, prec]) -> tensor[n, prec] = {
  half = sp_lift_t(x, cast(0.5, prec))
  sqrt_half = sp_lift_t(x, cast(0.7071067811865476, prec))
  one = sp_lift_t(x, cast(1.0, prec))
  q = x |> add(one) |> mul(half)
  q |> norminv_t |> mul(sqrt_half)
}
