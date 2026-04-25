module Nautilus.Tests.Roots

-- Identity / structural tests for Nautilus.Roots.
-- All expected values are mathematical identities, exact constants,
-- or documented closed-form roots. No scipy-derived numerics.

import Nautilus.Roots (bisection, newton, brent)
import Std.Test (assert_close, assert_true)

-- ===== test functions and their derivatives =====

-- f(x) = x^2 - 2  has root at sqrt(2)
def root_xsq_minus_2(x: f32) -> f32 = sub(mul(x, x), cast(2.0, f32))
def root_xsq_minus_2_deriv(x: f32) -> f32 = mul(cast(2.0, f32), x)

-- f(x) = x^2 - 3  has root at sqrt(3)
def root_xsq_minus_3(x: f32) -> f32 = sub(mul(x, x), cast(3.0, f32))
def root_xsq_minus_3_deriv(x: f32) -> f32 = mul(cast(2.0, f32), x)

-- f(x) = x^2 - 1  has roots at +/-1
def root_xsq_minus_1(x: f32) -> f32 = sub(mul(x, x), cast(1.0, f32))

-- f(x) = exp(x) - 2  has root at ln(2)
def root_exp_minus_2(x: f32) -> f32 = sub(exp(x), cast(2.0, f32))
def root_exp_minus_2_deriv(x: f32) -> f32 = exp(x)

-- f(x) = x - 1  has root at 1.0 (trivial / exact)
def root_x_minus_1(x: f32) -> f32 = sub(x, cast(1.0, f32))
def root_x_minus_1_deriv(_x: f32) -> f32 = cast(1.0, f32)

-- ===== bisection =====

def test_bisection_sqrt2() -> unit ! { Test } = {
  -- f(x) = x^2 - 2 has root at sqrt(2); bracket [1, 2]
  -- 1.4142135 = sqrt(2) (documented constant)
  r = bisection(root_xsq_minus_2, cast(1.0, f32), cast(2.0, f32),
                cast(1.0e-6, f32), cast(100, int64))
  assert_close(r, cast(1.4142135, f32), cast(1.0e-4, f32),
               "bisection f(x)=x^2-2 -> sqrt(2)")
}

def test_bisection_sqrt3() -> unit ! { Test } = {
  -- f(x) = x^2 - 3 has root at sqrt(3); bracket [1, 2]
  -- 1.7320508 = sqrt(3) (documented constant)
  r = bisection(root_xsq_minus_3, cast(1.0, f32), cast(2.0, f32),
                cast(1.0e-6, f32), cast(100, int64))
  assert_close(r, cast(1.7320508, f32), cast(1.0e-4, f32),
               "bisection f(x)=x^2-3 -> sqrt(3)")
}

def test_bisection_xsq_minus_1() -> unit ! { Test } = {
  -- Bracket-condition smoke: bisection on x^2 - 1 with [0, 2]
  -- has sign change (f(0) = -1 < 0, f(2) = 3 > 0); root at 1.0
  r = bisection(root_xsq_minus_1, cast(0.0, f32), cast(2.0, f32),
                cast(1.0e-6, f32), cast(100, int64))
  assert_close(r, cast(1.0, f32), cast(1.0e-4, f32),
               "bisection f(x)=x^2-1 on [0,2] -> 1")
}

def test_bisection_trivial_linear() -> unit ! { Test } = {
  -- f(x) = x - 1 has exact root at 1.0; bracket [0, 2]
  r = bisection(root_x_minus_1, cast(0.0, f32), cast(2.0, f32),
                cast(1.0e-6, f32), cast(100, int64))
  assert_close(r, cast(1.0, f32), cast(1.0e-4, f32),
               "bisection f(x)=x-1 -> 1")
}

-- ===== newton =====

def test_newton_sqrt2() -> unit ! { Test } = {
  -- f(x) = x^2 - 2 has root at sqrt(2); start at 1.5
  -- 1.4142135 = sqrt(2) (documented constant)
  r = newton(root_xsq_minus_2, root_xsq_minus_2_deriv,
             cast(1.5, f32), cast(1.0e-6, f32), cast(50, int64))
  assert_close(r, cast(1.4142135, f32), cast(1.0e-5, f32),
               "newton f(x)=x^2-2 -> sqrt(2)")
}

def test_newton_sqrt3() -> unit ! { Test } = {
  -- f(x) = x^2 - 3 has root at sqrt(3); start at 2.0
  -- 1.7320508 = sqrt(3) (documented constant)
  r = newton(root_xsq_minus_3, root_xsq_minus_3_deriv,
             cast(2.0, f32), cast(1.0e-6, f32), cast(50, int64))
  assert_close(r, cast(1.7320508, f32), cast(1.0e-5, f32),
               "newton f(x)=x^2-3 -> sqrt(3)")
}

def test_newton_ln2() -> unit ! { Test } = {
  -- f(x) = exp(x) - 2 has root at ln(2); start at 1.0
  -- 0.6931471 = ln(2) (documented constant)
  r = newton(root_exp_minus_2, root_exp_minus_2_deriv,
             cast(1.0, f32), cast(1.0e-6, f32), cast(50, int64))
  assert_close(r, cast(0.6931471, f32), cast(1.0e-5, f32),
               "newton f(x)=exp(x)-2 -> ln(2)")
}

def test_newton_trivial_linear() -> unit ! { Test } = {
  -- f(x) = x - 1, derivative 1, exact root at 1.0 in one step from any start
  r = newton(root_x_minus_1, root_x_minus_1_deriv,
             cast(5.0, f32), cast(1.0e-6, f32), cast(50, int64))
  assert_close(r, cast(1.0, f32), cast(1.0e-5, f32),
               "newton f(x)=x-1 -> 1")
}

-- ===== brent =====

def test_brent_sqrt2() -> unit ! { Test } = {
  -- f(x) = x^2 - 2 has root at sqrt(2); bracket [1, 2]
  -- 1.4142135 = sqrt(2) (documented constant)
  r = brent(root_xsq_minus_2, cast(1.0, f32), cast(2.0, f32),
            cast(1.0e-6, f32), cast(100, int64))
  assert_close(r, cast(1.4142135, f32), cast(1.0e-5, f32),
               "brent f(x)=x^2-2 -> sqrt(2)")
}

def test_brent_sqrt3() -> unit ! { Test } = {
  -- f(x) = x^2 - 3 has root at sqrt(3); bracket [1, 2]
  -- 1.7320508 = sqrt(3) (documented constant)
  r = brent(root_xsq_minus_3, cast(1.0, f32), cast(2.0, f32),
            cast(1.0e-6, f32), cast(100, int64))
  assert_close(r, cast(1.7320508, f32), cast(1.0e-5, f32),
               "brent f(x)=x^2-3 -> sqrt(3)")
}

def test_brent_ln2() -> unit ! { Test } = {
  -- f(x) = exp(x) - 2 has root at ln(2); bracket [0, 1]
  -- 0.6931471 = ln(2) (documented constant)
  r = brent(root_exp_minus_2, cast(0.0, f32), cast(1.0, f32),
            cast(1.0e-6, f32), cast(100, int64))
  assert_close(r, cast(0.6931471, f32), cast(1.0e-5, f32),
               "brent f(x)=exp(x)-2 -> ln(2)")
}

-- ===== convergence sanity (root lies inside bracket) =====

def test_bisection_root_above_lo() -> unit ! { Test } = {
  -- Returned root for x^2 - 2 must lie above lo = 1
  r = bisection(root_xsq_minus_2, cast(1.0, f32), cast(2.0, f32),
                cast(1.0e-6, f32), cast(100, int64))
  assert_true(gt(r, cast(1.0, f32)), "bisection root > 1")
}

def test_bisection_root_below_hi() -> unit ! { Test } = {
  -- Returned root for x^2 - 2 must lie below hi = 2
  r = bisection(root_xsq_minus_2, cast(1.0, f32), cast(2.0, f32),
                cast(1.0e-6, f32), cast(100, int64))
  assert_true(lt(r, cast(2.0, f32)), "bisection root < 2")
}
