module Nautilus.Special
export (erf, erfc, erfinv, erf_t, erfinv_t, gamma, log_gamma, digamma, beta, lbeta, trigamma, bessel_i0, bessel_i1, bessel_k0, bessel_k1, bessel_j0, bessel_j1, bessel_y0, bessel_y1, airy_ai, airy_bi, ellipk, ellipe)
-- chelis:provenance/v1 authority
-- id = NAUT-MOD-SPECIAL
-- kind = behavioral
-- scopes = nautilus
-- statement = Nautilus.Special MUST provide the special-function surface listed in the module support table.
def abs_f32(x: f32) -> f32 = if lt(x, cast(0.0, f32)) then neg(x) else x
def is_nonpositive_integer(x: f32) -> bool = {
  zero = cast(0.0, f32)
  if gt(x, zero) then false else {
    xi_i = cast_trunc(x, int64)
    xi = cast(xi_i, f32)
    eq(x, xi)
  }
}
def pos_inf() -> f32 = cast(1.0, f32) |> div(cast(0.0, f32))
def neg_inf() -> f32 = cast(-1.0, f32) |> div(cast(0.0, f32))
def nan_f32() -> f32 = cast(0.0, f32) |> div(cast(0.0, f32))
-- Maclaurin series for erf, truncated after the x^7 term:
--   erf(x) = (2/sqrt(pi)) * (x - x^3/3 + x^5/10 - x^7/42 + ...)
-- Horner in x^2. Accurate to <5e-8 absolute for |x| <= 0.25, which is where
-- `erf` uses it; the next term contributes ~(2/sqrt(pi))*x^9/216.
def erf_taylor_core(x: f32) -> f32 = {
  x2 = mul(x, x)
  c3 = cast(0.3333333333333333, f32)
  c5 = cast(0.1, f32)
  c7 = cast(0.023809523809523808, f32)
  two_over_sqrt_pi = cast(1.1283791670955126, f32)
  poly = sub(cast(1.0, f32), mul(x2, sub(c3, mul(x2, sub(c5, mul(x2, c7))))))
  mul(mul(x, poly), two_over_sqrt_pi)
}
def erf(x: f32) -> f32 = {
  a1 = cast(0.254829592, f32)
  a2 = cast(-0.284496736, f32)
  a3 = cast(1.421413741, f32)
  a4 = cast(-1.453152027, f32)
  a5 = cast(1.061405429, f32)
  p = cast(0.3275911, f32)
  one = cast(1.0, f32)
  ax = abs_f32(x)
  -- ERROR BOUND, and why it is written down here.
  --
  -- The rational arm below is Abramowitz & Stegun 7.1.26, whose published
  -- bound is |eps| <= 1.5e-7 ABSOLUTE in exact arithmetic; evaluating the
  -- formula in f64 measures 1.394e-7, inside that.
  --
  -- Evaluated in f32 with f32 coefficients it realizes WORSE. Measured by
  -- exhaustive scan of every f32 in range, not by sampling:
  --   max |error| 4.44e-7 over |x| >= 0.25, the range it still owns
  --                       (worst at x = 0.25292396545410156)
  --   max |error| 6.62e-7 over |x| >= 1e-5, the range it owned before the
  --                       cutover moved (worst at x = 0.03796697407960892)
  -- Quote those, not the 1.5e-7 formula bound, when you need what this
  -- function actually delivers.
  --
  -- That bound is ABSOLUTE and roughly constant, so the RELATIVE error
  -- diverges as x -> 0. At the old 1e-5 cutover it reached 2.404e-2.
  --
  -- These constants are f32 constants. Widening this function to f64 does
  -- NOT buy f64 accuracy: 7.1.26 is a 1.5e-7 formula at any precision, so
  -- the coefficients must be replaced, not merely re-typed. The same
  -- approximation is duplicated at `erf_t` below, and the sibling shoals
  -- repo carries its own copy -- see shoals#61 for that propagation.
  small = cast(0.25, f32)
  if lt(ax, small) then {
    xt = if lt(ax, small) then x else cast(0.0, f32)
    erf_taylor_core(xt)
  } else {
    t = div(one, add(one, mul(p, ax)))
    poly = mul(t, add(a1, mul(t, add(a2, mul(t, add(a3, mul(t, add(a4, mul(t, a5)))))))))
    x2 = mul(ax, ax)
    nx2 = neg(x2)
    e = exp(nx2)
    y = sub(one, mul(poly, e))
    if lt(x, cast(0.0, f32)) then neg(y) else y
  }
  -- Clamp the series input to the branch domain. A masked-select lowering
  -- evaluates BOTH arms (chelis#1464), and an unclamped x^7 overflows f32
  -- for |x| > ~5.5e5; on the clamped value the untaken arm stays bounded.
}
def erfc(x: f32) -> f32 = cast(1.0, f32) |> sub(erf(x))
def lanczos_sum(x: f32) -> f32 = {
  c0 = cast(0.9999999999998099, f32)
  c1 = cast(676.5203681218851, f32)
  c2 = cast(-1259.1392167224028, f32)
  c3 = cast(771.3234287776531, f32)
  c4 = cast(-176.6150291621406, f32)
  c5 = cast(12.507343278686905, f32)
  c6 = cast(-0.13857109526572012, f32)
  c7 = cast(9.984369578019572e-6, f32)
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
  log_sqrt_2pi |> add(mul(add(xm1, half), log_t)) |> add(sub(log_a, t))
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
    one_minus_x = cast(1.0, f32) |> sub(x)
    lgc = log_gamma_core(one_minus_x)
    log_pi |> sub(log_aspix) |> sub(lgc)
  } else log_gamma_core(x)
}
def gamma(x: f32) -> f32 = {
  half = cast(0.5, f32)
  pi = cast(3.141592653589793, f32)
  if is_nonpositive_integer(x) then pos_inf() else if lt(x, half) then {
    pix = mul(pi, x)
    spix = sin(pix)
    one_minus_x = cast(1.0, f32) |> sub(x)
    g1 = one_minus_x |> log_gamma_core |> exp
    div(pi, mul(spix, g1))
  } else x |> log_gamma_core |> exp
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
  if gte(x, six) then x |> digamma_asymptotic |> add(acc) else x |> add(one) |> digamma_rec(sub(acc, div(one, x)))
}
def digamma(x: f32) -> f32 = if is_nonpositive_integer(x) then nan_f32() else digamma_rec(x, cast(0.0, f32))
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
  den =
    u
    |> mul(add(mul(u, add(mul(u, add(mul(u, d1), d2)), d3)), d4))
    |> add(one)
  div(num, den)
}
def norminv(q: f32) -> f32 = {
  plow = cast(0.02425, f32)
  one = cast(1.0, f32)
  phigh = sub(one, plow)
  two = cast(2.0, f32)
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
def erfinv(x: f32) -> f32 = {
  half = cast(0.5, f32)
  sqrt_half = cast(0.7071067811865476, f32)
  q = x |> add(cast(1.0, f32)) |> mul(half)
  q |> norminv |> mul(sqrt_half)
}
def lbeta(a: f32, b: f32) -> f32 = {
  zero = cast(0.0, f32)
  if a |> lte(zero) |> or(lte(b, zero)) then nan_f32() else {
    la = log_gamma(a)
    lb = log_gamma(b)
    lab = a |> add(b) |> log_gamma
    la |> add(lb) |> sub(lab)
  }
}
def beta(a: f32, b: f32) -> f32 = {
  zero = cast(0.0, f32)
  if a |> lte(zero) |> or(lte(b, zero)) then nan_f32() else {
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
  add(sub(add(add(t1, t2), t3), t4), t5)
}
def trigamma_rec(x: f32, acc: f32) -> f32 = {
  six = cast(6.0, f32)
  one = cast(1.0, f32)
  if gte(x, six) then x |> trigamma_asymptotic |> add(acc) else {
    inv_x = div(one, x)
    inv_x2 = mul(inv_x, inv_x)
    x |> add(one) |> trigamma_rec(add(acc, inv_x2))
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
  add(a0, mul(y, add(a1, mul(y, add(a2, mul(y, add(a3, mul(y, add(a4, mul(y, add(a5, mul(y, a6))))))))))))
}
def bessel_i0_large(ax: f32) -> f32 = {
  t = cast(3.75, f32) |> div(ax)
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
  e |> mul(poly) |> div(s)
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
  mul(ax, poly)
}
def bessel_i1_large(ax: f32) -> f32 = {
  t = cast(3.75, f32) |> div(ax)
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
  e |> mul(poly) |> div(s)
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
  a6 = cast(7.4e-6, f32)
  poly = add(a0, mul(y, add(a1, mul(y, add(a2, mul(y, add(a3, mul(y, add(a4, mul(y, add(a5, mul(y, a6))))))))))))
  lhx = log(half_x)
  i0 = bessel_i0(x)
  sub(poly, mul(lhx, i0))
}
def bessel_k0_large(x: f32) -> f32 = {
  t = cast(2.0, f32) |> div(x)
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
  e |> mul(poly) |> div(s)
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
  inv_x = cast(1.0, f32) |> div(x)
  lhx |> mul(i1) |> add(mul(inv_x, poly))
}
def bessel_k1_large(x: f32) -> f32 = {
  t = cast(2.0, f32) |> div(x)
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
  e |> mul(poly) |> div(s)
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
  z = cast(8.0, f32) |> div(ax)
  y = mul(z, z)
  p0 = cast(1.0, f32)
  p1 = cast(-0.001098628627, f32)
  p2 = cast(0.00002734510407, f32)
  p3 = cast(-2.073370639e-6, f32)
  p4 = cast(2.093887211e-7, f32)
  q0 = cast(-0.01562499995, f32)
  q1 = cast(0.0001430488765, f32)
  q2 = cast(-6.911147651e-6, f32)
  q3 = cast(7.621095161e-7, f32)
  q4 = cast(-9.34935152e-8, f32)
  pp = add(p0, mul(y, add(p1, mul(y, add(p2, mul(y, add(p3, mul(y, p4))))))))
  qq = add(q0, mul(y, add(q1, mul(y, add(q2, mul(y, add(q3, mul(y, q4))))))))
  phi = cast(0.785398163397448, f32)
  xx = sub(ax, phi)
  half_pi = cast(1.5707963267948966, f32)
  cos_xx = xx |> add(half_pi) |> sin
  sin_xx = sin(xx)
  two_over_pi = cast(0.6366197723675814, f32)
  pre = two_over_pi |> div(ax) |> sqrt
  body = cos_xx |> mul(pp) |> sub(mul(mul(z, sin_xx), qq))
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
  z = cast(8.0, f32) |> div(ax)
  y = mul(z, z)
  p0 = cast(1.0, f32)
  p1 = cast(0.00183105, f32)
  p2 = cast(-0.00003516396496, f32)
  p3 = cast(2.457520174e-6, f32)
  p4 = cast(-2.40337019e-7, f32)
  q0 = cast(0.04687499995, f32)
  q1 = cast(-0.0002002690873, f32)
  q2 = cast(8.449199096e-6, f32)
  q3 = cast(-8.8228987e-7, f32)
  q4 = cast(1.05787412e-7, f32)
  pp = add(p0, mul(y, add(p1, mul(y, add(p2, mul(y, add(p3, mul(y, p4))))))))
  qq = add(q0, mul(y, add(q1, mul(y, add(q2, mul(y, add(q3, mul(y, q4))))))))
  phi = cast(2.356194490192345, f32)
  xx = sub(ax, phi)
  half_pi = cast(1.5707963267948966, f32)
  cos_xx = xx |> add(half_pi) |> sin
  sin_xx = sin(xx)
  two_over_pi = cast(0.6366197723675814, f32)
  pre = two_over_pi |> div(ax) |> sqrt
  body = cos_xx |> mul(pp) |> sub(mul(mul(z, sin_xx), qq))
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
  z = cast(8.0, f32) |> div(x)
  y = mul(z, z)
  p0 = cast(1.0, f32)
  p1 = cast(-0.001098628627, f32)
  p2 = cast(0.00002734510407, f32)
  p3 = cast(-2.073370639e-6, f32)
  p4 = cast(2.093887211e-7, f32)
  q0 = cast(-0.01562499995, f32)
  q1 = cast(0.0001430488765, f32)
  q2 = cast(-6.911147651e-6, f32)
  q3 = cast(7.621095161e-7, f32)
  q4 = cast(-9.34935152e-8, f32)
  pp = add(p0, mul(y, add(p1, mul(y, add(p2, mul(y, add(p3, mul(y, p4))))))))
  qq = add(q0, mul(y, add(q1, mul(y, add(q2, mul(y, add(q3, mul(y, q4))))))))
  phi = cast(0.785398163397448, f32)
  xx = sub(x, phi)
  half_pi = cast(1.5707963267948966, f32)
  cos_xx = xx |> add(half_pi) |> sin
  sin_xx = sin(xx)
  two_over_pi = cast(0.6366197723675814, f32)
  pre = two_over_pi |> div(x) |> sqrt
  body = sin_xx |> mul(pp) |> add(mul(mul(z, cos_xx), qq))
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
  inv_x = cast(1.0, f32) |> div(x)
  add(rat, mul(two_over_pi, j1v |> mul(lx) |> sub(inv_x)))
}
def bessel_y1_large(x: f32) -> f32 = {
  z = cast(8.0, f32) |> div(x)
  y = mul(z, z)
  p0 = cast(1.0, f32)
  p1 = cast(0.00183105, f32)
  p2 = cast(-0.00003516396496, f32)
  p3 = cast(2.457520174e-6, f32)
  p4 = cast(-2.40337019e-7, f32)
  q0 = cast(0.04687499995, f32)
  q1 = cast(-0.0002002690873, f32)
  q2 = cast(8.449199096e-6, f32)
  q3 = cast(-8.8228987e-7, f32)
  q4 = cast(1.05787412e-7, f32)
  pp = add(p0, mul(y, add(p1, mul(y, add(p2, mul(y, add(p3, mul(y, p4))))))))
  qq = add(q0, mul(y, add(q1, mul(y, add(q2, mul(y, add(q3, mul(y, q4))))))))
  phi = cast(2.356194490192345, f32)
  xx = sub(x, phi)
  half_pi = cast(1.5707963267948966, f32)
  cos_xx = xx |> add(half_pi) |> sin
  sin_xx = sin(xx)
  two_over_pi = cast(0.6366197723675814, f32)
  pre = two_over_pi |> div(x) |> sqrt
  body = sin_xx |> mul(pp) |> add(mul(mul(z, cos_xx), qq))
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
    denom = k3 |> add(cast(2.0, f32)) |> mul(add(k3, three))
    term_next = term |> mul(x3) |> div(denom)
    acc_next = add(acc, term_next)
    abs_term = abs_f32(term_next)
    abs_acc = abs_f32(acc_next)
    floor = one_f
    scale = if gt(abs_acc, floor) then abs_acc else floor
    tol = cast(1e-8, f32)
    converged = lt(abs_term, mul(tol, scale))
    if converged then acc_next else airy_f_rec(x3, term_next, acc_next, add(k, one_f), sub(iters, one_i))
  }
}
def airy_g_rec(x3: f32, term: f32, acc: f32, k: f32, iters: int64) -> f32 = {
  zero_i = cast(0, int64)
  one_i = cast(1, int64)
  one_f = cast(1.0, f32)
  three = cast(3.0, f32)
  if lte(iters, zero_i) then acc else {
    k3 = mul(three, k)
    denom = k3 |> add(three) |> mul(add(k3, cast(4.0, f32)))
    term_next = term |> mul(x3) |> div(denom)
    acc_next = add(acc, term_next)
    abs_term = abs_f32(term_next)
    abs_acc = abs_f32(acc_next)
    floor = one_f
    scale = if gt(abs_acc, floor) then abs_acc else floor
    tol = cast(1e-8, f32)
    converged = lt(abs_term, mul(tol, scale))
    if converged then acc_next else airy_g_rec(x3, term_next, acc_next, add(k, one_f), sub(iters, one_i))
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
  xi = cast(0.6666666666666666, f32) |> mul(x_to_1_5)
  neg_xi = neg(xi)
  exp_neg_xi = exp(neg_xi)
  x_to_0_25 = sqrt(sqrt_x)
  inv_x_0_25 = cast(1.0, f32) |> div(x_to_0_25)
  two_sqrt_pi = cast(3.5449077018110318, f32)
  pre = div(inv_x_0_25, two_sqrt_pi)
  mul(pre, exp_neg_xi)
}
def airy_bi_asymptotic_pos(x: f32) -> f32 = {
  sqrt_x = sqrt(x)
  x_to_1_5 = mul(x, sqrt_x)
  xi = cast(0.6666666666666666, f32) |> mul(x_to_1_5)
  exp_xi = exp(xi)
  x_to_0_25 = sqrt(sqrt_x)
  inv_x_0_25 = cast(1.0, f32) |> div(x_to_0_25)
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
    c1 |> mul(f) |> sub(mul(c2, g))
  }
}
def airy_bi(x: f32) -> f32 = {
  c1 = cast(0.3550280538878172, f32)
  c2 = cast(0.2588194037928068, f32)
  sqrt3 = cast(1.7320508075688772, f32)
  if gt(x, cast(5.0, f32)) then airy_bi_asymptotic_pos(x) else {
    f = airy_fg(x)
    g = airy_gg(x)
    mul(sqrt3, c1 |> mul(f) |> add(mul(c2, g)))
  }
}
def ellip_agm_a_rec(a: f32, b: f32, iters: int64) -> f32 = {
  zero_i = cast(0, int64)
  one_i = cast(1, int64)
  two = cast(2.0, f32)
  if lte(iters, zero_i) then a else {
    a_next = a |> add(b) |> div(two)
    b_next = a |> mul(b) |> sqrt
    c_next = a |> sub(b) |> div(two)
    tol = cast(1e-8, f32)
    stalled = a_next |> eq(a) |> or(eq(b_next, b))
    converged = or(lt(abs_f32(c_next), mul(tol, a_next)), stalled)
    if converged then a_next else ellip_agm_a_rec(a_next, b_next, sub(iters, one_i))
  }
}
def ellip_agm_csum_rec(a: f32, b: f32, c_sum: f32, weight: f32, iters: int64) -> f32 = {
  zero_i = cast(0, int64)
  one_i = cast(1, int64)
  two = cast(2.0, f32)
  if lte(iters, zero_i) then c_sum else {
    a_next = a |> add(b) |> div(two)
    b_next = a |> mul(b) |> sqrt
    c_next = a |> sub(b) |> div(two)
    w_next = mul(weight, two)
    c2 = mul(c_next, c_next)
    c_sum_next = add(c_sum, mul(w_next, c2))
    tol = cast(1e-8, f32)
    stalled = a_next |> eq(a) |> or(eq(b_next, b))
    converged = or(lt(abs_f32(c_next), mul(tol, a_next)), stalled)
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
    div(half_pi, a_inf)
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
    init_sum = cast(0.5, f32) |> mul(c0_sq)
    a_inf = ellip_agm_a_rec(one, b0, cast(50, int64))
    c_sum = ellip_agm_csum_rec(one, b0, init_sum, cast(0.5, f32), cast(50, int64))
    k = div(half_pi, a_inf)
    mul(k, sub(one, c_sum))
  }
}
-- Tensor-domain special functions (nautilus PR 45).
--
-- The scalar `erf` / `erfinv` above are the reference; these compute the same
-- approximations at tensor rank so a caller holding a tensor of values never
-- has to leave tensor rank to reach them. Chelis has no implicit
-- tensor-scalar broadcasting, so every constant is lifted to rank `n` with
-- `sp_lift_t`, and every scalar `if` becomes an elementwise `where`.
def sp_lift_t[n](template: &tensor[n, f32], c: f32) -> tensor[n, f32] = c |> scalar_to_tensor |> insert(0, shape(template, cast(0, int32)))
def sp_abs_t[n](x: &tensor[n, f32]) -> tensor[n, f32] = {
  zeros = sp_lift_t(x, cast(0.0, f32))
  x |> lt(zeros) |> where(neg(x), x)
}
def erf_t[n](x: &tensor[n, f32]) -> tensor[n, f32] = {
  a1 = sp_lift_t(x, cast(0.254829592, f32))
  a2 = sp_lift_t(x, cast(-0.284496736, f32))
  a3 = sp_lift_t(x, cast(1.421413741, f32))
  a4 = sp_lift_t(x, cast(-1.453152027, f32))
  a5 = sp_lift_t(x, cast(1.061405429, f32))
  p = sp_lift_t(x, cast(0.3275911, f32))
  one = sp_lift_t(x, cast(1.0, f32))
  zero = sp_lift_t(x, cast(0.0, f32))
  ax = sp_abs_t(x)
  t = div(one, add(one, mul(p, ax)))
  poly = mul(t, add(a1, mul(t, add(a2, mul(t, add(a3, mul(t, add(a4, mul(t, a5)))))))))
  x2 = mul(ax, ax)
  e = x2 |> neg |> exp
  y = sub(one, mul(poly, e))
  signed = x |> lt(zero) |> where(neg(y), y)
  -- Mirror the scalar `erf` exactly: the same 0.25 cutover onto the same
  -- 4-term series. nautilus#45 requires these two lanes to agree
  -- elementwise, so they change together or not at all.
  small = sp_lift_t(x, cast(0.25, f32))
  two_over_sqrt_pi = sp_lift_t(x, cast(1.1283791670955126, f32))
  c3 = sp_lift_t(x, cast(0.3333333333333333, f32))
  c5 = sp_lift_t(x, cast(0.1, f32))
  c7 = sp_lift_t(x, cast(0.023809523809523808, f32))
  in_small = lt(ax, small)
  -- Clamped for lane symmetry with the scalar `erf`, NOT because `where`
  -- needs it: a discarded `where` arm holding inf or NaN does not poison
  -- the selected value (probed directly). Deleting this clamp changes no
  -- measured output. The scalar clamp IS load-bearing -- see chelis#1464
  -- there -- and nautilus#45 wants the two lanes to stay the same shape.
  xt = where(in_small, x, zero)
  xt2 = mul(xt, xt)
  tpoly = sub(one, mul(xt2, sub(c3, mul(xt2, sub(c5, mul(xt2, c7))))))
  taylor = mul(mul(xt, tpoly), two_over_sqrt_pi)
  where(in_small, taylor, signed)
}
def acklam_central_t[n](q: &tensor[n, f32]) -> tensor[n, f32] = {
  a1 = sp_lift_t(q, cast(-39.69683028665376, f32))
  a2 = sp_lift_t(q, cast(220.9460984245205, f32))
  a3 = sp_lift_t(q, cast(-275.9285104469687, f32))
  a4 = sp_lift_t(q, cast(138.357751867269, f32))
  a5 = sp_lift_t(q, cast(-30.66479806614716, f32))
  a6 = sp_lift_t(q, cast(2.506628277459239, f32))
  b1 = sp_lift_t(q, cast(-54.47609879822406, f32))
  b2 = sp_lift_t(q, cast(161.5858368580409, f32))
  b3 = sp_lift_t(q, cast(-155.6989798598866, f32))
  b4 = sp_lift_t(q, cast(66.80131188771972, f32))
  b5 = sp_lift_t(q, cast(-13.28068155288572, f32))
  one = sp_lift_t(q, cast(1.0, f32))
  half = sp_lift_t(q, cast(0.5, f32))
  u = sub(q, half)
  r = mul(u, u)
  num = mul(add(mul(r, add(mul(r, add(mul(r, add(mul(r, add(mul(r, a1), a2)), a3)), a4)), a5)), a6), u)
  den = add(mul(r, add(mul(r, add(mul(r, add(mul(r, add(mul(r, b1), b2)), b3)), b4)), b5)), one)
  div(num, den)
}
def acklam_tail_t[n](u: &tensor[n, f32]) -> tensor[n, f32] = {
  c1 = sp_lift_t(u, cast(-0.007784894002430293, f32))
  c2 = sp_lift_t(u, cast(-0.3223964580411365, f32))
  c3 = sp_lift_t(u, cast(-2.400758277161838, f32))
  c4 = sp_lift_t(u, cast(-2.549732539343734, f32))
  c5 = sp_lift_t(u, cast(4.374664141464968, f32))
  c6 = sp_lift_t(u, cast(2.938163982698783, f32))
  d1 = sp_lift_t(u, cast(0.007784695709041462, f32))
  d2 = sp_lift_t(u, cast(0.3224671290700398, f32))
  d3 = sp_lift_t(u, cast(2.445134137142996, f32))
  d4 = sp_lift_t(u, cast(3.754408661907416, f32))
  one = sp_lift_t(u, cast(1.0, f32))
  num = add(mul(u, add(mul(u, add(mul(u, add(mul(u, add(mul(u, c1), c2)), c3)), c4)), c5)), c6)
  den = add(one, mul(u, u |> mul(add(mul(u, add(mul(u, d1), d2)), d3)) |> add(d4)))
  div(num, den)
}
def norminv_t[n](q: &tensor[n, f32]) -> tensor[n, f32] = {
  plow = sp_lift_t(q, cast(0.02425, f32))
  one = sp_lift_t(q, cast(1.0, f32))
  two = sp_lift_t(q, cast(2.0, f32))
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
def erfinv_t[n](x: &tensor[n, f32]) -> tensor[n, f32] = {
  half = sp_lift_t(x, cast(0.5, f32))
  sqrt_half = sp_lift_t(x, cast(0.7071067811865476, f32))
  one = sp_lift_t(x, cast(1.0, f32))
  q = x |> add(one) |> mul(half)
  q |> norminv_t |> mul(sqrt_half)
}
