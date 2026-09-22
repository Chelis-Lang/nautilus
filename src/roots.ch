module Nautilus.Roots
export (bisection, newton, brent)
-- chelis:provenance/v1 authority
-- id = NAUT-MOD-ROOTS
-- kind = behavioral
-- scopes = nautilus
-- statement = Nautilus.Roots MUST provide the root-finding surface listed in the module support table.
def r_abs_f32(x: f32) -> f32 = if lt(x, cast(0.0, f32)) then neg(x) else x
def r_nan_f32() -> f32 = cast(0.0, f32) |> div(cast(0.0, f32))
def bisection_rec(f: f32 -> f32, lo: f32, hi: f32, flo: f32, tol: f32, iters: i64) -> f32 = {
  zero_i = cast(0, i64)
  one_i = cast(1, i64)
  if lte(iters, zero_i) then r_nan_f32() else {
    width = sub(hi, lo)
    if lt(width, tol) then cast(0.5, f32) |> mul(add(lo, hi)) else {
      mid = cast(0.5, f32) |> mul(add(lo, hi))
      if or(eq(mid, lo), eq(mid, hi)) then mid else {
        fmid = f(mid)
        afmid = r_abs_f32(fmid)
        if lt(afmid, tol) then mid else {
          same_sign = flo |> mul(fmid) |> gt(cast(0.0, f32))
          if same_sign then bisection_rec(f, mid, hi, fmid, tol, sub(iters, one_i)) else bisection_rec(f, lo, mid, flo, tol, sub(iters, one_i))
        }
      }
    }
  }
}
def bisection(f: f32 -> f32, lo: f32, hi: f32, tol: f32, max_iters: i64) -> f32 = {
  flo = f(lo)
  aflo = r_abs_f32(flo)
  if lt(aflo, tol) then lo else {
    fhi = f(hi)
    afhi = r_abs_f32(fhi)
    if lt(afhi, tol) then hi else {
      prod = mul(flo, fhi)
      if gt(prod, cast(0.0, f32)) then r_nan_f32() else bisection_rec(f, lo, hi, flo, tol, max_iters)
    }
  }
}
def newton_rec(f: f32 -> f32, df: f32 -> f32, x: f32, tol: f32, iters: i64) -> f32 = {
  zero_i = cast(0, i64)
  one_i = cast(1, i64)
  if lte(iters, zero_i) then r_nan_f32() else {
    fx = f(x)
    afx = r_abs_f32(fx)
    if lt(afx, tol) then x else {
      dfx = df(x)
      adfx = r_abs_f32(dfx)
      if lt(adfx, cast(1e-30, f32)) then r_nan_f32() else {
        step = div(fx, dfx)
        x_next = sub(x, step)
        if eq(x_next, x) then x_next else newton_rec(f, df, x_next, tol, sub(iters, one_i))
      }
    }
  }
}
def newton(f: f32 -> f32, df: f32 -> f32, x0: f32, tol: f32, max_iters: i64) -> f32 = {
  fx0 = f(x0)
  afx0 = r_abs_f32(fx0)
  if lt(afx0, tol) then x0 else newton_rec(f, df, x0, tol, max_iters)
}
def brent_rec(f: f32 -> f32, a: f32, b: f32, c: f32, d: f32, fa: f32, fb: f32, fc: f32, was_bisect: bool, tol: f32, iters: i64) -> f32 = {
  zero_i = cast(0, i64)
  one_i = cast(1, i64)
  zero_f = cast(0.0, f32)
  half = cast(0.5, f32)
  tol_floor = cast(1e-6, f32)
  tol_eff = if lt(tol, tol_floor) then tol_floor else tol
  if lte(iters, zero_i) then r_nan_f32() else {
    afa = r_abs_f32(fa)
    afb = r_abs_f32(fb)
    swap = lt(afa, afb)
    a1 = if swap then b else a
    b1 = if swap then a else b
    fa1 = if swap then fb else fa
    fb1 = if swap then fa else fb
    c1 = if swap then a else c
    fc1 = if swap then fa else fc
    width = sub(b1, a1)
    awidth = r_abs_f32(width)
    afb1 = r_abs_f32(fb1)
    if lt(afb1, tol_eff) then b1 else if lt(awidth, tol_eff) then b1 else {
      use_iqi = and(not(eq(fa1, fc1)), not(eq(fb1, fc1)))
      d_ab = sub(fa1, fb1)
      d_ac = sub(fa1, fc1)
      d_bc = sub(fb1, fc1)
      nd_ab = neg(d_ab)
      nd_ac = neg(d_ac)
      nd_bc = neg(d_bc)
      iqi_t1 = a1 |> mul(mul(fb1, fc1)) |> div(mul(d_ab, d_ac))
      iqi_t2 = b1 |> mul(mul(fa1, fc1)) |> div(mul(nd_ab, d_bc))
      iqi_t3 = c1 |> mul(mul(fa1, fb1)) |> div(mul(nd_ac, nd_bc))
      s_iqi = iqi_t1 |> add(iqi_t2) |> add(iqi_t3)
      sec_denom = sub(fb1, fa1)
      sec_step = fb1 |> mul(sub(b1, a1)) |> div(sec_denom)
      s_sec = sub(b1, sec_step)
      s_try = if use_iqi then s_iqi else s_sec
      three_a = cast(3.0, f32) |> mul(a1)
      m = cast(0.25, f32) |> mul(add(three_a, b1))
      cond_range = gt(mul(sub(s_try, m), sub(s_try, b1)), zero_f)
      diff_bc = b1 |> sub(c1) |> r_abs_f32
      diff_cd = c1 |> sub(d) |> r_abs_f32
      diff_sb = s_try |> sub(b1) |> r_abs_f32
      half_bc = mul(half, diff_bc)
      half_cd = mul(half, diff_cd)
      cond_step_bisect = and(was_bisect, gte(diff_sb, half_bc))
      cond_step_interp = was_bisect |> not |> and(gte(diff_sb, half_cd))
      cond_small_bc = and(was_bisect, lt(diff_bc, tol_eff))
      cond_small_cd = was_bisect |> not |> and(lt(diff_cd, tol_eff))
      force_bisect = or(or(or(or(cond_range, cond_step_bisect), cond_step_interp), cond_small_bc), cond_small_cd)
      s = if force_bisect then mul(half, add(a1, b1)) else s_try
      this_was_bisect = force_bisect
      if eq(s, b1) then b1 else {
        fs = f(s)
        d_new = c1
        c_new = b1
        fc_new = fb1
        same_sign = fa1 |> mul(fs) |> gt(zero_f)
        a_new = if same_sign then s else a1
        fa_new = if same_sign then fs else fa1
        b_new = if same_sign then b1 else s
        fb_new = if same_sign then fb1 else fs
        brent_rec(f, a_new, b_new, c_new, d_new, fa_new, fb_new, fc_new, this_was_bisect, tol, sub(iters, one_i))
      }
    }
  }
}
def brent(f: f32 -> f32, lo: f32, hi: f32, tol: f32, max_iters: i64) -> f32 = {
  flo = f(lo)
  aflo = r_abs_f32(flo)
  if lt(aflo, tol) then lo else {
    fhi = f(hi)
    afhi = r_abs_f32(fhi)
    if lt(afhi, tol) then hi else {
      prod = mul(flo, fhi)
      if gt(prod, cast(0.0, f32)) then r_nan_f32() else brent_rec(f, lo, hi, hi, lo, flo, fhi, fhi, true, tol, max_iters)
    }
  }
}
