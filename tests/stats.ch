module Nautilus.Tests.Stats

-- Identity / structural tests for Nautilus.Stats.
-- All expected values are mathematical identities, exact constants,
-- or documented closed-form results. No scipy-derived numerics.
--
-- NOTE on variance/std signature: variance_vec(v, ddof) and std_vec(v, ddof)
-- use denominator (N - ddof). ddof=0 -> population, ddof=1 -> sample.

import Nautilus.Stats (mean_vec, variance_vec, std_vec,
                      median_vec, min_vec, max_vec, range_vec)
import Std.Test (assert_close, assert_true)

-- ===== mean_vec =====

def test_mean_constant() -> unit ! { Test } = {
  -- mean of a constant vector is the constant
  v = to_tensor([cast(7.0, f32), cast(7.0, f32), cast(7.0, f32),
                 cast(7.0, f32), cast(7.0, f32)])
  assert_close(mean_vec(v), cast(7.0, f32), cast(1.0e-6, f32),
               "mean of constant vector = constant")
}

def test_mean_zero_vector() -> unit ! { Test } = {
  -- mean of all-zero vector is zero
  v = to_tensor([cast(0.0, f32), cast(0.0, f32), cast(0.0, f32)])
  assert_close(mean_vec(v), cast(0.0, f32), cast(1.0e-6, f32),
               "mean of zero vector = 0")
}

def test_mean_arithmetic_progression_5() -> unit ! { Test } = {
  -- mean of [1..5] = (1 + 5) / 2 = 3
  v = to_tensor([cast(1.0, f32), cast(2.0, f32), cast(3.0, f32),
                 cast(4.0, f32), cast(5.0, f32)])
  assert_close(mean_vec(v), cast(3.0, f32), cast(1.0e-6, f32),
               "mean(1..5) = 3")
}

def test_mean_arithmetic_progression_6() -> unit ! { Test } = {
  -- mean of [1..6] = (1 + 6) / 2 = 3.5
  v = to_tensor([cast(1.0, f32), cast(2.0, f32), cast(3.0, f32),
                 cast(4.0, f32), cast(5.0, f32), cast(6.0, f32)])
  assert_close(mean_vec(v), cast(3.5, f32), cast(1.0e-6, f32),
               "mean(1..6) = 3.5")
}

def test_mean_homogeneity() -> unit ! { Test } = {
  -- mean(2 * v) = 2 * mean(v); for v = [1,2,3], mean(v) = 2, mean(2v) = 4
  v2 = to_tensor([cast(2.0, f32), cast(4.0, f32), cast(6.0, f32)])
  base = to_tensor([cast(1.0, f32), cast(2.0, f32), cast(3.0, f32)])
  lhs = mean_vec(v2)
  rhs = mul(cast(2.0, f32), mean_vec(base))
  assert_close(lhs, rhs, cast(1.0e-6, f32),
               "mean(2v) = 2 * mean(v)")
}

-- ===== variance_vec =====

def test_variance_constant_zero_pop() -> unit ! { Test } = {
  -- variance of a constant vector is 0 (any ddof < N)
  v = to_tensor([cast(5.0, f32), cast(5.0, f32), cast(5.0, f32), cast(5.0, f32)])
  assert_close(variance_vec(v, cast(0, int64)), cast(0.0, f32),
               cast(1.0e-6, f32), "population variance of constant = 0")
}

def test_variance_constant_zero_sample() -> unit ! { Test } = {
  -- sample variance of a constant vector is also 0
  v = to_tensor([cast(5.0, f32), cast(5.0, f32), cast(5.0, f32), cast(5.0, f32)])
  assert_close(variance_vec(v, cast(1, int64)), cast(0.0, f32),
               cast(1.0e-6, f32), "sample variance of constant = 0")
}

def test_variance_two_points_population() -> unit ! { Test } = {
  -- v = [0, 2], mean = 1, sum_sq_dev = 1 + 1 = 2; population (ddof=0) = 2/2 = 1
  v = to_tensor([cast(0.0, f32), cast(2.0, f32)])
  assert_close(variance_vec(v, cast(0, int64)), cast(1.0, f32),
               cast(1.0e-6, f32), "population variance of [0,2] = 1")
}

def test_variance_two_points_sample() -> unit ! { Test } = {
  -- v = [0, 2], sum_sq_dev = 2; sample (ddof=1) = 2/1 = 2
  v = to_tensor([cast(0.0, f32), cast(2.0, f32)])
  assert_close(variance_vec(v, cast(1, int64)), cast(2.0, f32),
               cast(1.0e-6, f32), "sample variance of [0,2] = 2")
}

def test_variance_nonnegative() -> unit ! { Test } = {
  -- variance is always nonnegative (population, ddof=0)
  v = to_tensor([cast(-3.5, f32), cast(1.2, f32), cast(4.8, f32),
                 cast(-1.0, f32), cast(2.7, f32)])
  vv = variance_vec(v, cast(0, int64))
  assert_true(gte(vv, cast(0.0, f32)), "variance >= 0 for any vector")
}

-- ===== std_vec =====

def test_std_constant_zero() -> unit ! { Test } = {
  -- std of a constant vector is 0 (sqrt of 0)
  v = to_tensor([cast(3.0, f32), cast(3.0, f32), cast(3.0, f32)])
  assert_close(std_vec(v, cast(0, int64)), cast(0.0, f32),
               cast(1.0e-6, f32), "std of constant = 0")
}

def test_std_sqrt_variance_identity() -> unit ! { Test } = {
  -- std_vec(v, ddof) = sqrt(variance_vec(v, ddof))
  v = to_tensor([cast(1.0, f32), cast(2.0, f32), cast(4.0, f32),
                 cast(7.0, f32), cast(11.0, f32)])
  s = std_vec(copy(v), cast(0, int64))
  rhs = sqrt(variance_vec(v, cast(0, int64)))
  assert_close(s, rhs, cast(1.0e-6, f32),
               "std(v) = sqrt(variance(v))")
}

def test_std_two_point_closed_form() -> unit ! { Test } = {
  -- v = [0, 2], population variance = 1, so std = sqrt(1) = 1 exactly
  v = to_tensor([cast(0.0, f32), cast(2.0, f32)])
  assert_close(std_vec(v, cast(0, int64)), cast(1.0, f32),
               cast(1.0e-6, f32), "std([0,2], pop) = 1")
}

-- ===== min_vec / max_vec / range_vec =====

def test_min_unsorted_input() -> unit ! { Test } = {
  -- min([3, 1, 2]) = 1
  v = to_tensor([cast(3.0, f32), cast(1.0, f32), cast(2.0, f32)])
  assert_close(min_vec(v), cast(1.0, f32), cast(1.0e-6, f32),
               "min([3,1,2]) = 1")
}

def test_max_unsorted_input() -> unit ! { Test } = {
  -- max([3, 1, 2]) = 3
  v = to_tensor([cast(3.0, f32), cast(1.0, f32), cast(2.0, f32)])
  assert_close(max_vec(v), cast(3.0, f32), cast(1.0e-6, f32),
               "max([3,1,2]) = 3")
}

def test_min_le_max() -> unit ! { Test } = {
  -- min(v) <= max(v) for any vector
  v = to_tensor([cast(-2.5, f32), cast(0.4, f32), cast(7.1, f32),
                 cast(3.3, f32), cast(-1.0, f32)])
  mn = min_vec(copy(v))
  mx = max_vec(v)
  assert_true(lte(mn, mx), "min(v) <= max(v)")
}

def test_range_max_minus_min() -> unit ! { Test } = {
  -- range_vec(v) = max_vec(v) - min_vec(v); for [3,1,2] -> 3 - 1 = 2
  v = to_tensor([cast(3.0, f32), cast(1.0, f32), cast(2.0, f32)])
  assert_close(range_vec(v), cast(2.0, f32), cast(1.0e-6, f32),
               "range([3,1,2]) = 2")
}

-- ===== median_vec =====

def test_median_odd_length() -> unit ! { Test } = {
  -- median of [3, 1, 2] (sorted: [1,2,3]) = 2
  v = to_tensor([cast(3.0, f32), cast(1.0, f32), cast(2.0, f32)])
  assert_close(median_vec(v), cast(2.0, f32), cast(1.0e-6, f32),
               "median([3,1,2]) = 2")
}

def test_median_even_length() -> unit ! { Test } = {
  -- median of [1,2,3,4] = (2 + 3) / 2 = 2.5
  v = to_tensor([cast(1.0, f32), cast(2.0, f32), cast(3.0, f32), cast(4.0, f32)])
  assert_close(median_vec(v), cast(2.5, f32), cast(1.0e-6, f32),
               "median([1,2,3,4]) = 2.5")
}

def test_median_constant() -> unit ! { Test } = {
  -- median of constant vector is the constant
  v = to_tensor([cast(4.0, f32), cast(4.0, f32), cast(4.0, f32),
                 cast(4.0, f32), cast(4.0, f32)])
  assert_close(median_vec(v), cast(4.0, f32), cast(1.0e-6, f32),
               "median of constant = constant")
}
