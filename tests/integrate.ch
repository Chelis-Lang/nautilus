module Nautilus.Tests.Integrate

-- Identity / structural tests for Nautilus.Integrate.
-- Every expected value is either:
--   * an exact analytic integral of a polynomial (so the rule is exact)
--   * a documented mathematical identity (sqrt(pi), e-1, ln(e)=1, ...)
--   * a cross-method consistency check on a smooth integrand
-- No scipy-derived numerics live here. scipy comparisons stay in parity/.

import Nautilus.Integrate (trapezoidal, simpsons, gauss_legendre_5,
                           adaptive_simpson, romberg_5, gauss_legendre_10,
                           gauss_hermite_10, gauss_laguerre_10)
import Std.Test (assert_close)

-- ===== integrand definitions =====
-- Chelis quadrature takes function-typed parameters f: f32 -> f32.

def f_one(x: f32) -> f32 = cast(1.0, f32)
def f_x(x: f32) -> f32 = x
def f_xsq(x: f32) -> f32 = mul(x, x)
def f_xcube(x: f32) -> f32 = mul(mul(x, x), x)
def f_sin(x: f32) -> f32 = sin(x)
def f_exp(x: f32) -> f32 = exp(x)
def f_recip(x: f32) -> f32 = div(cast(1.0, f32), x)

-- ===== exact polynomial integrals =====

-- ----- constant: integral of 1 over [0,1] = 1 (every rule exact) -----

def test_trap_const_one() -> unit ! { Test } = {
  v = trapezoidal(f_one, cast(0.0, f32), cast(1.0, f32), cast(10, int64))
  assert_close(v, cast(1.0, f32), cast(1.0e-6, f32),
               "trapezoidal: integral of 1 over [0,1] = 1")
}

def test_simp_const_one() -> unit ! { Test } = {
  v = simpsons(f_one, cast(0.0, f32), cast(1.0, f32), cast(10, int64))
  assert_close(v, cast(1.0, f32), cast(1.0e-6, f32),
               "simpsons: integral of 1 over [0,1] = 1")
}

def test_gl5_const_one() -> unit ! { Test } = {
  v = gauss_legendre_5(f_one, cast(0.0, f32), cast(1.0, f32), cast(5, int64))
  assert_close(v, cast(1.0, f32), cast(1.0e-6, f32),
               "gauss_legendre_5: integral of 1 over [0,1] = 1")
}

def test_gl10_const_one() -> unit ! { Test } = {
  v = gauss_legendre_10(f_one, cast(0.0, f32), cast(1.0, f32))
  assert_close(v, cast(1.0, f32), cast(1.0e-6, f32),
               "gauss_legendre_10: integral of 1 over [0,1] = 1")
}

def test_romberg_const_one() -> unit ! { Test } = {
  v = romberg_5(f_one, cast(0.0, f32), cast(1.0, f32))
  assert_close(v, cast(1.0, f32), cast(1.0e-6, f32),
               "romberg_5: integral of 1 over [0,1] = 1")
}

-- ----- linear: integral of x over [0,1] = 1/2 (trap and above exact) -----

def test_trap_x() -> unit ! { Test } = {
  v = trapezoidal(f_x, cast(0.0, f32), cast(1.0, f32), cast(10, int64))
  assert_close(v, cast(0.5, f32), cast(1.0e-6, f32),
               "trapezoidal: integral of x over [0,1] = 0.5 (trap exact for linear)")
}

def test_simp_x() -> unit ! { Test } = {
  v = simpsons(f_x, cast(0.0, f32), cast(1.0, f32), cast(10, int64))
  assert_close(v, cast(0.5, f32), cast(1.0e-6, f32),
               "simpsons: integral of x over [0,1] = 0.5")
}

def test_gl5_x() -> unit ! { Test } = {
  v = gauss_legendre_5(f_x, cast(0.0, f32), cast(1.0, f32), cast(5, int64))
  assert_close(v, cast(0.5, f32), cast(1.0e-6, f32),
               "gauss_legendre_5: integral of x over [0,1] = 0.5")
}

def test_gl10_x() -> unit ! { Test } = {
  v = gauss_legendre_10(f_x, cast(0.0, f32), cast(1.0, f32))
  assert_close(v, cast(0.5, f32), cast(1.0e-6, f32),
               "gauss_legendre_10: integral of x over [0,1] = 0.5")
}

def test_trap_x_0_2() -> unit ! { Test } = {
  v = trapezoidal(f_x, cast(0.0, f32), cast(2.0, f32), cast(10, int64))
  assert_close(v, cast(2.0, f32), cast(1.0e-6, f32),
               "trapezoidal: integral of x over [0,2] = 2 (1/2 * 2^2)")
}

def test_simp_x_symmetric() -> unit ! { Test } = {
  -- odd integrand on symmetric interval [-1, 1] has integral 0
  v = simpsons(f_x, cast(-1.0, f32), cast(1.0, f32), cast(10, int64))
  assert_close(v, cast(0.0, f32), cast(1.0e-6, f32),
               "simpsons: integral of x over [-1,1] = 0 (odd on symmetric)")
}

def test_gl10_x_symmetric() -> unit ! { Test } = {
  v = gauss_legendre_10(f_x, cast(-1.0, f32), cast(1.0, f32))
  assert_close(v, cast(0.0, f32), cast(1.0e-6, f32),
               "gauss_legendre_10: integral of x over [-1,1] = 0 (odd on symmetric)")
}

-- ----- non-symmetric integrand on symmetric bracket — catches bad weights -----
-- The two `_x_symmetric` tests above cancel by ANTI-symmetry regardless of
-- whether the quadrature weights are correct; a buggy weighting that just
-- preserves antisymmetry would still pass them. These two tests use an
-- EVEN integrand (x^2) on the same [-1, 1] bracket, where the answer
-- depends on the weights being right: integral of x^2 over [-1, 1] = 2/3.
-- Red-team round 2 LOW-3.

def test_simp_xsq_symmetric_bracket() -> unit ! { Test } = {
  v = simpsons(f_xsq, cast(-1.0, f32), cast(1.0, f32), cast(10, int64))
  -- 2/3 = 0.6666666... documented (catches bad-weight bugs that pass the
  --                     odd-symmetric anti-cancellation tests).
  assert_close(v, cast(0.6666666, f32), cast(1.0e-5, f32),
               "simpsons: x^2 over [-1,1] = 2/3 (weight check)")
}

def test_gl10_xsq_symmetric_bracket() -> unit ! { Test } = {
  v = gauss_legendre_10(f_xsq, cast(-1.0, f32), cast(1.0, f32))
  -- 2/3 = 0.6666666...
  assert_close(v, cast(0.6666666, f32), cast(1.0e-5, f32),
               "gauss_legendre_10: x^2 over [-1,1] = 2/3 (weight check)")
}

-- ----- quadratic: integral of x^2 over [0,1] = 1/3 (Simpson and above exact) -----

def test_simp_xsq() -> unit ! { Test } = {
  v = simpsons(f_xsq, cast(0.0, f32), cast(1.0, f32), cast(10, int64))
  -- 0.3333333 = 1/3
  assert_close(v, cast(0.3333333, f32), cast(1.0e-5, f32),
               "simpsons: integral of x^2 over [0,1] = 1/3")
}

def test_gl5_xsq() -> unit ! { Test } = {
  v = gauss_legendre_5(f_xsq, cast(0.0, f32), cast(1.0, f32), cast(5, int64))
  -- 0.3333333 = 1/3
  assert_close(v, cast(0.3333333, f32), cast(1.0e-5, f32),
               "gauss_legendre_5: integral of x^2 over [0,1] = 1/3")
}

def test_gl10_xsq() -> unit ! { Test } = {
  v = gauss_legendre_10(f_xsq, cast(0.0, f32), cast(1.0, f32))
  -- 0.3333333 = 1/3
  assert_close(v, cast(0.3333333, f32), cast(1.0e-5, f32),
               "gauss_legendre_10: integral of x^2 over [0,1] = 1/3")
}

def test_romberg_xsq() -> unit ! { Test } = {
  v = romberg_5(f_xsq, cast(0.0, f32), cast(1.0, f32))
  -- 0.3333333 = 1/3
  assert_close(v, cast(0.3333333, f32), cast(1.0e-5, f32),
               "romberg_5: integral of x^2 over [0,1] = 1/3")
}

def test_simp_xsq_symmetric() -> unit ! { Test } = {
  -- integral of x^2 over [-1, 1] = 2/3
  v = simpsons(f_xsq, cast(-1.0, f32), cast(1.0, f32), cast(10, int64))
  -- 0.6666666 = 2/3
  assert_close(v, cast(0.6666666, f32), cast(1.0e-5, f32),
               "simpsons: integral of x^2 over [-1,1] = 2/3")
}

def test_gl10_xsq_symmetric() -> unit ! { Test } = {
  v = gauss_legendre_10(f_xsq, cast(-1.0, f32), cast(1.0, f32))
  -- 0.6666666 = 2/3
  assert_close(v, cast(0.6666666, f32), cast(1.0e-5, f32),
               "gauss_legendre_10: integral of x^2 over [-1,1] = 2/3")
}

-- ----- cubic: integral of x^3 over [0,1] = 1/4 (Simpson exact through degree 3) -----

def test_simp_xcube() -> unit ! { Test } = {
  v = simpsons(f_xcube, cast(0.0, f32), cast(1.0, f32), cast(10, int64))
  assert_close(v, cast(0.25, f32), cast(1.0e-5, f32),
               "simpsons: integral of x^3 over [0,1] = 0.25 (Simpson exact for cubic)")
}

def test_gl5_xcube() -> unit ! { Test } = {
  v = gauss_legendre_5(f_xcube, cast(0.0, f32), cast(1.0, f32), cast(5, int64))
  assert_close(v, cast(0.25, f32), cast(1.0e-6, f32),
               "gauss_legendre_5: integral of x^3 over [0,1] = 0.25")
}

def test_gl10_xcube() -> unit ! { Test } = {
  v = gauss_legendre_10(f_xcube, cast(0.0, f32), cast(1.0, f32))
  assert_close(v, cast(0.25, f32), cast(1.0e-6, f32),
               "gauss_legendre_10: integral of x^3 over [0,1] = 0.25")
}

-- ===== documented analytic identities =====

-- ----- integral of sin(x) over [0, pi] = 2 -----

def test_simp_sin_0_pi() -> unit ! { Test } = {
  -- 3.1415927 = pi
  pi = cast(3.1415927, f32)
  v = simpsons(f_sin, cast(0.0, f32), pi, cast(64, int64))
  assert_close(v, cast(2.0, f32), cast(1.0e-4, f32),
               "simpsons: integral of sin over [0,pi] = 2")
}

def test_gl10_sin_0_pi() -> unit ! { Test } = {
  -- 3.1415927 = pi
  pi = cast(3.1415927, f32)
  v = gauss_legendre_10(f_sin, cast(0.0, f32), pi)
  assert_close(v, cast(2.0, f32), cast(1.0e-5, f32),
               "gauss_legendre_10: integral of sin over [0,pi] = 2")
}

def test_romberg_sin_0_pi() -> unit ! { Test } = {
  -- 3.1415927 = pi
  pi = cast(3.1415927, f32)
  v = romberg_5(f_sin, cast(0.0, f32), pi)
  assert_close(v, cast(2.0, f32), cast(1.0e-4, f32),
               "romberg_5: integral of sin over [0,pi] = 2")
}

def test_adapt_sin_0_pi() -> unit ! { Test } = {
  -- 3.1415927 = pi
  pi = cast(3.1415927, f32)
  v = adaptive_simpson(f_sin, cast(0.0, f32), pi,
                       cast(1.0e-6, f32), cast(20, int64))
  assert_close(v, cast(2.0, f32), cast(1.0e-4, f32),
               "adaptive_simpson: integral of sin over [0,pi] = 2")
}

-- ----- integral of cos(x) over [0, pi/2] = 1 -----
-- cos is not a host-runtime builtin, so rephrase via the antiderivative:
-- ∫_{pi/2}^{pi} sin(x) dx = -cos(pi) + cos(pi/2) = 1 + 0 = 1
def test_gl10_sin_halfpi_pi() -> unit ! { Test } = {
  -- 1.5707963 = pi/2 ; 3.1415927 = pi
  v = gauss_legendre_10(f_sin, cast(1.5707963, f32), cast(3.1415927, f32))
  assert_close(v, cast(1.0, f32), cast(1.0e-5, f32),
               "gauss_legendre_10: integral of sin over [pi/2,pi] = 1 (= antideriv of cos on [0,pi/2])")
}

-- ----- integral of sin(x) over [0, 2*pi] = 0 (periodic) -----

def test_gl10_sin_period() -> unit ! { Test } = {
  -- 6.2831853 = 2*pi
  two_pi = cast(6.2831853, f32)
  v = gauss_legendre_10(f_sin, cast(0.0, f32), two_pi)
  assert_close(v, cast(0.0, f32), cast(1.0e-4, f32),
               "gauss_legendre_10: integral of sin over [0,2pi] = 0 (full period)")
}

def test_simp_sin_period() -> unit ! { Test } = {
  -- 6.2831853 = 2*pi
  two_pi = cast(6.2831853, f32)
  v = simpsons(f_sin, cast(0.0, f32), two_pi, cast(64, int64))
  assert_close(v, cast(0.0, f32), cast(1.0e-4, f32),
               "simpsons: integral of sin over [0,2pi] = 0 (full period)")
}

-- ----- integral of exp(x) over [0,1] = e - 1 -----

def test_simp_exp_0_1() -> unit ! { Test } = {
  v = simpsons(f_exp, cast(0.0, f32), cast(1.0, f32), cast(64, int64))
  -- 1.7182818 = e - 1
  assert_close(v, cast(1.7182818, f32), cast(1.0e-5, f32),
               "simpsons: integral of exp over [0,1] = e - 1")
}

def test_gl10_exp_0_1() -> unit ! { Test } = {
  v = gauss_legendre_10(f_exp, cast(0.0, f32), cast(1.0, f32))
  -- 1.7182818 = e - 1
  assert_close(v, cast(1.7182818, f32), cast(1.0e-5, f32),
               "gauss_legendre_10: integral of exp over [0,1] = e - 1")
}

def test_adapt_exp_0_1() -> unit ! { Test } = {
  v = adaptive_simpson(f_exp, cast(0.0, f32), cast(1.0, f32),
                       cast(1.0e-6, f32), cast(20, int64))
  -- 1.7182818 = e - 1
  assert_close(v, cast(1.7182818, f32), cast(1.0e-5, f32),
               "adaptive_simpson: integral of exp over [0,1] = e - 1")
}

-- ----- integral of 1/x over [1, e] = ln(e) - ln(1) = 1 -----

def test_gl10_recip_1_e() -> unit ! { Test } = {
  -- 2.7182817 = e
  e = cast(2.7182817, f32)
  v = gauss_legendre_10(f_recip, cast(1.0, f32), e)
  assert_close(v, cast(1.0, f32), cast(1.0e-5, f32),
               "gauss_legendre_10: integral of 1/x over [1,e] = ln(e) - ln(1) = 1")
}

def test_romberg_recip_1_e() -> unit ! { Test } = {
  -- 2.7182817 = e
  e = cast(2.7182817, f32)
  v = romberg_5(f_recip, cast(1.0, f32), e)
  assert_close(v, cast(1.0, f32), cast(1.0e-4, f32),
               "romberg_5: integral of 1/x over [1,e] = 1")
}

-- ===== cross-method consistency on smooth integrands =====
-- Different quadrature rules should agree on a smooth integrand.

def test_consistency_trap_simp_sin() -> unit ! { Test } = {
  -- 3.1415927 = pi
  pi = cast(3.1415927, f32)
  vt = trapezoidal(f_sin, cast(0.0, f32), pi, cast(100, int64))
  vs = simpsons(f_sin, cast(0.0, f32), pi, cast(100, int64))
  assert_close(vt, vs, cast(1.0e-3, f32),
               "trapezoidal vs simpsons agree within 1e-3 on smooth sin over [0,pi]")
}

def test_consistency_simp_gl5_xsq() -> unit ! { Test } = {
  vs = simpsons(f_xsq, cast(0.0, f32), cast(1.0, f32), cast(100, int64))
  vg = gauss_legendre_5(f_xsq, cast(0.0, f32), cast(1.0, f32), cast(5, int64))
  assert_close(vs, vg, cast(1.0e-4, f32),
               "simpsons vs gauss_legendre_5 agree within 1e-4 on smooth x^2 over [0,1]")
}

def test_consistency_gl10_romberg_sin() -> unit ! { Test } = {
  -- 3.1415927 = pi
  pi = cast(3.1415927, f32)
  vg = gauss_legendre_10(f_sin, cast(0.0, f32), pi)
  vr = romberg_5(f_sin, cast(0.0, f32), pi)
  assert_close(vg, vr, cast(1.0e-4, f32),
               "gauss_legendre_10 vs romberg_5 agree within 1e-4 on smooth sin over [0,pi]")
}

def test_consistency_gl10_adapt_exp() -> unit ! { Test } = {
  vg = gauss_legendre_10(f_exp, cast(0.0, f32), cast(1.0, f32))
  va = adaptive_simpson(f_exp, cast(0.0, f32), cast(1.0, f32),
                        cast(1.0e-6, f32), cast(20, int64))
  assert_close(vg, va, cast(1.0e-5, f32),
               "gauss_legendre_10 vs adaptive_simpson agree within 1e-5 on smooth exp over [0,1]")
}

-- ===== Gauss-Hermite =====
-- Weight w(x) = exp(-x^2) on (-inf, +inf).
-- ∫_{-inf}^{+inf} exp(-x^2) dx = sqrt(pi)
-- gauss_hermite_10 applied to f(x) = 1 returns ∑ w_i * 1 = sqrt(pi).

def test_hermite_const_one() -> unit ! { Test } = {
  v = gauss_hermite_10(f_one)
  -- 1.7724539 = sqrt(pi)
  assert_close(v, cast(1.7724539, f32), cast(1.0e-4, f32),
               "gauss_hermite_10(1) = integral of exp(-x^2) over R = sqrt(pi)")
}

def test_hermite_xsq_identity() -> unit ! { Test } = {
  -- ∫ x^2 exp(-x^2) dx over R = sqrt(pi)/2
  v = gauss_hermite_10(f_xsq)
  -- 0.8862269 = sqrt(pi)/2
  assert_close(v, cast(0.8862269, f32), cast(1.0e-4, f32),
               "gauss_hermite_10(x^2) = sqrt(pi)/2")
}

def test_hermite_x_odd() -> unit ! { Test } = {
  -- ∫ x exp(-x^2) dx over R = 0 (odd integrand)
  v = gauss_hermite_10(f_x)
  assert_close(v, cast(0.0, f32), cast(1.0e-6, f32),
               "gauss_hermite_10(x) = 0 (odd integrand)")
}

-- ===== Gauss-Laguerre =====
-- Weight w(x) = exp(-x) on [0, +inf).
-- ∫_0^{+inf} exp(-x) dx = 1.

def test_laguerre_const_one() -> unit ! { Test } = {
  v = gauss_laguerre_10(f_one)
  assert_close(v, cast(1.0, f32), cast(1.0e-5, f32),
               "gauss_laguerre_10(1) = integral of exp(-x) over [0,inf) = 1")
}

def test_laguerre_x_identity() -> unit ! { Test } = {
  -- ∫_0^inf x exp(-x) dx = gamma(2) = 1! = 1
  v = gauss_laguerre_10(f_x)
  assert_close(v, cast(1.0, f32), cast(1.0e-5, f32),
               "gauss_laguerre_10(x) = gamma(2) = 1! = 1")
}

def test_laguerre_xsq_identity() -> unit ! { Test } = {
  -- ∫_0^inf x^2 exp(-x) dx = gamma(3) = 2! = 2
  v = gauss_laguerre_10(f_xsq)
  assert_close(v, cast(2.0, f32), cast(1.0e-4, f32),
               "gauss_laguerre_10(x^2) = gamma(3) = 2! = 2")
}
