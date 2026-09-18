module Nautilus.Tests.RootsGeneric
import Nautilus.Roots (bisection, newton, brent)
import Std.Test (assert_true)
-- nautilus#67: Nautilus.Roots is dtype-generic over the Float family, and its
-- accuracy is bounded by the caller's tolerance and the dtype's resolution,
-- not by an f32-tuned floor.
def rg_abs_f64(x: f64) -> f64 = if lt(x, cast(0.0, f64)) then neg(x) else x
def rg_abs_f32(x: f32) -> f32 = if lt(x, cast(0.0, f32)) then neg(x) else x
def rg_xsq_minus_2_f64(x: f64) -> f64 = sub(mul(x, x), cast(2.0, f64))
def rg_dxsq_f64(x: f64) -> f64 = mul(cast(2.0, f64), x)
def rg_exp_minus_2_f64(x: f64) -> f64 = sub(exp(x), cast(2.0, f64))
def rg_xsq_minus_2_f32(x: f32) -> f32 = sub(mul(x, x), cast(2.0, f32))
def rg_dxsq_f32(x: f32) -> f32 = mul(cast(2.0, f32), x)
def rg_sqrt2_f64() -> f64 = cast(1.4142135623730951, f64)
def test_brent_f64_reaches_sub_micro_tolerance() -> unit ! { Test } = {
  r = brent(rg_xsq_minus_2_f64, cast(1.0, f64), cast(2.0, f64), cast(1e-13, f64), cast(200, int64))
  assert_true(lt(rg_abs_f64(sub(r, rg_sqrt2_f64())), cast(1e-12, f64)), "f64 brent on x^2-2 at tol 1e-13 is within 1e-12 of sqrt(2); an f32-tuned 1e-6 tolerance floor would leave ~1e-7")
}
def test_brent_f64_ln2() -> unit ! { Test } = {
  r = brent(rg_exp_minus_2_f64, cast(0.0, f64), cast(1.0, f64), cast(1e-13, f64), cast(200, int64))
  assert_true(lt(rg_abs_f64(sub(r, cast(0.6931471805599453, f64))), cast(1e-12, f64)), "f64 brent on exp(x)-2 is within 1e-12 of ln 2")
}
def test_bisection_f64_reaches_sub_micro_tolerance() -> unit ! { Test } = {
  r = bisection(rg_xsq_minus_2_f64, cast(1.0, f64), cast(2.0, f64), cast(1e-13, f64), cast(200, int64))
  assert_true(lt(rg_abs_f64(sub(r, rg_sqrt2_f64())), cast(1e-12, f64)), "f64 bisection on x^2-2 at tol 1e-13 is within 1e-12 of sqrt(2)")
}
def test_newton_f64_reaches_sub_micro_tolerance() -> unit ! { Test } = {
  r = newton(rg_xsq_minus_2_f64, rg_dxsq_f64, cast(1.5, f64), cast(1e-14, f64), cast(50, int64))
  assert_true(lt(rg_abs_f64(sub(r, rg_sqrt2_f64())), cast(1e-13, f64)), "f64 newton on x^2-2 at tol 1e-14 is within 1e-13 of sqrt(2)")
}
def test_brent_f64_unbracketed_is_nan() -> unit ! { Test } = {
  r = brent(rg_xsq_minus_2_f64, cast(2.0, f64), cast(3.0, f64), cast(1e-13, f64), cast(200, int64))
  assert_true(neq(r, r), "f64 brent with no sign change returns NaN, as at f32")
}
def test_brent_f32_sub_ulp_tolerance_terminates_finite() -> unit ! { Test } = {
  r = brent(rg_xsq_minus_2_f32, cast(1.0, f32), cast(2.0, f32), cast(1e-12, f32), cast(200, int64))
  _ = assert_true(eq(r, r), "f32 brent at a tolerance below f32 resolution stops at the resolution plateau instead of exhausting iterations into NaN")
  assert_true(lt(rg_abs_f32(sub(r, cast(1.4142135, f32))), cast(1e-6, f32)), "f32 brent at sub-ULP tolerance is still within 1e-6 of sqrt(2)")
}
def test_brent_f32_zero_tolerance_terminates_finite() -> unit ! { Test } = {
  r = brent(rg_xsq_minus_2_f32, cast(1.0, f32), cast(2.0, f32), cast(0.0, f32), cast(200, int64))
  assert_true(eq(r, r), "f32 brent at tolerance 0 stops at the resolution plateau, not NaN")
}
def test_brent_f64_zero_tolerance_terminates_finite() -> unit ! { Test } = {
  r = brent(rg_xsq_minus_2_f64, cast(1.0, f64), cast(2.0, f64), cast(0.0, f64), cast(400, int64))
  _ = assert_true(eq(r, r), "f64 brent at tolerance 0 stops at the resolution plateau, not NaN")
  assert_true(lt(rg_abs_f64(sub(r, rg_sqrt2_f64())), cast(1e-15, f64)), "f64 brent at tolerance 0 lands on sqrt(2) to double resolution")
}
def test_newton_f32_unchanged() -> unit ! { Test } = {
  r = newton(rg_xsq_minus_2_f32, rg_dxsq_f32, cast(1.5, f32), cast(1e-6, f32), cast(50, int64))
  assert_true(lt(rg_abs_f32(sub(r, cast(1.4142135, f32))), cast(0.00001, f32)), "f32 callers keep working through the generic signature")
}
