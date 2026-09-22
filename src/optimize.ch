module Nautilus.Optimize
import Nautilus.Optim (brent_minimize)
import Nautilus.Roots (brent)
export (minimize, root, optimize_ad_smoke)
-- chelis:provenance/v1 authority
-- id = NAUT-MOD-OPTIMIZE
-- kind = behavioral
-- scopes = nautilus
-- statement = Nautilus.Optimize MUST provide the stable minimize and root wrapper surface listed in the module support table.
def minimize(f: f32 -> f32, lo: f32, hi: f32, tol: f32, max_iters: i64) -> f32 = brent_minimize(f, lo, hi, tol, max_iters)
def root(f: f32 -> f32, lo: f32, hi: f32, tol: f32, max_iters: i64) -> f32 = brent(f, lo, hi, tol, max_iters)
def optimize_ad_smoke(x: f32) -> f32 = {
  y = sub(x, cast(2.0, f32))
  mul(y, y)
}
