module Nautilus.ExampleDistributions
import Nautilus.Distributions (normal_cdf, normal_inv_cdf, student_t_cdf, gamma_cdf, gamma_sf, chi_squared_cdf, beta_cdf, f_cdf, binomial_cdf)
import Nautilus.Testing (z_statistic, z_p_value_two_sided, normal_ci_half_width, t_statistic_one_sample, t_p_value_two_sided)
export (example_z_test, example_two_sided_p, example_ci_95, example_t_test, example_normal_quantile_975, example_gamma_cdf_degenerate_arguments, example_beta_family_large_parameters)
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
-- A regression that returned the incomplete beta to f32, or that flattened its
-- chunked recursion, is invisible to `chelis test`: that lane's worker holds
-- about 500 frames, so a flat recursion completes there. `chelis eval --file`
-- holds far fewer and aborts the whole process instead, and CI's step that
-- evaluates `src/example*.ch` is the only gate that observes it. So this
-- detector lives in an example module rather than in `tests/`.
-- Each case contributes one decimal digit, so one f32 says which hold. Expect
-- 11111.0; before the incomplete beta moved to f64 the first two cases aborted
-- the process and the rest returned 10 (f_cdf 1.0 for a true 0.317,
-- student_t 0.5 for a true 0.841,
-- binomial 1.0 for a true 0.990).
def example_beta_family_large_parameters() -> f32 = {
  tol = cast(0.00001, f32)
  -- 0.5 exactly, by symmetry; needs 726 and 1564 f64 continued-fraction
  -- iterations, so both are past the 535 a flattened recursion survives.
  b7 = beta_cdf(cast(0.5, f32), cast(10000000.0, f32), cast(10000000.0, f32))
  b8 = beta_cdf(cast(0.5, f32), cast(100000000.0, f32), cast(100000000.0, f32))
  d1 = if lt(ex_rel(b7, cast(0.5, f32)), tol) then cast(10000.0, f32) else cast(0.0, f32)
  d2 = if lt(ex_rel(b8, cast(0.5, f32)), tol) then cast(1000.0, f32) else cast(0.0, f32)
  -- the three argument-saturation cases, one per remaining export
  fv = f_cdf(cast(1.0, f32), cast(100000000.0, f32), cast(1.0, f32))
  tv = student_t_cdf(cast(1.0, f32), cast(100000000.0, f32))
  bv = binomial_cdf(cast(0.0, f32), cast(1000000.0, f32), cast(1e-8, f32))
  d3 = if lt(ex_rel(fv, cast(0.3173105, f32)), tol) then cast(100.0, f32) else cast(0.0, f32)
  d4 = if lt(ex_rel(tv, cast(0.8413447, f32)), tol) then cast(10.0, f32) else cast(0.0, f32)
  d5 = if lt(ex_rel(bv, cast(0.99004984, f32)), tol) then cast(1.0, f32) else cast(0.0, f32)
  add(add(add(add(d1, d2), d3), d4), d5)
}
def ex_rel(v: f32, ref: f32) -> f32 = {
  d = sub(v, ref)
  a = if lt(d, cast(0.0, f32)) then neg(d) else d
  div(a, ref)
}
