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
-- `1 - exp(-t)` carries absolute error of about `0.5 * ulp(1)` however
-- accurate `exp` is, so it returns exactly `0.0` once the true value falls
-- below that. `exponential_cdf` and `weibull_cdf` are the two CDFs whose own
-- small value sits there, so no survival function can help them the way
-- `gamma_sf` helps a right tail: the quantity asked for IS the one that
-- cancels. `expm1_neg_d` is the negated `expm1`, `-expm1(-t)`, and it gives
-- `1 - exp(-t)` a relative error contract by summing the Maclaurin series
-- where the subtraction would cancel and performing the subtraction where it
-- would not.
--
-- Evaluating in f64 and returning f32 is not sufficient on its own. It moves
-- the collapse rather than removing it: the absolute error becomes about
-- `0.5 * ulp_f64(1)`, so `1.1e-16 / t` is the envelope on the relative
-- error, which degrades without bound as `t` shrinks and reaches exactly
-- `0.0` a little below `t = 1e-16`. `weibull_cdf(1e-8, 2, 1)` reaches
-- `t = 1e-16` from ordinary arguments. The series has no such floor. Three
-- tests pin points on that ladder, and the f64-only form fails all three;
-- the figures are in those tests rather than here, so there is one place to
-- correct if the lane's `exp` ever changes its last bit.
--
-- The cut is `1/16`. Below it the sum keeps terms through `t^10/10!`, so the
-- first omitted term is `t^11/11!`, which at the cut is `2.3e-20` of the
-- result; the nested factors are all near `1` and each deeper rounding is
-- damped by its own `t/j`, so the series stands at about one f64 ulp. At and
-- above the cut `exp(-t) <= 0.9394`, so the subtraction amplifies f64
-- rounding by at most `0.9394/0.0606 = 15.5`, giving about `1.7e-15`. Both
-- branches are therefore far inside the half f32 ulp the return rounds to.
--
-- The term count is set by that derivation and not by the smallest count an
-- f32 return happens to accept. Four terms put the truncation at about
-- `1.3e-7` of the result at the cut, which is two f32 ulps there, so a
-- four-term form returns a different f32 and a test does reject it. Five
-- terms and ten are indistinguishable at every argument in the accuracy
-- grid; they part only at arguments whose exact answer sits within a percent
-- or so of an f32 midpoint, where the five-term value is still within about
-- half an ulp, so a test built on one would be a near-tie rather than a
-- contract. Ten is what keeps `expm1_neg_d` correct as an f64 function, so a
-- later f64 caller inherits a bound rather than a coincidence.
--
-- The series window is `[0, 1/16)` and not `(-inf, 1/16)` on purpose. A
-- negative `t` is not a distribution, but `exponential_cdf` admits one for a
-- negative rate and nothing here decides that case; sending it to the
-- subtraction keeps it on the expression it has always been on.
def expm1_cut() -> f64 = cast(0.0625, f64)
def expm1_terms() -> i64 = cast(10, i64)
def expm1_horner(t: f64, j: i64, m: i64) -> f64 =
  if gt(j, m) then one_d64() else {
    inner = expm1_horner(t, add(j, cast(1, i64)), m)
    sub(one_d64(), div(mul(t, inner), cast(j, f64)))
  }
def expm1_neg_d(t: f64) -> f64 = if and(gte(t, zero_d64()), lt(t, expm1_cut())) then mul(t, expm1_horner(t, cast(2, i64), expm1_terms())) else sub(one_d64(), exp(neg(t)))
-- `rate * x` is formed in f64 from the widened f32 arguments, so the product
-- is exact: two 24-bit significands multiply inside f64's 53. Forming it in
-- f32 first costs at most half an f32 ulp of `t`, which for a small `t`
-- transfers whole to the answer, so what this buys is bounded by about one
-- ulp of the return rather than by a decade of it.
def exponential_cdf(x: f32, rate: f32) -> f32 =
  if lt(x, zero_f()) then zero_f() else {
    t = mul(cast(rate, f64), cast(x, f64))
    expm1_neg_d(t) |> cast(f32)
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
-- Chelis standard_normal_cdf uses an erfc-based graph with a correction for
-- rounding -x/sqrt(2), preserving the negative tail without subtracting erf
-- from 1. Standardization still rounds in the caller's f32 precision.
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
-- The log-space density uses f64 to limit cancellation between
-- `(shape - 1)*log(x)`, `x/scale`, and `log_gamma(shape)`, and returns f32.
-- The quantile uses `gammainc_front` in log coordinates instead of a density
-- quotient, so this density calculation does not set its Newton derivative.
def gamma_pdf_core(x: f64, shape: f64, scale: f64) -> f64 = {
  lx = log(x)
  lscale = log(scale)
  k_minus_one = sub(shape, one_d64())
  term1 = mul(k_minus_one, lx)
  term2 = mul(shape, lscale)
  xs = div(x, scale)
  lgk = log_gamma(shape)
  log_pdf = sub(sub(sub(term1, xs), term2), lgk)
  exp(log_pdf)
}
def gamma_pdf(x: f32, shape: f32, scale: f32) -> f32 = if lt(x, zero_f()) then zero_f() else if eq(x, zero_f()) then if gt(shape, one_f()) then zero_f() else if eq(shape, one_f()) then div(one_f(), scale) else pos_inf_d() else cast(gamma_pdf_core(cast(x, f64), cast(shape, f64), cast(scale, f64)), f32)
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
-- The regularised incomplete gamma is evaluated in f64 and returned as f32.
-- The series and continued fraction share a front factor,
-- `exp(a*log(x) - x - log_gamma(a))`,
-- whose exponent is a difference of large quantities that very nearly cancel.
-- At `a = x = 1e5` the three terms are each about 1.1e6 and the exponent they
-- leave is 4.84, where one f32 rounding of the largest is 0.125. An absolute
-- error in an exponent is a multiplicative error in the result, so in f32 that
-- single rounding dominated everything this family returned at a large shape,
-- whatever number of series or continued-fraction terms was spent:
-- `gamma_sf(1e5, 1e5, 1)` returned 0.753 against a true 0.4996, and
-- `gamma_pdf(5e7, 5e7, 1)` returned 1.0 against a true 5.64e-5. This is the
-- same defect one function family over that `betai` had below; see the comment
-- there and `docs/book/src/distributions/beta-family.md`.
--
-- For those routes, f64 moves that cliff rather than removing it. The floor
-- is one f64 ulp of
-- `log_gamma(a)`, which is quantised and so steps at binade boundaries rather
-- than growing smoothly: 2.3e-10 at `a = 1e5`, 3.0e-8 at 1e7, 1.19e-7 at 5e7
-- and 4.8e-7 at 2e8. That crosses f32's own resolution -- one f32 ulp is about
-- 1.2e-7 relative -- at about `a = 3.3e7`, so below that shape the return type
-- hides it entirely.
-- `gamma_pdf` is the clean probe for that floor, being one log-space
-- expression with no iteration budget to confound it. At the single argument
-- `x = a`: 7.2e-8 at 1e5, 1.5e-7 at 5e7, 3.4e-6 at 1e9, 2.1e-5 at 1e10 and
-- 1.5e-4 at 1e11, which is 1248 times one f32 ulp. That settles that the error
-- grows, since the return type's own rounding is constant in `a`.
-- It does not bound it, and the two must not be confused: at `a = 2e8` that
-- same single argument gives 1.1e-8 because two roundings cancelled, while the
-- worst over a neighbourhood of 2e8 is 3.5e-7, thirty times larger at the
-- same shape. The envelope is estimated from neighbourhood worst cases, which
-- sit at 1.2x and 0.7x of `ulp64(log_gamma(a))`; that is why the accuracy gate
-- walks a neighbourhood rather than evaluating a point.
-- `docs/book/src/appendix/precision.md` states the measured set this bounds
-- and `parity/check_gamma_accuracy.py` is its gate.
--
-- Outside the bounded asymptotic window below, both budgets are far larger
-- than the f32 lane's 200, because f32 could not
-- have spent more usefully and f64 can. Measured iteration counts at the
-- branch point `x = a`, where both routes are slowest. Measured with the
-- constants below: the series needs 2197 terms at `a = 1e5` and 45662 at
-- `a = 5e7`, which is about `6.5*sqrt(a)`; the continued fraction needs 380
-- and 3021, which is about `0.43*sqrt(a)` at the upper end and 1.2 times that
-- at the lower one. Neither pair is a law -- 380/sqrt(1e5) is 1.20 while
-- 3021/sqrt(5e7) is 0.427 -- so the square-root form is a scaling for sizing
-- the budget and not a formula to predict a count from. The budget is 65536,
-- which carries the series to about `a = 9e7`. It is spent through four levels
-- of 16-way chunking, so peak recursion depth is about 64 frames rather than
-- 65536: `chelis eval --file` evaluates on a bounded stack and aborts the
-- process outright when a recursion outruns it (see the eval-lane entry in
-- `docs/UPSTREAM_BUGS.md`, which cites the upstream issue by number).
--
-- The series tolerance is relative to the running sum. Near the branch point,
-- the uncomputed tail is about sqrt(a) times its last term; size the tolerance
-- for that amplification. Keep series and continued-fraction tolerances
-- separate so each convergence criterion can be calibrated independently.
def gammainc_series_tol() -> f64 = cast(1e-13, f64)
def gammainc_cf_tol() -> f64 = cast(1e-13, f64)
def gammainc_tiny() -> f64 = cast(1e-300, f64)
def gammainc_fanout_i() -> i64 = cast(16, i64)
def gammainc_max_i() -> i64 = cast(65536, i64)
def gammainc_front(a: f64, x: f64) -> f64 = exp(sub(sub(mul(a, log(x)), x), log_gamma(a)))
-- One term of the series for the lower regularised incomplete gamma, carrying
-- the running (term, sum, denominator) and whether the step met the tolerance.
def gammainc_series_chunk(x: f64, term: f64, acc: f64, ap: f64, i: i64, max_i: i64, steps: i64) -> (f64, f64, f64, i64, bool) = {
  zero_i = cast(0, i64)
  one_i = cast(1, i64)
  if or(gt(i, max_i), lte(steps, zero_i)) then (term, acc, ap, i, false) else {
    ap_next = add(ap, one_d64())
    term_next = mul(term, div(x, ap_next))
    acc_next = add(acc, term_next)
    i_next = add(i, one_i)
    converged = lt(fabs64_inner(term_next), mul(gammainc_series_tol(), fabs64_inner(acc_next)))
    if converged then (term_next, acc_next, ap_next, i_next, true) else gammainc_series_chunk(x, term_next, acc_next, ap_next, i_next, max_i, sub(steps, one_i))
  }
}
def gammainc_series_block(x: f64, term: f64, acc: f64, ap: f64, i: i64, max_i: i64, chunks: i64) -> (f64, f64, f64, i64, bool) = {
  zero_i = cast(0, i64)
  one_i = cast(1, i64)
  if or(gt(i, max_i), lte(chunks, zero_i)) then (term, acc, ap, i, false) else {
    st = gammainc_series_chunk(x, term, acc, ap, i, max_i, gammainc_fanout_i())
    if st.4 then st else gammainc_series_block(x, st.0, st.1, st.2, st.3, max_i, sub(chunks, one_i))
  }
}
def gammainc_series_super(x: f64, term: f64, acc: f64, ap: f64, i: i64, max_i: i64, blocks: i64) -> (f64, f64, f64, i64, bool) = {
  zero_i = cast(0, i64)
  one_i = cast(1, i64)
  if or(gt(i, max_i), lte(blocks, zero_i)) then (term, acc, ap, i, false) else {
    st = gammainc_series_block(x, term, acc, ap, i, max_i, gammainc_fanout_i())
    if st.4 then st else gammainc_series_super(x, st.0, st.1, st.2, st.3, max_i, sub(blocks, one_i))
  }
}
def gammainc_series_drive(x: f64, term: f64, acc: f64, ap: f64, i: i64, max_i: i64) -> f64 =
  if gt(i, max_i) then acc else {
    st = gammainc_series_super(x, term, acc, ap, i, max_i, gammainc_fanout_i())
    if st.4 then st.1 else gammainc_series_drive(x, st.0, st.1, st.2, st.3, max_i)
  }
-- One modified-Lentz step of the continued fraction for the upper regularised
-- incomplete gamma. `i` counts up here where the f32 lane counted a budget
-- down and recovered the forward index as `201 - i`; the arithmetic is the
-- same sequence.
def gammaq_cf_chunk(a: f64, b: f64, c: f64, d: f64, h: f64, i: i64, max_i: i64, steps: i64) -> (f64, f64, f64, f64, i64, bool) = {
  zero_i = cast(0, i64)
  one_i = cast(1, i64)
  if or(gt(i, max_i), lte(steps, zero_i)) then (b, c, d, h, i, false) else {
    eps = gammainc_tiny()
    j = cast(i, f64)
    an = mul(neg(j), sub(j, a))
    b_next = add(b, cast(2.0, f64))
    d_raw = add(mul(an, d), b_next)
    d_guard = if lt(fabs64_inner(d_raw), eps) then eps else d_raw
    c_raw = add(b_next, div(an, c))
    c_guard = if lt(fabs64_inner(c_raw), eps) then eps else c_raw
    d_inv = div(one_d64(), d_guard)
    delta = mul(c_guard, d_inv)
    h_next = mul(h, delta)
    i_next = add(i, one_i)
    converged = lt(fabs64_inner(sub(delta, one_d64())), gammainc_cf_tol())
    if converged then (b_next, c_guard, d_inv, h_next, i_next, true) else gammaq_cf_chunk(a, b_next, c_guard, d_inv, h_next, i_next, max_i, sub(steps, one_i))
  }
}
def gammaq_cf_block(a: f64, b: f64, c: f64, d: f64, h: f64, i: i64, max_i: i64, chunks: i64) -> (f64, f64, f64, f64, i64, bool) = {
  zero_i = cast(0, i64)
  one_i = cast(1, i64)
  if or(gt(i, max_i), lte(chunks, zero_i)) then (b, c, d, h, i, false) else {
    st = gammaq_cf_chunk(a, b, c, d, h, i, max_i, gammainc_fanout_i())
    if st.5 then st else gammaq_cf_block(a, st.0, st.1, st.2, st.3, st.4, max_i, sub(chunks, one_i))
  }
}
def gammaq_cf_super(a: f64, b: f64, c: f64, d: f64, h: f64, i: i64, max_i: i64, blocks: i64) -> (f64, f64, f64, f64, i64, bool) = {
  zero_i = cast(0, i64)
  one_i = cast(1, i64)
  if or(gt(i, max_i), lte(blocks, zero_i)) then (b, c, d, h, i, false) else {
    st = gammaq_cf_block(a, b, c, d, h, i, max_i, gammainc_fanout_i())
    if st.5 then st else gammaq_cf_super(a, st.0, st.1, st.2, st.3, st.4, max_i, sub(blocks, one_i))
  }
}
def gammaq_cf_drive(a: f64, b: f64, c: f64, d: f64, h: f64, i: i64, max_i: i64) -> f64 =
  if gt(i, max_i) then h else {
    st = gammaq_cf_super(a, b, c, d, h, i, max_i, gammainc_fanout_i())
    if st.5 then st.3 else gammaq_cf_drive(a, st.0, st.1, st.2, st.3, st.4, max_i)
  }
-- Handle non-finite x before recursion: NaN cannot satisfy either relative
-- convergence test, and +inf and non-positive x have direct limiting answers.
-- Form the front factor first and return a NaN factor before spending the
-- 65536-step budget. A NaN shape follows log_gamma's error behavior.
def gammap_core(a: f64, x: f64) -> f64 =
  if neq(x, x) then nan_d64() else if eq(x, div(one_d64(), zero_d64())) then one_d64() else if lte(x, zero_d64()) then zero_d64() else {
    front = gammainc_front(a, x)
    inv_a = div(one_d64(), a)
    if neq(front, front) then front else mul(front, gammainc_series_drive(x, inv_a, inv_a, a, cast(1, i64), gammainc_max_i()))
  }
-- `b0` is `x - a + 1`, which is at least 1 on the route that reaches this
-- function, since the callers send the continued fraction only `x >= a + 1`.
-- The guard is there because this is an f64 entry point and nothing in its own
-- signature says so.
def gammaq_core(a: f64, x: f64) -> f64 =
  if neq(x, x) then nan_d64() else if eq(x, div(one_d64(), zero_d64())) then zero_d64() else if lte(x, zero_d64()) then one_d64() else {
    eps = gammainc_tiny()
    front = gammainc_front(a, x)
    b0_raw = add(sub(x, a), one_d64())
    b0 = if lt(fabs64_inner(b0_raw), eps) then eps else b0_raw
    c0 = div(one_d64(), eps)
    d0 = div(one_d64(), b0)
    if neq(front, front) then front else mul(front, gammaq_cf_drive(a, b0, c0, d0, d0, cast(1, i64), gammainc_max_i()))
  }
-- `x < a + 1` is the series' domain and the rest is the continued fraction's.
-- Each route computes the tail it owns and the other is its complement, so the
-- Outside the large-parameter window, a small `P` is reached through the
-- series directly and a small `Q` through the continued fraction. Within the
-- window, both tails exceed the f64 cancellation floor.
-- DLMF 8.12's uniform large-parameter form avoids tens of thousands of
-- series terms near x = a. The five-standard-deviation window keeps both
-- complementary tails large enough for f64 subtraction.
def gammainc_asymptotic_window(a: f64, x: f64) -> bool = and(gte(a, cast(100000.0, f64)), lte(fabs64_inner(sub(x, a)), mul(cast(5.0, f64), sqrt(a))))
def gammainc_asymptotic_eta(mu: f64) -> f64 =
  if lt(fabs64_inner(mu), cast(0.0001, f64)) then {
    mu2 = mul(mu, mu)
    mul(mu, add(sub(one_d64(), div(mu, cast(3.0, f64))), mul(div(cast(7.0, f64), cast(36.0, f64)), mu2)))
  } else {
    radius = sqrt(mul(cast(2.0, f64), sub(mu, log(add(one_d64(), mu)))))
    if lt(mu, zero_d64()) then neg(radius) else radius
  }
def gammainc_asymptotic_c0(mu: f64, eta: f64) -> f64 = if lt(fabs64_inner(mu), cast(0.0001, f64)) then add(neg(div(one_d64(), cast(3.0, f64))), div(mu, cast(12.0, f64))) else sub(div(one_d64(), mu), div(one_d64(), eta))
def gammainc_asymptotic_q(a: f64, x: f64) -> f64 = {
  mu = div(sub(x, a), a)
  eta = gammainc_asymptotic_eta(mu)
  root_a = sqrt(a)
  z = mul(eta, root_a)
  correction = div(mul(exp(neg(mul(cast(0.5, f64), mul(z, z)))), gammainc_asymptotic_c0(mu, eta)), mul(sqrt_2pi_d64(), root_a))
  add(standard_normal_cdf(neg(z)), correction)
}
def gammainc_p(a: f64, x: f64) -> f64 = if gammainc_asymptotic_window(a, x) then sub(one_d64(), gammainc_asymptotic_q(a, x)) else if lt(x, add(a, one_d64())) then gammap_core(a, x) else sub(one_d64(), gammaq_core(a, x))
def gammainc_q(a: f64, x: f64) -> f64 = if gammainc_asymptotic_window(a, x) then gammainc_asymptotic_q(a, x) else if lt(x, add(a, one_d64())) then sub(one_d64(), gammap_core(a, x)) else gammaq_core(a, x)
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
-- a bisection for one lands wherever it starts. Chelis 0.19.2 lets this
-- 4096-step tail recursion run without the former process-aborting evaluator
-- overflow. The arithmetic order, convergence test, and iteration budget stay
-- the same as the chunked form.
def zero_d64() -> f64 = cast(0.0, f64)
def one_d64() -> f64 = cast(1.0, f64)
def fabs64_inner(x: f64) -> f64 = if lt(x, zero_d64()) then neg(x) else x
def betacf_tol() -> f64 = cast(1e-7, f64)
def betacf_tiny() -> f64 = cast(1e-30, f64)
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
def betacf_rec(a: f64, b: f64, x: f64, c: f64, d: f64, h: f64, m: i64, max_m: i64) -> (f64, bool) = {
  one_i = cast(1, i64)
  if gt(m, max_m) then (h, false) else {
    st = betacf_step(a, b, x, c, d, h, m)
    m_next = add(m, one_i)
    if st.3 then (st.2, true) else betacf_rec(a, b, x, st.0, st.1, st.2, m_next, max_m)
  }
}
def betacf64(a: f64, b: f64, x: f64) -> (f64, bool) = {
  eps = betacf_tiny()
  one = one_d64()
  qab = add(a, b)
  qap = add(a, one)
  d0_raw = sub(one, div(mul(qab, x), qap))
  d0 = if lt(fabs64_inner(d0_raw), eps) then eps else d0_raw
  d0_inv = div(one, d0)
  betacf_rec(a, b, x, one, d0_inv, d0_inv, cast(1, i64), betacf_max_m())
}
def nan_d64() -> f64 = div(zero_d64(), zero_d64())
def sqrt_2pi_d64() -> f64 = cast(2.5066282746310002, f64)
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
-- and the one that could not would otherwise lose it: `x` saturates to 1.0 for
-- `f_cdf` once d2 is small beside d1*x, and the guard below would then answer
-- 1.0 for a distribution whose true value is nowhere near 1. `student_t_cdf`
-- uses the normal expansion above `student_t_normal_df`; below it, its `omx`
-- is still exact rather than subtracted, because the two arguments share one
-- denominator and there is no reason to spend the digits.
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
-- Form the log-space PMF in f64, including k + 1 in log_gamma(k + 1),
-- then round once to f32. The log-factorial grows with k, so rounding in
-- the exponent limits the final relative accuracy.
def poisson_pmf(k: f32, lambda: f32) -> f32 =
  if lt(lambda, zero_f()) then nan_d() else if lt(k, zero_f()) then zero_f() else if not(is_integer_f32(k)) then zero_f() else if eq(lambda, zero_f()) then if eq(k, zero_f()) then one_f() else zero_f() else {
    k64 = cast(k, f64)
    lambda64 = cast(lambda, f64)
    lk = log(lambda64)
    k_lk = mul(k64, lk)
    lg_k1 = log_gamma(add(k64, one_d64()))
    log_pmf = sub(sub(k_lk, lambda64), lg_k1)
    exp(log_pmf) |> cast(f32)
  }
-- P(X <= k) = Q(k+1, lambda), the upper regularized incomplete gamma.
-- Evaluate it directly to avoid subtracting a CDF near 1 from 1.
-- Form k + 1 in f64: f32 cannot preserve that increment above 2^24.
def poisson_cdf(k: f32, lambda: f32) -> f32 =
  if lt(lambda, zero_f()) then nan_d() else if lt(k, zero_f()) then zero_f() else if eq(lambda, zero_f()) then one_f() else if neq(lambda, lambda) then nan_d() else if eq(lambda, pos_inf_d()) then zero_f() else {
    k_plus_one = add(cast(k, f64), one_d64())
    cast(gammainc_q(k_plus_one, cast(lambda, f64)), f32)
  }
-- Compute the log-binomial coefficient and log-probability in f64, then
-- return f32. Cancellation between three large log-factorials sets a
-- parameter-dependent accuracy limit; see the public precision guide.
def binomial_pmf(k: f32, n: f32, p: f32) -> f32 =
  if or(lt(k, zero_f()), gt(k, n)) then zero_f() else if not(is_integer_f32(k)) then zero_f() else if not(is_integer_f32(n)) then nan_d() else if or(lt(p, zero_f()), gt(p, one_f())) then nan_d() else if eq(p, zero_f()) then if eq(k, zero_f()) then one_f() else zero_f() else if eq(p, one_f()) then if eq(k, n) then one_f() else zero_f() else {
    k64 = cast(k, f64)
    n64 = cast(n, f64)
    p64 = cast(p, f64)
    n_minus_k = sub(n64, k64)
    lg_n1 = log_gamma(add(n64, one_d64()))
    lg_k1 = log_gamma(add(k64, one_d64()))
    lg_nmk1 = log_gamma(add(n_minus_k, one_d64()))
    log_choose = sub(sub(lg_n1, lg_k1), lg_nmk1)
    lp = log(p64)
    l1mp = log(sub(one_d64(), p64))
    k_lp = mul(k64, lp)
    nmk_l1mp = mul(n_minus_k, l1mp)
    log_pmf = add(add(log_choose, k_lp), nmk_l1mp)
    exp(log_pmf) |> cast(f32)
  }
-- Form n - k and k + 1 in f64 before the incomplete beta call so the
-- increment remains distinct when the f32 count spacing exceeds 1.
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
-- `(x/scale)^shape` is formed in f64 as well as complemented there. The f32
-- round trip through `exp(shape * log(x/scale))` carries relative error of
-- half an f32 ulp of `log(x/scale)`, amplified by `exp`, which is `1.1e-6` at
-- `x/scale = 1e-8` even for `shape = 1`, so an exact complement of an f32 `t`
-- would still have lost the sixth digit before `expm1_neg_d` saw it.
def weibull_cdf(x: f32, shape: f32, scale: f32) -> f32 =
  if lt(x, zero_f()) then zero_f() else if or(lte(shape, zero_f()), lte(scale, zero_f())) then nan_d() else {
    xl = div(cast(x, f64), cast(scale, f64))
    t = exp(mul(cast(shape, f64), log(xl)))
    expm1_neg_d(t) |> cast(f32)
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
-- For large df, use Phi(t) - phi(t)*(t^3+t)/(4*df). Keeping the 1/df
-- correction preserves tail accuracy near the handover; the expansion's
-- omitted term is O(df^-2). The incomplete-beta formula below the threshold
-- has cancellation in its log-gamma normalization that grows with df.
-- The threshold and accuracy measurements are documented in the precision
-- guide; neither approximation has a uniform relative-error bound in t.
-- Restrict the correction to t*t < 1600: beyond it the f64 density is zero,
-- and forming zero times an infinite polynomial would produce NaN.
def student_t_normal_df() -> f32 = cast(10000000.0, f32)
def student_t_normal_limit(t: f32, df: f32) -> f32 = {
  t64 = cast(t, f64)
  t2 = mul(t64, t64)
  phi = div(exp(mul(cast(-0.5, f64), t2)), sqrt_2pi_d64())
  cubic = add(mul(t64, t2), t64)
  scaled = div(cubic, mul(cast(4.0, f64), cast(df, f64)))
  corr = if lt(t2, cast(1600.0, f64)) then mul(phi, scaled) else zero_d64()
  sub(standard_normal_cdf(t64), corr) |> cast(f32)
}
def student_t_cdf(t: f32, df: f32) -> f32 =
  if lte(df, zero_f()) then nan_d() else if gte(df, student_t_normal_df()) then student_t_normal_limit(t, df) else {
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
-- Reject non-positive shape or scale here. Form x/scale in f64 and let the
-- incomplete-gamma cores handle its NaN, +inf, and non-positive cases there.
-- A finite f32 quotient can underflow before the lower-tail CDF does:
-- gamma_cdf(1e-30, 0.5, 1e20) is about 1.128379e-25. Any quotient of finite
-- nonzero f32 values fits in f64, so the wider division preserves that tail.
def gamma_cdf(x: f32, shape: f32, scale: f32) -> f32 = if or(lte(shape, zero_f()), lte(scale, zero_f())) then nan_d() else cast(gammainc_p(cast(shape, f64), div(cast(x, f64), cast(scale, f64))), f32)
def gamma_sf(x: f32, shape: f32, scale: f32) -> f32 = if or(lte(shape, zero_f()), lte(scale, zero_f())) then nan_d() else cast(gammainc_q(cast(shape, f64), div(cast(x, f64), cast(scale, f64))), f32)
def chi_squared_cdf(x: f32, df: f32) -> f32 = {
  half_df = mul(half_f(), df)
  gamma_cdf(x, half_df, two_f())
}
def chi_squared_sf(x: f32, df: f32) -> f32 = {
  half_df = mul(half_f(), df)
  gamma_sf(x, half_df, two_f())
}
-- Solve P(shape, y) = q on the unit-scale distribution in u = log(y),
-- and multiply by scale once at the end. The log-coordinate slope dP/du is
-- gammainc_front, so the Newton step needs no absolute density floor.
-- The residual uses log(P): in the deep lower tail it is nearly linear in u.
-- A maintained bracket contains each accepted step; a step outside it uses
-- bisection. Exit on convergence, a narrow bracket, or the iteration budget.
-- Iteration counts depend on the inputs; a sampled maximum is not a bound.
def gamma_inv_newton_tol() -> f64 = cast(1e-10, f64)
def gamma_inv_newton_max_i() -> i64 = cast(80, i64)
-- The window where `exp` is neither 0 nor +inf in f64. A start outside it is
-- clamped to the edge rather than evaluated: the asymptotic below is a
-- logarithm divided by `shape`, so a small shape in a deep tail sends it to
-- -5037 at `q = 1e-7, shape = 0.0032`, where the root is genuinely below f64
-- and the honest answer is the underflowed one. Clamping also bounds the
-- widening below, which is what lets its cap be a provable number.
def gamma_inv_u_min() -> f64 = cast(-745.0, f64)
def gamma_inv_u_max() -> f64 = cast(709.0, f64)
-- `P` and `dP/du` at `u = log y`, with both ends of the window given their
-- limits directly instead of being reached through an `exp` that has already
-- lost the value.
def gamma_inv_p_at(shape: f64, u: f64) -> f64 = if lt(u, gamma_inv_u_min()) then zero_d64() else if gt(u, gamma_inv_u_max()) then one_d64() else gammainc_p(shape, exp(u))
def gamma_inv_slope_at(shape: f64, u: f64) -> f64 = if or(lt(u, gamma_inv_u_min()), gt(u, gamma_inv_u_max())) then zero_d64() else gammainc_front(shape, exp(u))
def gamma_inv_clamp_u(u: f64) -> f64 = if lt(u, gamma_inv_u_min()) then gamma_inv_u_min() else if gt(u, gamma_inv_u_max()) then gamma_inv_u_max() else u
-- Use Wilson-Hilferty where its cube is positive and the small-q asymptotic
-- otherwise. The asymptotic starts in log coordinates and preserves deep
-- tails without forming an underflowed initial value.
--
-- `P(a, y) ~ y^a / Gamma(a+1)` as `y -> 0` is the leading term of the same
-- series `gammap_core` sums, so inverting it is accurate exactly where
-- Wilson-Hilferty degenerates, and its log is exact in `u` with no `exp`:
-- `u = (log q + log_gamma(a+1)) / a`. AS 91 and Numerical Recipes both switch
-- here. There is no threshold to be continuous across, because the two
-- branches are separated by the sign of `s` and Wilson-Hilferty is not a
-- start at all where `s <= 0`.
def gamma_inv_start_u(q: f64, z: f64, shape: f64) -> f64 = {
  inv_9k = div(one_d64(), mul(cast(9.0, f64), shape))
  s = add(sub(one_d64(), inv_9k), mul(z, sqrt(inv_9k)))
  if gt(s, zero_d64()) then gamma_inv_clamp_u(add(log(shape), mul(cast(3.0, f64), log(s)))) else gamma_inv_clamp_u(div(add(log(q), log_gamma(add(shape, one_d64()))), shape))
}
-- A straddling bracket for the root, widened from the start by a DOUBLING
-- step. `P` is increasing in `u`, so each endpoint is found by a sign test.
-- Doubling rather than a fixed step is what makes the cap a guarantee instead
-- of a hope: twelve steps span 4095 nats, the clamped start is inside a window
-- 1454 nats wide, and the low end always terminates because `P` is 0 once
-- `exp(u)` underflows while `q` is strictly positive. So the bracket cannot
-- fail to close, at a cost of twelve `P` evaluations in the worst case and
-- one or two in every case measured.
def gamma_inv_widen_max() -> i64 = cast(12, i64)
def gamma_inv_widen_lo(shape: f64, q: f64, u: f64, k: f64, n: i64) -> f64 = if lte(n, cast(0, i64)) then u else if lte(gamma_inv_p_at(shape, u), q) then u else gamma_inv_widen_lo(shape, q, sub(u, k), mul(k, cast(2.0, f64)), sub(n, cast(1, i64)))
def gamma_inv_widen_hi(shape: f64, q: f64, u: f64, k: f64, n: i64) -> f64 = if lte(n, cast(0, i64)) then u else if gte(gamma_inv_p_at(shape, u), q) then u else gamma_inv_widen_hi(shape, q, add(u, k), mul(k, cast(2.0, f64)), sub(n, cast(1, i64)))
-- Incorporate the current point into the bracket, then accept a Newton
-- candidate only inside it; otherwise bisect. Test convergence before strict
-- membership, since rounding can make a converged candidate equal an endpoint.
def gamma_inv_step(shape: f64, q: f64, log_q: f64, u: f64, lo: f64, hi: f64) -> (f64, f64, f64, bool) = {
  pv = gamma_inv_p_at(shape, u)
  lo_next = if lt(pv, q) then u else lo
  hi_next = if gt(pv, q) then u else hi
  slope = gamma_inv_slope_at(shape, u)
  usable = and(gt(slope, zero_d64()), gt(pv, zero_d64()))
  step = if usable then div(mul(sub(log(pv), log_q), pv), slope) else zero_d64()
  cand = sub(u, step)
  converged = and(usable, lt(fabs64_inner(step), gamma_inv_newton_tol()))
  inside = and(and(usable, gt(cand, lo_next)), lt(cand, hi_next))
  u_next = if or(converged, inside) then cand else mul(cast(0.5, f64), add(lo_next, hi_next))
  narrow = lt(sub(hi_next, lo_next), gamma_inv_newton_tol())
  (u_next, lo_next, hi_next, or(converged, narrow))
}
def gamma_inv_chunk(shape: f64, q: f64, log_q: f64, u: f64, lo: f64, hi: f64, i: i64, max_i: i64, steps: i64) -> (f64, f64, f64, i64, bool) = {
  zero_i = cast(0, i64)
  one_i = cast(1, i64)
  if or(gt(i, max_i), lte(steps, zero_i)) then (u, lo, hi, i, false) else {
    st = gamma_inv_step(shape, q, log_q, u, lo, hi)
    i_next = add(i, one_i)
    if st.3 then (st.0, st.1, st.2, i_next, true) else gamma_inv_chunk(shape, q, log_q, st.0, st.1, st.2, i_next, max_i, sub(steps, one_i))
  }
}
def gamma_inv_drive(shape: f64, q: f64, log_q: f64, u: f64, lo: f64, hi: f64, i: i64, max_i: i64) -> f64 =
  if gt(i, max_i) then u else {
    st = gamma_inv_chunk(shape, q, log_q, u, lo, hi, i, max_i, gammainc_fanout_i())
    if st.4 then st.0 else gamma_inv_drive(shape, q, log_q, st.0, st.1, st.2, st.3, max_i)
  }
-- At interior q, require finite positive shape and scale and return NaN
-- otherwise. Re-dilate the unit quantile in f64 before the final f32 cast:
-- a small unit quantile can be below f32's range while its scaled value fits.
def gamma_inv_cdf(q: f32, shape: f32, scale: f32) -> f32 =
  if or(neq(q, q), or(lt(q, zero_f()), gt(q, one_f()))) then nan_d() else if lte(q, zero_f()) then zero_f() else if gte(q, one_f()) then pos_inf_d() else if or(neq(shape, shape), or(lte(shape, zero_f()), eq(shape, pos_inf_d()))) then nan_d() else if or(neq(scale, scale), or(lte(scale, zero_f()), eq(scale, pos_inf_d()))) then nan_d() else {
    q64 = cast(q, f64)
    shape64 = cast(shape, f64)
    z = cast(normal_inv_cdf(q, zero_f(), one_f()), f64)
    u0 = gamma_inv_start_u(q64, z, shape64)
    lo = gamma_inv_widen_lo(shape64, q64, u0, one_d64(), gamma_inv_widen_max())
    hi = gamma_inv_widen_hi(shape64, q64, u0, one_d64(), gamma_inv_widen_max())
    u = gamma_inv_drive(shape64, q64, log(q64), u0, lo, hi, cast(1, i64), gamma_inv_newton_max_i())
    cast(mul(cast(scale, f64), exp(u)), f32)
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
