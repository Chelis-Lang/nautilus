module Nautilus.Distributions
import Nautilus.Special (erfinv, erfinv_t, log_gamma)
export (uniform_pdf, uniform_cdf, uniform_inv_cdf, uniform_sample, exponential_pdf, exponential_cdf, exponential_inv_cdf, exponential_sample, normal_pdf, normal_cdf, normal_inv_cdf, normal_sample, lognormal_pdf, lognormal_cdf, lognormal_inv_cdf, lognormal_sample, gamma_pdf, chi_squared_pdf, student_t_pdf, gamma_cdf, gamma_sf, chi_squared_cdf, chi_squared_sf, gamma_inv_cdf, chi_squared_inv_cdf, chi_squared_sample, student_t_sample, gamma_sample, student_t_cdf, poisson_pmf, poisson_cdf, binomial_pmf, binomial_cdf, beta_pdf, beta_cdf, f_pdf, f_cdf, weibull_pdf, weibull_cdf, weibull_inv_cdf, normal_cdf_t, normal_inv_cdf_t, normal_pdf_t)
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
def uniform_sample[n](k: key, template: tensor[n, f32], lo: f32, hi: f32) -> tensor[n, f32] = {
  u = uniform_like(k, template, 0.0, 1.0)
  widths = dist_lift_t(u, sub(hi, lo))
  los = dist_lift_t(u, lo)
  add(los, mul(widths, u))
}
def exponential_pdf(x: f32, rate: f32) -> f32 =
  if lt(x, zero_f()) then zero_f() else {
    neg_rx = neg(mul(rate, x))
    e = exp(neg_rx)
    mul(rate, e)
  }
def exponential_cdf(x: f32, rate: f32) -> f32 =
  if lt(x, zero_f()) then zero_f() else {
    neg_rx = neg(mul(rate, x))
    e = exp(neg_rx)
    sub(one_f(), e)
  }
def exponential_inv_cdf(q: f32, rate: f32) -> f32 =
  if or(lt(q, zero_f()), gt(q, one_f())) then nan_d() else if eq(q, one_f()) then pos_inf_d() else if eq(q, zero_f()) then zero_f() else {
    omq = sub(one_f(), q)
    l = log(omq)
    neg(div(l, rate))
  }
def exponential_sample[n](k: key, template: tensor[n, f32], rate: f32) -> tensor[n, f32] = {
  u = uniform_like(k, template, 1e-7, 1.0)
  rates = dist_lift_t(u, rate)
  div(neg(log(u)), rates)
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
-- `standard_normal_cdf` is the Chelis builtin `Phi`, an erfc-based graph with a
-- Veltkamp/Dekker correction for the rounding of `-x/sqrt(2)`. The previous
-- spelling `0.5 * (1 + erf(z))` cancelled as `erf(z)` approached `-1`: its
-- absolute error was about `0.5 * ulp(1.0)` however accurate `erf` was, so it
-- returned exactly `0.0` for every standardized point below about `-6` and
-- carried no significant digits below about `-5.3`.
def normal_cdf(x: f32, mean: f32, std: f32) -> f32 = standard_normal_cdf(div(sub(x, mean), std))
def normal_inv_cdf(q: f32, mean: f32, std: f32) -> f32 =
  if or(lt(q, zero_f()), gt(q, one_f())) then nan_d() else if lte(q, zero_f()) then neg(pos_inf_d()) else if gte(q, one_f()) then pos_inf_d() else {
    two_q_minus_one = sub(mul(two_f(), q), one_f())
    z = erfinv(two_q_minus_one)
    add(mean, mul(std, mul(sqrt_two_f(), z)))
  }
def normal_sample[n](k: key, template: tensor[n, f32], mean: f32, std: f32) -> tensor[n, f32] = {
  ks = split_key(k)
  u1 = uniform_like(ks.0, copy(template), 1e-7, 1.0)
  u2 = uniform_like(ks.1, template, 0.0, 1.0)
  two_pis = dist_lift_t(u2, two_pi_f())
  half_pis = dist_lift_t(u2, mul(half_f(), pi_f()))
  twos = dist_lift_t(u1, two_f())
  means = dist_lift_t(u1, mean)
  stds = dist_lift_t(u1, std)
  cos_term = sin(sub(half_pis, mul(two_pis, u2)))
  radius = sqrt(neg(mul(twos, log(u1))))
  add(means, mul(stds, mul(radius, cos_term)))
}
def lognormal_pdf(x: f32, mu: f32, sigma: f32) -> f32 =
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
def lognormal_cdf(x: f32, mu: f32, sigma: f32) -> f32 =
  if lte(x, zero_f()) then zero_f() else {
    lx = log(x)
    normal_cdf(lx, mu, sigma)
  }
def lognormal_inv_cdf(q: f32, mu: f32, sigma: f32) -> f32 = {
  y = normal_inv_cdf(q, mu, sigma)
  exp(y)
}
def lognormal_sample[n](k: key, template: tensor[n, f32], mu: f32, sigma: f32) -> tensor[n, f32] = {
  z = normal_sample(k, template, mu, sigma)
  exp(z)
}
def gamma_pdf(x: f32, shape: f32, scale: f32) -> f32 =
  if lt(x, zero_f()) then zero_f() else if eq(x, zero_f()) then if gt(shape, one_f()) then zero_f() else if eq(shape, one_f()) then div(one_f(), scale) else pos_inf_d() else {
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
-- The incomplete-gamma series and continued fraction below each carry a
-- 200-iteration budget, and each runs it in chunks of this many steps through
-- an outer driver so the budget costs about 30 stack frames instead of 200.
-- `chelis eval --file` evaluates on `main` and aborts the process at 136
-- frames of a body this size, so the flat recursion could not spend its budget:
-- see the eval-lane entry in `docs/UPSTREAM_BUGS.md`, which cites the
-- upstream issue by number.
-- The chunking changes no arithmetic: the iteration sequence, the convergence
-- test and the result are the flat form's, bit for bit, on every converging
-- input.
def gammainc_chunk_i() -> i64 = cast(16, i64)
def gammainc_series_chunk(x: f32, term: f32, acc: f32, ap: f32, iters: i64, steps: i64) -> (f32, f32, f32, i64, bool) = {
  zero_i = cast(0, i64)
  one_i = cast(1, i64)
  if or(lte(iters, zero_i), lte(steps, zero_i)) then (term, acc, ap, iters, false) else {
    ap_next = add(ap, one_f())
    term_next = mul(term, div(x, ap_next))
    acc_next = add(acc, term_next)
    abs_term = abs_f32_inner(term_next)
    abs_acc = abs_f32_inner(acc_next)
    floor = cast(1.0, f32)
    scale = if gt(abs_acc, floor) then abs_acc else floor
    tol = cast(1e-7, f32)
    converged = lt(abs_term, mul(tol, scale))
    iters_next = sub(iters, one_i)
    if converged then (term_next, acc_next, ap_next, iters_next, true) else gammainc_series_chunk(x, term_next, acc_next, ap_next, iters_next, sub(steps, one_i))
  }
}
def gammainc_series(x: f32, term: f32, acc: f32, ap: f32, iters: i64) -> f32 = {
  zero_i = cast(0, i64)
  if lte(iters, zero_i) then acc else {
    st = gammainc_series_chunk(x, term, acc, ap, iters, gammainc_chunk_i())
    if st.4 then st.1 else gammainc_series(x, st.0, st.1, st.2, st.3)
  }
}
def gammap(a: f32, x: f32) -> f32 =
  if lte(x, zero_f()) then zero_f() else {
    la = log_gamma(a)
    lx = log(x)
    a_lx = mul(a, lx)
    front_exp_arg = sub(sub(a_lx, x), la)
    front = exp(front_exp_arg)
    inv_a = div(one_f(), a)
    series = gammainc_series(x, inv_a, inv_a, a, cast(200, i64))
    mul(front, series)
  }
def gammaq_cf_chunk(a: f32, b: f32, c: f32, d: f32, h: f32, i: i64, steps: i64) -> (f32, f32, f32, f32, i64, bool) = {
  zero_i = cast(0, i64)
  one_i = cast(1, i64)
  if or(lte(i, zero_i), lte(steps, zero_i)) then (b, c, d, h, i, false) else {
    fi = cast(201, f32)
    j = sub(fi, cast(i, f32))
    an = mul(neg(j), sub(j, a))
    b_next = add(b, two_f())
    d_raw = add(mul(an, d), b_next)
    d_guard = if lt(abs_f32_inner(d_raw), cast(1e-30, f32)) then cast(1e-30, f32) else d_raw
    c_raw = add(b_next, div(an, c))
    c_guard = if lt(abs_f32_inner(c_raw), cast(1e-30, f32)) then cast(1e-30, f32) else c_raw
    d_inv = div(one_f(), d_guard)
    delta = mul(c_guard, d_inv)
    h_next = mul(h, delta)
    cf_tol = cast(1e-7, f32)
    delta_err = abs_f32_inner(sub(delta, one_f()))
    converged = lt(delta_err, cf_tol)
    i_next = sub(i, one_i)
    if converged then (b_next, c_guard, d_inv, h_next, i_next, true) else gammaq_cf_chunk(a, b_next, c_guard, d_inv, h_next, i_next, sub(steps, one_i))
  }
}
def gammaq_cf_rec(a: f32, b: f32, c: f32, d: f32, h: f32, i: i64) -> f32 = {
  zero_i = cast(0, i64)
  if lte(i, zero_i) then h else {
    st = gammaq_cf_chunk(a, b, c, d, h, i, gammainc_chunk_i())
    if st.5 then st.3 else gammaq_cf_rec(a, st.0, st.1, st.2, st.3, st.4)
  }
}
def abs_f32_inner(x: f32) -> f32 = if lt(x, zero_f()) then neg(x) else x
-- The regularised incomplete beta is evaluated in f64 and returned as f32.
-- `betai`'s front factor is `exp(lgamma(a+b) - lgamma(a) - lgamma(b)
-- + a*ln x + b*ln(1-x))`, whose exponent is a difference of large quantities:
-- at a = b = 1e5 the log-gammas are about 2.2e6, where one f32 rounding is an
-- absolute error of 0.25 in the exponent and so a multiplicative error in the
-- result. In f32 that dominated every value this family returned at large
-- parameters, independently of how many continued-fraction iterations were
-- spent. See `docs/book/src/distributions/beta-family.md`.
-- The continued fraction also needs more than 200 iterations for a large
-- min(a, b) -- first near 1.7e5, and consistently past about 4.2e5; the f32
-- count is not monotone in the parameters, so there is no single threshold and
-- a bisection for one lands wherever it starts. The budget below is 4096, spent through
-- three levels of chunking: a chunk of 16 single steps, a block of 16 chunks,
-- and a driver of 16 blocks. Peak depth is about 48 frames rather than 4096,
-- because `chelis eval --file` evaluates on a bounded stack and aborts the
-- process outright when a recursion outruns it (see the eval-lane entry in
-- `docs/UPSTREAM_BUGS.md`, which cites the upstream issue by number).
def zero_d64() -> f64 = cast(0.0, f64)
def one_d64() -> f64 = cast(1.0, f64)
def fabs64_inner(x: f64) -> f64 = if lt(x, zero_d64()) then neg(x) else x
def betacf_tol() -> f64 = cast(1e-7, f64)
def betacf_tiny() -> f64 = cast(1e-30, f64)
def betacf_fanout_i() -> i64 = cast(16, i64)
def betacf_max_m() -> i64 = cast(4096, i64)
-- One Lentz iteration of the continued fraction for the incomplete beta.
-- Returns the updated (c, d_inv, h) and whether the step met the tolerance.
def betacf_step(a: f64, b: f64, x: f64, c: f64, d: f64, h: f64, m: i64) -> (f64, f64, f64, bool) = {
  eps = betacf_tiny()
  one = one_d64()
  m_f = cast(m, f64)
  m2_f = mul(cast(2.0, f64), m_f)
  qab = add(a, b)
  qap = add(a, one)
  qam = sub(a, one)
  aa1_num = mul(m_f, mul(sub(b, m_f), x))
  aa1_den = mul(add(qam, m2_f), add(a, m2_f))
  aa1 = div(aa1_num, aa1_den)
  d1_raw = add(one, mul(aa1, d))
  d1 = if lt(fabs64_inner(d1_raw), eps) then eps else d1_raw
  c1_raw = add(one, div(aa1, c))
  c1 = if lt(fabs64_inner(c1_raw), eps) then eps else c1_raw
  d1_inv = div(one, d1)
  h1 = mul(mul(h, d1_inv), c1)
  aa2_num_neg = mul(neg(add(a, m_f)), mul(add(qab, m_f), x))
  aa2_den = mul(add(a, m2_f), add(qap, m2_f))
  aa2 = div(aa2_num_neg, aa2_den)
  d2_raw = add(one, mul(aa2, d1_inv))
  d2 = if lt(fabs64_inner(d2_raw), eps) then eps else d2_raw
  c2_raw = add(one, div(aa2, c1))
  c2 = if lt(fabs64_inner(c2_raw), eps) then eps else c2_raw
  d2_inv = div(one, d2)
  delta = mul(d2_inv, c2)
  h2 = mul(h1, delta)
  delta_err = fabs64_inner(sub(delta, one))
  converged = lt(delta_err, betacf_tol())
  (c2, d2_inv, h2, converged)
}
def betacf_chunk(a: f64, b: f64, x: f64, c: f64, d: f64, h: f64, m: i64, max_m: i64, steps: i64) -> (f64, f64, f64, i64, bool) = {
  zero_i = cast(0, i64)
  one_i = cast(1, i64)
  if or(gt(m, max_m), lte(steps, zero_i)) then (c, d, h, m, false) else {
    st = betacf_step(a, b, x, c, d, h, m)
    m_next = add(m, one_i)
    if st.3 then (st.0, st.1, st.2, m_next, true) else betacf_chunk(a, b, x, st.0, st.1, st.2, m_next, max_m, sub(steps, one_i))
  }
}
def betacf_block(a: f64, b: f64, x: f64, c: f64, d: f64, h: f64, m: i64, max_m: i64, chunks: i64) -> (f64, f64, f64, i64, bool) = {
  zero_i = cast(0, i64)
  one_i = cast(1, i64)
  if or(gt(m, max_m), lte(chunks, zero_i)) then (c, d, h, m, false) else {
    st = betacf_chunk(a, b, x, c, d, h, m, max_m, betacf_fanout_i())
    if st.4 then st else betacf_block(a, b, x, st.0, st.1, st.2, st.3, max_m, sub(chunks, one_i))
  }
}
def betacf_drive(a: f64, b: f64, x: f64, c: f64, d: f64, h: f64, m: i64, max_m: i64) -> (f64, bool) =
  if gt(m, max_m) then (h, false) else {
    st = betacf_block(a, b, x, c, d, h, m, max_m, betacf_fanout_i())
    if st.4 then (st.2, true) else betacf_drive(a, b, x, st.0, st.1, st.2, st.3, max_m)
  }
def betacf64(a: f64, b: f64, x: f64) -> (f64, bool) = {
  eps = betacf_tiny()
  one = one_d64()
  qab = add(a, b)
  qap = add(a, one)
  d0_raw = sub(one, div(mul(qab, x), qap))
  d0 = if lt(fabs64_inner(d0_raw), eps) then eps else d0_raw
  d0_inv = div(one, d0)
  betacf_drive(a, b, x, one, d0_inv, d0_inv, cast(1, i64), betacf_max_m())
}
def nan_d64() -> f64 = div(zero_d64(), zero_d64())
-- A regularised incomplete beta lies in [0, 1] by definition, so a value
-- outside that range is not an approximation of anything. Two different things
-- produce one, though, and they want opposite answers.
-- A *converged* continued fraction can still overshoot by a rounding: the front
-- factor's exponent is a difference of log-gammas whose absolute error is about
-- one ulp of the larger one, so for a small `a` with a large `b`, where the true
-- value is 1.0, the computation lands just above it. Measured up to 4.7e-7 --
-- about four f32 ulps -- at a = 1e-7, b = 1e8, with the continued fraction
-- converging in one to four iterations. That is the right answer with a
-- rounding on it, so it is clamped to the boundary rather than discarded.
-- An *abandoned* continued fraction that lands outside the range has produced
-- nothing at all: `beta_cdf(0.5, 1e12, 1e12)` reaches -0.416 that way, and that
-- becomes NaN rather than a number no caller can tell from a probability.
-- Convergence is the separator rather than a tolerance because the overshoot
-- grows with the cancellation and no fixed epsilon bounds it. An exhausted
-- budget is still not by itself a NaN: wherever its value is in range it is
-- returned, which is the conclusion the gamma family reached for the same
-- question (recorded in `docs/book/src/appendix/precision.md`). None of this
-- makes an in-range wrong answer impossible; `docs/book` states the parameter
-- range instead.
def betai_finish(v: f64, converged: bool) -> f64 = if or(lt(v, zero_d64()), gt(v, one_d64())) then if converged then if lt(v, zero_d64()) then zero_d64() else one_d64() else nan_d64() else v
-- `omx` is the caller's own value for `1 - x`, not a value recovered by
-- subtraction here. Every call site can form it exactly from its own inputs,
-- and the two that could not would otherwise lose it: `x` saturates to 1.0
-- for `student_t_cdf` once df reaches 2^24 and for `f_cdf` once d2 is small
-- beside d1*x, and the guard below would then answer 1.0 for a distribution
-- whose true value is nowhere near 1.
def betai_core(a: f64, b: f64, x: f64, omx: f64) -> f64 =
  if lte(x, zero_d64()) then zero_d64() else if lte(omx, zero_d64()) then one_d64() else {
    one = one_d64()
    lg_ab = log_gamma(add(a, b))
    lg_a = log_gamma(a)
    lg_b = log_gamma(b)
    lx = log(x)
    l1mx = log(omx)
    front_exp_arg = add(sub(sub(lg_ab, lg_a), lg_b), add(mul(a, lx), mul(b, l1mx)))
    front = exp(front_exp_arg)
    threshold_num = add(a, one)
    threshold_den = add(add(a, b), cast(2.0, f64))
    threshold = div(threshold_num, threshold_den)
    st = if lt(x, threshold) then {
      r = betacf64(a, b, x)
      (mul(front, div(r.0, a)), r.1)
    } else {
      r = betacf64(b, a, omx)
      val = mul(front, div(r.0, b))
      (sub(one, val), r.1)
    }
    betai_finish(st.0, st.1)
  }
def betai(a: f32, b: f32, x: f32) -> f32 = {
  x64 = cast(x, f64)
  betai_core(cast(a, f64), cast(b, f64), x64, sub(one_d64(), x64)) |> cast(f32)
}
def is_integer_f32(x: f32) -> bool = {
  xi = cast(cast_trunc(x, i64), f32)
  eq(x, xi)
}
def poisson_pmf(k: f32, lambda: f32) -> f32 =
  if lt(lambda, zero_f()) then nan_d() else if lt(k, zero_f()) then zero_f() else if not(is_integer_f32(k)) then zero_f() else if eq(lambda, zero_f()) then if eq(k, zero_f()) then one_f() else zero_f() else {
    lk = log(lambda)
    k_lk = mul(k, lk)
    lg_k1 = log_gamma(add(k, one_f()))
    log_pmf = sub(sub(k_lk, lambda), lg_k1)
    exp(log_pmf)
  }
def poisson_cdf(k: f32, lambda: f32) -> f32 =
  if lt(lambda, zero_f()) then nan_d() else if lt(k, zero_f()) then zero_f() else if eq(lambda, zero_f()) then one_f() else {
    k_plus_one = add(k, one_f())
    gc = gamma_cdf(lambda, k_plus_one, one_f())
    sub(one_f(), gc)
  }
def binomial_pmf(k: f32, n: f32, p: f32) -> f32 =
  if or(lt(k, zero_f()), gt(k, n)) then zero_f() else if not(is_integer_f32(k)) then zero_f() else if not(is_integer_f32(n)) then nan_d() else if or(lt(p, zero_f()), gt(p, one_f())) then nan_d() else if eq(p, zero_f()) then if eq(k, zero_f()) then one_f() else zero_f() else if eq(p, one_f()) then if eq(k, n) then one_f() else zero_f() else {
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
-- `n - k` and `k + 1` are formed in f64, not in f32 and then widened. In
-- f32 the `+ 1` vanishes for k >= 2^24 (ulp(5e7) is 4), which turned
-- `binomial_cdf(5e7, 1e8, 0.5)` into the symmetric `I(0.5; 5e7, 5e7)` --
-- exactly 0.5 -- instead of `I(0.5; 5e7, 5e7+1)` = 0.50003989, an error of
-- 8e-5 at an ordinary sample size. `n - k` loses its low bits the same way.
def binomial_cdf(k: f32, n: f32, p: f32) -> f32 =
  if or(lt(p, zero_f()), gt(p, one_f())) then nan_d() else if lt(k, zero_f()) then zero_f() else if gte(k, n) then one_f() else {
    a = sub(cast(n, f64), cast(k, f64))
    b = add(cast(k, f64), one_d64())
    p64 = cast(p, f64)
    betai_core(a, b, sub(one_d64(), p64), p64) |> cast(f32)
  }
def beta_pdf(x: f32, a: f32, b: f32) -> f32 =
  if or(lte(a, zero_f()), lte(b, zero_f())) then nan_d() else if or(lt(x, zero_f()), gt(x, one_f())) then zero_f() else if eq(x, zero_f()) then if gt(a, one_f()) then zero_f() else if eq(a, one_f()) then b else pos_inf_d() else if eq(x, one_f()) then if gt(b, one_f()) then zero_f() else if eq(b, one_f()) then a else pos_inf_d() else {
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
def nan_guard_b_const(b: f32) -> f32 = b
def beta_cdf(x: f32, a: f32, b: f32) -> f32 = if or(lte(a, zero_f()), lte(b, zero_f())) then nan_d() else betai(a, b, x)
def f_pdf(x: f32, d1: f32, d2: f32) -> f32 =
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
def f_cdf(x: f32, d1: f32, d2: f32) -> f32 =
  if lte(x, zero_f()) then zero_f() else if or(lte(d1, zero_f()), lte(d2, zero_f())) then nan_d() else {
    half = cast(0.5, f64)
    half_d1 = mul(half, cast(d1, f64))
    half_d2 = mul(half, cast(d2, f64))
    d1x = mul(cast(d1, f64), cast(x, f64))
    denom = add(d1x, cast(d2, f64))
    u = div(d1x, denom)
    omu = div(cast(d2, f64), denom)
    betai_core(half_d1, half_d2, u, omu) |> cast(f32)
  }
def weibull_pdf(x: f32, shape: f32, scale: f32) -> f32 =
  if lt(x, zero_f()) then zero_f() else if or(lte(shape, zero_f()), lte(scale, zero_f())) then nan_d() else if eq(x, zero_f()) then if gt(shape, one_f()) then zero_f() else if eq(shape, one_f()) then div(one_f(), scale) else pos_inf_d() else {
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
def weibull_cdf(x: f32, shape: f32, scale: f32) -> f32 =
  if lt(x, zero_f()) then zero_f() else if or(lte(shape, zero_f()), lte(scale, zero_f())) then nan_d() else {
    xl = div(x, scale)
    lxl = log(xl)
    xlk = exp(mul(shape, lxl))
    nxlk = neg(xlk)
    e = exp(nxlk)
    sub(one_f(), e)
  }
def weibull_inv_cdf(q: f32, shape: f32, scale: f32) -> f32 =
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
def student_t_cdf(t: f32, df: f32) -> f32 =
  if lte(df, zero_f()) then nan_d() else {
    df64 = cast(df, f64)
    half_df = mul(cast(0.5, f64), df64)
    t64 = cast(t, f64)
    t2 = mul(t64, t64)
    df_plus_t2 = add(df64, t2)
    x_arg = div(df64, df_plus_t2)
    om_x_arg = div(t2, df_plus_t2)
    bi = betai_core(half_df, cast(0.5, f64), x_arg, om_x_arg) |> cast(f32)
    half_bi = mul(half_f(), bi)
    if gte(t, zero_f()) then sub(one_f(), half_bi) else half_bi
  }
def gammaq(a: f32, x: f32) -> f32 =
  if lte(x, zero_f()) then one_f() else {
    la = log_gamma(a)
    lx = log(x)
    a_lx = mul(a, lx)
    front_exp_arg = sub(sub(a_lx, x), la)
    front = exp(front_exp_arg)
    b0 = add(sub(x, a), one_f())
    tiny = cast(1e-30, f32)
    c0 = div(one_f(), tiny)
    d0 = div(one_f(), b0)
    h0 = d0
    h = gammaq_cf_rec(a, b0, c0, d0, h0, cast(200, i64))
    mul(front, h)
  }
-- A non-positive `shape` or `scale` is not a distribution, and a non-finite
-- `x` is a limit rather than a point to integrate to, so both are decided
-- before the standardised argument `xs` reaches either recursion.
-- These are the guards `gamma_pdf`, `gamma_inv_cdf` and `weibull_cdf` already
-- use, and they agree with SciPy. The guards read `xs`, not `x`, so a finite
-- `x` whose `x / scale` overflows lands on the same answer as `x = +inf`.
def gamma_cdf(x: f32, shape: f32, scale: f32) -> f32 =
  if or(lte(shape, zero_f()), lte(scale, zero_f())) then nan_d() else {
    xs = div(x, scale)
    if neq(xs, xs) then nan_d() else if lte(xs, zero_f()) then zero_f() else if eq(xs, pos_inf_d()) then one_f() else if lt(xs, add(shape, one_f())) then gammap(shape, xs) else sub(one_f(), gammaq(shape, xs))
  }
def gamma_sf(x: f32, shape: f32, scale: f32) -> f32 =
  if or(lte(shape, zero_f()), lte(scale, zero_f())) then nan_d() else {
    xs = div(x, scale)
    if neq(xs, xs) then nan_d() else if lte(xs, zero_f()) then one_f() else if eq(xs, pos_inf_d()) then zero_f() else if lt(xs, add(shape, one_f())) then sub(one_f(), gammap(shape, xs)) else gammaq(shape, xs)
  }
def chi_squared_cdf(x: f32, df: f32) -> f32 = {
  half_df = mul(half_f(), df)
  gamma_cdf(x, half_df, two_f())
}
def chi_squared_sf(x: f32, df: f32) -> f32 = {
  half_df = mul(half_f(), df)
  gamma_sf(x, half_df, two_f())
}
def gamma_inv_cdf_newton(target: f32, shape: f32, scale: f32, x: f32, iters: i64) -> f32 = {
  zero_i = cast(0, i64)
  one_i = cast(1, i64)
  if lte(iters, zero_i) then x else {
    cur = gamma_cdf(x, shape, scale)
    resid = sub(cur, target)
    pdf_v = gamma_pdf(x, shape, scale)
    floor_pdf = cast(1e-30, f32)
    pdf_safe = if lt(pdf_v, floor_pdf) then floor_pdf else pdf_v
    step = div(resid, pdf_safe)
    x_next_raw = sub(x, step)
    x_next = if lte(x_next_raw, zero_f()) then mul(half_f(), x) else x_next_raw
    gamma_inv_cdf_newton(target, shape, scale, x_next, sub(iters, one_i))
  }
}
def gamma_inv_cdf(q: f32, shape: f32, scale: f32) -> f32 =
  if or(lt(q, zero_f()), gt(q, one_f())) then nan_d() else if lte(q, zero_f()) then zero_f() else if gte(q, one_f()) then pos_inf_d() else {
    z = normal_inv_cdf(q, zero_f(), one_f())
    inv_9k = div(one_f(), mul(cast(9.0, f32), shape))
    third = cast(0.3333333333, f32)
    sqrt_inv_9k = sqrt(inv_9k)
    a = sub(one_f(), inv_9k)
    b = mul(z, sqrt_inv_9k)
    s = add(a, b)
    s_cubed = mul(s, mul(s, s))
    wh_safe = if gt(s_cubed, cast(1e-30, f32)) then s_cubed else cast(1e-30, f32)
    x0 = mul(shape, mul(scale, wh_safe))
    gamma_inv_cdf_newton(q, shape, scale, x0, cast(80, i64))
  }
def chi_squared_inv_cdf(q: f32, df: f32) -> f32 = {
  half_df = mul(half_f(), df)
  gamma_inv_cdf(q, half_df, two_f())
}
-- Each mapped element owns one key; its 64 candidates use separate child keys.
-- NaN marks a rejected candidate for first-accept selection below.
def gamma_candidate(k: key, d: f32, c: f32, scale: f32) -> f32 = {
  ks = split_key(k)
  normal_keys = split_key(ks.0)
  u1 = tensor_to_scalar(uniform_like(normal_keys.0, scalar_to_tensor(0.0f32), 1e-7f32, 1.0f32))
  u2 = tensor_to_scalar(uniform_like(normal_keys.1, scalar_to_tensor(0.0f32), 0.0f32, 1.0f32))
  u = tensor_to_scalar(uniform_like(ks.1, scalar_to_tensor(0.0f32), 1e-7f32, 1.0f32))
  radius = sqrt(neg(mul(2.0f32, log(u1))))
  angle = sub(1.5707964f32, mul(6.2831855f32, u2))
  z = mul(radius, sin(angle))
  v_base = add(1.0f32, mul(c, z))
  v = mul(mul(v_base, v_base), v_base)
  valid = gt(v_base, 0.0f32)
  v_safe = if valid then v else 1.0f32
  z2 = mul(z, z)
  z4 = mul(z2, z2)
  fast = lt(u, sub(1.0f32, mul(0.0331f32, z4)))
  slow = lt(log(u), add(mul(0.5f32, z2), mul(d, add(sub(1.0f32, v_safe), log(v_safe)))))
  if and(valid, or(fast, slow)) then mul(mul(d, v_safe), scale) else div(0.0f32, 0.0f32)
}
def gamma_candidates(k: key, d: f32, c: f32, scale: f32) -> tensor[64, f32] = vmap(gamma_candidate)(split_keys(k, 64i64), d, c, scale)
def gamma_first_accepted[n](values: tensor[n, 64, f32]) -> tensor[n, f32] = {
  accepted = eq(values, values)
  accepted_i = cast(accepted, i64)
  first = and(accepted, eq(cumsum(accepted_i, 1i32), accepted_i))
  zero_matrix = sub(cast(accepted, f32), cast(accepted, f32))
  selected = sum(where(first, values, zero_matrix), 1i32)
  accepted_count = count(accepted, 1i32)
  zero_vector = sub(accepted_count, accepted_count)
  has_value = gt(accepted_count, zero_vector)
  nan_vector = div(cast(zero_vector, f32), cast(zero_vector, f32))
  where(has_value, selected, nan_vector)
}
def gamma_sample[n](k: key, template: tensor[n, f32], shape: f32, scale: f32) -> tensor[n, f32] = {
  d = sub(shape, 0.3333333333f32)
  c = div(0.3333333333f32, sqrt(d))
  -- Keep split_keys inline: its key axis is consumed directly by vmap.
  values = vmap(gamma_candidates)(split_keys(k, numel(template)), d, c, scale)
  gamma_first_accepted(values)
}
def chi_squared_sample[n](k: key, template: tensor[n, f32], df: f32) -> tensor[n, f32] = {
  half_df = mul(half_f(), df)
  gamma_sample(k, template, half_df, two_f())
}
def student_t_sample[n](k: key, template: tensor[n, f32], df: f32) -> tensor[n, f32] = {
  ks = split_key(k)
  z = normal_sample(ks.0, copy(template), zero_f(), one_f())
  v = chi_squared_sample(ks.1, template, df)
  to_tensor(map(fn (pair: (f32, f32)) -> {
    zi = pair.0
    vi = pair.1
    ratio = div(vi, df)
    s = sqrt(ratio)
    div(zi, s)
  }, zip(to_list(z), to_list(v))))
}
-- Tensor-domain normal family (nautilus PR 45).
--
-- The scalar `normal_cdf` / `normal_inv_cdf` / `normal_pdf` above are the
-- reference; these evaluate the same formulas at tensor rank. A Monte Carlo or
-- option-pricing caller holding a tensor of paths can reach Phi and Phi-inverse
-- without dropping to `List` and back, which the `*_sample` functions still do.
def dist_lift_t[n](template: &tensor[n, f32], c: f32) -> tensor[n, f32] = insert(scalar_to_tensor(c), 0, shape(template, cast(0, i32)))
-- [05-OP-48] admits a tensor operand and preserves its shape and dtype, so the
-- tensor lane delegates to the same builtin as the scalar reference above.
def normal_cdf_t[n](x: &tensor[n, f32], mean: f32, std: f32) -> tensor[n, f32] = {
  means = dist_lift_t(x, mean)
  stds = dist_lift_t(x, std)
  standard_normal_cdf(div(sub(x, means), stds))
}
def normal_pdf_t[n](x: &tensor[n, f32], mean: f32, std: f32) -> tensor[n, f32] = {
  means = dist_lift_t(x, mean)
  stds = dist_lift_t(x, std)
  halves = dist_lift_t(x, half_f())
  denoms = dist_lift_t(x, mul(std, sqrt_2pi_f()))
  z = div(sub(x, means), stds)
  div(exp(neg(mul(halves, mul(z, z)))), denoms)
}
def normal_inv_cdf_t[n](q: &tensor[n, f32], mean: f32, std: f32) -> tensor[n, f32] = {
  zeros = dist_lift_t(q, zero_f())
  ones = dist_lift_t(q, one_f())
  twos = dist_lift_t(q, two_f())
  means = dist_lift_t(q, mean)
  stds = dist_lift_t(q, std)
  sqrt_twos = dist_lift_t(q, sqrt_two_f())
  nans = dist_lift_t(q, nan_d())
  pinfs = dist_lift_t(q, pos_inf_d())
  ninfs = dist_lift_t(q, neg(pos_inf_d()))
  -- The interior value is computed for every lane; `where` then reinstates the
  -- scalar guards in the same order `normal_inv_cdf` applies them, so the two
  -- agree on the boundary cases as well as the interior.
  interior = add(means, mul(stds, mul(sqrt_twos, erfinv_t(sub(mul(twos, q), ones)))))
  with_high = where(gte(q, ones), pinfs, interior)
  with_low = where(lte(q, zeros), ninfs, with_high)
  out_of_range = or(lt(q, zeros), gt(q, ones))
  where(out_of_range, nans, with_low)
}
