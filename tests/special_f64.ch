module Nautilus.Tests.SpecialF64
import Nautilus.Special (erf, erfc, erfinv, erf_t, erfinv_t, gamma, log_gamma, digamma, beta, lbeta, trigamma, bessel_i0, bessel_i1, bessel_k0, bessel_k1, bessel_j0, bessel_j1, bessel_y0, bessel_y1, airy_ai, airy_bi, ellipk, ellipe)
import Std.Test (assert_close, assert_true, assert_eq)
-- Every Float-generic Nautilus.Special export called at f64 (nautilus#59).
--
-- Reference values are mpmath at 50 dps, spelled to 17 significant figures.
-- Each tolerance was CHOSEN FROM MEASUREMENT, not from habit: it sits at
-- least 3x above the error this module actually realizes at f64 and at least
-- 2x below the error the same call realizes at f32. A pass therefore shows
-- the computation ran in f64 arithmetic. It does not merely show the call
-- typechecks, which is the failure mode a re-typed f32 kernel would have.
--
-- That claim was verified, not assumed. Running this file with every `f64`
-- rewritten to `f32` gives 7 passed, 23 failed. The 7 survivors are the three
-- algorithm-bound `erf`/`erfc` cases, the ceiling guard, the lane-agreement
-- invariant, and the two `grad` cases -- none of which is an accuracy claim.
-- Re-run that control if you retune a tolerance; four earlier candidate points
-- had to be moved because the f32 result there was correctly rounded and no
-- absolute tolerance could separate the two lanes. (The control needs
-- `erf_at_f64` renamed first, or the blind rewrite collides with
-- `erf_at_f32`.)
--
-- HOW MUCH BETTER f64 IS VARIES A LOT, and the tolerances here are not
-- accuracy claims. Six exports are limited by f32 rounding rather than by
-- their own coefficients and so reach f64 grade: `gamma`, `log_gamma`,
-- `beta`, `lbeta`, `ellipk`, `ellipe`. The rest are limited by their
-- approximations and improve by less.
--
-- No figure is quoted here for how much less, because there is no single
-- figure. Each tolerance below sits at least 3x above the error measured AT
-- ITS OWN TEST POINT and at least 2x below the error the same call realizes
-- at f32 -- that pairing is what makes the test discriminate, and several
-- tolerances are far looser than 3x. None of them says anything about its
-- function at any other argument. `bessel_y1` is the clearest warning: near
-- its large-x seam around 7.4 it is some six orders worse than at the 2.2 it
-- is tested at. No per-function, per-domain f64 figure is established
-- anywhere in this repo; measure the argument you care about.
--
-- `erf` is capped hardest. Abramowitz & Stegun 7.1.26 carries a 1.5e-7 error
-- of its own, so at x = 0.5 f64 measures 1.385e-7 against f32's 1.861e-7 and
-- no tolerance separates the two lanes. Its tests below assert the algorithm
-- bound and say so, and `test_f64_erf_is_not_more_accurate_than_f32` locks
-- the fact, so replacing the coefficients makes this suite fail loudly and
-- the accuracy documentation gets revisited with it.
--
-- `erfc` is the opposite case and the one place f64 changes what is
-- computable rather than how precisely. See the tail tests below.
def test_f64_erfinv() -> unit ! { Test } = assert_close(erfinv(0.5f64), 0.4769362762044699f64, 5e-10f64, "erfinv at f64; the f32 path misses this by 2.6e-8")
def test_f64_gamma() -> unit ! { Test } = assert_close(gamma(5.5f64), 52.34277778455352f64, 2e-9f64, "gamma at f64; the f32 path misses this by 1.1e-4")
def test_f64_log_gamma() -> unit ! { Test } = assert_close(log_gamma(12.25f64), 18.115669505710894f64, 5e-11f64, "log_gamma at f64; the f32 path misses this by 1.5e-6")
def test_f64_digamma() -> unit ! { Test } = assert_close(digamma(3.75f64), 1.1825373886117962f64, 1e-8f64, "digamma at f64; the f32 path misses this by 2.1e-7")
def test_f64_beta() -> unit ! { Test } = assert_close(beta(2.5f64, 3.5f64), 0.03681553890925539f64, 5e-13f64, "beta at f64; the f32 path misses this by 2.6e-8")
def test_f64_lbeta() -> unit ! { Test } = assert_close(lbeta(2.5f64, 3.5f64), -3.301835269962053f64, 1e-11f64, "lbeta at f64; the f32 path misses this by 7.3e-7")
def test_f64_trigamma() -> unit ! { Test } = assert_close(trigamma(2.5f64), 0.49035775610023485f64, 1e-8f64, "trigamma at f64; the f32 path misses this by 6.4e-8")
def test_f64_bessel_i0() -> unit ! { Test } = assert_close(bessel_i0(1.5f64), 1.646723189772891f64, 4e-8f64, "bessel_i0 at f64; the f32 path misses this by 1.1e-7")
def test_f64_bessel_i1() -> unit ! { Test } = assert_close(bessel_i1(3.0f64), 3.9533702174026093f64, 5e-8f64, "bessel_i1 at f64; the f32 path misses this by 3.8e-7, over an ulp")
def test_f64_bessel_k0() -> unit ! { Test } = assert_close(bessel_k0(1.5f64), 0.21380556264752573f64, 2e-8f64, "bessel_k0 at f64; the f32 path misses this by 5.7e-8")
def test_f64_bessel_k1() -> unit ! { Test } = assert_close(bessel_k1(1.5f64), 0.2773878004568438f64, 1e-8f64, "bessel_k1 at f64; the f32 path misses this by 3.0e-8")
def test_f64_bessel_j0() -> unit ! { Test } = assert_close(bessel_j0(5.0f64), -0.1775967713143383f64, 2e-8f64, "bessel_j0 at f64; the f32 path misses this by 9.9e-8, several ulp")
def test_f64_bessel_j1() -> unit ! { Test } = assert_close(bessel_j1(1.5f64), 0.5579365079100996f64, 5e-10f64, "bessel_j1 at f64; the f32 path misses this by 4.2e-8")
def test_f64_bessel_y0() -> unit ! { Test } = assert_close(bessel_y0(1.5f64), 0.38244892379775886f64, 5e-9f64, "bessel_y0 at f64; the f32 path misses this by 1.6e-8")
def test_f64_bessel_y1() -> unit ! { Test } = assert_close(bessel_y1(2.2f64), 0.0014877892897632759f64, 2e-9f64, "bessel_y1 at f64; cancellation near the 2.2 crossing costs the f32 path 2.7e-8")
def test_f64_airy_ai() -> unit ! { Test } = assert_close(airy_ai(1.5f64), 0.07174949700810541f64, 5e-10f64, "airy_ai at f64; the f32 path misses this by 1.3e-8")
def test_f64_airy_bi() -> unit ! { Test } = assert_close(airy_bi(3.0f64), 14.037328963730232f64, 5e-8f64, "airy_bi at f64; the f32 path misses this by 1.0e-6")
def test_f64_ellipk() -> unit ! { Test } = assert_close(ellipk(0.3f64), 1.7138894481787912f64, 2e-12f64, "ellipk at f64; the AGM converges to f64 and the f32 path misses this by 1.5e-7")
def test_f64_ellipe() -> unit ! { Test } = assert_close(ellipe(0.3f64), 1.4453630644126654f64, 2e-12f64, "ellipe at f64; the AGM converges to f64 and the f32 path misses this by 1.4e-7")
def test_f64_erfinv_t() -> unit ! { Test } = {
  ys = to_list(erfinv_t(to_tensor([0.25f64, 0.5f64, 0.875f64])))
  tol = 2e-9f64
  _ = assert_close(index(ys, 0i64), 0.2253120550121781f64, tol, "erfinv_t[0] at f64; the f32 path misses this by 5.0e-9")
  _ = assert_close(index(ys, 1i64), 0.4769362762044699f64, tol, "erfinv_t[1] at f64; the f32 path misses this by 2.6e-8")
  assert_close(index(ys, 2i64), 1.0847870400692832f64, tol, "erfinv_t[2] at f64; the f32 path misses this by 5.2e-6")
}
def test_f64_erf_t_small_arm() -> unit ! { Test } = {
  ys = to_list(erf_t(to_tensor([0.125f64])))
  assert_close(index(ys, 0i64), 0.14031620480133383f64, 5e-10f64, "erf_t's Maclaurin arm at x = 0.125 is f64-accurate; the f32 path misses this by 1.5e-8. The arm degrades toward the cutover -- 1.4e-8 at 0.24 and 1.97e-8 at 0.25 -- so this is a point measurement, not an arm-wide bound")
}
-- The two algorithm-bound exports. These tolerances are the A&S 7.1.26 bound,
-- not an f64 accuracy claim; see `erf`'s comment in src/special.ch.
def test_f64_erf_at_its_algorithm_bound() -> unit ! { Test } = assert_close(erf(0.5f64), 0.5204998778130465f64, 5e-7f64, "erf at f64 lands inside A&S 7.1.26's 1.5e-7 formula bound, which is all it can do")
def test_f64_erfc_at_its_algorithm_bound() -> unit ! { Test } = assert_close(erfc(1.0f64), 0.15729920705028513f64, 5e-7f64, "erfc at f64 lands inside the same bound, since it is 1 - erf")
def test_f64_erf_t_at_its_algorithm_bound() -> unit ! { Test } = {
  ys = to_list(erf_t(to_tensor([0.5f64, 1.5f64])))
  tol = 5e-7f64
  _ = assert_close(index(ys, 0i64), 0.5204998778130465f64, tol, "erf_t's rational arm carries the same bound as the scalar lane")
  assert_close(index(ys, 1i64), 0.9661051464753108f64, tol, "erf_t at 1.5 is bounded by the formula, not by the dtype")
}
-- Guard rails, not accuracy tests.
def test_f64_erf_is_not_more_accurate_than_f32() -> unit ! { Test } = {
  err = sub(erf(0.5f64), 0.5204998778130465f64)
  aerr = if lt(err, 0.0f64) then neg(err) else err
  assert_true(gt(aerr, 1e-8f64), "erf at f64 still carries an f32-grade approximation error (measured 1.385e-7). If this fails the coefficients changed: update src/special.ch's bound comment, docs/CHELIS_SURFACE.md and nautilus#59's caveat in the same change")
}
def test_f64_scalar_and_tensor_erf_agree() -> unit ! { Test } = {
  ys = to_list(erf_t(to_tensor([0.5f64])))
  assert_eq(index(ys, 0i64), erf(0.5f64), "the scalar and tensor erf lanes must agree exactly at f64, as they do at f32")
}
-- `erfc`'s f64 tail. f32 `erfc` underflows to exactly 0 from x = 4 because it
-- is computed as `1 - erf(x)` and the difference is below f32's resolution
-- near 1. f64 keeps returning values out to about x = 5.5. These are the
-- assertions that separate the two lanes most sharply, and the only ones that
-- distinguish "returns something usable" from "returns nothing at all".
def test_f64_erfc_tail_is_nonzero_where_f32_underflows() -> unit ! { Test } = {
  _ = assert_true(gt(erfc(4.0f64), 0.0f64), "erfc(4) at f64 is positive; at f32 it is exactly 0")
  _ = assert_true(gt(erfc(5.0f64), 0.0f64), "erfc(5) at f64 is positive; at f32 it is exactly 0")
  assert_true(lt(erfc(4.0f64), erfc(3.5f64)), "the f64 tail still decreases")
}
def test_f64_erfc_tail_magnitude() -> unit ! { Test } = {
  _ = assert_close(erfc(4.0f64), 1.5417257900280017e-8f64, 1e-10f64, "erfc(4) at f64 is right to ~3e-3 relative; the absolute bound it inherits from erf is what limits it")
  assert_close(erfc(5.0f64), 1.5374597944280351e-12f64, 1e-13f64, "erfc(5) at f64 remains finite and of the right magnitude")
}
-- `grad` over a generic export needs the dtype fixed first. The point-free
-- `grad(erf)` stopped type-checking when the module became generic, which
-- `tests_neg/special/grad_point_free_neg.ch` pins. These lock the wrapped
-- form, which is the shape callers should use, at both dtypes.
def erf_at_f32(x: f32) -> f32 = erf(x)
def erf_at_f64(x: f64) -> f64 = erf(x)
def test_f32_grad_through_a_wrapper_still_works() -> unit ! { Test } = assert_close(grad(erf_at_f32)(0.5f32), 0.8787826f32, 0.00001f32, "grad of a wrapped erf at f32, the shape that worked before the module became generic")
def test_f64_grad_through_a_wrapper_works() -> unit ! { Test } = assert_close(grad(erf_at_f64)(0.5f64), 0.8787825789354446f64, 1e-6f64, "grad of a wrapped erf at f64; 2/sqrt(pi) * exp(-0.25), to the approximation's own accuracy")
