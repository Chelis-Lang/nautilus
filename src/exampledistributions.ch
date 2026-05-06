module Nautilus.ExampleDistributions
import Nautilus.Distributions (normal_cdf, normal_inv_cdf, student_t_cdf)
import Nautilus.Testing (
  z_statistic, z_p_value_two_sided, normal_ci_half_width,
  t_statistic_one_sample, t_p_value_two_sided
)
export (
  example_z_test,
  example_two_sided_p,
  example_ci_95,
  example_t_test,
  example_normal_quantile_975
)

def example_z_test() -> f32 =
  z_statistic(cast(105.0, f32), cast(100.0, f32), cast(15.0, f32), cast(36.0, f32))

def example_two_sided_p() -> f32 =
  z_p_value_two_sided(cast(2.0, f32))

def example_ci_95() -> f32 =
  normal_ci_half_width(cast(0.95, f32), cast(12.0, f32), cast(49.0, f32))

def example_t_test() -> f32 = {
  t = t_statistic_one_sample(cast(5.2, f32), cast(1.0, f32), cast(25.0, f32), cast(5.0, f32))
  t_p_value_two_sided(t, cast(24.0, f32))
}

def example_normal_quantile_975() -> f32 =
  normal_inv_cdf(cast(0.975, f32), cast(0.0, f32), cast(1.0, f32))
