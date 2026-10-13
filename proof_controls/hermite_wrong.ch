module Nautilus.Proof_controls.Hermite_wrong
import Nautilus.Interpolation (cubic_hermite)
-- The left knot returns y0, so claiming it always returns y1 must refute.
@property hermite_left_returns_right forall(x0: f32, x1: f32, y0: f32, y1: f32, m0: f32, m1: f32) where x1 > x0:
  (cubic_hermite(x0, x1, y0, y1, m0, m1, x0) == y1)
