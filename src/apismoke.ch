module Nautilus.Apismoke
import Nautilus.Special (erf, erfinv, log_gamma, digamma, beta, lbeta)
import Nautilus.Distributions (
  normal_pdf, normal_cdf, normal_inv_cdf,
  uniform_pdf, uniform_cdf, uniform_inv_cdf,
  exponential_pdf, exponential_cdf, exponential_inv_cdf,
  lognormal_pdf, lognormal_cdf, lognormal_inv_cdf,
  gamma_pdf, gamma_cdf, gamma_inv_cdf,
  chi_squared_pdf, chi_squared_cdf, chi_squared_inv_cdf,
  student_t_pdf
)
import Nautilus.LinAlg (
  transpose, matmul_wrap, gram, aat,
  diag, trace_mat, trace_scalar,
  l2_norm_vec, inner_product, frobenius_sq, frobenius_norm,
  scale_vec, matvec, vecmat,
  det_2x2, det_3x3,
  la_vec_add, la_vec_sub, la_vec_saxpy, cg_solve,
  inv_2x2, inv_3x3, solve_2x2, solve_3x3, eig_2x2_real, cholesky_2x2
)
import Nautilus.Roots (bisection, newton, brent)
import Nautilus.ODE (euler_step, euler_solve, rk4_step, rk4_solve)
import Nautilus.Stats (
  mean_vec, variance_vec, std_vec,
  skewness_vec, kurtosis_vec, median_vec,
  covariance_scalar, correlation_scalar
)
import Nautilus.Integrate (trapezoidal, simpsons, gauss_legendre_5)
import Nautilus.Testing (
  z_statistic, z_p_value_two_sided, z_p_value_upper, z_p_value_lower,
  normal_ci_half_width, chi_squared_p_value
)
import Nautilus.Distance (
  squared_euclidean, euclidean, manhattan, chebyshev,
  cosine_similarity, cosine_distance,
  mahalanobis_squared, mahalanobis
)
import Nautilus.Signal (
  fft_magnitude_stub, ifft_magnitude_stub, stft_magnitude_stub,
  lowpass_stub, highpass_stub, bandpass_stub, fftfreq
)
import Nautilus.Optim (golden_section_search, brent_minimize, gradient_descent_1d, newton_minimize_1d)
import Nautilus.Interpolation (linear_interp_uniform, linear_interp_sorted, cubic_hermite)
import Nautilus.SDE (euler_maruyama_fixed, milstein_fixed)
import Nautilus.Integrate (
  trapezoidal, simpsons, gauss_legendre_5,
  adaptive_simpson, romberg_5, gauss_legendre_10
)
export (
  smoke_special, smoke_distributions, smoke_linalg,
  smoke_roots, smoke_ode, smoke_stats,
  smoke_integrate, smoke_testing, smoke_distance, smoke_signal,
  smoke_optim, smoke_interpolation, smoke_cg_solve,
  smoke_sde, smoke_linalg_inv, smoke_integrate_adaptive
)

def smoke_poly(x: f32) -> f32 = {
  x2 = mul(x, x)
  sub(x2, cast(2.0, f32))
}
def smoke_dpoly(x: f32) -> f32 = mul(cast(2.0, f32), x)
def smoke_decay(y: f32, t: f32) -> f32 = neg(y)

def smoke_special() -> f32 = {
  e = erf(cast(0.5, f32))
  ei = erfinv(cast(0.5, f32))
  lg = log_gamma(cast(3.0, f32))
  dg = digamma(cast(3.0, f32))
  b  = beta(cast(2.0, f32), cast(3.0, f32))
  lb = lbeta(cast(2.0, f32), cast(3.0, f32))
  add(add(add(add(add(e, ei), lg), dg), b), lb)
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
  ab = matmul_wrap(copy(a), b)
  ignore_ab = ab
  g_mat = gram(copy(a))
  ignore_g = g_mat
  tr_val = trace_scalar(at)
  ignore_tr = tr_val
  aat_mat = aat(a)
  ignore_aat = aat_mat
  inner = inner_product(copy(v), w)
  n2 = l2_norm_vec(v)
  d2 = det_2x2(s)
  d3 = det_3x3(t3)
  add(add(add(inner, n2), d2), d3)
}

def smoke_roots() -> f32 = {
  r1 = bisection(smoke_poly, cast(1.0, f32), cast(2.0, f32), cast(1.0e-10, f32), cast(100, int64))
  r2 = newton(smoke_poly, smoke_dpoly, cast(1.5, f32), cast(1.0e-12, f32), cast(50, int64))
  r3 = brent(smoke_poly, cast(1.0, f32), cast(2.0, f32), cast(1.0e-10, f32), cast(100, int64))
  add(add(r1, r2), r3)
}

def smoke_ode() -> f32 = {
  a = euler_step(smoke_decay, cast(1.0, f32), cast(0.0, f32), cast(0.01, f32))
  b = rk4_step(smoke_decay, cast(1.0, f32), cast(0.0, f32), cast(0.01, f32))
  c = euler_solve(smoke_decay, cast(1.0, f32), cast(0.0, f32), cast(1.0, f32), cast(100, int64))
  d = rk4_solve(smoke_decay, cast(1.0, f32), cast(0.0, f32), cast(1.0, f32), cast(100, int64))
  add(add(add(a, b), c), d)
}

def smoke_stats[n](v: tensor[n, f32], w: tensor[n, f32]) -> f32 = {
  m  = mean_vec(copy(v))
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
  g = golden_section_search(smoke_optim_parab, cast(0.0, f32), cast(5.0, f32), cast(1.0e-8, f32), cast(200, int64))
  b = brent_minimize(smoke_optim_parab, cast(0.0, f32), cast(5.0, f32), cast(1.0e-8, f32), cast(200, int64))
  gd = gradient_descent_1d(smoke_optim_parab, smoke_optim_dparab, cast(0.0, f32), cast(0.1, f32), cast(500, int64))
  nm = newton_minimize_1d(smoke_optim_parab, smoke_optim_dparab, smoke_optim_ddparab, cast(0.0, f32), cast(1.0e-10, f32), cast(50, int64))
  add(add(add(g, b), gd), nm)
}

def smoke_interpolation[n](ys: tensor[n, f32]) -> f32 = {
  lu = linear_interp_uniform(copy(ys), cast(0.0, f32), cast(1.0, f32), cast(0.5, f32))
  ignore_ls = ys
  ch = cubic_hermite(cast(0.0, f32), cast(1.0, f32), cast(0.0, f32), cast(1.0, f32), cast(0.0, f32), cast(0.0, f32), cast(0.5, f32))
  add(lu, ch)
}

def smoke_cg_solve[n](
  a_mat: tensor[n, n, f32],
  b: tensor[n, f32],
  x0: tensor[n, f32]
) -> f32 = {
  x = cg_solve(a_mat, b, x0, cast(1.0e-10, f32), cast(100, int64))
  l2_norm_vec(x)
}

def smoke_sde_drift(y: f32, t: f32) -> f32 = neg(y)
def smoke_sde_diff(y: f32, t: f32) -> f32 = cast(0.1, f32)
def smoke_sde_dg(y: f32, t: f32) -> f32 = cast(0.0, f32)

def smoke_sde[n](noise: tensor[n, f32]) -> f32 = {
  em = euler_maruyama_fixed(smoke_sde_drift, smoke_sde_diff,
    cast(1.0, f32), cast(0.0, f32), cast(1.0, f32), copy(noise))
  ml = milstein_fixed(smoke_sde_drift, smoke_sde_diff, smoke_sde_dg,
    cast(1.0, f32), cast(0.0, f32), cast(1.0, f32), noise)
  add(em, ml)
}

def smoke_linalg_inv(
  a2: tensor[2, 2, f32],
  a3: tensor[3, 3, f32],
  b2: tensor[2, f32],
  b3: tensor[3, f32]
) -> f32 = {
  inv2 = inv_2x2(copy(a2))
  inv3 = inv_3x3(copy(a3))
  sol2 = solve_2x2(copy(a2), b2)
  sol3 = solve_3x3(copy(a3), b3)
  eigs = eig_2x2_real(copy(a2))
  ch2 = cholesky_2x2(a2)
  d_inv2 = det_2x2(inv2)
  d_inv3 = det_3x3(inv3)
  d_ch2  = det_2x2(ch2)
  n_sol2 = l2_norm_vec(sol2)
  n_sol3 = l2_norm_vec(sol3)
  eig_sum = add(eigs.0, eigs.1)
  add(add(add(add(add(d_inv2, d_inv3), d_ch2), n_sol2), n_sol3), eig_sum)
}

def smoke_integrate_adaptive_fn(x: f32) -> f32 = mul(x, x)

def smoke_integrate_adaptive() -> f32 = {
  a  = adaptive_simpson(smoke_integrate_adaptive_fn, cast(0.0, f32), cast(1.0, f32), cast(1.0e-10, f32), cast(20, int64))
  r  = romberg_5(smoke_integrate_adaptive_fn, cast(0.0, f32), cast(1.0, f32))
  g  = gauss_legendre_10(smoke_integrate_adaptive_fn, cast(0.0, f32), cast(1.0, f32))
  add(add(a, r), g)
}
