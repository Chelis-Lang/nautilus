module Nautilus.ExampleDistributions
import Nautilus.Distributions (normal_cdf, normal_inv_cdf, student_t_cdf, gamma_cdf, gamma_sf, chi_squared_cdf)
import Nautilus.Testing (z_statistic, z_p_value_two_sided, normal_ci_half_width, t_statistic_one_sample, t_p_value_two_sided)
export (example_z_test, example_two_sided_p, example_ci_95, example_t_test, example_normal_quantile_975, example_gamma_cdf_degenerate_arguments)
def example_z_test() -> f32 = z_statistic(cast(105.0, f32), cast(100.0, f32), cast(15.0, f32), cast(36.0, f32))
def example_two_sided_p() -> f32 = z_p_value_two_sided(cast(2.0, f32))
def example_ci_95() -> f32 = normal_ci_half_width(cast(0.95, f32), cast(12.0, f32), cast(49.0, f32))
def example_t_test() -> f32 = {
  t = t_statistic_one_sample(cast(5.2, f32), cast(1.0, f32), cast(25.0, f32), cast(5.0, f32))
  t_p_value_two_sided(t, cast(24.0, f32))
}
def example_normal_quantile_975() -> f32 = normal_inv_cdf(cast(0.975, f32), cast(0.0, f32), cast(1.0, f32))
def example_gamma_cdf_degenerate_arguments() -> f32 = {
  inf_x = div(cast(1.0, f32), cast(0.0, f32))
  zero_scale = gamma_cdf(cast(1.0, f32), cast(2.0, f32), cast(0.0, f32))
  cdf_at_inf = gamma_cdf(inf_x, cast(2.0, f32), cast(1.0, f32))
  chi_at_inf = chi_squared_cdf(inf_x, cast(3.0, f32))
  sf_at_inf = gamma_sf(inf_x, cast(2.0, f32), cast(1.0, f32))
  large_df = chi_squared_cdf(cast(4000.0, f32), cast(4000.0, f32))
  r1 = if neq(zero_scale, zero_scale) then cast(1.0, f32) else cast(0.0, f32)
  r2 = if eq(cdf_at_inf, cast(1.0, f32)) then cast(10.0, f32) else cast(0.0, f32)
  r3 = if eq(chi_at_inf, cast(1.0, f32)) then cast(100.0, f32) else cast(0.0, f32)
  r4 = if eq(sf_at_inf, cast(0.0, f32)) then cast(1000.0, f32) else cast(0.0, f32)
  r5 = if lt(abs(sub(large_df, cast(0.50297356, f32))), cast(0.001, f32)) then cast(10000.0, f32) else cast(0.0, f32)
  add(add(add(add(r1, r2), r3), r4), r5)
}
