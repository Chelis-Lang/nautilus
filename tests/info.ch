module Nautilus.Tests.Info
import Nautilus.Info (entropy, cross_entropy, kl_divergence)
import Std.Test (assert_close, assert_true)
def test_entropy_uniform_two() -> unit ! { Test } = {
  p = to_tensor([cast(0.5, f32), cast(0.5, f32)])
  assert_close(entropy(p), cast(0.6931472, f32), cast(0.000001, f32), "entropy([0.5,0.5]) = ln(2)")
}
def test_cross_entropy_matches_entropy_when_equal() -> unit ! { Test } = {
  p = to_tensor([cast(0.25, f32), cast(0.75, f32)])
  ce = cross_entropy(copy(p), copy(p))
  h = entropy(p)
  assert_close(ce, h, cast(0.000001, f32), "cross_entropy(p,p) = entropy(p)")
}
def test_kl_divergence_nonnegative() -> unit ! { Test } = {
  p = to_tensor([cast(0.75, f32), cast(0.25, f32)])
  q = to_tensor([cast(0.5, f32), cast(0.5, f32)])
  assert_true(gte(kl_divergence(p, q), cast(0.0, f32)), "KL divergence is nonnegative")
}
