module Nautilus.Distance
import Nautilus.LinAlg (l2_norm_vec, inner_product, matvec)
export (squared_euclidean, euclidean, manhattan, chebyshev, cosine_similarity, cosine_distance, mahalanobis_squared, mahalanobis)
def d_abs_f32(x: f32) -> f32 = if lt(x, cast(0.0, f32)) then neg(x) else x
def d_max_f32(a: f32, b: f32) -> f32 = if gt(a, b) then a else b
def squared_euclidean[n](a: &tensor[n, f32], b: &tensor[n, f32]) -> f32 = {
  zipped = zip(to_list(a), to_list(b))
  fold(fn (acc: f32, pair: (f32, f32)) -> {
    d = sub(pair.0, pair.1)
    d2 = mul(d, d)
    add(acc, d2)
  }, cast(0.0, f32), zipped)
}
def euclidean[n](a: &tensor[n, f32], b: &tensor[n, f32]) -> f32 = {
  s = squared_euclidean(a, b)
  sqrt(s)
}
def manhattan[n](a: &tensor[n, f32], b: &tensor[n, f32]) -> f32 = {
  zipped = zip(to_list(a), to_list(b))
  fold(fn (acc: f32, pair: (f32, f32)) -> {
    d = sub(pair.0, pair.1)
    ad = d_abs_f32(d)
    add(acc, ad)
  }, cast(0.0, f32), zipped)
}
def chebyshev[n](a: &tensor[n, f32], b: &tensor[n, f32]) -> f32 = {
  zipped = zip(to_list(a), to_list(b))
  fold(fn (acc: f32, pair: (f32, f32)) -> {
    d = sub(pair.0, pair.1)
    ad = d_abs_f32(d)
    d_max_f32(acc, ad)
  }, cast(0.0, f32), zipped)
}
def cosine_similarity[n](a: &tensor[n, f32], b: &tensor[n, f32]) -> f32 = {
  dot = inner_product(copy(a), copy(b))
  na = l2_norm_vec(a)
  nb = l2_norm_vec(b)
  denom = mul(na, nb)
  div(dot, denom)
}
def cosine_distance[n](a: &tensor[n, f32], b: &tensor[n, f32]) -> f32 = {
  sim = cosine_similarity(a, b)
  cast(1.0, f32) |> sub(sim)
}
def vec_sub[n](a: &tensor[n, f32], b: &tensor[n, f32]) -> tensor[n, f32] = to_tensor(map(fn (pair: (f32, f32)) -> sub(pair.0, pair.1), zip(to_list(a), to_list(b))))
def mahalanobis_squared[n](a: &tensor[n, f32], b: &tensor[n, f32], cov_inv: &tensor[n, n, f32]) -> f32 = {
  diff = vec_sub(a, b)
  mv = matvec(cov_inv, copy(diff))
  inner_product(diff, mv)
}
def mahalanobis[n](a: &tensor[n, f32], b: &tensor[n, f32], cov_inv: &tensor[n, n, f32]) -> f32 = {
  s = mahalanobis_squared(a, b, cov_inv)
  sqrt(s)
}
