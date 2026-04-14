module Nautilus.Testing
import Nautilus.Special (erf, erfinv)
import Nautilus.Distributions (normal_cdf, normal_inv_cdf, chi_squared_cdf)
export (
  z_statistic,
  z_p_value_two_sided,
  z_p_value_upper,
  z_p_value_lower,
  normal_ci_half_width,
  chi_squared_p_value
)

def t_abs_f32(x: f32) -> f32 = if lt(x, cast(0.0, f32)) then neg(x) else x

def z_statistic(sample_mean: f32, pop_mean: f32, pop_std: f32, sample_n: f32) -> f32 = {
  diff = sub(sample_mean, pop_mean)
  sqrt_n = sqrt(sample_n)
  se = div(pop_std, sqrt_n)
  div(diff, se)
}

def z_p_value_two_sided(z: f32) -> f32 = {
  az = t_abs_f32(z)
  upper = normal_cdf(az, cast(0.0, f32), cast(1.0, f32))
  tail = sub(cast(1.0, f32), upper)
  mul(cast(2.0, f32), tail)
}

def z_p_value_upper(z: f32) -> f32 = {
  cdf = normal_cdf(z, cast(0.0, f32), cast(1.0, f32))
  sub(cast(1.0, f32), cdf)
}

def z_p_value_lower(z: f32) -> f32 = normal_cdf(z, cast(0.0, f32), cast(1.0, f32))

def normal_ci_half_width(confidence: f32, pop_std: f32, sample_n: f32) -> f32 = {
  alpha = sub(cast(1.0, f32), confidence)
  half_alpha = mul(cast(0.5, f32), alpha)
  q = sub(cast(1.0, f32), half_alpha)
  z_crit = normal_inv_cdf(q, cast(0.0, f32), cast(1.0, f32))
  sqrt_n = sqrt(sample_n)
  se = div(pop_std, sqrt_n)
  mul(z_crit, se)
}

def chi_squared_p_value(statistic: f32, df: f32) -> f32 = {
  cdf = chi_squared_cdf(statistic, df)
  sub(cast(1.0, f32), cdf)
}
