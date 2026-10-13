module Nautilus.Properties.Literature
import Nautilus.Distributions (uniform_cdf, uniform_inv_cdf)
import Nautilus.Interpolation (cubic_hermite)
-- Real-arithmetic bounds for the public uniform distribution functions.
@property uniform_cdf_range forall(x: f32, lo: f32, hi: f32) where hi > lo:
  ((uniform_cdf(x, lo, hi) >= 0.0f32) && (uniform_cdf(x, lo, hi) <= 1.0f32))
@property uniform_inverse_range forall(q: f32, lo: f32, hi: f32) where hi > lo, q >= 0.0f32, q <= 1.0f32:
  ((uniform_inv_cdf(q, lo, hi) >= lo) && (uniform_inv_cdf(q, lo, hi) <= hi))
-- With increasing data and endpoint slopes between zero and three times the
-- secant slope, the Hermite segment stays between its knots.
@property hermite_nonovershoot_lower forall(x0: f32, x1: f32, y0: f32, y1: f32, m0: f32, m1: f32, x: f32) where x1 > x0, y1 > y0, x >= x0, x <= x1, m0 >= 0.0f32, m1 >= 0.0f32, ((x1 - x0) * m0) <= (3.0f32 * (y1 - y0)), ((x1 - x0) * m1) <= (3.0f32 * (y1 - y0)):
  (cubic_hermite(x0, x1, y0, y1, m0, m1, x) >= y0)
@property hermite_nonovershoot_upper forall(x0: f32, x1: f32, y0: f32, y1: f32, m0: f32, m1: f32, x: f32) where x1 > x0, y1 > y0, x >= x0, x <= x1, m0 >= 0.0f32, m1 >= 0.0f32, ((x1 - x0) * m0) <= (3.0f32 * (y1 - y0)), ((x1 - x0) * m1) <= (3.0f32 * (y1 - y0)):
  (cubic_hermite(x0, x1, y0, y1, m0, m1, x) <= y1)
-- Reversing ordinate and slope signs gives the decreasing segment case.
@property hermite_decreasing_lower forall(x0: f32, x1: f32, y0: f32, y1: f32, m0: f32, m1: f32, x: f32) where x1 > x0, y1 < y0, x >= x0, x <= x1, m0 <= 0.0f32, m1 <= 0.0f32, ((x1 - x0) * m0) >= (3.0f32 * (y1 - y0)), ((x1 - x0) * m1) >= (3.0f32 * (y1 - y0)):
  (cubic_hermite(x0, x1, y0, y1, m0, m1, x) >= y1)
@property hermite_decreasing_upper forall(x0: f32, x1: f32, y0: f32, y1: f32, m0: f32, m1: f32, x: f32) where x1 > x0, y1 < y0, x >= x0, x <= x1, m0 <= 0.0f32, m1 <= 0.0f32, ((x1 - x0) * m0) >= (3.0f32 * (y1 - y0)), ((x1 - x0) * m1) >= (3.0f32 * (y1 - y0)):
  (cubic_hermite(x0, x1, y0, y1, m0, m1, x) <= y0)
