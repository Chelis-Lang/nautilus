module Nautilus.Stats
import Nautilus.Distributions (chi_squared_cdf)
export (mean_vec, variance_vec, std_vec, skewness_vec, kurtosis_vec, median_vec, covariance_scalar, correlation_scalar, min_vec, max_vec, range_vec, quantile_vec, percentile_vec, trimmed_mean_vec, rank_vec, zscore_vec, bonferroni_adjust, stat_holm_adjust, benjamini_hochberg_adjust, fdr_adjust, likelihood_ratio_stat, likelihood_ratio_p_value, covariance_2x2, correlation_2x2, covariance_matrix_2, correlation_matrix_2, covariance_matrix, correlation_matrix)
-- chelis:provenance/v1 authority
-- id = NAUT-MOD-STATS
-- kind = behavioral
-- scopes = nautilus
-- statement = Nautilus.Stats MUST provide the descriptive-statistics surface listed in the module support table.
-- chelis:provenance/v1 binding
-- record = blake3-256:d68b13e3a8466c421ba48e840a87cea11268bc08c074df3a15add39cfb1f000d
def zero_i() -> int64 = cast(0, int64)
def zero_axis() -> int32 = cast(0, int32)
def one_i() -> int64 = cast(1, int64)
def two_i() -> int64 = cast(2, int64)
-- Truncate a Float-bounded scalar toward zero to int64. chelis#2151: `cast` and
-- `cast_trunc` reject a scalar source typed by a Float-bounded binder, while the
-- tensor form with the same binder is accepted, so this lifts the scalar to a
-- length-1 tensor, truncates there, and reads the element back. The result is
-- identical to `cast_trunc(x, int64)`. Replace every call with that once
-- chelis#2151 is fixed.
def stats_trunc_i64[prec: Float](x: prec) -> int64 =
  x
  |> scalar_to_tensor
  |> insert(0, cast(1, int64))
  |> cast_trunc(int64)
  |> to_list
  |> index(cast(0, int64))
def mean_vec[n, prec: Float](v: &tensor[n, prec]) -> prec = {
  n_i = numel(v)
  n_f = cast(n_i, prec)
  s = fold(fn (acc: prec, x: prec) -> add(acc, x), cast(0.0, prec), to_list(v))
  div(s, n_f)
}
def variance_vec[n, prec: Float](v: &tensor[n, prec], ddof: int64) -> prec = {
  n_i = numel(v)
  n_f = cast(n_i, prec)
  mu = mean_vec(v)
  ss = fold(fn (acc: prec, x: prec) -> {
    d = sub(x, mu)
    add(acc, mul(d, d))
  }, cast(0.0, prec), to_list(v))
  denom = sub(n_f, cast(ddof, prec))
  div(ss, denom)
}
def std_vec[n, prec: Float](v: &tensor[n, prec], ddof: int64) -> prec = {
  vr = variance_vec(v, ddof)
  sqrt(vr)
}
def skewness_vec[n, prec: Float](v: &tensor[n, prec]) -> prec = {
  n_i = numel(v)
  n_f = cast(n_i, prec)
  mu = mean_vec(v)
  ss = fold(fn (acc: prec, x: prec) -> {
    d = sub(x, mu)
    add(acc, mul(d, d))
  }, cast(0.0, prec), to_list(v))
  sc = fold(fn (acc: prec, x: prec) -> {
    d = sub(x, mu)
    d2 = mul(d, d)
    add(acc, mul(d2, d))
  }, cast(0.0, prec), to_list(v))
  m2 = div(ss, n_f)
  m3 = div(sc, n_f)
  m2_sqrt = sqrt(m2)
  m2_15 = mul(m2, m2_sqrt)
  div(m3, m2_15)
}
def kurtosis_vec[n, prec: Float](v: &tensor[n, prec]) -> prec = {
  n_i = numel(v)
  n_f = cast(n_i, prec)
  mu = mean_vec(v)
  ss = fold(fn (acc: prec, x: prec) -> {
    d = sub(x, mu)
    add(acc, mul(d, d))
  }, cast(0.0, prec), to_list(v))
  sq = fold(fn (acc: prec, x: prec) -> {
    d = sub(x, mu)
    d2 = mul(d, d)
    add(acc, mul(d2, d2))
  }, cast(0.0, prec), to_list(v))
  m2 = div(ss, n_f)
  m4 = div(sq, n_f)
  m2_sq = mul(m2, m2)
  ratio = div(m4, m2_sq)
  sub(ratio, cast(3.0, prec))
}
def median_vec[n, prec: Float](v: &tensor[n, prec]) -> prec = {
  n_i = numel(v)
  sorted_pair = sort(v, zero_axis())
  sorted_v = sorted_pair.0
  lst = to_list(sorted_v)
  enum_lst = enumerate(lst)
  half = floor_div(n_i, two_i())
  is_odd = n_i |> mod(two_i()) |> eq(one_i())
  lo_idx = sub(half, one_i())
  hi_idx = half
  picked = fold(fn (acc: prec, pair: (int64, prec)) -> {
    i = pair.0
    x = pair.1
    take_odd = and(is_odd, eq(i, half))
    take_even = is_odd |> not |> and(or(eq(i, lo_idx), eq(i, hi_idx)))
    if take_odd then x else if take_even then add(acc, x) else acc
  }, cast(0.0, prec), enum_lst)
  if is_odd then picked else cast(0.5, prec) |> mul(picked)
}
def covariance_scalar[n, prec: Float](a: &tensor[n, prec], b: &tensor[n, prec], ddof: int64) -> prec = {
  n_i = numel(a)
  n_f = cast(n_i, prec)
  mu_a = mean_vec(a)
  mu_b = mean_vec(b)
  zipped = a |> to_list |> zip(to_list(b))
  ss = fold(fn (acc: prec, pair: (prec, prec)) -> {
    x = pair.0
    y = pair.1
    da = sub(x, mu_a)
    db = sub(y, mu_b)
    add(acc, mul(da, db))
  }, cast(0.0, prec), zipped)
  denom = sub(n_f, cast(ddof, prec))
  div(ss, denom)
}
def correlation_scalar[n, prec: Float](a: &tensor[n, prec], b: &tensor[n, prec]) -> prec = {
  cov = covariance_scalar(a, b, zero_i())
  sa = std_vec(a, zero_i())
  sb = std_vec(b, zero_i())
  denom = mul(sa, sb)
  div(cov, denom)
}
def min_vec[n, prec: Float](v: &tensor[n, prec]) -> prec = {
  lst = to_list(v)
  big = div(cast(1.0, prec), cast(0.0, prec))
  fold(fn (acc: prec, x: prec) -> if lt(x, acc) then x else acc, big, lst)
}
def max_vec[n, prec: Float](v: &tensor[n, prec]) -> prec = {
  lst = to_list(v)
  small = div(cast(-1.0, prec), cast(0.0, prec))
  fold(fn (acc: prec, x: prec) -> if gt(x, acc) then x else acc, small, lst)
}
def range_vec[n, prec: Float](v: &tensor[n, prec]) -> prec = {
  mx = max_vec(v)
  mn = min_vec(v)
  sub(mx, mn)
}
def quantile_vec[n, prec: Float](v: &tensor[n, prec], q: prec) -> prec = {
  n_i = numel(v)
  n_f = cast(n_i, prec)
  q_clamped = if lt(q, cast(0.0, prec)) then cast(0.0, prec) else if gt(q, cast(1.0, prec)) then cast(1.0, prec) else q
  sorted_pair = sort(v, zero_axis())
  sorted_v = sorted_pair.0
  lst = to_list(sorted_v)
  enum_lst = enumerate(lst)
  pos = mul(q_clamped, sub(n_f, cast(1.0, prec)))
  lo_idx_f = pos
  hi_idx_f = add(pos, cast(1.0, prec))
  lo_idx_i = stats_trunc_i64(lo_idx_f)
  lo_idx_back = cast(lo_idx_i, prec)
  frac = sub(pos, lo_idx_back)
  hi_idx_i = add(lo_idx_i, one_i())
  last_idx = sub(n_i, one_i())
  hi_idx_clamped = if gt(hi_idx_i, last_idx) then last_idx else hi_idx_i
  picked = fold(fn (acc: (prec, prec), pair: (int64, prec)) -> {
    i = pair.0
    x = pair.1
    take_lo = eq(i, lo_idx_i)
    take_hi = eq(i, hi_idx_clamped)
    lo_val = if take_lo then x else acc.0
    hi_val = if take_hi then x else acc.1
    (lo_val, hi_val)
  }, (cast(0.0, prec), cast(0.0, prec)), enum_lst)
  add(picked.0, mul(frac, sub(picked.1, picked.0)))
}
def percentile_vec[n, prec: Float](v: &tensor[n, prec], p: prec) -> prec = {
  q = div(p, cast(100.0, prec))
  quantile_vec(v, q)
}
-- Average rank of one element against the whole sample: 1 + (#below) +
-- (#tied - 1)/2. Counting rather than sorting is what makes ties average
-- cleanly, and it matches scipy.stats.rankdata's default `method="average"`.
def stats_rank_one[n, prec: Float](sample: &tensor[n, prec], x: prec) -> prec = {
  counts = fold(fn (acc: (prec, prec), y: prec) -> {
    below = if lt(y, x) then add(acc.0, cast(1.0, prec)) else acc.0
    tied = if eq(y, x) then add(acc.1, cast(1.0, prec)) else acc.1
    (below, tied)
  }, (cast(0.0, prec), cast(0.0, prec)), to_list(sample))
  half = cast(0.5, prec)
  counts.0
  |> add(cast(1.0, prec))
  |> add(mul(half, sub(counts.1, cast(1.0, prec))))
}
def rank_vec[n, prec: Float](v: &tensor[n, prec]) -> tensor[n, prec] = to_tensor(map(fn (x: prec) -> stats_rank_one(v, x), to_list(v)))
def zscore_vec[n, prec: Float](v: &tensor[n, prec], ddof: int64) -> tensor[n, prec] = {
  mu = mean_vec(v)
  sd = std_vec(v, ddof)
  to_tensor(map(fn (x: prec) -> div(sub(x, mu), sd), to_list(v)))
}
def trimmed_mean_vec[n, prec: Float](v: &tensor[n, prec], proportion: prec) -> prec = {
  half = cast(0.5, prec)
  bad_prop = proportion |> lt(cast(0.0, prec)) |> or(gte(proportion, half))
  if bad_prop then div(cast(0.0, prec), cast(0.0, prec)) else {
    n_i = numel(v)
    n_f = cast(n_i, prec)
    sorted_pair = sort(v, zero_axis())
    sorted_v = sorted_pair.0
    lst = to_list(sorted_v)
    enum_lst = enumerate(lst)
    trim_count_f = mul(proportion, n_f)
    trim_count_i = stats_trunc_i64(trim_count_f)
    lo_bound = trim_count_i
    hi_bound_excl = sub(n_i, trim_count_i)
    kept_sum_pair = fold(fn (acc: (prec, int64), pair: (int64, prec)) -> {
      i = pair.0
      x = pair.1
      within = i |> gte(lo_bound) |> and(lt(i, hi_bound_excl))
      sum_next = if within then add(acc.0, x) else acc.0
      count_next = if within then add(acc.1, one_i()) else acc.1
      (sum_next, count_next)
    }, (cast(0.0, prec), zero_i()), enum_lst)
    count_f = cast(kept_sum_pair.1, prec)
    div(kept_sum_pair.0, count_f)
  }
}
def stats_min_one[prec: Float](x: prec) -> prec = if gt(x, cast(1.0, prec)) then cast(1.0, prec) else x
def bonferroni_adjust[n, prec: Float](p_values: &tensor[n, prec]) -> tensor[n, prec] = {
  m = cast(numel(p_values), prec)
  to_tensor(map(fn (p: prec) -> stats_min_one(mul(p, m)), to_list(p_values)))
}
def stat_holm_adjust_one[n, prec: Float](sorted_p: &tensor[n, prec], p: prec, m: prec) -> prec = {
  pairs = enumerate(to_list(sorted_p))
  raw = fold(fn (acc: prec, pair: (int64, prec)) -> {
    rank0 = pair.0
    sp = pair.1
    multiplier = sub(m, cast(rank0, prec))
    adj = mul(multiplier, sp)
    if lte(sp, p) then if gt(adj, acc) then adj else acc else acc
  }, cast(0.0, prec), pairs)
  stats_min_one(raw)
}
def stat_holm_adjust[n, prec: Float](p_values: &tensor[n, prec]) -> tensor[n, prec] = {
  sorted_pair = sort(p_values, zero_axis())
  sorted_p = sorted_pair.0
  m = cast(numel(p_values), prec)
  to_tensor(map(fn (p: prec) -> stat_holm_adjust_one(sorted_p, p, m), to_list(p_values)))
}
def bh_adjust_one[n, prec: Float](sorted_p: &tensor[n, prec], p: prec, m: prec) -> prec = {
  pairs = enumerate(to_list(sorted_p))
  raw = fold(fn (acc: prec, pair: (int64, prec)) -> {
    rank = add(pair.0, one_i())
    sp = pair.1
    adj = div(mul(m, sp), cast(rank, prec))
    if gte(sp, p) then if lt(adj, acc) then adj else acc else acc
  }, cast(1.0, prec), pairs)
  stats_min_one(raw)
}
def benjamini_hochberg_adjust[n, prec: Float](p_values: &tensor[n, prec]) -> tensor[n, prec] = {
  sorted_pair = sort(p_values, zero_axis())
  sorted_p = sorted_pair.0
  m = cast(numel(p_values), prec)
  to_tensor(map(fn (p: prec) -> bh_adjust_one(sorted_p, p, m), to_list(p_values)))
}
def fdr_adjust[n, prec: Float](p_values: &tensor[n, prec]) -> tensor[n, prec] = benjamini_hochberg_adjust(p_values)
def likelihood_ratio_stat[prec: Float](log_likelihood_null: prec, log_likelihood_alt: prec) -> prec = mul(cast(2.0, prec), sub(log_likelihood_alt, log_likelihood_null))
def likelihood_ratio_p_value(log_likelihood_null: f32, log_likelihood_alt: f32, df: f32) -> f32 = {
  stat = likelihood_ratio_stat(log_likelihood_null, log_likelihood_alt)
  sub(cast(1.0, f32), chi_squared_cdf(stat, df))
}
def covariance_2x2[n, prec: Float](a: &tensor[n, prec], b: &tensor[n, prec], ddof: int64) -> tensor[2, 2, prec] = {
  va = covariance_scalar(a, a, ddof)
  vb = covariance_scalar(b, b, ddof)
  cab = covariance_scalar(a, b, ddof)
  to_tensor([[va, cab], [cab, vb]])
}
def correlation_2x2[n, prec: Float](a: &tensor[n, prec], b: &tensor[n, prec]) -> tensor[2, 2, prec] = {
  rab = correlation_scalar(a, b)
  to_tensor([[cast(1.0, prec), rab], [rab, cast(1.0, prec)]])
}
def covariance_matrix_2[n, prec: Float](a: &tensor[n, prec], b: &tensor[n, prec], ddof: int64) -> tensor[2, 2, prec] = covariance_2x2(a, b, ddof)
def correlation_matrix_2[n, prec: Float](a: &tensor[n, prec], b: &tensor[n, prec]) -> tensor[2, 2, prec] = correlation_2x2(a, b)
-- Lift a scalar to rank 1 / rank 2 so an elementwise tensor op can take it.
-- Chelis has no implicit tensor-scalar broadcasting; `insert` adds a new axis
-- of the given length and lowers to a stride-0 view, so this costs no
-- per-element storage. Same idiom as `la_lift_t` in Nautilus.LinAlg.
def stats_lift_t[n, prec: Float](template: &tensor[n, prec], c: prec) -> tensor[n, prec] = c |> scalar_to_tensor |> insert(0, shape(template, cast(0, int32)))
def stats_lift_t2[m, n, prec: Float](template: &tensor[m, n, prec], c: prec) -> tensor[m, n, prec] =
  c
  |> scalar_to_tensor
  |> insert(0, shape(template, cast(0, int32)))
  |> insert(1, shape(template, cast(1, int32)))
-- Covariance over m variables and n observations. Each ROW is a variable and
-- each COLUMN an observation, matching numpy.cov's default `rowvar=True`;
-- `covariance_matrix(to_tensor([a, b]), ddof)` therefore agrees entrywise with
-- `covariance_matrix_2(a, b, ddof)`, which tests/stats.ch pins.
def covariance_matrix[m, n, prec: Float](x: &tensor[m, n, prec], ddof: int64) -> tensor[m, m, prec] = {
  n_obs = cast(shape(x, cast(1, int32)), prec)
  row_sums = sum(x, 1)
  mu = div(row_sums, stats_lift_t(row_sums, n_obs))
  centered = sub(x, insert(mu, 1, shape(x, cast(1, int32))))
  cross = einsum("ik,jk->ij", centered, centered)
  denom = sub(n_obs, cast(ddof, prec))
  div(cross, stats_lift_t2(cross, denom))
}
-- Pearson correlation over m variables. Scale-invariant, so the ddof the
-- covariance is built with cancels and is fixed at 0. A constant row has zero
-- variance and yields NaN in its row and column, as numpy.corrcoef does.
def correlation_matrix[m, n, prec: Float](x: &tensor[m, n, prec]) -> tensor[m, m, prec] = {
  cov = covariance_matrix(x, zero_i())
  sd = sqrt(diagonal(cov, 0, 1))
  outer = einsum("i,j->ij", sd, sd)
  div(cov, outer)
}
