module Nautilus.Tests.Sde
import Nautilus.Sde (euler_maruyama_fixed, milstein_fixed)
import Std.Test (assert_close, assert_true)
def decay_drift(y: f32, t: f32) -> f32 = neg(y)
def zero_drift(y: f32, t: f32) -> f32 = cast(0.0, f32)
def zero_diffusion(y: f32, t: f32) -> f32 = cast(0.0, f32)
def unit_diffusion(y: f32, t: f32) -> f32 = cast(1.0, f32)
def gbm_drift(y: f32, t: f32) -> f32 = mul(cast(0.1, f32), y)
def gbm_diffusion(y: f32, t: f32) -> f32 = mul(cast(0.2, f32), y)
def gbm_dg_dy(y: f32, t: f32) -> f32 = cast(0.2, f32)
def test_em_zero_noise_one_step_decay() -> unit ! { Test } = {
  noise = to_tensor([cast(0.0, f32)])
  y_em = euler_maruyama_fixed(decay_drift, zero_diffusion, cast(1.0, f32), cast(0.0, f32), cast(0.1, f32), noise)
  assert_close(y_em, cast(0.9, f32), cast(0.000001, f32), "EM(decay, g=0, z=0): y_next = 0.9 = forward Euler step")
}
def test_em_zero_noise_two_steps_decay() -> unit ! { Test } = {
  noise = to_tensor([cast(0.0, f32), cast(0.0, f32)])
  y_em = euler_maruyama_fixed(decay_drift, zero_diffusion, cast(1.0, f32), cast(0.0, f32), cast(0.2, f32), noise)
  assert_close(y_em, cast(0.81, f32), cast(0.000001, f32), "EM(decay, g=0, z=[0,0]): two forward Euler steps -> 0.81")
}
def test_em_zero_diffusion_with_nonzero_noise_is_deterministic() -> unit ! { Test } = {
  noise_zero = to_tensor([cast(0.0, f32)])
  noise_big = to_tensor([cast(100.0, f32)])
  y_zero = euler_maruyama_fixed(decay_drift, zero_diffusion, cast(1.0, f32), cast(0.0, f32), cast(0.1, f32), noise_zero)
  y_big = euler_maruyama_fixed(decay_drift, zero_diffusion, cast(1.0, f32), cast(0.0, f32), cast(0.1, f32), noise_big)
  assert_close(y_zero, y_big, cast(0.0000001, f32), "EM with g=0 is independent of noise sample")
}
def test_em_zero_drift_zero_diffusion_preserves_y() -> unit ! { Test } = {
  noise = to_tensor([cast(0.0, f32), cast(0.0, f32), cast(0.0, f32)])
  y_em = euler_maruyama_fixed(zero_drift, zero_diffusion, cast(2.5, f32), cast(0.0, f32), cast(1.0, f32), noise)
  assert_close(y_em, cast(2.5, f32), cast(0.0000001, f32), "EM(f=0, g=0): y stays at y0 = 2.5")
}
def test_em_pure_noise_one_step_unit_dt() -> unit ! { Test } = {
  noise = to_tensor([cast(1.0, f32)])
  y_em = euler_maruyama_fixed(zero_drift, unit_diffusion, cast(0.0, f32), cast(0.0, f32), cast(1.0, f32), noise)
  assert_close(y_em, cast(1.0, f32), cast(0.0000001, f32), "EM(f=0, g=1, dt=1, z=1): y_next = 0 + sqrt(1)*1 = 1")
}
def test_em_pure_noise_negative_z() -> unit ! { Test } = {
  noise = to_tensor([neg(cast(1.0, f32))])
  y_em = euler_maruyama_fixed(zero_drift, unit_diffusion, cast(0.0, f32), cast(0.0, f32), cast(1.0, f32), noise)
  assert_close(y_em, neg(cast(1.0, f32)), cast(0.0000001, f32), "EM(f=0, g=1, dt=1, z=-1): y_next = -1")
}
def test_em_pure_noise_scales_linearly_in_z() -> unit ! { Test } = {
  noise1 = to_tensor([cast(1.0, f32)])
  noise2 = to_tensor([cast(2.0, f32)])
  y1 = euler_maruyama_fixed(zero_drift, unit_diffusion, cast(0.0, f32), cast(0.0, f32), cast(1.0, f32), noise1)
  y2 = euler_maruyama_fixed(zero_drift, unit_diffusion, cast(0.0, f32), cast(0.0, f32), cast(1.0, f32), noise2)
  assert_close(y2, mul(cast(2.0, f32), y1), cast(0.000001, f32), "EM noise term is linear in z: y(2z) = 2*y(z) when f=0, y0=0")
}
def test_milstein_zero_noise_gbm_one_step() -> unit ! { Test } = {
  noise = to_tensor([cast(0.0, f32)])
  y_m = milstein_fixed(gbm_drift, gbm_diffusion, gbm_dg_dy, cast(1.0, f32), cast(0.0, f32), cast(1.0, f32), noise)
  assert_close(y_m, cast(1.08, f32), cast(0.000001, f32), "Milstein(GBM, z=0, dt=1): y_next = 1 + drift + Ito correction = 1.08")
}
def test_milstein_zero_diff_zero_noise_matches_em() -> unit ! { Test } = {
  noise = to_tensor([cast(0.0, f32)])
  y_em = euler_maruyama_fixed(decay_drift, zero_diffusion, cast(1.0, f32), cast(0.0, f32), cast(0.1, f32), copy(noise))
  y_m = milstein_fixed(decay_drift, zero_diffusion, zero_diffusion, cast(1.0, f32), cast(0.0, f32), cast(0.1, f32), noise)
  assert_close(y_m, y_em, cast(0.0000001, f32), "Milstein with g=0 matches EM with g=0")
}
def test_em_substep_count_changes_dt() -> unit ! { Test } = {
  noise1 = to_tensor([cast(0.0, f32)])
  noise2 = to_tensor([cast(0.0, f32), cast(0.0, f32)])
  y1 = euler_maruyama_fixed(decay_drift, zero_diffusion, cast(1.0, f32), cast(0.0, f32), cast(0.2, f32), noise1)
  y2 = euler_maruyama_fixed(decay_drift, zero_diffusion, cast(1.0, f32), cast(0.0, f32), cast(0.2, f32), noise2)
  _ = assert_close(y1, cast(0.8, f32), cast(0.000001, f32), "EM n=1 over [0,0.2]: dt=0.2 -> 0.8")
  _ = assert_close(y2, cast(0.81, f32), cast(0.000001, f32), "EM n=2 over [0,0.2]: dt=0.1 -> 0.81")
  assert_true(lt(y1, y2), "EM n=2 closer to exp(-0.2) than n=1 (smaller-step EM is more accurate)")
}
def test_em_trivial_interval_returns_y0() -> unit ! { Test } = {
  noise = to_tensor([cast(3.7, f32)])
  y_em = euler_maruyama_fixed(decay_drift, unit_diffusion, cast(2.0, f32), cast(0.5, f32), cast(0.5, f32), noise)
  assert_close(y_em, cast(2.0, f32), cast(0.0000001, f32), "EM with t0 == t1 returns y0 exactly")
}
