module Nautilus.Tests.SDE

-- Identity / structural tests for Nautilus.SDE.
-- All expected values are mathematical identities, exact constants,
-- or documented closed-form results derived from the EM / Milstein
-- update equations. No scipy-derived numerics.
--
-- API recap (see src/sde.ch):
--   euler_maruyama_fixed(f, g, y0, t0, t1, noise: tensor[n, f32]) -> f32
--   milstein_fixed(f, g, dg_dy, y0, t0, t1, noise: tensor[n, f32]) -> f32
--
-- Update per noise sample z (with dt = (t1-t0)/n, dW = sqrt(dt)*z):
--   EM:       y_{k+1} = y_k + f(y_k, t_k)*dt + g(y_k, t_k)*dW
--   Milstein: y_{k+1} = y_k + f*dt + g*dW + 0.5 * g * dg_dy * (dW^2 - dt)

import Nautilus.SDE (euler_maruyama_fixed, milstein_fixed)
import Std.Test (assert_close, assert_true)

-- ===== drift / diffusion functions =====

-- f(y, t) = -y    (linear decay drift)
def decay_drift(y: f32, t: f32) -> f32 = neg(y)

-- f(y, t) = 0     (no drift)
def zero_drift(y: f32, t: f32) -> f32 = cast(0.0, f32)

-- g(y, t) = 0     (no diffusion -> deterministic ODE)
def zero_diffusion(y: f32, t: f32) -> f32 = cast(0.0, f32)

-- g(y, t) = 1     (unit diffusion)
def unit_diffusion(y: f32, t: f32) -> f32 = cast(1.0, f32)

-- GBM coefficients with mu = 0.1, sigma = 0.2:
--   dy = mu*y dt + sigma*y dW,   dg/dy = sigma
def gbm_drift(y: f32, t: f32) -> f32 = mul(cast(0.1, f32), y)
def gbm_diffusion(y: f32, t: f32) -> f32 = mul(cast(0.2, f32), y)
def gbm_dg_dy(y: f32, t: f32) -> f32 = cast(0.2, f32)

-- ===== EM with zero noise reduces to forward Euler =====

def test_em_zero_noise_one_step_decay() -> unit ! { Test } = {
  -- f=-y, g=0, noise=[0], y0=1, dt=0.1
  --   y_next = 1 + (-1)*0.1 + 0 = 0.9
  noise = to_tensor([cast(0.0, f32)])
  y_em = euler_maruyama_fixed(decay_drift, zero_diffusion,
                              cast(1.0, f32), cast(0.0, f32),
                              cast(0.1, f32), noise)
  assert_close(y_em, cast(0.9, f32), cast(1.0e-6, f32),
               "EM(decay, g=0, z=0): y_next = 0.9 = forward Euler step")
}

def test_em_zero_noise_two_steps_decay() -> unit ! { Test } = {
  -- f=-y, g=0, noise=[0, 0], y0=1, t0=0, t1=0.2, dt=0.1
  --   step 1: y = 1 + (-1)*0.1 = 0.9
  --   step 2: y = 0.9 + (-0.9)*0.1 = 0.81
  noise = to_tensor([cast(0.0, f32), cast(0.0, f32)])
  y_em = euler_maruyama_fixed(decay_drift, zero_diffusion,
                              cast(1.0, f32), cast(0.0, f32),
                              cast(0.2, f32), noise)
  assert_close(y_em, cast(0.81, f32), cast(1.0e-6, f32),
               "EM(decay, g=0, z=[0,0]): two forward Euler steps -> 0.81")
}

def test_em_zero_diffusion_with_nonzero_noise_is_deterministic() -> unit ! { Test } = {
  -- With g(y,t) = 0, the noise term g*sqrt(dt)*z vanishes regardless of z.
  -- Should give the same answer as with z=0.
  noise_zero = to_tensor([cast(0.0, f32)])
  noise_big  = to_tensor([cast(100.0, f32)])
  y_zero = euler_maruyama_fixed(decay_drift, zero_diffusion,
                                cast(1.0, f32), cast(0.0, f32),
                                cast(0.1, f32), noise_zero)
  y_big = euler_maruyama_fixed(decay_drift, zero_diffusion,
                               cast(1.0, f32), cast(0.0, f32),
                               cast(0.1, f32), noise_big)
  assert_close(y_zero, y_big, cast(1.0e-7, f32),
               "EM with g=0 is independent of noise sample")
}

-- ===== EM trivial fixed point: drift=0, diffusion=0 =====

def test_em_zero_drift_zero_diffusion_preserves_y() -> unit ! { Test } = {
  -- f=0, g=0, any noise: y stays at y0 exactly.
  noise = to_tensor([cast(0.0, f32), cast(0.0, f32), cast(0.0, f32)])
  y_em = euler_maruyama_fixed(zero_drift, zero_diffusion,
                              cast(2.5, f32), cast(0.0, f32),
                              cast(1.0, f32), noise)
  assert_close(y_em, cast(2.5, f32), cast(1.0e-7, f32),
               "EM(f=0, g=0): y stays at y0 = 2.5")
}

-- ===== EM noise-only step (drift=0, diffusion=1) =====

def test_em_pure_noise_one_step_unit_dt() -> unit ! { Test } = {
  -- f=0, g=1, noise=[1.0], y0=0, t0=0, t1=1, dt=1, sqrt(dt)=1.
  --   y_next = 0 + 0 + 1 * 1 * 1 = 1.0
  noise = to_tensor([cast(1.0, f32)])
  y_em = euler_maruyama_fixed(zero_drift, unit_diffusion,
                              cast(0.0, f32), cast(0.0, f32),
                              cast(1.0, f32), noise)
  assert_close(y_em, cast(1.0, f32), cast(1.0e-7, f32),
               "EM(f=0, g=1, dt=1, z=1): y_next = 0 + sqrt(1)*1 = 1")
}

def test_em_pure_noise_negative_z() -> unit ! { Test } = {
  -- f=0, g=1, noise=[-1.0], y0=0, dt=1.
  --   y_next = 0 + 1 * 1 * (-1) = -1
  noise = to_tensor([neg(cast(1.0, f32))])
  y_em = euler_maruyama_fixed(zero_drift, unit_diffusion,
                              cast(0.0, f32), cast(0.0, f32),
                              cast(1.0, f32), noise)
  assert_close(y_em, neg(cast(1.0, f32)), cast(1.0e-7, f32),
               "EM(f=0, g=1, dt=1, z=-1): y_next = -1")
}

def test_em_pure_noise_scales_linearly_in_z() -> unit ! { Test } = {
  -- With f=0 and g constant in y, EM is linear in the noise sample z.
  -- y(z=2) - y0 should equal 2 * (y(z=1) - y0).
  noise1 = to_tensor([cast(1.0, f32)])
  noise2 = to_tensor([cast(2.0, f32)])
  y1 = euler_maruyama_fixed(zero_drift, unit_diffusion,
                            cast(0.0, f32), cast(0.0, f32),
                            cast(1.0, f32), noise1)
  y2 = euler_maruyama_fixed(zero_drift, unit_diffusion,
                            cast(0.0, f32), cast(0.0, f32),
                            cast(1.0, f32), noise2)
  assert_close(y2, mul(cast(2.0, f32), y1), cast(1.0e-6, f32),
               "EM noise term is linear in z: y(2z) = 2*y(z) when f=0, y0=0")
}

-- ===== Milstein with zero noise: deterministic + Ito correction =====

def test_milstein_zero_noise_gbm_one_step() -> unit ! { Test } = {
  -- mu=0.1, sigma=0.2, y0=1, t0=0, t1=1, n=1, noise=[0].
  --   dt = 1, sqrt_dt = 1, dW = 0
  --   drift = mu*y*dt = 0.1*1*1 = 0.1
  --   diff  = sigma*y*dW = 0
  --   correction = 0.5 * g * dg/dy * (dW^2 - dt)
  --              = 0.5 * 0.2 * 0.2 * (0 - 1)
  --              = -0.02
  --   y_next = 1 + 0.1 + 0 + (-0.02) = 1.08
  noise = to_tensor([cast(0.0, f32)])
  y_m = milstein_fixed(gbm_drift, gbm_diffusion, gbm_dg_dy,
                       cast(1.0, f32), cast(0.0, f32),
                       cast(1.0, f32), noise)
  assert_close(y_m, cast(1.08, f32), cast(1.0e-6, f32),
               "Milstein(GBM, z=0, dt=1): y_next = 1 + drift + Ito correction = 1.08")
}

def test_milstein_zero_diff_zero_noise_matches_em() -> unit ! { Test } = {
  -- With g=0 and noise=0, both Milstein correction (g*dg*(dW^2-dt)) and
  -- diffusion term vanish; Milstein reduces to forward Euler, same as EM.
  noise = to_tensor([cast(0.0, f32)])
  y_em = euler_maruyama_fixed(decay_drift, zero_diffusion,
                              cast(1.0, f32), cast(0.0, f32),
                              cast(0.1, f32), noise)
  y_m = milstein_fixed(decay_drift, zero_diffusion, zero_diffusion,
                       cast(1.0, f32), cast(0.0, f32),
                       cast(0.1, f32), noise)
  assert_close(y_m, y_em, cast(1.0e-7, f32),
               "Milstein with g=0 matches EM with g=0")
}

-- ===== Structural: substep count (n) controls dt =====

def test_em_substep_count_changes_dt() -> unit ! { Test } = {
  -- f=-y, g=0, y0=1, t0=0, t1=0.2.
  --   n=1, noise=[0]:        dt=0.2, y = 1 + (-1)*0.2 = 0.8
  --   n=2, noise=[0,0]:      dt=0.1, two Euler steps -> 0.81
  -- Confirms the noise tensor length determines the substep count.
  noise1 = to_tensor([cast(0.0, f32)])
  noise2 = to_tensor([cast(0.0, f32), cast(0.0, f32)])
  y1 = euler_maruyama_fixed(decay_drift, zero_diffusion,
                            cast(1.0, f32), cast(0.0, f32),
                            cast(0.2, f32), noise1)
  y2 = euler_maruyama_fixed(decay_drift, zero_diffusion,
                            cast(1.0, f32), cast(0.0, f32),
                            cast(0.2, f32), noise2)
  _ = assert_close(y1, cast(0.8, f32), cast(1.0e-6, f32),
                   "EM n=1 over [0,0.2]: dt=0.2 -> 0.8");
  _ = assert_close(y2, cast(0.81, f32), cast(1.0e-6, f32),
                   "EM n=2 over [0,0.2]: dt=0.1 -> 0.81");
  assert_true(lt(y1, y2),
              "EM n=2 closer to exp(-0.2) than n=1 (smaller-step EM is more accurate)")
}

def test_em_trivial_interval_returns_y0() -> unit ! { Test } = {
  -- t0 == t1: dt = 0, so drift*dt = 0 and sqrt(dt)*z = 0. y stays at y0.
  noise = to_tensor([cast(3.7, f32)])
  y_em = euler_maruyama_fixed(decay_drift, unit_diffusion,
                              cast(2.0, f32), cast(0.5, f32),
                              cast(0.5, f32), noise)
  assert_close(y_em, cast(2.0, f32), cast(1.0e-7, f32),
               "EM with t0 == t1 returns y0 exactly")
}
