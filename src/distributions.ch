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
-- The density's log-space body has the same cancellation the incomplete gamma
-- does, for the same reason: `(k - 1)*log(x)` and `log_gamma(k)` are each
-- about 1.1e6 at `k = x = 1e5` and the exponent they leave is -6.67. In f32
-- `gamma_pdf(1e5, 1e5, 1)` was 5.2e-2 relative and `gamma_pdf(5e7, 5e7, 1)`
-- returned exactly 1.0 against a true 5.64e-5 -- a density above every value
-- a Gamma(5e7, 1) density takes. It is evaluated in f64 and returned as f32.
-- `gamma_inv_cdf`'s Newton step reads this as its derivative, so the quantile
-- inherited the error from here as well as from `gamma_cdf`.
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
-- Both routes below share one front factor, `exp(a*log(x) - x - log_gamma(a))`,
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
-- f64 moves that cliff rather than removing it. The floor is one f64 ulp of
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
-- `docs/book/src/appendix/precision.md` states the range this bounds and
-- `parity/check_gamma_accuracy.py` is its gate.
--
-- Both budgets are far larger than the f32 lane's 200, because f32 could not
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
-- The series tolerance is relative to the running sum, and the f32 lane's was
-- not. It compared the term against `max(|sum|, 1.0)`, and that floor made the
-- test absolute wherever the sum fell below 1. The sum is `P(a, x)` divided by
-- the front factor, which is 1.8e-4 at `a = 5e7`, so a nominal 1e-7 bought a
-- relative 5.6e-4 there. Near the branch point the tail is also about
-- `sqrt(a)` times its last term rather than comparable to it, so a tolerance
-- buys `tol*sqrt(a)` of relative accuracy and not `tol`: 1e-7 measured 1.8e-4
-- at `a = 5e7` in f64 too. 1e-13 is what keeps the truncation inside one f32
-- ulp across the documented range, and the two tolerances are deliberately
-- separate numbers so the continued fraction's can move without the series'.
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
-- The two cores guard a non-finite `x` before entering their recursions, and
-- that guard is a cost control rather than a new answer. Neither the series'
-- `|term| < tol*|sum|` nor the continued fraction's `|delta - 1| < tol` can be
-- satisfied by a NaN, so a NaN argument spends the whole 65536-step budget and
-- returns the NaN it would have returned anyway -- and `gamma_inv_cdf` pays
-- that 80 times over. The f32 lane's budget was 200, so the same inputs were
-- cheap there. `gamma_inv_cdf(0.5, 1, 0)` is the reachable case: its
-- Wilson-Hilferty start is 0 when `scale` is 0, and `0 / 0` is the `x` that
-- arrives here. The answers are the limits, which are what the lane already
-- returned by propagation.
-- The front factor is formed BEFORE the recursion and a non-finite one
-- short-circuits, which is a cost control and changes no value: the product of
-- a NaN front factor with any sum is that NaN. Two paths reach it. A `+inf`
-- shape makes `1/a` exactly zero, so the running sum stays exactly zero and
-- the relative convergence test `|term| < tol*|sum|` can never fire -- the f32
-- lane's absolute-floored test converged at step one, so this is a cost the
-- f64 lane introduced, and `gamma_cdf(1, +inf, 1)` spent all 65536 terms to
-- return the NaN it returns immediately now. A NaN shape traps inside
-- `log_gamma`, and forming the front factor first means it traps before the
-- budget is spent rather than after: the trap itself is unchanged and is
-- tracked elsewhere.
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
-- subtraction is never the one that cancels: a small `P` is reached through
-- the series directly and a small `Q` through the continued fraction, which is
-- the arrangement #137 and #139 settled for this family.
def gammainc_p(a: f64, x: f64) -> f64 = if lt(x, add(a, one_d64())) then gammap_core(a, x) else sub(one_d64(), gammaq_core(a, x))
def gammainc_q(a: f64, x: f64) -> f64 = if lt(x, add(a, one_d64())) then sub(one_d64(), gammap_core(a, x)) else gammaq_core(a, x)
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
-- saturated the same way once df reached 2^24 and no longer reaches this
-- function at all above `student_t_normal_df`, which is below that; its `omx`
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
-- The log-space body is evaluated in f64 and the result returned as f32.
-- `log_gamma(k + 1)` is `log(k!)`, which reaches 1.05e6 at k = 1e5 and 8.36e8
-- at k = 5e7. One f32 ulp at 1.05e6 is 0.125, an absolute error in an
-- exponent and hence a multiplicative error in the result: `poisson_pmf(1e5,
-- 1e5)` was 5.2% high. Above k = 2^24 the `+ 1` vanishes outright
-- (`ulp(5e7)` is 4), so the normalising constant was `log(k!)` for the wrong
-- factorial and `poisson_pmf(5e7, 5e7)` returned 1.0 against a true
-- 5.6418952e-05. Forming `k + 1` in f64 fixes the second; evaluating the
-- whole exponent there fixes the first, which is the larger term below 2^24.
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
-- `P(X <= k) = Q(k+1, lambda)`, the upper regularised incomplete gamma, which
-- is what `gamma_sf` returns. The earlier spelling `1 - gamma_cdf(lambda,
-- k+1, 1)` subtracted a value near `1.0` from `1.0`, so the whole left tail
-- arrived as `0.0`: `poisson_cdf(10, 50)` returned zero against a true
-- `6.4501529e-12`. `gamma_sf`'s branch point is the one this needs -- a small
-- `P(X <= k)` means `lambda >> k + 1`, which is exactly where `gamma_sf`
-- evaluates the continued fraction directly instead of complementing.
-- `k + 1` is formed in f64 and the upper regularised incomplete gamma is
-- entered directly, rather than going through `gamma_sf`'s f32 signature. In
-- f32 the `+ 1` is lost outright above `k = 2^24`, which made
-- `poisson_cdf(5e7, 5e7)` evaluate `Q(5e7, 5e7)` instead of `Q(5e7 + 1, 5e7)`:
-- the difference between them is `poisson_pmf(5e7, 5e7) = 5.64e-5`, so the
-- answer was short by 1.1e-4 of itself. That was invisible underneath the
-- front-factor error this change removes -- the same call was 99.87% wrong
-- before -- and it is the whole residual once the front factor is fixed. It is
-- the site #146 named and then narrowed away from, so it is repaired here,
-- where the export is already being moved.
-- The three guards that remain are `gamma_sf`'s own, specialised to `scale =
-- 1`: with that scale the standardised argument is `lambda` exactly, in f32
-- and in f64 alike, so specialising them changes no boundary.
def poisson_cdf(k: f32, lambda: f32) -> f32 =
  if lt(lambda, zero_f()) then nan_d() else if lt(k, zero_f()) then zero_f() else if eq(lambda, zero_f()) then one_f() else if neq(lambda, lambda) then nan_d() else if eq(lambda, pos_inf_d()) then zero_f() else {
    k_plus_one = add(cast(k, f64), one_d64())
    cast(gammainc_q(k_plus_one, cast(lambda, f64)), f32)
  }
-- The log-space body is evaluated in f64 and the result returned as f32, for
-- the reason recorded above `poisson_pmf` and one more: `log_choose` is a
-- difference of three log-factorials, so its f32 error is bounded by the
-- *largest* of them rather than by the answer. At n = 1e8,
-- `log_gamma(n + 1)` is 1.74e9, where one f32 rounding is an absolute error
-- of 128 in the exponent -- a factor of e^128. `binomial_pmf(5e7, 1e8, 0.5)`
-- returned `inf`, and `binomial_pmf(2e7, 4e7, 0.5)` returned 1.0; neither is
-- a probability. The three log-gammas and the `(n - k) * log(1 - p)` term
-- rounded independently, which is how the result left [0, 1] rather than
-- merely drifting. The error is continuous in n, not a cliff at 2^24: it was
-- already 15% at n = 2e5 and 59% at n = 2e6.
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
-- Above `student_t_normal_df` the beta route is replaced by the t
-- distribution's own large-`df` expansion, because no amount of precision
-- rescues it there. `betai_core`'s front factor is
-- `exp(lgamma(a+b) - lgamma(a) - lgamma(b) + ...)` with `a = df/2`, and the
-- absolute error of that exponent is about one f64 ulp of the largest
-- log-gamma: `lgamma(5e8)` is 9.5e9, where one ulp is 1.9e-6, so the result
-- carries a multiplicative error of that order. The error is an absolute one
-- in an *exponent*, so it grows without bound in `df` and widening the
-- arithmetic only moves the onset. Measured on the beta route, worst over a
-- `t` axis of -0.5 to -11 and +1: 1.1e-7 at `df = 1e7`, 1.2e-6 at 1e8,
-- 9.1e-6 at 1e9, 1.9e-4 at 1e11, 2.3e-3 at 1e12, 2.6 at 1e14, 1.1e1 at 1e16
-- and 2.6e27 at 1e20. The peak sits at `t = -sqrt(3)`, the continued
-- fraction's branch boundary, where the upper branch returns `1 - val`: a
-- relative error on `val` becomes `(1 - I)/I` times as large on `I = 2 F(t)`,
-- which is 11.0 there. That figure is the algebra, not a measurement: the
-- boundary is measurably worse than its neighbours in `t`, but the ratio you
-- get depends on which neighbour and which `df` you pick, so no single
-- measured multiple belongs here.
-- At `t = 1` alone it reads 2.9e-7 at `df = 1e9`, 7.1e-5 at 1e12, 9.6e-2 at
-- 1e14 and 41% from 1e16 up, because `student_t_cdf(1, 1e16)` returned exactly
-- 0.5 -- the value the
-- function also returns at `t = 0`, so the answer was indistinguishable from
-- a real one. The left tail was worse than that 0.5 suggests:
-- `student_t_cdf(-5, 1e18)` returned 0.49981025 against a true 2.8665157e-7,
-- and `student_t_cdf(-8, 1e18)` returned 0.0. `df = inf` returned 0.5 too.
-- Saturation of `x = df/(df+t*t)` to exactly 1.0 near `df = 2^53` is a second
-- and much later cause; the cancellation above already dominates at `df = 1e14`,
-- where `x` is not saturated for any `|t| > 0.09`.
--
-- The expansion is `F_df(t) = Phi(t) - phi(t)(t^3 + t)/(4 df) + O(df^-2)`.
-- The `1/df` term is not a refinement that could be dropped: without it the
-- limit's own relative error at `t = -11` is 3.7e-4 at `df = 1e7` and 3.7e-5
-- at 1e8, falling only as `1/df`, so it first reaches 2e-6 around
-- `df = 1.9e9`. The beta route's worst over the same `t` axis passes 2e-6
-- between `df = 3e8` and 5e8. A plain `Phi(t)` branch therefore has no
-- threshold that holds the documented bound anywhere.
--
-- The threshold is 1e7 because by there the expansion has reached the beta
-- route's own noise floor. It is NOT a crossing: the beta
-- route's worst is flat rounding noise through this region -- 1.3e-7 at
-- `df = 1e6`, 1.2e-7 at 5e6, 1.5e-7 at 9e6, 1.1e-7 at 1e7, 2.0e-7 at 2e7,
-- 1.5e-7 at 3e7 -- so no exact crossing point is identifiable, and a grid that
-- claimed one would be reading its own spacing. The expansion is 8.6e-8 at
-- `df = 1e7` and improves as `1/df^2` from there, so both forms sit about 20x
-- inside the bound at the handover.
--
-- That handover is not free. Just above the threshold, at `|t|` of 11 and
-- beyond, the expansion is less accurate than the beta route was, by about a
-- factor of three at `(t = -11, df = 1e7)` and by more in the far tail. All
-- of it stays well inside 2e-6, and the beta route's own error at those `df`
-- is about to rise through it, but the figures above are worst cases over
-- `|t| <= 11` and not a uniform improvement at every point.
--
-- `t*t < 1600` is a domain test, not a tolerance. `phi(t)` is exactly 0.0 in
-- f64 for `|t| >= 38.7` and `Phi(t)` is 0.0 or 1.0 there, so the correction
-- cannot change a finite answer above that; the test exists so that
-- `t = +-inf` yields the correction's limit of 0 rather than the
-- indeterminate `0 * inf`, which would make NaN of a CDF the beta route got
-- right. A NaN `t` still reaches `standard_normal_cdf` and still returns NaN.
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
-- A non-positive `shape` or `scale` is not a distribution, and a non-finite
-- `x` is a limit rather than a point to integrate to, so both are decided
-- before the standardised argument `xs` reaches either recursion.
-- These are the guards `gamma_pdf`, `gamma_inv_cdf` and `weibull_cdf` already
-- use, and they agree with SciPy. The guards read `xs`, not `x`, so a finite
-- `x` whose `x / scale` overflows lands on the same answer as `x = +inf`.
-- The three guards read the f32 `xs` and the body reads an f64 one. That is
-- deliberate: the guards are the ones #140 settled, including the clause above
-- that a finite `x` whose f32 `x / scale` overflows answers as `x = +inf`
-- does, and widening the quotient would quietly move that boundary. The f64
-- quotient the body uses carries the digits the recursion needs.
def gamma_cdf(x: f32, shape: f32, scale: f32) -> f32 =
  if or(lte(shape, zero_f()), lte(scale, zero_f())) then nan_d() else {
    xs = div(x, scale)
    xs64 = div(cast(x, f64), cast(scale, f64))
    if neq(xs, xs) then nan_d() else if lte(xs, zero_f()) then zero_f() else if eq(xs, pos_inf_d()) then one_f() else cast(gammainc_p(cast(shape, f64), xs64), f32)
  }
def gamma_sf(x: f32, shape: f32, scale: f32) -> f32 =
  if or(lte(shape, zero_f()), lte(scale, zero_f())) then nan_d() else {
    xs = div(x, scale)
    xs64 = div(cast(x, f64), cast(scale, f64))
    if neq(xs, xs) then nan_d() else if lte(xs, zero_f()) then one_f() else if eq(xs, pos_inf_d()) then zero_f() else cast(gammainc_q(cast(shape, f64), xs64), f32)
  }
def chi_squared_cdf(x: f32, df: f32) -> f32 = {
  half_df = mul(half_f(), df)
  gamma_cdf(x, half_df, two_f())
}
def chi_squared_sf(x: f32, df: f32) -> f32 = {
  half_df = mul(half_f(), df)
  gamma_sf(x, half_df, two_f())
}
-- The quantile is a Wilson-Hilferty closed form refined by Newton's method on
-- the CDF, and the refinement now runs in f64 on the f64 CDF and density.
--
-- The loop stays, and its own measurement is why. Against `gammaincinv`, with
-- the f32 CDF underneath it, the refinement was worth 41856x at `shape = 1`
-- and about 8.1e5 at `q = 0.05, shape = 1`, where the closed form is weak;
-- above the bracket it was 1001x *worse* at `shape = 1e3` and returned 5e29 at
-- `shape = 1e7`. Both of those are one defect: Newton converges on the root of
-- the function it is given, so a biased CDF moves the root it finds, and the
-- closed form happened to be nearer the true quantile than that moved root
-- was. Removing the loop would have traded a large-shape error for a
-- small-shape one five orders of magnitude bigger. Fixing the CDF fixes the
-- loop, and no threshold is introduced, so there is no shape at which this
-- function changes method and nothing here to be continuous across.
--
-- The crossover above is a bracket and not a located boundary: the sweep that
-- found it stepped `shape` by decades, so what it establishes is that the flip
-- happens somewhere between 100 and 1000 at the median and somewhere between
-- 1e3 and 1e4 in the 0.1% tails.
--
-- The exit test is new and is a cost control rather than an accuracy one. 80
-- unconditional steps each cost a full CDF evaluation, which near the branch
-- point is tens of thousands of series terms; the loop reaches the f64 noise
-- floor of the CDF it is reading in about five. `1e-10` relative is the
-- stopping point because the floor itself is parameter-dependent -- the step
-- settles at about 3.5e-11 of `x` at `shape = 5e7` and 2.3e-12 at `shape =
-- 1e5` -- so a test tighter than the floor would never fire and would spend
-- the whole budget. 1e-10 is still 170x finer than the f32 return resolves.
-- The 80-step budget remains as the backstop for a non-converging case.
def gamma_inv_newton_tol() -> f64 = cast(1e-10, f64)
-- Not `gammainc_tiny()`, and the difference is 270 decades of consequence.
-- That constant is the continued fraction's Lentz floor, where the only job is
-- to be small enough never to be reached by a real denominator. These two are
-- the smallest *starting point* and the smallest *derivative* the Newton loop
-- can usefully be handed, and both are reached: Wilson-Hilferty's `s` goes
-- negative for a small shape in the far lower tail -- `shape = 1.25, q = 0.001`
-- is one -- so the cube is floored and becomes the start. At 1e-30 the density
-- there is 1.8e-8, so the first Newton step overshoots the root by about six
-- decades and roughly twenty-three halvings of the `x_next <= 0` fallback
-- bring it back inside the 80-step budget. At 1e-300 the density underflows to
-- zero, the step is divided by the floor instead, and
-- `gamma_inv_cdf(0.001, 1.25, 2)` diverges to +inf from a value that was
-- correct to seven digits. The f32 lane used 1e-30 for both and this keeps it.
def gamma_inv_floor() -> f64 = cast(1e-30, f64)
def gamma_inv_newton_max_i() -> i64 = cast(80, i64)
def gamma_inv_newton_step(target: f64, shape: f64, scale: f64, x: f64) -> (f64, bool) = {
  cur = gammainc_p(shape, div(x, scale))
  resid = sub(cur, target)
  pdf_v = gamma_pdf_core(x, shape, scale)
  floor_pdf = gamma_inv_floor()
  pdf_safe = if lt(pdf_v, floor_pdf) then floor_pdf else pdf_v
  step = div(resid, pdf_safe)
  x_next_raw = sub(x, step)
  x_next = if lte(x_next_raw, zero_d64()) then mul(cast(0.5, f64), x) else x_next_raw
  settled = lt(fabs64_inner(sub(x_next, x)), mul(gamma_inv_newton_tol(), fabs64_inner(x)))
  (x_next, settled)
}
def gamma_inv_newton_chunk(target: f64, shape: f64, scale: f64, x: f64, i: i64, max_i: i64, steps: i64) -> (f64, i64, bool) = {
  zero_i = cast(0, i64)
  one_i = cast(1, i64)
  if or(gt(i, max_i), lte(steps, zero_i)) then (x, i, false) else {
    st = gamma_inv_newton_step(target, shape, scale, x)
    i_next = add(i, one_i)
    if st.1 then (st.0, i_next, true) else gamma_inv_newton_chunk(target, shape, scale, st.0, i_next, max_i, sub(steps, one_i))
  }
}
def gamma_inv_newton_drive(target: f64, shape: f64, scale: f64, x: f64, i: i64, max_i: i64) -> f64 =
  if gt(i, max_i) then x else {
    st = gamma_inv_newton_chunk(target, shape, scale, x, i, max_i, gammainc_fanout_i())
    if st.2 then st.0 else gamma_inv_newton_drive(target, shape, scale, st.0, st.1, max_i)
  }
def gamma_inv_cdf(q: f32, shape: f32, scale: f32) -> f32 =
  if or(lt(q, zero_f()), gt(q, one_f())) then nan_d() else if lte(q, zero_f()) then zero_f() else if gte(q, one_f()) then pos_inf_d() else {
    z = cast(normal_inv_cdf(q, zero_f(), one_f()), f64)
    shape64 = cast(shape, f64)
    scale64 = cast(scale, f64)
    inv_9k = div(one_d64(), mul(cast(9.0, f64), shape64))
    sqrt_inv_9k = sqrt(inv_9k)
    a = sub(one_d64(), inv_9k)
    b = mul(z, sqrt_inv_9k)
    s = add(a, b)
    s_cubed = mul(s, mul(s, s))
    wh_safe = if gt(s_cubed, gamma_inv_floor()) then s_cubed else gamma_inv_floor()
    x0 = mul(shape64, mul(scale64, wh_safe))
    cast(gamma_inv_newton_drive(cast(q, f64), shape64, scale64, x0, cast(1, i64), gamma_inv_newton_max_i()), f32)
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
