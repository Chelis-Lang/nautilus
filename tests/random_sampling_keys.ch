module Nautilus.Tests.RandomSamplingKeys
import Nautilus.Distributions (uniform_sample, exponential_sample, normal_sample, lognormal_sample, gamma_sample, chi_squared_sample, student_t_sample)
import Std.Test (assert_true)
def sample_template_three() -> tensor[3, f32] = to_tensor([0.0f32, 0.0f32, 0.0f32])
def sample_template_one() -> tensor[1, f32] = to_tensor([0.0f32])
def test_uniform_key_replay() -> unit ! { Test } = {
  a = uniform_sample(key_from_seed(42i64), sample_template_three(), 2.0f32, 5.0f32)
  b = uniform_sample(key_from_seed(42i64), sample_template_three(), 2.0f32, 5.0f32)
  aa = to_list(a)
  bb = to_list(b)
  _ = assert_true(eq(index(aa, 0i64), index(bb, 0i64)), "same key repeats the uniform draw")
  assert_true(and(gte(index(aa, 1i64), 2.0f32), lt(index(bb, 1i64), 5.0f32)), "uniform values stay within bounds")
}
def test_normal_key_replay_after_split() -> unit ! { Test } = {
  (left, right) = split_key(key_from_seed(7i64))
  (replay, _) = split_key(key_from_seed(7i64))
  a = normal_sample(left, sample_template_three(), 0.0f32, 1.0f32)
  b = normal_sample(replay, sample_template_three(), 0.0f32, 1.0f32)
  c = normal_sample(right, sample_template_three(), 0.0f32, 1.0f32)
  aa = to_list(a)
  bb = to_list(b)
  cc = to_list(c)
  _ = assert_true(eq(index(aa, 0i64), index(bb, 0i64)), "normal replay uses the same two child draws")
  assert_true(neq(index(aa, 0i64), index(cc, 0i64)), "distinct child keys draw differently")
}
def test_other_sampler_key_calls() -> unit ! { Test } = {
  e = exponential_sample(key_from_seed(11i64), sample_template_one(), 2.0f32)
  l = lognormal_sample(key_from_seed(12i64), sample_template_one(), 0.0f32, 1.0f32)
  g = gamma_sample(key_from_seed(13i64), sample_template_one(), 2.0f32, 1.0f32)
  c = chi_squared_sample(key_from_seed(14i64), sample_template_one(), 4.0f32)
  t = student_t_sample(key_from_seed(15i64), sample_template_one(), 4.0f32)
  _ = assert_true(gte(index(to_list(e), 0i64), 0.0f32), "exponential sample is nonnegative")
  _ = assert_true(gt(index(to_list(l), 0i64), 0.0f32), "lognormal sample is positive")
  _ = assert_true(gt(index(to_list(g), 0i64), 0.0f32), "gamma sample is positive")
  _ = assert_true(gt(index(to_list(c), 0i64), 0.0f32), "chi-squared sample is positive")
  assert_true(eq(index(to_list(t), 0i64), index(to_list(student_t_sample(key_from_seed(15i64), sample_template_one(), 4.0f32)), 0i64)), "Student-t replay is exact")
}
def test_keyed_families_preserve_three_element_shape() -> unit ! { Test } = {
  e = exponential_sample(key_from_seed(31i64), sample_template_three(), 2.0f32)
  l = lognormal_sample(key_from_seed(32i64), sample_template_three(), 0.0f32, 1.0f32)
  c = chi_squared_sample(key_from_seed(33i64), sample_template_three(), 4.0f32)
  t = student_t_sample(key_from_seed(34i64), sample_template_three(), 4.0f32)
  _ = assert_true(eq(numel(e), 3i64), "exponential output keeps template extent")
  _ = assert_true(eq(numel(l), 3i64), "lognormal output keeps template extent")
  _ = assert_true(eq(numel(c), 3i64), "chi-squared output keeps template extent")
  assert_true(eq(numel(t), 3i64), "Student-t output keeps template extent")
}
