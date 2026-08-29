module Nautilus.ApiSmoke
import Nautilus.Special (erf, erfc, erfinv, gamma, log_gamma, digamma, beta, lbeta, trigamma, bessel_i0, bessel_i1, bessel_k0, bessel_k1, bessel_j0, bessel_j1, bessel_y0, bessel_y1, airy_ai, airy_bi, ellipk, ellipe)
import Nautilus.Distributions (normal_pdf, normal_cdf, normal_inv_cdf, uniform_pdf, uniform_cdf, uniform_inv_cdf, exponential_pdf, exponential_cdf, exponential_inv_cdf, lognormal_pdf, lognormal_cdf, lognormal_inv_cdf, gamma_pdf, gamma_cdf, gamma_inv_cdf, chi_squared_pdf, chi_squared_cdf, chi_squared_inv_cdf, student_t_pdf, poisson_pmf, poisson_cdf, binomial_pmf, binomial_cdf, beta_pdf, beta_cdf, f_pdf, f_cdf, weibull_pdf, weibull_cdf, weibull_inv_cdf)
import Nautilus.LinAlg (transpose, matmul_wrap, gram, aat, diag, trace_mat, trace_scalar, l2_norm_vec, inner_product, frobenius_sq, frobenius_norm, scale_vec, matvec, vecmat, det_2x2, det_3x3, la_vec_add, la_vec_sub, la_vec_saxpy, cg_solve, inv_2x2, inv_3x3, solve_2x2, solve_3x3, eig_2x2_real, cholesky_2x2, cholesky_n, lu_solve, qr_decompose, svd_n, eig_n)
import Nautilus.Roots (bisection, newton, brent)
import Nautilus.Ode (euler_step, euler_solve, rk4_step, rk4_solve, rk45_adaptive_solve, rk45_adaptive_solve_grid)
import Nautilus.Stats (mean_vec, variance_vec, std_vec, skewness_vec, kurtosis_vec, median_vec, covariance_scalar, correlation_scalar, min_vec, max_vec, range_vec, quantile_vec, percentile_vec, trimmed_mean_vec, bonferroni_adjust, stat_holm_adjust, benjamini_hochberg_adjust, fdr_adjust, likelihood_ratio_stat, likelihood_ratio_p_value, covariance_2x2, correlation_2x2, covariance_matrix_2, correlation_matrix_2)
import Nautilus.Info (entropy, cross_entropy, kl_divergence)
import Nautilus.Integrate (trapezoidal, simpsons, gauss_legendre_5)
import Nautilus.Testing (z_statistic, z_p_value_two_sided, z_p_value_upper, z_p_value_lower, normal_ci_half_width, chi_squared_p_value)
import Nautilus.Distance (squared_euclidean, euclidean, manhattan, chebyshev, cosine_similarity, cosine_distance, mahalanobis_squared, mahalanobis)
import Nautilus.Signal (fft_magnitude_stub, ifft_magnitude_stub, stft_magnitude_stub, lowpass_stub, highpass_stub, bandpass_stub, fftfreq)
import Nautilus.Optim (golden_section_search, brent_minimize, gradient_descent_1d, newton_minimize_1d)
import Nautilus.Optimize (minimize, root, optimize_ad_smoke)
import Nautilus.Interpolation (linear_interp_uniform, linear_interp_sorted, cubic_hermite, spline_fit, spline_eval)
import Nautilus.Sde (euler_maruyama_fixed, milstein_fixed)
import Nautilus.Integrate (trapezoidal, simpsons, gauss_legendre_5, adaptive_simpson, romberg_5, gauss_legendre_10, gauss_hermite_10, gauss_laguerre_10)
import Nautilus.CurveFit (lm_scalar_1param, lm_scalar_nparam)
import Nautilus.StateSpace (kalman_predict_scalar, kalman_update_scalar, kalman_step_scalar, local_level_predict, local_level_update, local_level_step)
import Nautilus.TimeSeries (ts_ewma_next, ts_ewma_series, exponential_smoothing_next, exponential_smoothing_series, ar1_predict_next, arma11_predict_next, arima110_predict_next)
export (smoke_special, smoke_distributions, smoke_linalg, smoke_roots, smoke_ode, smoke_stats, smoke_integrate, smoke_testing, smoke_distance, smoke_signal, smoke_optim, smoke_interpolation, smoke_cg_solve, smoke_sde, smoke_linalg_inv, smoke_integrate_adaptive, smoke_integrate_hl, smoke_curvefit, smoke_distributions_p4, smoke_stats_p4, smoke_qr, smoke_svd_n, smoke_lm_nparam, smoke_eig_n, smoke_ode_grid, smoke_spline, smoke_optimize, smoke_info, smoke_stats_inference, smoke_statespace, smoke_timeseries)
-- chelis:provenance/v1 surface
-- id = NAUT-SUPPORT-SURFACE
-- member-key-schema = nautilus-module-key/v1
-- disposition-schema = nautilus-module-disposition/v1
-- generation = 1
-- members = special;distributions;linalg;stats;info;distance;roots;ode;integrate;testing;optim;optimize;interpolation;sde;curvefit;statespace;timeseries;signal;core
-- rows = special:normative:NAUT-MOD-SPECIAL@xxh3-128:5f32f4036da62f1c5a1fe9b5f0b382c2;distributions:normative:NAUT-MOD-DISTRIBUTIONS@xxh3-128:1b62d03e9dff79a353c7bf3b01969ca9;linalg:normative:NAUT-MOD-LINALG@xxh3-128:49dca51dd2b5269319d41eaa1523c417;stats:normative:NAUT-MOD-STATS@xxh3-128:83e4d24feb0b0af7a179db04db8ace9b;info:normative:NAUT-MOD-INFO@xxh3-128:88412a1ac196cd9fb55b11d631b50f17;distance:normative:NAUT-MOD-DISTANCE@xxh3-128:1902302ae9e5d41e347fe2167751ab9c;roots:normative:NAUT-MOD-ROOTS@xxh3-128:a36ea90f78ffdb7b8c154ff0984f1920;ode:normative:NAUT-MOD-ODE@xxh3-128:7326b3378b82060cd092b6e6e685375e;integrate:normative:NAUT-MOD-INTEGRATE@xxh3-128:b445640133fa4dc13a57770525425323;testing:normative:NAUT-MOD-TESTING@xxh3-128:b21a5b4736239a275ac37573324de7c2;optim:normative:NAUT-MOD-OPTIM@xxh3-128:d4759e42e806d2ac9f12f212dbf77050;optimize:normative:NAUT-MOD-OPTIMIZE@xxh3-128:9f1258a7cd711b9116795f1fcc4ce073;interpolation:normative:NAUT-MOD-INTERPOLATION@xxh3-128:731752085861ee4f4e593de2e49ab5ee;sde:normative:NAUT-MOD-SDE@xxh3-128:6f7aef2de519a11882d6327dd30dbaaa;curvefit:normative:NAUT-MOD-CURVEFIT@xxh3-128:8a91e5e810699197bea88c33c4e50aa3;statespace:normative:NAUT-MOD-STATESPACE@xxh3-128:66dabb0a8d21664d4d718e970e8277f0;timeseries:normative:NAUT-MOD-TIMESERIES@xxh3-128:c6b3e0cd2c00b5d0ff10dbe95f3b01d5;signal:deferred:NAUT-MOD-SIGNAL@xxh3-128:6a1b10484def2dcd1098ffe84895e0df;core:normative:NAUT-MOD-CORE@xxh3-128:ccb55b5be38b9d68f425c8813d656889
def smoke_poly(x: f32) -> f32 = {
  x2 = mul(x, x)
  sub(x2, cast(2.0, f32))
}
def smoke_dpoly(x: f32) -> f32 = mul(cast(2.0, f32), x)
def smoke_decay(y: f32, t: f32) -> f32 = neg(y)
def smoke_special() -> f32 = {
  e = erf(cast(0.5, f32))
  ec = erfc(cast(0.5, f32))
  ei = erfinv(cast(0.5, f32))
  g = gamma(cast(3.0, f32))
  lg = log_gamma(cast(3.0, f32))
  dg = digamma(cast(3.0, f32))
  b = beta(cast(2.0, f32), cast(3.0, f32))
  lb = lbeta(cast(2.0, f32), cast(3.0, f32))
  tg = trigamma(cast(2.0, f32))
  bi0 = bessel_i0(cast(1.0, f32))
  bi1 = bessel_i1(cast(1.0, f32))
  bk0 = bessel_k0(cast(1.0, f32))
  bk1 = bessel_k1(cast(1.0, f32))
  bj0 = bessel_j0(cast(1.0, f32))
  bj1 = bessel_j1(cast(1.0, f32))
  by0 = bessel_y0(cast(1.0, f32))
  by1 = bessel_y1(cast(1.0, f32))
  aai = airy_ai(cast(1.0, f32))
  abi = airy_bi(cast(1.0, f32))
  ek = ellipk(cast(0.5, f32))
  ee = ellipe(cast(0.5, f32))
  s0 = add(add(add(add(add(add(add(e, ec), ei), g), lg), dg), b), lb)
  s1 = add(add(add(add(tg, bi0), bi1), bk0), bk1)
  s2 = add(add(add(add(bj0, bj1), by0), by1), aai)
  s3 = add(add(abi, ek), ee)
  add(add(add(s0, s1), s2), s3)
}
def smoke_distributions() -> f32 = {
  a = normal_pdf(cast(0.0, f32), cast(0.0, f32), cast(1.0, f32))
  b = normal_cdf(cast(1.0, f32), cast(0.0, f32), cast(1.0, f32))
  c = normal_inv_cdf(cast(0.975, f32), cast(0.0, f32), cast(1.0, f32))
  d = uniform_pdf(cast(0.5, f32), cast(0.0, f32), cast(1.0, f32))
  e = uniform_cdf(cast(0.3, f32), cast(0.0, f32), cast(1.0, f32))
  f = uniform_inv_cdf(cast(0.5, f32), cast(0.0, f32), cast(1.0, f32))
  g = exponential_pdf(cast(1.0, f32), cast(2.0, f32))
  h = exponential_cdf(cast(1.0, f32), cast(2.0, f32))
  i = exponential_inv_cdf(cast(0.5, f32), cast(2.0, f32))
  j = lognormal_pdf(cast(1.0, f32), cast(0.0, f32), cast(1.0, f32))
  k = lognormal_cdf(cast(1.0, f32), cast(0.0, f32), cast(1.0, f32))
  l = lognormal_inv_cdf(cast(0.5, f32), cast(0.0, f32), cast(1.0, f32))
  m = gamma_pdf(cast(2.0, f32), cast(2.0, f32), cast(1.0, f32))
  n = gamma_cdf(cast(2.0, f32), cast(2.0, f32), cast(1.0, f32))
  o = gamma_inv_cdf(cast(0.5, f32), cast(2.0, f32), cast(1.0, f32))
  p = chi_squared_pdf(cast(2.0, f32), cast(3.0, f32))
  q = chi_squared_cdf(cast(2.0, f32), cast(3.0, f32))
  r = chi_squared_inv_cdf(cast(0.5, f32), cast(3.0, f32))
  s = student_t_pdf(cast(0.0, f32), cast(5.0, f32))
  s1 = add(add(add(add(a, b), c), d), e)
  s2 = add(add(add(add(f, g), h), i), j)
  s3 = add(add(add(add(k, l), m), n), o)
  s4 = add(add(add(p, q), r), s)
  add(add(add(s1, s2), s3), s4)
}
def smoke_linalg[m, k, n](a: tensor[m, k, f32], b: tensor[k, n, f32], v: tensor[k, f32], w: tensor[k, f32], s: tensor[2, 2, f32], t3: tensor[3, 3, f32]) -> f32 = {
  at = transpose(copy(a))
  ignore_at = at
  ab = matmul_wrap(copy(a), b)
  ignore_ab = ab
  g_mat = gram(copy(a))
  ignore_g = g_mat
  aat_mat = aat(a)
  tr_val = trace_scalar(aat_mat)
  ignore_tr = tr_val
  inner = inner_product(copy(v), w)
  n2 = l2_norm_vec(v)
  d2 = det_2x2(s)
  d3 = det_3x3(t3)
  add(add(add(inner, n2), d2), d3)
}
def smoke_roots() -> f32 = {
  r1 = bisection(smoke_poly, cast(1.0, f32), cast(2.0, f32), cast(1e-10, f32), cast(100, int64))
  r2 = newton(smoke_poly, smoke_dpoly, cast(1.5, f32), cast(1e-12, f32), cast(50, int64))
  r3 = brent(smoke_poly, cast(1.0, f32), cast(2.0, f32), cast(1e-10, f32), cast(100, int64))
  add(add(r1, r2), r3)
}
def smoke_ode() -> f32 = {
  a = euler_step(smoke_decay, cast(1.0, f32), cast(0.0, f32), cast(0.01, f32))
  b = rk4_step(smoke_decay, cast(1.0, f32), cast(0.0, f32), cast(0.01, f32))
  c = euler_solve(smoke_decay, cast(1.0, f32), cast(0.0, f32), cast(1.0, f32), cast(100, int64))
  d = rk4_solve(smoke_decay, cast(1.0, f32), cast(0.0, f32), cast(1.0, f32), cast(100, int64))
  e = rk45_adaptive_solve(smoke_decay, cast(1.0, f32), cast(0.0, f32), cast(1.0, f32), cast(1e-6, f32), cast(1e-8, f32))
  add(add(add(add(a, b), c), d), e)
}
def smoke_stats[n](v: tensor[n, f32], w: tensor[n, f32]) -> f32 = {
  m = mean_vec(copy(v))
  vr = variance_vec(copy(v), cast(0, int64))
  sd = std_vec(copy(v), cast(1, int64))
  sk = skewness_vec(copy(v))
  ku = kurtosis_vec(copy(v))
  md = median_vec(copy(v))
  cv = covariance_scalar(copy(v), copy(w), cast(1, int64))
  cr = correlation_scalar(v, w)
  s1 = add(add(add(m, vr), sd), sk)
  s2 = add(add(add(ku, md), cv), cr)
  add(s1, s2)
}
def smoke_integrate() -> f32 = {
  t = trapezoidal(smoke_poly, cast(0.0, f32), cast(1.0, f32), cast(100, int64))
  s = simpsons(smoke_poly, cast(0.0, f32), cast(1.0, f32), cast(100, int64))
  g = gauss_legendre_5(smoke_poly, cast(0.0, f32), cast(1.0, f32), cast(5, int64))
  add(add(t, s), g)
}
def smoke_testing() -> f32 = {
  z = z_statistic(cast(102.0, f32), cast(100.0, f32), cast(15.0, f32), cast(25.0, f32))
  p1 = z_p_value_two_sided(z)
  p2 = z_p_value_upper(cast(1.96, f32))
  p3 = z_p_value_lower(cast(-1.96, f32))
  ci = normal_ci_half_width(cast(0.95, f32), cast(15.0, f32), cast(25.0, f32))
  cp = chi_squared_p_value(cast(11.07, f32), cast(5.0, f32))
  add(add(add(add(add(z, p1), p2), p3), ci), cp)
}
def smoke_distance[n](v: tensor[n, f32], w: tensor[n, f32], cov_inv: tensor[n, n, f32]) -> f32 = {
  se = squared_euclidean(copy(v), copy(w))
  eu = euclidean(copy(v), copy(w))
  mn = manhattan(copy(v), copy(w))
  cb = chebyshev(copy(v), copy(w))
  cs = cosine_similarity(copy(v), copy(w))
  cd = cosine_distance(copy(v), copy(w))
  ma = mahalanobis(v, w, cov_inv)
  s1 = add(add(add(se, eu), mn), cb)
  s2 = add(add(cs, cd), ma)
  add(s1, s2)
}
def smoke_signal[n](x: tensor[n, f32]) -> tensor[n, f32] = fft_magnitude_stub(x)
def smoke_optim_parab(x: f32) -> f32 = {
  d = sub(x, cast(2.0, f32))
  mul(d, d)
}
def smoke_optim_dparab(x: f32) -> f32 = mul(cast(2.0, f32), sub(x, cast(2.0, f32)))
def smoke_optim_ddparab(x: f32) -> f32 = cast(2.0, f32)
def smoke_optim() -> f32 = {
  g = golden_section_search(smoke_optim_parab, cast(0.0, f32), cast(5.0, f32), cast(1e-8, f32), cast(200, int64))
  b = brent_minimize(smoke_optim_parab, cast(0.0, f32), cast(5.0, f32), cast(1e-8, f32), cast(200, int64))
  gd = gradient_descent_1d(smoke_optim_parab, smoke_optim_dparab, cast(0.0, f32), cast(0.1, f32), cast(500, int64))
  nm = newton_minimize_1d(smoke_optim_parab, smoke_optim_dparab, smoke_optim_ddparab, cast(0.0, f32), cast(1e-10, f32), cast(50, int64))
  add(add(add(g, b), gd), nm)
}
def smoke_interpolation[n](ys: tensor[n, f32]) -> f32 = {
  lu = linear_interp_uniform(copy(ys), cast(0.0, f32), cast(1.0, f32), cast(0.5, f32))
  ignore_ls = ys
  ch = cubic_hermite(cast(0.0, f32), cast(1.0, f32), cast(0.0, f32), cast(1.0, f32), cast(0.0, f32), cast(0.0, f32), cast(0.5, f32))
  add(lu, ch)
}
def smoke_cg_solve[n](a_mat: tensor[n, n, f32], b: tensor[n, f32], x0: tensor[n, f32]) -> f32 = {
  x = cg_solve(a_mat, b, x0, cast(1e-10, f32), cast(100, int64))
  l2_norm_vec(x)
}
def smoke_lu_solve(a3: tensor[3, 3, f32], b3: tensor[3, f32]) -> f32 = {
  x = lu_solve(a3, b3)
  l2_norm_vec(x)
}
def smoke_sde_drift(y: f32, t: f32) -> f32 = neg(y)
def smoke_sde_diff(y: f32, t: f32) -> f32 = cast(0.1, f32)
def smoke_sde_dg(y: f32, t: f32) -> f32 = cast(0.0, f32)
def smoke_sde[n](noise: tensor[n, f32]) -> f32 = {
  em = euler_maruyama_fixed(smoke_sde_drift, smoke_sde_diff, cast(1.0, f32), cast(0.0, f32), cast(1.0, f32), copy(noise))
  ml = milstein_fixed(smoke_sde_drift, smoke_sde_diff, smoke_sde_dg, cast(1.0, f32), cast(0.0, f32), cast(1.0, f32), noise)
  add(em, ml)
}
def smoke_linalg_inv(a2: tensor[2, 2, f32], a3: tensor[3, 3, f32], b2: tensor[2, f32], b3: tensor[3, f32]) -> f32 = {
  inv2 = inv_2x2(copy(a2))
  inv3 = inv_3x3(copy(a3))
  sol2 = solve_2x2(copy(a2), b2)
  sol3 = solve_3x3(copy(a3), b3)
  eigs = eig_2x2_real(copy(a2))
  ch2 = cholesky_2x2(a2)
  chn = cholesky_n(copy(a3))
  d_inv2 = det_2x2(inv2)
  d_inv3 = det_3x3(inv3)
  d_ch2 = det_2x2(ch2)
  d_chn = det_3x3(chn)
  n_sol2 = l2_norm_vec(sol2)
  n_sol3 = l2_norm_vec(sol3)
  eig_sum = add(eigs.0, eigs.1)
  add(add(add(add(add(add(d_inv2, d_inv3), d_ch2), d_chn), n_sol2), n_sol3), eig_sum)
}
def smoke_integrate_adaptive_fn(x: f32) -> f32 = mul(x, x)
def smoke_integrate_adaptive() -> f32 = {
  a = adaptive_simpson(smoke_integrate_adaptive_fn, cast(0.0, f32), cast(1.0, f32), cast(1e-10, f32), cast(20, int64))
  r = romberg_5(smoke_integrate_adaptive_fn, cast(0.0, f32), cast(1.0, f32))
  g = gauss_legendre_10(smoke_integrate_adaptive_fn, cast(0.0, f32), cast(1.0, f32))
  add(add(a, r), g)
}
def smoke_hl_one(x: f32) -> f32 = cast(1.0, f32)
def smoke_integrate_hl() -> f32 = {
  gh = gauss_hermite_10(smoke_hl_one)
  gl = gauss_laguerre_10(smoke_hl_one)
  add(gh, gl)
}
def smoke_cf_model(x: f32, theta: f32) -> f32 = mul(theta, x)
def smoke_cf_dmodel(x: f32, theta: f32) -> f32 = x
def smoke_curvefit[n](xs: tensor[n, f32], ys: tensor[n, f32]) -> f32 = lm_scalar_1param(smoke_cf_model, smoke_cf_dmodel, xs, ys, cast(0.5, f32), cast(0.001, f32), cast(1e-8, f32), cast(50, int64))
def smoke_distributions_p4() -> f32 = {
  pp = poisson_pmf(cast(3.0, f32), cast(3.0, f32))
  pc = poisson_cdf(cast(3.0, f32), cast(3.0, f32))
  bp = binomial_pmf(cast(5.0, f32), cast(10.0, f32), cast(0.5, f32))
  bc = binomial_cdf(cast(5.0, f32), cast(10.0, f32), cast(0.5, f32))
  bep = beta_pdf(cast(0.5, f32), cast(2.0, f32), cast(3.0, f32))
  bec = beta_cdf(cast(0.5, f32), cast(2.0, f32), cast(3.0, f32))
  fp = f_pdf(cast(1.0, f32), cast(5.0, f32), cast(10.0, f32))
  fc = f_cdf(cast(1.0, f32), cast(5.0, f32), cast(10.0, f32))
  wp = weibull_pdf(cast(1.0, f32), cast(2.0, f32), cast(1.0, f32))
  wc = weibull_cdf(cast(1.0, f32), cast(2.0, f32), cast(1.0, f32))
  wi = weibull_inv_cdf(cast(0.5, f32), cast(2.0, f32), cast(1.0, f32))
  s1 = add(add(add(pp, pc), bp), bc)
  s2 = add(add(add(bep, bec), fp), fc)
  s3 = add(add(wp, wc), wi)
  add(add(s1, s2), s3)
}
def smoke_qr(a3: tensor[3, 3, f32]) -> f32 = {
  qr_q = qr_decompose(copy(a3))
  qr_r = qr_decompose(a3)
  q = qr_q.0
  r = qr_r.1
  add(det_3x3(q), det_3x3(r))
}
def smoke_stats_p4[n](v: tensor[n, f32]) -> f32 = {
  mn = min_vec(copy(v))
  mx = max_vec(copy(v))
  rg = range_vec(copy(v))
  q = quantile_vec(copy(v), cast(0.5, f32))
  p = percentile_vec(copy(v), cast(75.0, f32))
  tm = trimmed_mean_vec(v, cast(0.1, f32))
  add(add(add(add(add(mn, mx), rg), q), p), tm)
}
def smoke_svd_n(a3: tensor[3, 3, f32]) -> f32 = {
  svd_u = svd_n(copy(a3))
  svd_s = svd_n(copy(a3))
  svd_vt = svd_n(a3)
  u = svd_u.0
  sigma = svd_s.1
  vt = svd_vt.2
  add(add(det_3x3(u), l2_norm_vec(sigma)), det_3x3(vt))
}
def smoke_lm_nparam(xs: tensor[3, f32], ys: tensor[3, f32], th0: tensor[2, f32]) -> f32 = {
  theta = lm_scalar_nparam(fn (th: &tensor[2, f32], xd: &tensor[3, f32]) -> scale_vec(xd, l2_norm_vec(th)), xs, ys, th0, cast(0.0001, f32), cast(5, int64))
  l2_norm_vec(theta)
}
def smoke_eig_n(a3: tensor[3, 3, f32]) -> f32 = {
  r_evals = eig_n(copy(a3))
  r_evecs = eig_n(a3)
  evals = r_evals.0
  evecs = r_evecs.1
  add(l2_norm_vec(evals), frobenius_norm(evecs))
}
def smoke_ode_grid_f(y: tensor[1, f32], t: f32) -> tensor[1, f32] = neg(y)
def smoke_ode_grid(y0: tensor[1, f32], t_out: tensor[4, f32]) -> f32 = {
  grid = rk45_adaptive_solve_grid(smoke_ode_grid_f, cast(0.0, f32), y0, cast(2.0, f32), cast(1e-6, f32), cast(1e-8, f32), t_out)
  frobenius_norm(grid)
}
def smoke_spline(xs: tensor[5, f32], ys: tensor[5, f32]) -> f32 = {
  v = spline_eval(copy(xs), copy(ys), cast(2.5, f32))
  m = spline_fit(xs, ys)
  add(v, l2_norm_vec(m))
}
def smoke_optimize() -> f32 = {
  mn = minimize(smoke_optim_parab, cast(0.0, f32), cast(5.0, f32), cast(1e-8, f32), cast(200, int64))
  rt = root(smoke_poly, cast(1.0, f32), cast(2.0, f32), cast(1e-7, f32), cast(100, int64))
  ad = optimize_ad_smoke(cast(2.5, f32))
  add(add(mn, rt), ad)
}
def smoke_info[n](p: tensor[n, f32], q: tensor[n, f32]) -> f32 = {
  h = entropy(copy(p))
  ce = cross_entropy(copy(p), copy(q))
  kl = kl_divergence(p, q)
  add(add(h, ce), kl)
}
def smoke_stats_inference[n](p: tensor[n, f32], a: tensor[n, f32], b: tensor[n, f32]) -> f32 = {
  bf = bonferroni_adjust(copy(p))
  hm = stat_holm_adjust(copy(p))
  bh = benjamini_hochberg_adjust(copy(p))
  fd = fdr_adjust(p)
  lr = likelihood_ratio_stat(cast(-12.0, f32), cast(-10.0, f32))
  lp = likelihood_ratio_p_value(cast(-12.0, f32), cast(-10.0, f32), cast(1.0, f32))
  cv = covariance_2x2(copy(a), copy(b), cast(1, int64))
  cr = correlation_2x2(copy(a), copy(b))
  cva = covariance_matrix_2(copy(a), copy(b), cast(1, int64))
  cra = correlation_matrix_2(a, b)
  add(add(add(add(l2_norm_vec(bf), l2_norm_vec(hm)), add(l2_norm_vec(bh), l2_norm_vec(fd))), add(lr, lp)), add(add(frobenius_norm(cv), frobenius_norm(cr)), add(frobenius_norm(cva), frobenius_norm(cra))))
}
def smoke_statespace() -> f32 = {
  pred = kalman_predict_scalar(cast(10.0, f32), cast(4.0, f32), cast(1.0, f32), cast(1.0, f32), cast(0.0, f32), cast(0.0, f32))
  upd = kalman_update_scalar(pred.0, pred.1, cast(12.0, f32), cast(1.0, f32), cast(3.0, f32))
  step = kalman_step_scalar(cast(10.0, f32), cast(4.0, f32), cast(12.0, f32), cast(1.0, f32), cast(1.0, f32), cast(1.0, f32), cast(3.0, f32))
  lp = local_level_predict(cast(10.0, f32), cast(4.0, f32), cast(1.0, f32))
  lu = local_level_update(lp.0, lp.1, cast(12.0, f32), cast(3.0, f32))
  ls = local_level_step(cast(10.0, f32), cast(4.0, f32), cast(12.0, f32), cast(1.0, f32), cast(3.0, f32))
  add(add(add(pred.0, upd.0), add(step.0, lp.0)), add(lu.0, ls.0))
}
def smoke_timeseries[n](values: tensor[n, f32]) -> f32 = {
  a = ts_ewma_next(copy(values), cast(0.5, f32), cast(0.0, f32))
  s = ts_ewma_series(copy(values), cast(0.5, f32), cast(0.0, f32))
  e = exponential_smoothing_next(copy(values), cast(0.5, f32), cast(0.0, f32))
  es = exponential_smoothing_series(copy(values), cast(0.5, f32), cast(0.0, f32))
  ar = ar1_predict_next(copy(values), cast(0.1, f32), cast(0.9, f32))
  arma = arma11_predict_next(copy(values), cast(0.1, f32), cast(0.9, f32), cast(0.2, f32), cast(0.3, f32))
  arima = arima110_predict_next(values, cast(0.1, f32), cast(0.9, f32), cast(0.2, f32), cast(0.3, f32))
  add(add(add(a, l2_norm_vec(s)), add(e, l2_norm_vec(es))), add(add(ar, arma), arima))
}
