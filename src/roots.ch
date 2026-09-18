module Nautilus.Roots
export (bisection, newton, brent)
-- chelis:provenance/v1 authority
-- id = NAUT-MOD-ROOTS
-- kind = behavioral
-- scopes = nautilus
-- statement = Nautilus.Roots MUST provide the root-finding surface listed in the module support table.
def r_abs[prec: Float](x: prec) -> prec = if lt(x, cast(0.0, prec)) then neg(x) else x
-- The witness fixes the binder at the call site (chelis#2056: a bound that
-- occurs only in a nullary def's return type checks clean and runs in no lane).
def r_nan[prec: Float](witness: prec) -> prec = cast(0.0, prec) |> div(cast(0.0, prec))
def bisection_rec[prec: Float](f: prec -> prec, lo: prec, hi: prec, flo: prec, tol: prec, iters: int64) -> prec = {
  zero_i = cast(0, int64)
  one_i = cast(1, int64)
  if lte(iters, zero_i) then r_nan(lo) else {
    width = sub(hi, lo)
    if lt(width, tol) then cast(0.5, prec) |> mul(add(lo, hi)) else {
      mid = cast(0.5, prec) |> mul(add(lo, hi))
      if or(eq(mid, lo), eq(mid, hi)) then mid else {
        fmid = f(mid)
        afmid = r_abs(fmid)
        if lt(afmid, tol) then mid else {
          same_sign = flo |> mul(fmid) |> gt(cast(0.0, prec))
          if same_sign then bisection_rec(f, mid, hi, fmid, tol, sub(iters, one_i)) else bisection_rec(f, lo, mid, flo, tol, sub(iters, one_i))
        }
      }
    }
  }
}
def bisection[prec: Float](f: prec -> prec, lo: prec, hi: prec, tol: prec, max_iters: int64) -> prec = {
  flo = f(lo)
  aflo = r_abs(flo)
  if lt(aflo, tol) then lo else {
    fhi = f(hi)
    afhi = r_abs(fhi)
    if lt(afhi, tol) then hi else {
      prod = mul(flo, fhi)
      if gt(prod, cast(0.0, prec)) then r_nan(lo) else bisection_rec(f, lo, hi, flo, tol, max_iters)
    }
  }
}
def newton_rec[prec: Float](f: prec -> prec, df: prec -> prec, x: prec, tol: prec, iters: int64) -> prec = {
  zero_i = cast(0, int64)
  one_i = cast(1, int64)
  if lte(iters, zero_i) then r_nan(x) else {
    fx = f(x)
    afx = r_abs(fx)
    if lt(afx, tol) then x else {
      dfx = df(x)
      adfx = r_abs(dfx)
      if lt(adfx, cast(1e-30, prec)) then r_nan(x) else {
        step = div(fx, dfx)
        x_next = sub(x, step)
        if eq(x_next, x) then x_next else newton_rec(f, df, x_next, tol, sub(iters, one_i))
      }
    }
  }
}
def newton[prec: Float](f: prec -> prec, df: prec -> prec, x0: prec, tol: prec, max_iters: int64) -> prec = {
  fx0 = f(x0)
  afx0 = r_abs(fx0)
  if lt(afx0, tol) then x0 else newton_rec(f, df, x0, tol, max_iters)
}
def brent_rec[prec: Float](f: prec -> prec, a: prec, b: prec, c: prec, d: prec, fa: prec, fb: prec, fc: prec, was_bisect: bool, tol: prec, iters: int64) -> prec = {
  zero_i = cast(0, int64)
  one_i = cast(1, int64)
  zero_f = cast(0.0, prec)
  half = cast(0.5, prec)
  if lte(iters, zero_i) then r_nan(a) else {
    afa = r_abs(fa)
    afb = r_abs(fb)
    swap = lt(afa, afb)
    a1 = if swap then b else a
    b1 = if swap then a else b
    fa1 = if swap then fb else fa
    fb1 = if swap then fa else fb
    c1 = if swap then a else c
    fc1 = if swap then fa else fc
    width = sub(b1, a1)
    awidth = r_abs(width)
    afb1 = r_abs(fb1)
    if lt(afb1, tol) then b1 else if lt(awidth, tol) then b1 else {
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
      three_a = cast(3.0, prec) |> mul(a1)
      m = cast(0.25, prec) |> mul(add(three_a, b1))
      cond_range = gt(mul(sub(s_try, m), sub(s_try, b1)), zero_f)
      diff_bc = b1 |> sub(c1) |> r_abs
      diff_cd = c1 |> sub(d) |> r_abs
      diff_sb = s_try |> sub(b1) |> r_abs
      half_bc = mul(half, diff_bc)
      half_cd = mul(half, diff_cd)
      cond_step_bisect = and(was_bisect, gte(diff_sb, half_bc))
      cond_step_interp = was_bisect |> not |> and(gte(diff_sb, half_cd))
      cond_small_bc = and(was_bisect, lt(diff_bc, tol))
      cond_small_cd = was_bisect |> not |> and(lt(diff_cd, tol))
      force_bisect = or(or(or(or(cond_range, cond_step_bisect), cond_step_interp), cond_small_bc), cond_small_cd)
      s = if force_bisect then mul(half, add(a1, b1)) else s_try
      this_was_bisect = force_bisect
      if or(eq(s, b1), eq(s, a1)) then b1 else {
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
def brent[prec: Float](f: prec -> prec, lo: prec, hi: prec, tol: prec, max_iters: int64) -> prec = {
  flo = f(lo)
  aflo = r_abs(flo)
  if lt(aflo, tol) then lo else {
    fhi = f(hi)
    afhi = r_abs(fhi)
    if lt(afhi, tol) then hi else {
      prod = mul(flo, fhi)
      if gt(prod, cast(0.0, prec)) then r_nan(lo) else brent_rec(f, lo, hi, hi, lo, flo, fhi, fhi, true, tol, max_iters)
    }
  }
}
