module Nautilus.Roots
export (bisection, newton, brent)

def r_abs_f32(x: f32) -> f32 = if lt(x, cast(0.0, f32)) then neg(x) else x
def r_nan_f32() -> f32 = div(cast(0.0, f32), cast(0.0, f32))

def bisection_rec(
  f: f32 -> f32,
  lo: f32,
  hi: f32,
  flo: f32,
  tol: f32,
  iters: int64
) -> f32 = {
  zero_i = cast(0, int64)
  one_i = cast(1, int64)
  if lte(iters, zero_i) then r_nan_f32()
  else {
    width = sub(hi, lo)
    if lt(width, tol) then mul(cast(0.5, f32), add(lo, hi))
    else {
      mid = mul(cast(0.5, f32), add(lo, hi))
      fmid = f(mid)
      afmid = r_abs_f32(fmid)
      if lt(afmid, tol) then mid
      else {
        same_sign = gt(mul(flo, fmid), cast(0.0, f32))
        if same_sign then bisection_rec(f, mid, hi, fmid, tol, sub(iters, one_i))
        else bisection_rec(f, lo, mid, flo, tol, sub(iters, one_i))
      }
    }
  }
}

def bisection(f: f32 -> f32, lo: f32, hi: f32, tol: f32, max_iters: int64) -> f32 = {
  flo = f(lo)
  aflo = r_abs_f32(flo)
  if lt(aflo, tol) then lo
  else {
    fhi = f(hi)
    afhi = r_abs_f32(fhi)
    if lt(afhi, tol) then hi
    else {
      prod = mul(flo, fhi)
      if gt(prod, cast(0.0, f32)) then r_nan_f32()
      else bisection_rec(f, lo, hi, flo, tol, max_iters)
    }
  }
}

def newton_rec(
  f: f32 -> f32,
  df: f32 -> f32,
  x: f32,
  tol: f32,
  iters: int64
) -> f32 = {
  zero_i = cast(0, int64)
  one_i = cast(1, int64)
  if lte(iters, zero_i) then r_nan_f32()
  else {
    fx = f(x)
    afx = r_abs_f32(fx)
    if lt(afx, tol) then x
    else {
      dfx = df(x)
      adfx = r_abs_f32(dfx)
      if lt(adfx, cast(1.0e-30, f32)) then r_nan_f32()
      else {
        step = div(fx, dfx)
        x_next = sub(x, step)
        newton_rec(f, df, x_next, tol, sub(iters, one_i))
      }
    }
  }
}

def newton(f: f32 -> f32, df: f32 -> f32, x0: f32, tol: f32, max_iters: int64) -> f32 = {
  fx0 = f(x0)
  afx0 = r_abs_f32(fx0)
  if lt(afx0, tol) then x0
  else newton_rec(f, df, x0, tol, max_iters)
}

def brent_rec(
  f: f32 -> f32,
  a: f32,
  b: f32,
  fa: f32,
  fb: f32,
  tol: f32,
  iters: int64,
  total_iters: int64
) -> f32 = {
  zero_i = cast(0, int64)
  one_i = cast(1, int64)
  two_i = cast(2, int64)
  if lte(iters, zero_i) then r_nan_f32()
  else {
    width = sub(b, a)
    awidth = r_abs_f32(width)
    if lt(awidth, tol) then mul(cast(0.5, f32), add(a, b))
    else {
      afb = r_abs_f32(fb)
      if lt(afb, tol) then b
      else {
        done_iters = sub(total_iters, iters)
        parity = mod(done_iters, two_i)
        bisect_this_iter = eq(parity, zero_i)
        if bisect_this_iter then {
          mid = mul(cast(0.5, f32), add(a, b))
          fmid = f(mid)
          same_sign = gt(mul(fa, fmid), cast(0.0, f32))
          if same_sign then brent_rec(f, mid, b, fmid, fb, tol, sub(iters, one_i), total_iters)
          else brent_rec(f, a, mid, fa, fmid, tol, sub(iters, one_i), total_iters)
        } else {
          denom = sub(fb, fa)
          adenom = r_abs_f32(denom)
          too_flat = lt(adenom, cast(1.0e-30, f32))
          if too_flat then {
            mid = mul(cast(0.5, f32), add(a, b))
            fmid = f(mid)
            same_sign = gt(mul(fa, fmid), cast(0.0, f32))
            if same_sign then brent_rec(f, mid, b, fmid, fb, tol, sub(iters, one_i), total_iters)
            else brent_rec(f, a, mid, fa, fmid, tol, sub(iters, one_i), total_iters)
          } else {
            slope = div(denom, width)
            step = div(fb, slope)
            cand = sub(b, step)
            qa = add(a, mul(cast(0.25, f32), width))
            qb = sub(b, mul(cast(0.25, f32), width))
            inside = and(gt(cand, qa), lt(cand, qb))
            if inside then {
              fcand = f(cand)
              same_sign = gt(mul(fa, fcand), cast(0.0, f32))
              if same_sign then brent_rec(f, cand, b, fcand, fb, tol, sub(iters, one_i), total_iters)
              else brent_rec(f, a, cand, fa, fcand, tol, sub(iters, one_i), total_iters)
            } else {
              mid = mul(cast(0.5, f32), add(a, b))
              fmid = f(mid)
              same_sign = gt(mul(fa, fmid), cast(0.0, f32))
              if same_sign then brent_rec(f, mid, b, fmid, fb, tol, sub(iters, one_i), total_iters)
              else brent_rec(f, a, mid, fa, fmid, tol, sub(iters, one_i), total_iters)
            }
          }
        }
      }
    }
  }
}

def brent(f: f32 -> f32, lo: f32, hi: f32, tol: f32, max_iters: int64) -> f32 = {
  flo = f(lo)
  aflo = r_abs_f32(flo)
  if lt(aflo, tol) then lo
  else {
    fhi = f(hi)
    afhi = r_abs_f32(fhi)
    if lt(afhi, tol) then hi
    else {
      prod = mul(flo, fhi)
      if gt(prod, cast(0.0, f32)) then r_nan_f32()
      else brent_rec(f, lo, hi, flo, fhi, tol, max_iters, max_iters)
    }
  }
}
