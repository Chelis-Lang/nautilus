module Nautilus.Stats
import Nautilus.Distributions (chi_squared_cdf)
export (mean_vec, variance_vec, std_vec, skewness_vec, kurtosis_vec, median_vec, covariance_scalar, correlation_scalar, min_vec, max_vec, range_vec, quantile_vec, percentile_vec, trimmed_mean_vec, bonferroni_adjust, stat_holm_adjust, benjamini_hochberg_adjust, fdr_adjust, likelihood_ratio_stat, likelihood_ratio_p_value, covariance_2x2, correlation_2x2, covariance_matrix_2, correlation_matrix_2)
-- chelis:provenance/v1 authority
-- id = NAUT-MOD-STATS
-- kind = behavioral
-- scopes = nautilus
-- statement = Nautilus.Stats MUST provide the descriptive-statistics surface listed in the module support table.
def zero_f() -> f32 = cast(0.0, f32)
-- chelis:provenance/v1 implementation-link
-- id = NAUT-LINK-STATS-HELPERS
-- atoms = NAUT-MOD-STATS@xxh3-128:83e4d24feb0b0af7a179db04db8ace9b
-- item-digest = xxh3-128:ecddac0920c0392a7d5330490f5c9114
-- navigation = implements
def one_f() -> f32 = cast(1.0, f32)
def two_f() -> f32 = cast(2.0, f32)
def three_f() -> f32 = cast(3.0, f32)
def pos_inf_f() -> f32 = 1.0 |> fn (__chelis_pipe) -> cast(__chelis_pipe, f32) |> div(cast(0.0, f32))
def neg_inf_f() -> f32 = -1.0 |> fn (__chelis_pipe) -> cast(__chelis_pipe, f32) |> div(cast(0.0, f32))
def zero_i() -> int64 = cast(0, int64)
def zero_axis() -> int32 = cast(0, int32)
def one_i() -> int64 = cast(1, int64)
def two_i() -> int64 = cast(2, int64)
def mean_vec[n](v: &tensor[n, f32]) -> f32 = {
  n_i = numel(v)
  n_f = cast(n_i, f32)
  s = fold(fn (acc: f32, x: f32) -> add(acc, x), zero_f(), to_list(v))
  div(s, n_f)
}
def variance_vec[n](v: &tensor[n, f32], ddof: int64) -> f32 = {
  n_i = numel(v)
  n_f = cast(n_i, f32)
  mu = mean_vec(v)
  ss = fold(fn (acc: f32, x: f32) -> {
    d = sub(x, mu)
    add(acc, mul(d, d))
  }, zero_f(), to_list(v))
  denom = sub(n_f, cast(ddof, f32))
  div(ss, denom)
}
def std_vec[n](v: &tensor[n, f32], ddof: int64) -> f32 = {
  vr = variance_vec(v, ddof)
  sqrt(vr)
}
def skewness_vec[n](v: &tensor[n, f32]) -> f32 = {
  n_i = numel(v)
  n_f = cast(n_i, f32)
  mu = mean_vec(v)
  ss = fold(fn (acc: f32, x: f32) -> {
    d = sub(x, mu)
    add(acc, mul(d, d))
  }, zero_f(), to_list(v))
  sc = fold(fn (acc: f32, x: f32) -> {
    d = sub(x, mu)
    d2 = mul(d, d)
    add(acc, mul(d2, d))
  }, zero_f(), to_list(v))
  m2 = div(ss, n_f)
  m3 = div(sc, n_f)
  m2_sqrt = sqrt(m2)
  m2_15 = mul(m2, m2_sqrt)
  div(m3, m2_15)
}
def kurtosis_vec[n](v: &tensor[n, f32]) -> f32 = {
  n_i = numel(v)
  n_f = cast(n_i, f32)
  mu = mean_vec(v)
  ss = fold(fn (acc: f32, x: f32) -> {
    d = sub(x, mu)
    add(acc, mul(d, d))
  }, zero_f(), to_list(v))
  sq = fold(fn (acc: f32, x: f32) -> {
    d = sub(x, mu)
    d2 = mul(d, d)
    add(acc, mul(d2, d2))
  }, zero_f(), to_list(v))
  m2 = div(ss, n_f)
  m4 = div(sq, n_f)
  m2_sq = mul(m2, m2)
  ratio = div(m4, m2_sq)
  sub(ratio, three_f())
}
def median_vec[n](v: &tensor[n, f32]) -> f32 = {
  n_i = numel(v)
  sorted_pair = sort(v, zero_axis())
  sorted_v = sorted_pair.0
  lst = to_list(sorted_v)
  enum_lst = enumerate(lst)
  half = floor_div(n_i, two_i())
  is_odd = n_i |> mod(two_i()) |> eq(one_i())
  lo_idx = sub(half, one_i())
  hi_idx = half
  picked = fold(fn (acc: f32, pair: (int64, f32)) -> {
    i = pair.0
    x = pair.1
    take_odd = and(is_odd, eq(i, half))
    take_even = is_odd |> not |> and(or(eq(i, lo_idx), eq(i, hi_idx)))
    if take_odd then x else if take_even then add(acc, x) else acc
  }, zero_f(), enum_lst)
  if is_odd then picked else 0.5 |> fn (__chelis_pipe) -> cast(__chelis_pipe, f32) |> mul(picked)
}
def covariance_scalar[n](a: &tensor[n, f32], b: &tensor[n, f32], ddof: int64) -> f32 = {
  n_i = numel(a)
  n_f = cast(n_i, f32)
  mu_a = mean_vec(a)
  mu_b = mean_vec(b)
  zipped = a |> to_list |> zip(to_list(b))
  ss = fold(fn (acc: f32, pair: (f32, f32)) -> {
    x = pair.0
    y = pair.1
    da = sub(x, mu_a)
    db = sub(y, mu_b)
    add(acc, mul(da, db))
  }, zero_f(), zipped)
  denom = sub(n_f, cast(ddof, f32))
  div(ss, denom)
}
def correlation_scalar[n](a: &tensor[n, f32], b: &tensor[n, f32]) -> f32 = {
  cov = covariance_scalar(a, b, zero_i())
  sa = std_vec(a, zero_i())
  sb = std_vec(b, zero_i())
  denom = mul(sa, sb)
  div(cov, denom)
}
def min_vec[n](v: &tensor[n, f32]) -> f32 = {
  lst = to_list(v)
  big = pos_inf_f()
  fold(fn (acc: f32, x: f32) -> if lt(x, acc) then x else acc, big, lst)
}
def max_vec[n](v: &tensor[n, f32]) -> f32 = {
  lst = to_list(v)
  small = neg_inf_f()
  fold(fn (acc: f32, x: f32) -> if gt(x, acc) then x else acc, small, lst)
}
def range_vec[n](v: &tensor[n, f32]) -> f32 = {
  mx = max_vec(v)
  mn = min_vec(v)
  sub(mx, mn)
}
def quantile_vec[n](v: &tensor[n, f32], q: f32) -> f32 = {
  n_i = numel(v)
  n_f = cast(n_i, f32)
  q_clamped = if lt(q, zero_f()) then zero_f() else if gt(q, one_f()) then one_f() else q
  sorted_pair = sort(v, zero_axis())
  sorted_v = sorted_pair.0
  lst = to_list(sorted_v)
  enum_lst = enumerate(lst)
  pos = mul(q_clamped, sub(n_f, one_f()))
  lo_idx_f = pos
  hi_idx_f = add(pos, one_f())
  lo_idx_i = cast_trunc(lo_idx_f, int64)
  lo_idx_back = cast(lo_idx_i, f32)
  frac = sub(pos, lo_idx_back)
  hi_idx_i = add(lo_idx_i, one_i())
  last_idx = sub(n_i, one_i())
  hi_idx_clamped = if gt(hi_idx_i, last_idx) then last_idx else hi_idx_i
  picked = fold(fn (acc: (f32, f32), pair: (int64, f32)) -> {
    i = pair.0
    x = pair.1
    take_lo = eq(i, lo_idx_i)
    take_hi = eq(i, hi_idx_clamped)
    lo_val = if take_lo then x else acc.0
    hi_val = if take_hi then x else acc.1
    (lo_val, hi_val)
  }, (zero_f(), zero_f()), enum_lst)
  add(picked.0, mul(frac, sub(picked.1, picked.0)))
}
def percentile_vec[n](v: &tensor[n, f32], p: f32) -> f32 = {
  q = div(p, cast(100.0, f32))
  quantile_vec(v, q)
}
def trimmed_mean_vec[n](v: &tensor[n, f32], proportion: f32) -> f32 = {
  half = cast(0.5, f32)
  bad_prop = proportion |> lt(zero_f()) |> or(gte(proportion, half))
  if bad_prop then div(zero_f(), zero_f()) else {
    n_i = numel(v)
    n_f = cast(n_i, f32)
    sorted_pair = sort(v, zero_axis())
    sorted_v = sorted_pair.0
    lst = to_list(sorted_v)
    enum_lst = enumerate(lst)
    trim_count_f = mul(proportion, n_f)
    trim_count_i = cast_trunc(trim_count_f, int64)
    lo_bound = trim_count_i
    hi_bound_excl = sub(n_i, trim_count_i)
    kept_sum_pair = fold(fn (acc: (f32, int64), pair: (int64, f32)) -> {
      i = pair.0
      x = pair.1
      within = i |> gte(lo_bound) |> and(lt(i, hi_bound_excl))
      sum_next = if within then add(acc.0, x) else acc.0
      count_next = if within then add(acc.1, one_i()) else acc.1
      (sum_next, count_next)
    }, (zero_f(), zero_i()), enum_lst)
    count_f = cast(kept_sum_pair.1, f32)
    div(kept_sum_pair.0, count_f)
  }
}
def stats_min_one(x: f32) -> f32 = if gt(x, one_f()) then one_f() else x
def bonferroni_adjust[n](p_values: &tensor[n, f32]) -> tensor[n, f32] = {
  m = cast(numel(p_values), f32)
  to_tensor(map(fn (p: f32) -> stats_min_one(mul(p, m)), to_list(p_values)))
}
def stat_holm_adjust_one[n](sorted_p: &tensor[n, f32], p: f32, m: f32) -> f32 = {
  pairs = enumerate(to_list(sorted_p))
  raw = fold(fn (acc: f32, pair: (int64, f32)) -> {
    rank0 = pair.0
    sp = pair.1
    multiplier = sub(m, cast(rank0, f32))
    adj = mul(multiplier, sp)
    if lte(sp, p) then if gt(adj, acc) then adj else acc else acc
  }, zero_f(), pairs)
  stats_min_one(raw)
}
def stat_holm_adjust[n](p_values: &tensor[n, f32]) -> tensor[n, f32] = {
  sorted_pair = sort(p_values, zero_axis())
  sorted_p = sorted_pair.0
  m = cast(numel(p_values), f32)
  to_tensor(map(fn (p: f32) -> stat_holm_adjust_one(sorted_p, p, m), to_list(p_values)))
}
def bh_adjust_one[n](sorted_p: &tensor[n, f32], p: f32, m: f32) -> f32 = {
  pairs = enumerate(to_list(sorted_p))
  raw = fold(fn (acc: f32, pair: (int64, f32)) -> {
    rank = add(pair.0, one_i())
    sp = pair.1
    adj = div(mul(m, sp), cast(rank, f32))
    if gte(sp, p) then if lt(adj, acc) then adj else acc else acc
  }, one_f(), pairs)
  stats_min_one(raw)
}
def benjamini_hochberg_adjust[n](p_values: &tensor[n, f32]) -> tensor[n, f32] = {
  sorted_pair = sort(p_values, zero_axis())
  sorted_p = sorted_pair.0
  m = cast(numel(p_values), f32)
  to_tensor(map(fn (p: f32) -> bh_adjust_one(sorted_p, p, m), to_list(p_values)))
}
def fdr_adjust[n](p_values: &tensor[n, f32]) -> tensor[n, f32] = benjamini_hochberg_adjust(p_values)
def likelihood_ratio_stat(log_likelihood_null: f32, log_likelihood_alt: f32) -> f32 = mul(two_f(), sub(log_likelihood_alt, log_likelihood_null))
def likelihood_ratio_p_value(log_likelihood_null: f32, log_likelihood_alt: f32, df: f32) -> f32 = {
  stat = likelihood_ratio_stat(log_likelihood_null, log_likelihood_alt)
  sub(one_f(), chi_squared_cdf(stat, df))
}
def covariance_2x2[n](a: &tensor[n, f32], b: &tensor[n, f32], ddof: int64) -> tensor[2, 2, f32] = {
  va = covariance_scalar(a, a, ddof)
  vb = covariance_scalar(b, b, ddof)
  cab = covariance_scalar(a, b, ddof)
  to_tensor([[va, cab], [cab, vb]])
}
def correlation_2x2[n](a: &tensor[n, f32], b: &tensor[n, f32]) -> tensor[2, 2, f32] = {
  rab = correlation_scalar(a, b)
  to_tensor([[one_f(), rab], [rab, one_f()]])
}
def covariance_matrix_2[n](a: &tensor[n, f32], b: &tensor[n, f32], ddof: int64) -> tensor[2, 2, f32] = covariance_2x2(a, b, ddof)
def correlation_matrix_2[n](a: &tensor[n, f32], b: &tensor[n, f32]) -> tensor[2, 2, f32] = correlation_2x2(a, b)
