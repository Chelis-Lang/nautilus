module Nautilus.Distributions
import Nautilus.Special (erf, erfinv, log_gamma)
export (uniform_pdf, uniform_cdf, uniform_inv_cdf, uniform_sample, exponential_pdf, exponential_cdf, exponential_inv_cdf, exponential_sample, normal_pdf, normal_cdf, normal_inv_cdf, normal_sample, lognormal_pdf, lognormal_cdf, lognormal_inv_cdf, lognormal_sample, gamma_pdf, chi_squared_pdf, student_t_pdf, gamma_cdf, chi_squared_cdf, gamma_inv_cdf, chi_squared_inv_cdf, chi_squared_sample, student_t_sample, gamma_sample, student_t_cdf, poisson_pmf, poisson_cdf, binomial_pmf, binomial_cdf, beta_pdf, beta_cdf, f_pdf, f_cdf, weibull_pdf, weibull_cdf, weibull_inv_cdf)
-- chelis:provenance/v1 authority
-- id = NAUT-MOD-DISTRIBUTIONS
-- kind = behavioral
-- scopes = nautilus
-- statement = Nautilus.Distributions MUST provide the distribution surface listed in the module support table.
def zero_f() -> f32 = cast(0.0, f32)
def one_f() -> f32 = cast(1.0, f32)
def two_f() -> f32 = cast(2.0, f32)
def half_f() -> f32 = cast(0.5, f32)
def pi_f() -> f32 = cast(3.141592653589793, f32)
def two_pi_f() -> f32 = cast(6.283185307179586, f32)
def sqrt_two_f() -> f32 = cast(1.4142135623730951, f32)
def sqrt_2pi_f() -> f32 = cast(2.5066282746310002, f32)
def log_sqrt_2pi_f() -> f32 = cast(0.9189385332046727, f32)
def pos_inf_d() -> f32 = div(cast(1.0, f32), cast(0.0, f32))
def nan_d() -> f32 = div(cast(0.0, f32), cast(0.0, f32))
def uniform_pdf(x: f32, lo: f32, hi: f32) -> f32 = {
  zero = zero_f()
  width = sub(hi, lo)
  inside = and(gte(x, lo), lte(x, hi))
  if inside then div(one_f(), width) else zero
}
def uniform_cdf(x: f32, lo: f32, hi: f32) -> f32 = {
  width = sub(hi, lo)
  if lte(x, lo) then zero_f() else if gte(x, hi) then one_f() else div(sub(x, lo), width)
}
def uniform_inv_cdf(q: f32, lo: f32, hi: f32) -> f32 = {
  width = sub(hi, lo)
  add(lo, mul(q, width))
}
def uniform_sample[n](template: tensor[n, f32], lo: f32, hi: f32) -> tensor[n, f32] ! { Random } = {
  u = uniform_like(template, 0.0, 1.0)
  width = sub(hi, lo)
  to_tensor(map(fn (x: f32) -> add(lo, mul(width, x)), to_list(u)))
}
def exponential_pdf(x: f32, rate: f32) -> f32 = {
  if lt(x, zero_f()) then zero_f() else {
    neg_rx = neg(mul(rate, x))
    e = exp(neg_rx)
    mul(rate, e)
  }
}
def exponential_cdf(x: f32, rate: f32) -> f32 = {
  if lt(x, zero_f()) then zero_f() else {
    neg_rx = neg(mul(rate, x))
    e = exp(neg_rx)
    sub(one_f(), e)
  }
}
def exponential_inv_cdf(q: f32, rate: f32) -> f32 = {
  if or(lt(q, zero_f()), gt(q, one_f())) then nan_d() else if eq(q, one_f()) then pos_inf_d() else if eq(q, zero_f()) then zero_f() else {
    omq = sub(one_f(), q)
    l = log(omq)
    neg(div(l, rate))
  }
}
def exponential_sample[n](template: tensor[n, f32], rate: f32) -> tensor[n, f32] ! { Random } = {
  u = uniform_like(template, 0.0000001, 1.0)
  to_tensor(map(fn (x: f32) -> {
    l = log(x)
    nl = neg(l)
    div(nl, rate)
  }, to_list(u)))
}
def normal_pdf(x: f32, mean: f32, std: f32) -> f32 = {
  z = div(sub(x, mean), std)
  z2 = mul(z, z)
  half_z2 = mul(half_f(), z2)
  nhz2 = neg(half_z2)
  e = exp(nhz2)
  denom = mul(std, sqrt_2pi_f())
  div(e, denom)
}
def normal_cdf(x: f32, mean: f32, std: f32) -> f32 = {
  z = div(sub(x, mean), mul(std, sqrt_two_f()))
  e = erf(z)
  mul(half_f(), add(one_f(), e))
}
def normal_inv_cdf(q: f32, mean: f32, std: f32) -> f32 = {
  if or(lt(q, zero_f()), gt(q, one_f())) then nan_d() else if lte(q, zero_f()) then neg(pos_inf_d()) else if gte(q, one_f()) then pos_inf_d() else {
    two_q_minus_one = sub(mul(two_f(), q), one_f())
    z = erfinv(two_q_minus_one)
    add(mean, mul(std, mul(sqrt_two_f(), z)))
  }
}
def normal_sample[n](template: tensor[n, f32], mean: f32, std: f32) -> tensor[n, f32] ! { Random } = {
  u1 = uniform_like(copy(template), 0.0000001, 1.0)
  u2 = uniform_like(template, 0.0, 1.0)
  to_tensor(map(fn (pair: (f32, f32)) -> {
    a = pair.0
    b = pair.1
    two_pi_b = mul(two_pi_f(), b)
    half_pi = mul(half_f(), pi_f())
    cos_term = sin(sub(half_pi, two_pi_b))
    la = log(a)
    minus_two_la = neg(mul(two_f(), la))
    radius = sqrt(minus_two_la)
    z = mul(radius, cos_term)
    add(mean, mul(std, z))
  }, zip(to_list(u1), to_list(u2))))
}
def lognormal_pdf(x: f32, mu: f32, sigma: f32) -> f32 = {
  if lte(x, zero_f()) then zero_f() else {
    lx = log(x)
    z = div(sub(lx, mu), sigma)
    z2 = mul(z, z)
    half_z2 = mul(half_f(), z2)
    nhz2 = neg(half_z2)
    e = exp(nhz2)
    denom = mul(x, mul(sigma, sqrt_2pi_f()))
    div(e, denom)
  }
}
def lognormal_cdf(x: f32, mu: f32, sigma: f32) -> f32 = {
  if lte(x, zero_f()) then zero_f() else {
    lx = log(x)
    normal_cdf(lx, mu, sigma)
  }
}
def lognormal_inv_cdf(q: f32, mu: f32, sigma: f32) -> f32 = {
  y = normal_inv_cdf(q, mu, sigma)
  exp(y)
}
def lognormal_sample[n](template: tensor[n, f32], mu: f32, sigma: f32) -> tensor[n, f32] ! { Random } = {
  z = normal_sample(template, mu, sigma)
  to_tensor(map(fn (x: f32) -> exp(x), to_list(z)))
}
def gamma_pdf(x: f32, shape: f32, scale: f32) -> f32 = {
  if lt(x, zero_f()) then zero_f() else if eq(x, zero_f()) then { if gt(shape, one_f()) then zero_f() else if eq(shape, one_f()) then div(one_f(), scale) else pos_inf_d() } else {
    lx = log(x)
    lscale = log(scale)
    k_minus_one = sub(shape, one_f())
    term1 = mul(k_minus_one, lx)
    term2 = mul(shape, lscale)
    xs = div(x, scale)
    lgk = log_gamma(shape)
    log_pdf = sub(sub(sub(term1, xs), term2), lgk)
    exp(log_pdf)
  }
}
def chi_squared_pdf(x: f32, df: f32) -> f32 = {
  half_df = mul(half_f(), df)
  gamma_pdf(x, half_df, two_f())
}
def student_t_pdf(x: f32, df: f32) -> f32 = {
  half_df = mul(half_f(), df)
  half_dfp1 = mul(half_f(), add(df, one_f()))
  lg_num = log_gamma(half_dfp1)
  lg_den = log_gamma(half_df)
  x2 = mul(x, x)
  x2_over_df = div(x2, df)
  base = add(one_f(), x2_over_df)
  lbase = log(base)
  exponent_term = mul(neg(half_dfp1), lbase)
  half_log_df = mul(half_f(), log(df))
  half_log_pi = mul(half_f(), cast(1.1447298858494002, f32))
  log_pdf = sub(sub(sub(add(lg_num, exponent_term), lg_den), half_log_df), half_log_pi)
  exp(log_pdf)
}
def gammainc_series(a: f32, x: f32, term: f32, acc: f32, ap: f32, iters: int64) -> f32 = {
  zero_i = cast(0, int64)
  one_i = cast(1, int64)
  if lte(iters, zero_i) then acc else {
    ap_next = add(ap, one_f())
    term_next = mul(term, div(x, ap_next))
    acc_next = add(acc, term_next)
    abs_term = abs_f32_inner(term_next)
    abs_acc = abs_f32_inner(acc_next)
    floor = cast(1.0, f32)
    scale = if gt(abs_acc, floor) then abs_acc else floor
    tol = cast(0.0000001, f32)
    converged = lt(abs_term, mul(tol, scale))
    if converged then acc_next else gammainc_series(a, x, term_next, acc_next, ap_next, sub(iters, one_i))
  }
}
def gammap(a: f32, x: f32) -> f32 = {
  if lte(x, zero_f()) then zero_f() else {
    la = log_gamma(a)
    lx = log(x)
    a_lx = mul(a, lx)
    front_exp_arg = sub(sub(a_lx, x), la)
    front = exp(front_exp_arg)
    inv_a = div(one_f(), a)
    series = gammainc_series(a, x, inv_a, inv_a, a, cast(200, int64))
    mul(front, series)
  }
}
def gammaq_cf_rec(a: f32, x: f32, b: f32, c: f32, d: f32, h: f32, i: int64) -> f32 = {
  zero_i = cast(0, int64)
  one_i = cast(1, int64)
  if lte(i, zero_i) then h else {
    fi = cast(201, f32)
    j = sub(fi, cast(i, f32))
    an = mul(neg(j), sub(j, a))
    b_next = add(b, two_f())
    d_raw = add(mul(an, d), b_next)
    d_guard = if lt(abs_f32_inner(d_raw), cast(0.000000000000000000000000000001, f32)) then cast(0.000000000000000000000000000001, f32) else d_raw
    c_raw = add(b_next, div(an, c))
    c_guard = if lt(abs_f32_inner(c_raw), cast(0.000000000000000000000000000001, f32)) then cast(0.000000000000000000000000000001, f32) else c_raw
    d_inv = div(one_f(), d_guard)
    delta = mul(c_guard, d_inv)
    h_next = mul(h, delta)
    cf_tol = cast(0.0000001, f32)
    delta_err = abs_f32_inner(sub(delta, one_f()))
    converged = lt(delta_err, cf_tol)
    if converged then h_next else gammaq_cf_rec(a, x, b_next, c_guard, d_inv, h_next, sub(i, one_i))
  }
}
def abs_f32_inner(x: f32) -> f32 = if lt(x, zero_f()) then neg(x) else x
def betacf_rec(a: f32, b: f32, x: f32, c: f32, d: f32, h: f32, m: int64, max_m: int64) -> f32 = {
  one_i = cast(1, int64)
  if gt(m, max_m) then h else {
    eps = cast(0.000000000000000000000000000001, f32)
    m_f = cast(m, f32)
    m2_f = mul(cast(2.0, f32), m_f)
    qab = add(a, b)
    qap = add(a, one_f())
    qam = sub(a, one_f())
    aa1_num = mul(m_f, mul(sub(b, m_f), x))
    aa1_den = mul(add(qam, m2_f), add(a, m2_f))
    aa1 = div(aa1_num, aa1_den)
    d1_raw = add(one_f(), mul(aa1, d))
    d1 = if lt(abs_f32_inner(d1_raw), eps) then eps else d1_raw
    c1_raw = add(one_f(), div(aa1, c))
    c1 = if lt(abs_f32_inner(c1_raw), eps) then eps else c1_raw
    d1_inv = div(one_f(), d1)
    h1 = mul(mul(h, d1_inv), c1)
    aa2_num_neg = mul(neg(add(a, m_f)), mul(add(qab, m_f), x))
    aa2_den = mul(add(a, m2_f), add(qap, m2_f))
    aa2 = div(aa2_num_neg, aa2_den)
    d2_raw = add(one_f(), mul(aa2, d1_inv))
    d2 = if lt(abs_f32_inner(d2_raw), eps) then eps else d2_raw
    c2_raw = add(one_f(), div(aa2, c1))
    c2 = if lt(abs_f32_inner(c2_raw), eps) then eps else c2_raw
    d2_inv = div(one_f(), d2)
    delta = mul(d2_inv, c2)
    h2 = mul(h1, delta)
    bcf_tol = cast(0.0000001, f32)
    delta_err = abs_f32_inner(sub(delta, one_f()))
    converged = lt(delta_err, bcf_tol)
    if converged then h2 else betacf_rec(a, b, x, c2, d2_inv, h2, add(m, one_i), max_m)
  }
}
def betacf(a: f32, b: f32, x: f32) -> f32 = {
  eps = cast(0.000000000000000000000000000001, f32)
  qab = add(a, b)
  qap = add(a, one_f())
  d0_raw = sub(one_f(), div(mul(qab, x), qap))
  d0 = if lt(abs_f32_inner(d0_raw), eps) then eps else d0_raw
  d0_inv = div(one_f(), d0)
  c0 = one_f()
  betacf_rec(a, b, x, c0, d0_inv, d0_inv, cast(1, int64), cast(200, int64))
}
def betai(a: f32, b: f32, x: f32) -> f32 = {
  if lte(x, zero_f()) then zero_f() else if gte(x, one_f()) then one_f() else {
    lg_ab = log_gamma(add(a, b))
    lg_a = log_gamma(a)
    lg_b = log_gamma(b)
    lx = log(x)
    l1mx = log(sub(one_f(), x))
    front_exp_arg = add(sub(sub(lg_ab, lg_a), lg_b), add(mul(a, lx), mul(b, l1mx)))
    front = exp(front_exp_arg)
    threshold_num = add(a, one_f())
    threshold_den = add(add(a, b), cast(2.0, f32))
    threshold = div(threshold_num, threshold_den)
    if lt(x, threshold) then {
      cf = betacf(a, b, x)
      mul(front, div(cf, a))
    } else {
      one_minus_x = sub(one_f(), x)
      cf = betacf(b, a, one_minus_x)
      val = mul(front, div(cf, b))
      sub(one_f(), val)
    }
  }
}
def is_integer_f32(x: f32) -> bool = {
  xi = cast(cast(x, int64), f32)
  eq(x, xi)
}
def poisson_pmf(k: f32, lambda: f32) -> f32 = {
  if lt(lambda, zero_f()) then nan_d() else if lt(k, zero_f()) then zero_f() else if not(is_integer_f32(k)) then zero_f() else if eq(lambda, zero_f()) then { if eq(k, zero_f()) then one_f() else zero_f() } else {
    lk = log(lambda)
    k_lk = mul(k, lk)
    lg_k1 = log_gamma(add(k, one_f()))
    log_pmf = sub(sub(k_lk, lambda), lg_k1)
    exp(log_pmf)
  }
}
def poisson_cdf(k: f32, lambda: f32) -> f32 = {
  if lt(lambda, zero_f()) then nan_d() else if lt(k, zero_f()) then zero_f() else if eq(lambda, zero_f()) then one_f() else {
    k_plus_one = add(k, one_f())
    gc = gamma_cdf(lambda, k_plus_one, one_f())
    sub(one_f(), gc)
  }
}
def binomial_pmf(k: f32, n: f32, p: f32) -> f32 = {
  if or(lt(k, zero_f()), gt(k, n)) then zero_f() else if not(is_integer_f32(k)) then zero_f() else if not(is_integer_f32(n)) then nan_d() else if or(lt(p, zero_f()), gt(p, one_f())) then nan_d() else if eq(p, zero_f()) then { if eq(k, zero_f()) then one_f() else zero_f() } else if eq(p, one_f()) then { if eq(k, n) then one_f() else zero_f() } else {
    lg_n1 = log_gamma(add(n, one_f()))
    lg_k1 = log_gamma(add(k, one_f()))
    lg_nmk1 = log_gamma(add(sub(n, k), one_f()))
    log_choose = sub(sub(lg_n1, lg_k1), lg_nmk1)
    lp = log(p)
    l1mp = log(sub(one_f(), p))
    k_lp = mul(k, lp)
    nmk_l1mp = mul(sub(n, k), l1mp)
    log_pmf = add(add(log_choose, k_lp), nmk_l1mp)
    exp(log_pmf)
  }
}
def binomial_cdf(k: f32, n: f32, p: f32) -> f32 = {
  if or(lt(p, zero_f()), gt(p, one_f())) then nan_d() else if lt(k, zero_f()) then zero_f() else if gte(k, n) then one_f() else {
    a = sub(n, k)
    b = add(k, one_f())
    betai(a, b, sub(one_f(), p))
  }
}
def beta_pdf(x: f32, a: f32, b: f32) -> f32 = {
  if or(lte(a, zero_f()), lte(b, zero_f())) then nan_d() else if or(lt(x, zero_f()), gt(x, one_f())) then zero_f() else if eq(x, zero_f()) then { if gt(a, one_f()) then zero_f() else if eq(a, one_f()) then b else pos_inf_d() } else if eq(x, one_f()) then { if gt(b, one_f()) then zero_f() else if eq(b, one_f()) then a else pos_inf_d() } else {
    lx = log(x)
    l1mx = log(sub(one_f(), x))
    lg_a = log_gamma(a)
    lg_b = log_gamma(b)
    lg_ab = log_gamma(add(a, b))
    a_m1 = sub(a, one_f())
    b_m1 = sub(b, one_f())
    log_pdf = add(add(sub(lg_ab, add(lg_a, lg_b)), mul(a_m1, lx)), mul(b_m1, l1mx))
    exp(log_pdf)
  }
}
def nan_guard_b_const(b: f32) -> f32 = b
def beta_cdf(x: f32, a: f32, b: f32) -> f32 = { if or(lte(a, zero_f()), lte(b, zero_f())) then nan_d() else betai(a, b, x) }
def f_pdf(x: f32, d1: f32, d2: f32) -> f32 = {
  if lte(x, zero_f()) then zero_f() else if or(lte(d1, zero_f()), lte(d2, zero_f())) then nan_d() else {
    half = half_f()
    half_d1 = mul(half, d1)
    half_d2 = mul(half, d2)
    half_sum = add(half_d1, half_d2)
    d1x = mul(d1, x)
    denom = add(d1x, d2)
    lnum = mul(half_d1, log(d1x))
    lden = mul(half_d2, log(d2))
    lbot = mul(half_sum, log(denom))
    lg_num = log_gamma(half_sum)
    lg_den = add(log_gamma(half_d1), log_gamma(half_d2))
    lbeta_half = sub(lg_num, lg_den)
    inv_x = div(one_f(), x)
    log_inv_x = log(x)
    log_pdf = sub(add(lbeta_half, add(add(lnum, lden), neg(log(x)))), lbot)
    ignore_unused = log_inv_x
    exp(log_pdf)
  }
}
def f_cdf(x: f32, d1: f32, d2: f32) -> f32 = {
  if lte(x, zero_f()) then zero_f() else if or(lte(d1, zero_f()), lte(d2, zero_f())) then nan_d() else {
    half = half_f()
    half_d1 = mul(half, d1)
    half_d2 = mul(half, d2)
    d1x = mul(d1, x)
    denom = add(d1x, d2)
    u = div(d1x, denom)
    betai(half_d1, half_d2, u)
  }
}
def weibull_pdf(x: f32, shape: f32, scale: f32) -> f32 = {
  if lt(x, zero_f()) then zero_f() else if or(lte(shape, zero_f()), lte(scale, zero_f())) then nan_d() else if eq(x, zero_f()) then { if gt(shape, one_f()) then zero_f() else if eq(shape, one_f()) then div(one_f(), scale) else pos_inf_d() } else {
    k = shape
    lam = scale
    xl = div(x, lam)
    lxl = log(xl)
    km1 = sub(k, one_f())
    k_over_lam = div(k, lam)
    lkl = log(k_over_lam)
    xlk = exp(mul(k, lxl))
    nxlk = neg(xlk)
    log_pdf = add(lkl, add(mul(km1, lxl), nxlk))
    exp(log_pdf)
  }
}
def weibull_cdf(x: f32, shape: f32, scale: f32) -> f32 = {
  if lt(x, zero_f()) then zero_f() else if or(lte(shape, zero_f()), lte(scale, zero_f())) then nan_d() else {
    xl = div(x, scale)
    lxl = log(xl)
    xlk = exp(mul(shape, lxl))
    nxlk = neg(xlk)
    e = exp(nxlk)
    sub(one_f(), e)
  }
}
def weibull_inv_cdf(q: f32, shape: f32, scale: f32) -> f32 = {
  if or(lt(q, zero_f()), gt(q, one_f())) then nan_d() else if eq(q, zero_f()) then zero_f() else if eq(q, one_f()) then pos_inf_d() else if or(lte(shape, zero_f()), lte(scale, zero_f())) then nan_d() else {
    omq = sub(one_f(), q)
    l = log(omq)
    nl = neg(l)
    lnl = log(nl)
    inv_k = div(one_f(), shape)
    exp_arg = mul(inv_k, lnl)
    factor = exp(exp_arg)
    mul(scale, factor)
  }
}
def student_t_cdf(t: f32, df: f32) -> f32 = {
  if lte(df, zero_f()) then nan_d() else {
    half_df = mul(half_f(), df)
    half = half_f()
    t2 = mul(t, t)
    df_plus_t2 = add(df, t2)
    x_arg = div(df, df_plus_t2)
    bi = betai(half_df, half, x_arg)
    half_bi = mul(half, bi)
    if gte(t, zero_f()) then sub(one_f(), half_bi) else half_bi
  }
}
def gammaq(a: f32, x: f32) -> f32 = {
  if lte(x, zero_f()) then one_f() else {
    la = log_gamma(a)
    lx = log(x)
    a_lx = mul(a, lx)
    front_exp_arg = sub(sub(a_lx, x), la)
    front = exp(front_exp_arg)
    b0 = add(sub(x, a), one_f())
    tiny = cast(0.000000000000000000000000000001, f32)
    c0 = div(one_f(), tiny)
    d0 = div(one_f(), b0)
    h0 = d0
    h = gammaq_cf_rec(a, x, b0, c0, d0, h0, cast(200, int64))
    mul(front, h)
  }
}
def gamma_cdf(x: f32, shape: f32, scale: f32) -> f32 = {
  xs = div(x, scale)
  if lt(xs, add(shape, one_f())) then gammap(shape, xs) else sub(one_f(), gammaq(shape, xs))
}
def chi_squared_cdf(x: f32, df: f32) -> f32 = {
  half_df = mul(half_f(), df)
  gamma_cdf(x, half_df, two_f())
}
def gamma_inv_cdf_newton(target: f32, shape: f32, scale: f32, x: f32, iters: int64) -> f32 = {
  zero_i = cast(0, int64)
  one_i = cast(1, int64)
  if lte(iters, zero_i) then x else {
    cur = gamma_cdf(x, shape, scale)
    resid = sub(cur, target)
    pdf_v = gamma_pdf(x, shape, scale)
    floor_pdf = cast(0.000000000000000000000000000001, f32)
    pdf_safe = if lt(pdf_v, floor_pdf) then floor_pdf else pdf_v
    step = div(resid, pdf_safe)
    x_next_raw = sub(x, step)
    x_next = if lte(x_next_raw, zero_f()) then mul(half_f(), x) else x_next_raw
    gamma_inv_cdf_newton(target, shape, scale, x_next, sub(iters, one_i))
  }
}
def gamma_inv_cdf(q: f32, shape: f32, scale: f32) -> f32 = {
  if or(lt(q, zero_f()), gt(q, one_f())) then nan_d() else if lte(q, zero_f()) then zero_f() else if gte(q, one_f()) then pos_inf_d() else {
    z = normal_inv_cdf(q, zero_f(), one_f())
    inv_9k = div(one_f(), mul(cast(9.0, f32), shape))
    third = cast(0.3333333333, f32)
    sqrt_inv_9k = sqrt(inv_9k)
    a = sub(one_f(), inv_9k)
    b = mul(z, sqrt_inv_9k)
    s = add(a, b)
    s_cubed = mul(s, mul(s, s))
    wh_safe = if gt(s_cubed, cast(0.000000000000000000000000000001, f32)) then s_cubed else cast(0.000000000000000000000000000001, f32)
    x0 = mul(shape, mul(scale, wh_safe))
    gamma_inv_cdf_newton(q, shape, scale, x0, cast(80, int64))
  }
}
def chi_squared_inv_cdf(q: f32, df: f32) -> f32 = {
  half_df = mul(half_f(), df)
  gamma_inv_cdf(q, half_df, two_f())
}
def gamma_sample_ge1_try[n](template: tensor[n, f32], d: f32, c: f32, attempts: int64) -> tensor[n, f32] ! { Random } = {
  zero_i = cast(0, int64)
  one_i = cast(1, int64)
  z_t = normal_sample(copy(template), zero_f(), one_f())
  u_t = uniform_like(copy(template), 0.0000001, 1.0)
  z_list = to_list(z_t)
  u_list = to_list(u_t)
  head_z = fold(fn (acc: f32, x: f32) -> acc, zero_f(), z_list)
  head_u = fold(fn (acc: f32, x: f32) -> acc, zero_f(), u_list)
  v_base = add(one_f(), mul(c, head_z))
  v = mul(mul(v_base, v_base), v_base)
  if lte(attempts, zero_i) then {
    result_val = mul(d, if gt(v, zero_f()) then v else one_f())
    to_tensor(map(fn (x: f32) -> result_val, to_list(copy(template))))
  } else if lte(v, zero_f()) then gamma_sample_ge1_try(template, d, c, sub(attempts, one_i)) else {
    lv = log(v)
    z2 = mul(head_z, head_z)
    half_z2 = mul(half_f(), z2)
    crit = sub(sub(one_f(), mul(cast(0.0331, f32), mul(z2, z2))), half_z2)
    lu = log(head_u)
    crit2 = add(half_z2, mul(d, sub(sub(one_f(), v), lv)))
    accept_fast = lt(head_u, crit)
    accept_slow = lt(lu, crit2)
    accept = or(accept_fast, accept_slow)
    if accept then {
      result_val = mul(d, v)
      to_tensor(map(fn (x: f32) -> result_val, to_list(template)))
    } else gamma_sample_ge1_try(template, d, c, sub(attempts, one_i))
  }
}
def gamma_sample[n](template: tensor[n, f32], shape: f32, scale: f32) -> tensor[n, f32] ! { Random } = {
  d = sub(shape, cast(0.3333333333, f32))
  inv_3 = cast(0.3333333333, f32)
  sqrt_d = sqrt(d)
  c = div(inv_3, sqrt_d)
  raw = gamma_sample_ge1_try(template, d, c, cast(64, int64))
  to_tensor(map(fn (x: f32) -> mul(x, scale), to_list(raw)))
}
def chi_squared_sample[n](template: tensor[n, f32], df: f32) -> tensor[n, f32] ! { Random } = {
  half_df = mul(half_f(), df)
  gamma_sample(template, half_df, two_f())
}
def student_t_sample[n](template: tensor[n, f32], df: f32) -> tensor[n, f32] ! { Random } = {
  z = normal_sample(copy(template), zero_f(), one_f())
  v = chi_squared_sample(template, df)
  to_tensor(map(fn (pair: (f32, f32)) -> {
    zi = pair.0
    vi = pair.1
    ratio = div(vi, df)
    s = sqrt(ratio)
    div(zi, s)
  }, zip(to_list(z), to_list(v))))
}
