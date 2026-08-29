module Nautilus.Optim
export (golden_section_search, brent_minimize, gradient_descent_1d, newton_minimize_1d)
-- chelis:provenance/v1 authority
-- id = NAUT-MOD-OPTIM
-- kind = behavioral
-- scopes = nautilus
-- statement = Nautilus.Optim MUST provide the scalar-optimization surface listed in the module support table.
def opt_abs_f32(x: f32) -> f32 = if lt(x, cast(0.0, f32)) then neg(x) else x
def opt_nan_f32() -> f32 = cast(0.0, f32) |> div(cast(0.0, f32))
def opt_phi() -> f32 = cast(0.6180339887, f32)
def opt_gs_rec(f: f32 -> f32, a: f32, b: f32, tol: f32, iters: int64) -> f32 = {
  zero_i = cast(0, int64)
  one_i = cast(1, int64)
  if lte(iters, zero_i) then cast(0.5, f32) |> mul(add(a, b)) else {
    width = sub(b, a)
    awidth = opt_abs_f32(width)
    if lt(awidth, tol) then cast(0.5, f32) |> mul(add(a, b)) else {
      phi = opt_phi()
      gap = mul(phi, width)
      c = sub(b, gap)
      d = add(a, gap)
      fc = f(c)
      fd = f(d)
      if eq(fc, fd) then cast(0.5, f32) |> mul(add(c, d)) else if lt(fc, fd) then opt_gs_rec(f, a, d, tol, sub(iters, one_i)) else opt_gs_rec(f, c, b, tol, sub(iters, one_i))
    }
  }
}
def golden_section_search(f: f32 -> f32, lo: f32, hi: f32, tol: f32, max_iters: int64) -> f32 = opt_gs_rec(f, lo, hi, tol, max_iters)
def opt_brent_rec(f: f32 -> f32, a: f32, b: f32, u: f32, v: f32, w: f32, fu: f32, fv: f32, fw: f32, tol: f32, iters: int64, total_iters: int64) -> f32 = {
  zero_i = cast(0, int64)
  one_i = cast(1, int64)
  two_i = cast(2, int64)
  tol_floor = cast(1e-6, f32)
  tol_eff = if lt(tol, tol_floor) then tol_floor else tol
  if lte(iters, zero_i) then u else {
    width = sub(b, a)
    awidth = opt_abs_f32(width)
    if lt(awidth, tol_eff) then u else {
      done_iters = sub(total_iters, iters)
      parity = mod(done_iters, two_i)
      use_golden = eq(parity, zero_i)
      if use_golden then {
        phi = opt_phi()
        gap = mul(phi, width)
        c = sub(b, gap)
        d = add(a, gap)
        fc = f(c)
        fd = f(d)
        if eq(fc, fd) then cast(0.5, f32) |> mul(add(c, d)) else if lt(fc, fd) then {
          new_fu = if lt(fc, fu) then fc else fu
          new_u = if lt(fc, fu) then c else u
          opt_brent_rec(f, a, d, new_u, u, v, new_fu, fu, fv, tol, sub(iters, one_i), total_iters)
        } else {
          new_fu = if lt(fd, fu) then fd else fu
          new_u = if lt(fd, fu) then d else u
          opt_brent_rec(f, c, b, new_u, u, v, new_fu, fu, fv, tol, sub(iters, one_i), total_iters)
        }
      } else {
        d1 = sub(v, u)
        d2 = sub(w, u)
        g1 = sub(fv, fu)
        g2 = sub(fw, fu)
        num1 = d1 |> mul(d1) |> mul(g2)
        num2 = d2 |> mul(d2) |> mul(g1)
        den1 = mul(d1, g2)
        den2 = mul(d2, g1)
        num = sub(num1, num2)
        den = sub(den1, den2)
        aden = opt_abs_f32(den)
        too_flat = lt(aden, cast(1e-30, f32))
        if too_flat then {
          phi = opt_phi()
          gap = mul(phi, width)
          c = sub(b, gap)
          d = add(a, gap)
          fc = f(c)
          fd = f(d)
          if eq(fc, fd) then cast(0.5, f32) |> mul(add(c, d)) else if lt(fc, fd) then {
            new_fu = if lt(fc, fu) then fc else fu
            new_u = if lt(fc, fu) then c else u
            opt_brent_rec(f, a, d, new_u, u, v, new_fu, fu, fv, tol, sub(iters, one_i), total_iters)
          } else {
            new_fu = if lt(fd, fu) then fd else fu
            new_u = if lt(fd, fu) then d else u
            opt_brent_rec(f, c, b, new_u, u, v, new_fu, fu, fv, tol, sub(iters, one_i), total_iters)
          }
        } else {
          half = cast(0.5, f32)
          offset = mul(half, div(num, den))
          cand = sub(u, offset)
          inside = cand |> gt(a) |> and(lt(cand, b))
          if eq(cand, u) then u else if inside then {
            fcand = f(cand)
            if lt(fcand, fu) then {
              new_a = if lt(cand, u) then a else u
              new_b = if lt(cand, u) then u else b
              opt_brent_rec(f, new_a, new_b, cand, u, v, fcand, fu, fv, tol, sub(iters, one_i), total_iters)
            } else {
              new_a = if lt(cand, u) then cand else a
              new_b = if lt(cand, u) then b else cand
              opt_brent_rec(f, new_a, new_b, u, cand, v, fu, fcand, fv, tol, sub(iters, one_i), total_iters)
            }
          } else {
            phi = opt_phi()
            gap = mul(phi, width)
            c = sub(b, gap)
            d = add(a, gap)
            fc = f(c)
            fd = f(d)
            if eq(fc, fd) then cast(0.5, f32) |> mul(add(c, d)) else if lt(fc, fd) then {
              new_fu = if lt(fc, fu) then fc else fu
              new_u = if lt(fc, fu) then c else u
              opt_brent_rec(f, a, d, new_u, u, v, new_fu, fu, fv, tol, sub(iters, one_i), total_iters)
            } else {
              new_fu = if lt(fd, fu) then fd else fu
              new_u = if lt(fd, fu) then d else u
              opt_brent_rec(f, c, b, new_u, u, v, new_fu, fu, fv, tol, sub(iters, one_i), total_iters)
            }
          }
        }
      }
    }
  }
}
def brent_minimize(f: f32 -> f32, lo: f32, hi: f32, tol: f32, max_iters: int64) -> f32 = {
  mid = cast(0.5, f32) |> mul(add(lo, hi))
  quarter = add(lo, cast(0.25, f32) |> mul(sub(hi, lo)))
  three_q = add(lo, cast(0.75, f32) |> mul(sub(hi, lo)))
  fm = f(mid)
  fq = f(quarter)
  ft = f(three_q)
  opt_brent_rec(f, lo, hi, mid, quarter, three_q, fm, fq, ft, tol, max_iters, max_iters)
}
def opt_gd_rec(f: f32 -> f32, df: f32 -> f32, x: f32, lr: f32, iters: int64) -> f32 = {
  zero_i = cast(0, int64)
  one_i = cast(1, int64)
  if lte(iters, zero_i) then x else {
    g = df(x)
    ag = opt_abs_f32(g)
    if lt(ag, cast(1e-10, f32)) then x else {
      x_next = sub(x, mul(lr, g))
      x_next_abs = opt_abs_f32(x_next)
      runaway = gt(x_next_abs, cast(1000000000000000.0, f32))
      diff = sub(x_next, x_next)
      nan_produced = diff |> eq(cast(0.0, f32)) |> not
      if or(runaway, nan_produced) then opt_nan_f32() else if eq(x_next, x) then x_next else opt_gd_rec(f, df, x_next, lr, sub(iters, one_i))
    }
  }
}
def gradient_descent_1d(f: f32 -> f32, df: f32 -> f32, x0: f32, lr: f32, max_iters: int64) -> f32 = opt_gd_rec(f, df, x0, lr, max_iters)
def opt_nmin_rec(f: f32 -> f32, df: f32 -> f32, ddf: f32 -> f32, x: f32, tol: f32, iters: int64) -> f32 = {
  zero_i = cast(0, int64)
  one_i = cast(1, int64)
  if lte(iters, zero_i) then opt_nan_f32() else {
    g = df(x)
    ag = opt_abs_f32(g)
    if lt(ag, tol) then {
      h = ddf(x)
      ah = opt_abs_f32(h)
      curvature_floor = cast(0.01, f32)
      if lt(ah, curvature_floor) then opt_nan_f32() else if lte(h, cast(0.0, f32)) then opt_nan_f32() else x
    } else {
      h = ddf(x)
      ah = opt_abs_f32(h)
      if lt(ah, cast(1e-30, f32)) then opt_nan_f32() else {
        step = div(g, h)
        x_next = sub(x, step)
        if eq(x_next, x) then x_next else opt_nmin_rec(f, df, ddf, x_next, tol, sub(iters, one_i))
      }
    }
  }
}
def newton_minimize_1d(f: f32 -> f32, df: f32 -> f32, ddf: f32 -> f32, x0: f32, tol: f32, max_iters: int64) -> f32 = opt_nmin_rec(f, df, ddf, x0, tol, max_iters)
