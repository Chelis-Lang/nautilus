module Nautilus.Optimize
import Nautilus.Optim (brent_minimize)
import Nautilus.Roots (brent)
export (minimize, root, optimize_ad_smoke)
def minimize(f: f32 -> f32, lo: f32, hi: f32, tol: f32, max_iters: int64) -> f32 = brent_minimize(f, lo, hi, tol, max_iters)
def root(f: f32 -> f32, lo: f32, hi: f32, tol: f32, max_iters: int64) -> f32 = brent(f, lo, hi, tol, max_iters)
def optimize_ad_smoke(x: f32) -> f32 = {
  y = sub(x, cast(2.0, f32))
  mul(y, y)
}
