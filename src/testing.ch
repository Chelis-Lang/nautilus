module Nautilus.Testing
import Nautilus.Special (erf, erfinv)
import Nautilus.Distributions (normal_cdf, normal_inv_cdf, chi_squared_cdf, student_t_cdf)
export (z_statistic, z_p_value_two_sided, z_p_value_upper, z_p_value_lower, normal_ci_half_width, chi_squared_p_value, t_statistic_one_sample, t_statistic_two_sample_pooled, t_p_value_two_sided, t_p_value_upper, t_p_value_lower, welch_t_statistic, welch_t_df)
def t_abs_f32(x: f32) -> f32 = if lt(x, cast(0.0, f32)) then neg(x) else x
def z_statistic(sample_mean: f32, pop_mean: f32, pop_std: f32, sample_n: f32) -> f32 = {
  diff = sub(sample_mean, pop_mean)
  sqrt_n = sqrt(sample_n)
  se = div(pop_std, sqrt_n)
  __borrow_migration_out_0 = div(diff, se)
  _ = drop(diff)
  __borrow_migration_out_0
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
def t_statistic_one_sample(sample_mean: f32, sample_std: f32, sample_n: f32, pop_mean: f32) -> f32 = {
  diff = sub(sample_mean, pop_mean)
  sqrt_n = sqrt(sample_n)
  se = div(sample_std, sqrt_n)
  __borrow_migration_out_1 = div(diff, se)
  _ = drop(diff)
  __borrow_migration_out_1
}
def t_statistic_two_sample_pooled(mean1: f32, std1: f32, n1: f32, mean2: f32, std2: f32, n2: f32) -> f32 = {
  one = cast(1.0, f32)
  diff = sub(mean1, mean2)
  var1 = mul(std1, std1)
  var2 = mul(std2, std2)
  df1 = sub(n1, one)
  df2 = sub(n2, one)
  ssq = add(mul(df1, var1), mul(df2, var2))
  pooled_df = add(df1, df2)
  sp2 = div(ssq, pooled_df)
  inv_sum = add(div(one, n1), div(one, n2))
  se_sq = mul(sp2, inv_sum)
  se = sqrt(se_sq)
  __borrow_migration_out_2 = div(diff, se)
  _ = drop(diff)
  __borrow_migration_out_2
}
def welch_t_statistic(mean1: f32, std1: f32, n1: f32, mean2: f32, std2: f32, n2: f32) -> f32 = {
  diff = sub(mean1, mean2)
  var1 = mul(std1, std1)
  var2 = mul(std2, std2)
  t1 = div(var1, n1)
  t2 = div(var2, n2)
  se_sq = add(t1, t2)
  se = sqrt(se_sq)
  __borrow_migration_out_3 = div(diff, se)
  _ = drop(diff)
  _ = drop(t1)
  _ = drop(t2)
  __borrow_migration_out_3
}
def welch_t_df(std1: f32, n1: f32, std2: f32, n2: f32) -> f32 = {
  one = cast(1.0, f32)
  var1 = mul(std1, std1)
  var2 = mul(std2, std2)
  t1 = div(var1, n1)
  t2 = div(var2, n2)
  num_sum = add(t1, t2)
  num = mul(num_sum, num_sum)
  t1_sq = mul(t1, t1)
  t2_sq = mul(t2, t2)
  den1 = div(t1_sq, sub(n1, one))
  den2 = div(t2_sq, sub(n2, one))
  den = add(den1, den2)
  __borrow_migration_out_4 = div(num, den)
  _ = drop(t1)
  _ = drop(t2)
  __borrow_migration_out_4
}
def t_p_value_two_sided(t: f32, df: f32) -> f32 = {
  at = t_abs_f32(t)
  upper = student_t_cdf(at, df)
  tail = sub(cast(1.0, f32), upper)
  __borrow_migration_out_0 = mul(cast(2.0, f32), tail)
  _ = drop(at)
  __borrow_migration_out_0
}
def t_p_value_upper(t: f32, df: f32) -> f32 = {
  cdf = student_t_cdf(t, df)
  sub(cast(1.0, f32), cdf)
}
def t_p_value_lower(t: f32, df: f32) -> f32 = student_t_cdf(t, df)
