module Nautilus.ProofControls.LiteratureWrong
import Nautilus.Distributions (uniform_cdf, uniform_inv_cdf)
import Nautilus.Interpolation (cubic_hermite)
@property uniform_cdf_upper_wrong forall(lo: f32, hi: f32) where hi > lo:
  (uniform_cdf(hi, lo, hi) <= 0.9f32)
@property uniform_inverse_upper_wrong forall(q: f32) where q >= 0.1f32, q <= 0.9f32:
  (uniform_inv_cdf(q, 2.0f32, 8.0f32) <= 7.0f32)
@property hermite_unrestricted_slope_wrong forall(x: f32) where x >= 0.0f32, x <= 1.0f32:
  (cubic_hermite(0.0f32, 1.0f32, 0.0f32, 1.0f32, 4.0f32, 0.0f32, x) <= 1.0f32)
@property hermite_decreasing_unrestricted_wrong forall(x: f32) where x >= 0.0f32, x <= 1.0f32:
  (cubic_hermite(0.0f32, 1.0f32, 1.0f32, 0.0f32, -4.0f32, 0.0f32, x) >= 0.0f32)
