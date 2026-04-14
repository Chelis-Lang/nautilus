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
  det_2x2, det_3x3
)
import Nautilus.Roots (bisection, newton, brent)
import Nautilus.ODE (euler_step, euler_solve, rk4_step, rk4_solve)
import Nautilus.Stats (
  mean_vec, variance_vec, std_vec,
  skewness_vec, kurtosis_vec, median_vec,
  covariance_scalar, correlation_scalar
)
export (smoke_special, smoke_distributions, smoke_linalg, smoke_roots, smoke_ode, smoke_stats)

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
