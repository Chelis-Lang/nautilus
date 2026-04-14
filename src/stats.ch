module Nautilus.Stats
export (
  mean_vec,
  variance_vec,
  std_vec,
  skewness_vec,
  kurtosis_vec,
  median_vec,
  covariance_scalar,
  correlation_scalar
)

def zero_f() -> f32 = cast(0.0, f32)
def one_f() -> f32 = cast(1.0, f32)
def two_f() -> f32 = cast(2.0, f32)
def three_f() -> f32 = cast(3.0, f32)
def zero_i() -> int64 = cast(0, int64)
def one_i() -> int64 = cast(1, int64)
def two_i() -> int64 = cast(2, int64)

def mean_vec[n](v: tensor[n, f32]) -> f32 = {
  n_i = numel(copy(v))
  n_f = cast(n_i, f32)
  s = fold(fn (acc: f32, x: f32) -> add(acc, x), zero_f(), to_list(v))
  div(s, n_f)
}

def variance_vec[n](v: tensor[n, f32], ddof: int64) -> f32 = {
  n_i = numel(copy(v))
  n_f = cast(n_i, f32)
  mu = mean_vec(copy(v))
  ss = fold(fn (acc: f32, x: f32) -> {
    d = sub(x, mu)
    add(acc, mul(d, d))
  }, zero_f(), to_list(v))
  denom = sub(n_f, cast(ddof, f32))
  div(ss, denom)
}

def std_vec[n](v: tensor[n, f32], ddof: int64) -> f32 = {
  vr = variance_vec(v, ddof)
  sqrt(vr)
}

def skewness_vec[n](v: tensor[n, f32]) -> f32 = {
  n_i = numel(copy(v))
  n_f = cast(n_i, f32)
  mu = mean_vec(copy(v))
  ss = fold(fn (acc: f32, x: f32) -> {
    d = sub(x, mu)
    add(acc, mul(d, d))
  }, zero_f(), to_list(copy(v)))
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

def kurtosis_vec[n](v: tensor[n, f32]) -> f32 = {
  n_i = numel(copy(v))
  n_f = cast(n_i, f32)
  mu = mean_vec(copy(v))
  ss = fold(fn (acc: f32, x: f32) -> {
    d = sub(x, mu)
    add(acc, mul(d, d))
  }, zero_f(), to_list(copy(v)))
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

def median_vec[n](v: tensor[n, f32]) -> f32 = {
  n_i = numel(copy(v))
  sorted_pair = sort(v, zero_i())
  sorted_v = sorted_pair.0
  lst = to_list(sorted_v)
  enum_lst = enumerate(lst)
  half = div(n_i, two_i())
  is_odd = eq(mod(n_i, two_i()), one_i())
  lo_idx = sub(half, one_i())
  hi_idx = half
  picked = fold(fn (acc: f32, pair: (int64, f32)) -> {
    i = pair.0
    x = pair.1
    take_odd = and(is_odd, eq(i, half))
    take_even = and(not(is_odd), or(eq(i, lo_idx), eq(i, hi_idx)))
    if take_odd then x
    else if take_even then add(acc, x)
    else acc
  }, zero_f(), enum_lst)
  if is_odd then picked else mul(cast(0.5, f32), picked)
}

def covariance_scalar[n](a: tensor[n, f32], b: tensor[n, f32], ddof: int64) -> f32 = {
  n_i = numel(copy(a))
  n_f = cast(n_i, f32)
  mu_a = mean_vec(copy(a))
  mu_b = mean_vec(copy(b))
  zipped = zip(to_list(a), to_list(b))
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

def correlation_scalar[n](a: tensor[n, f32], b: tensor[n, f32]) -> f32 = {
  cov = covariance_scalar(copy(a), copy(b), zero_i())
  sa = std_vec(a, zero_i())
  sb = std_vec(b, zero_i())
  denom = mul(sa, sb)
  div(cov, denom)
}
