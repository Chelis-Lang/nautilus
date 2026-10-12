module Nautilus.Properties.Interpolation
import Nautilus.Interpolation (cubic_hermite)
-- A Hermite segment returns each endpoint value, regardless of the endpoint
-- slopes, when the knot interval is nonempty. The solver checks real arithmetic.
@property hermite_left_endpoint forall(x0: f32, x1: f32, y0: f32, y1: f32, m0: f32, m1: f32) where x1 > x0:
  (cubic_hermite(x0, x1, y0, y1, m0, m1, x0) == y0)
@property hermite_right_endpoint forall(x0: f32, x1: f32, y0: f32, y1: f32, m0: f32, m1: f32) where x1 > x0:
  (cubic_hermite(x0, x1, y0, y1, m0, m1, x1) == y1)
