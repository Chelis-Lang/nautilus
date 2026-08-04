module Nautilus.Interpolation
export (linear_interp_uniform, linear_interp_sorted, cubic_hermite, spline_fit, spline_eval)
def interp_zero_f() -> f32 = cast(0.0, f32)
def interp_one_f() -> f32 = cast(1.0, f32)
def interp_two_f() -> f32 = cast(2.0, f32)
def interp_three_f() -> f32 = cast(3.0, f32)
def interp_zero_i() -> int64 = cast(0, int64)
def interp_one_i() -> int64 = cast(1, int64)
def interp_abs_f32(x: f32) -> f32 = if lt(x, cast(0.0, f32)) then neg(x) else x
def interp_max_i64(a: int64, b: int64) -> int64 = if gt(a, b) then a else b
def interp_min_i64(a: int64, b: int64) -> int64 = if lt(a, b) then a else b
def linear_interp_uniform[n](ys: &tensor[n, f32], x_min: f32, x_max: f32, x_query: f32) -> f32 = {
  n_i = numel(copy(ys))
  n_minus_1_i = sub(n_i, interp_one_i())
  n_minus_1_f = cast(n_minus_1_i, f32)
  lst = to_list(ys)
  enum_lst = enumerate(lst)
  span = sub(x_max, x_min)
  h = div(span, n_minus_1_f)
  u_raw = div(sub(x_query, x_min), h)
  u_lo_clamped = if lt(u_raw, interp_zero_f()) then interp_zero_f() else u_raw
  u_clamped = if gt(u_lo_clamped, n_minus_1_f) then n_minus_1_f else u_lo_clamped
  k_trunc_i = cast_trunc(u_clamped, int64)
  k_i_pre = interp_min_i64(k_trunc_i, sub(n_minus_1_i, interp_one_i()))
  k_i = interp_max_i64(k_i_pre, interp_zero_i())
  k_f = cast(k_i, f32)
  kp1_i = add(k_i, interp_one_i())
  picked = fold(fn (acc: (f32, f32), pair: (int64, f32)) -> {
    i = pair.0
    v = pair.1
    take_lo = eq(i, k_i)
    take_hi = eq(i, kp1_i)
    if take_lo then (v, acc.1) else if take_hi then (acc.0, v) else acc
  }, (interp_zero_f(), interp_zero_f()), enum_lst)
  y_lo = picked.0
  y_hi = picked.1
  frac = sub(u_clamped, k_f)
  add(y_lo, mul(frac, sub(y_hi, y_lo)))
}
def linear_interp_sorted[n](xs: &tensor[n, f32], ys: &tensor[n, f32], x_query: f32) -> f32 = {
  n_i = numel(copy(xs))
  last_i = sub(n_i, interp_one_i())
  x_list = to_list(xs)
  y_list = to_list(ys)
  zipped = zip(x_list, y_list)
  enum_zipped = enumerate(zipped)
  init = (false, interp_zero_f(), interp_zero_f(), interp_zero_f(), interp_zero_f(), interp_zero_f(), interp_zero_f(), interp_zero_f(), interp_zero_f(), interp_zero_f(), interp_zero_f())
  acc_final = fold(fn (acc: (bool, f32, f32, f32, f32, f32, f32, f32, f32, f32, f32), entry: (int64, (f32, f32))) -> {
    i = entry.0
    xy = entry.1
    xi = xy.0
    yi = xy.1
    is_first = eq(i, interp_zero_i())
    is_last = eq(i, last_i)
    first_x_new = if is_first then xi else acc.7
    first_y_new = if is_first then yi else acc.8
    last_x_new = if is_last then xi else acc.9
    last_y_new = if is_last then yi else acc.10
    not_found = not(acc.0)
    not_first = not(is_first)
    in_range_lo = gte(x_query, acc.5)
    in_range_hi = lte(x_query, xi)
    in_range = and(in_range_lo, in_range_hi)
    bracket_hit = and(and(not_found, not_first), in_range)
    found_new = if bracket_hit then true else acc.0
    y_lo_new = if bracket_hit then acc.6 else acc.1
    y_hi_new = if bracket_hit then yi else acc.2
    x_lo_new = if bracket_hit then acc.5 else acc.3
    x_hi_new = if bracket_hit then xi else acc.4
    (found_new, y_lo_new, y_hi_new, x_lo_new, x_hi_new, xi, yi, first_x_new, first_y_new, last_x_new, last_y_new)
  }, init, enum_zipped)
  found = acc_final.0
  y_lo = acc_final.1
  y_hi = acc_final.2
  x_lo = acc_final.3
  x_hi = acc_final.4
  first_x = acc_final.7
  first_y = acc_final.8
  last_y = acc_final.10
  dx = sub(x_hi, x_lo)
  frac = div(sub(x_query, x_lo), dx)
  bracket_val = add(y_lo, mul(frac, sub(y_hi, y_lo)))
  if found then bracket_val else if lt(x_query, first_x) then first_y else last_y
}
def cubic_hermite(x0: f32, x1: f32, y0: f32, y1: f32, m0: f32, m1: f32, x_query: f32) -> f32 = {
  h = sub(x1, x0)
  if eq(h, interp_zero_f()) then div(interp_zero_f(), interp_zero_f()) else {
    t = div(sub(x_query, x0), h)
    t2 = mul(t, t)
    t3 = mul(t2, t)
    two_t3 = mul(interp_two_f(), t3)
    three_t2 = mul(interp_three_f(), t2)
    two_t2 = mul(interp_two_f(), t2)
    h00 = add(sub(two_t3, three_t2), interp_one_f())
    h10 = add(sub(t3, two_t2), t)
    h01 = sub(three_t2, two_t3)
    h11 = sub(t3, t2)
    term0 = mul(h00, y0)
    term1 = mul(h10, mul(h, m0))
    term2 = mul(h01, y1)
    term3 = mul(h11, mul(h, m1))
    add(add(term0, term1), add(term2, term3))
  }
}
def spline_zeros[m](xs: &tensor[m, f32]) -> tensor[m, f32] = to_tensor(map(fn (v: f32) -> cast(0.0, f32), to_list(xs)))
def spline_fit_h[m](xs: tensor[m, f32], h0: tensor[m, f32], n_len_m1: int64) -> tensor[m, f32] = {
  fold(fn (hacc: tensor[m, f32], i: int64) -> {
    tpl_loc = spline_zeros(copy(hacc))
    e_i = la_basis_n_f32(i, cast(1.0, f32), copy(tpl_loc))
    e_ip1 = la_basis_n_f32(add(i, cast(1, int64)), cast(1.0, f32), tpl_loc)
    xi = inner_product(copy(xs), copy(e_i))
    xip1 = inner_product(copy(xs), e_ip1)
    hi = sub(xip1, xi)
    abs_hi = if lt(hi, cast(0.0, f32)) then neg(hi) else hi
    safe_hi = if lt(abs_hi, cast(0.000000000000000000000000000001, f32)) then cast(1.0, f32) else hi
    la_vec_saxpy(safe_hi, hacc, e_i)
  }, h0, range(cast(0, int64), n_len_m1))
}
def spline_fit_lower[m](h: tensor[m, f32], low0: tensor[m, f32], n_len_m1: int64) -> tensor[m, f32] = {
  fold(fn (acc: tensor[m, f32], i: int64) -> {
    tpl_loc = spline_zeros(copy(acc))
    e_im1 = la_basis_n_f32(sub(i, cast(1, int64)), cast(1.0, f32), copy(tpl_loc))
    e_i = la_basis_n_f32(i, cast(1.0, f32), tpl_loc)
    h_im1 = inner_product(copy(h), e_im1)
    la_vec_saxpy(h_im1, acc, e_i)
  }, low0, range(cast(1, int64), n_len_m1))
}
def spline_fit_diag[m](h: tensor[m, f32], d_init: tensor[m, f32], n_len_m1: int64) -> tensor[m, f32] = {
  fold(fn (acc: tensor[m, f32], i: int64) -> {
    tpl_loc = spline_zeros(copy(acc))
    e_im1 = la_basis_n_f32(sub(i, cast(1, int64)), cast(1.0, f32), copy(tpl_loc))
    e_i = la_basis_n_f32(i, cast(1.0, f32), tpl_loc)
    h_im1 = inner_product(copy(h), e_im1)
    h_i = inner_product(copy(h), copy(e_i))
    d_i = mul(cast(2.0, f32), add(h_im1, h_i))
    la_vec_saxpy(d_i, acc, e_i)
  }, d_init, range(cast(1, int64), n_len_m1))
}
def spline_fit_upper[m](h: tensor[m, f32], up0: tensor[m, f32], n_len_m1: int64) -> tensor[m, f32] = {
  fold(fn (acc: tensor[m, f32], i: int64) -> {
    tpl_loc = spline_zeros(copy(acc))
    e_i = la_basis_n_f32(i, cast(1.0, f32), tpl_loc)
    h_i = inner_product(copy(h), copy(e_i))
    la_vec_saxpy(h_i, acc, e_i)
  }, up0, range(cast(1, int64), n_len_m1))
}
def spline_fit_rhs[m](ys: tensor[m, f32], h: tensor[m, f32], rhs0: tensor[m, f32], n_len_m1: int64) -> tensor[m, f32] = {
  fold(fn (acc: tensor[m, f32], i: int64) -> {
    tpl_loc = spline_zeros(copy(acc))
    e_im1 = la_basis_n_f32(sub(i, cast(1, int64)), cast(1.0, f32), copy(tpl_loc))
    e_i = la_basis_n_f32(i, cast(1.0, f32), copy(tpl_loc))
    e_ip1 = la_basis_n_f32(add(i, cast(1, int64)), cast(1.0, f32), tpl_loc)
    h_im1 = inner_product(copy(h), copy(e_im1))
    h_i = inner_product(copy(h), copy(e_i))
    y_im1 = inner_product(copy(ys), copy(e_im1))
    y_i = inner_product(copy(ys), copy(e_i))
    y_ip1 = inner_product(copy(ys), e_ip1)
    safe_him1 = if lt(h_im1, cast(0.000000000000000000000000000001, f32)) then cast(1.0, f32) else h_im1
    safe_hi = if lt(h_i, cast(0.000000000000000000000000000001, f32)) then cast(1.0, f32) else h_i
    rhs_i = mul(cast(6.0, f32), sub(div(sub(y_ip1, y_i), safe_hi), div(sub(y_i, y_im1), safe_him1)))
    la_vec_saxpy(rhs_i, acc, e_i)
  }, rhs0, range(cast(1, int64), n_len_m1))
}
def spline_fit[m](xs: &tensor[m, f32], ys: &tensor[m, f32]) -> tensor[m, f32] = {
  n_len = len(to_list(copy(xs)))
  n_len_m1 = sub(n_len, cast(1, int64))
  zeros0 = spline_zeros(copy(xs))
  h = spline_fit_h(copy(xs), copy(zeros0), n_len_m1)
  lower_v = spline_fit_lower(copy(h), copy(zeros0), n_len_m1)
  e_0 = la_basis_n_f32(cast(0, int64), cast(1.0, f32), copy(zeros0))
  e_last = la_basis_n_f32(n_len_m1, cast(1.0, f32), zeros0)
  d_init = la_vec_saxpy(cast(1.0, f32), la_vec_saxpy(cast(1.0, f32), spline_zeros(copy(xs)), e_0), e_last)
  diag_v = spline_fit_diag(copy(h), d_init, n_len_m1)
  upper_v = spline_fit_upper(copy(h), spline_zeros(copy(xs)), n_len_m1)
  rhs_v = spline_fit_rhs(copy(ys), h, spline_zeros(xs), n_len_m1)
  la_tridiag_solve(lower_v, diag_v, upper_v, rhs_v)
}
def spline_eval[m](xs: &tensor[m, f32], ys: &tensor[m, f32], x_query: f32) -> f32 = {
  m_sec = spline_fit(copy(xs), copy(ys))
  n_len = len(to_list(copy(xs)))
  n_len_m1 = sub(n_len, cast(1, int64))
  tpl = to_tensor(map(fn (v: f32) -> cast(0.0, f32), to_list(copy(xs))))
  x_list = to_list(copy(xs))
  y_list = to_list(copy(ys))
  zipped = zip(x_list, y_list)
  enum_zipped = enumerate(zipped)
  first_x = inner_product(copy(xs), la_basis_n_f32(cast(0, int64), cast(1.0, f32), copy(tpl)))
  first_y = inner_product(copy(ys), la_basis_n_f32(cast(0, int64), cast(1.0, f32), copy(tpl)))
  last_y = inner_product(copy(ys), la_basis_n_f32(n_len_m1, cast(1.0, f32), copy(tpl)))
  init = (false, cast(0.0, f32), first_x, first_y, cast(0.0, f32))
  acc_final = fold(fn (acc: (bool, f32, f32, f32, f32), entry: (int64, (f32, f32))) -> {
    i = entry.0
    xy = entry.1
    xi = xy.0
    yi = xy.1
    found = acc.0
    result_prev = acc.1
    prev_x = acc.2
    prev_y = acc.3
    prev_m = acc.4
    mi_val = inner_product(copy(m_sec), la_basis_n_f32(i, cast(1.0, f32), copy(tpl)))
    is_first = eq(i, cast(0, int64))
    not_found = not(found)
    past_query = gte(xi, x_query)
    in_segment = gte(x_query, prev_x)
    bracket_hit = and(not_found, and(not(is_first), and(past_query, in_segment)))
    h_seg = sub(xi, prev_x)
    abs_h = if lt(h_seg, cast(0.0, f32)) then neg(h_seg) else h_seg
    safe_h = if lt(abs_h, cast(0.000000000000000000000000000001, f32)) then cast(1.0, f32) else h_seg
    t = sub(x_query, prev_x)
    t2 = mul(t, t)
    t3 = mul(t2, t)
    a_c = prev_y
    b_c = sub(div(sub(yi, prev_y), safe_h), div(mul(safe_h, add(mul(cast(2.0, f32), prev_m), mi_val)), cast(6.0, f32)))
    c_c = div(prev_m, cast(2.0, f32))
    d_c = div(sub(mi_val, prev_m), mul(cast(6.0, f32), safe_h))
    seg_val = add(add(a_c, mul(b_c, t)), add(mul(c_c, t2), mul(d_c, t3)))
    new_found = if bracket_hit then true else found
    new_result = if bracket_hit then seg_val else result_prev
    (new_found, new_result, xi, yi, mi_val)
  }, init, enum_zipped)
  found = acc_final.0
  result = acc_final.1
  if found then result else if lt(x_query, first_x) then first_y else last_y
}
