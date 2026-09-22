module Nautilus.Tests.Distance
import Nautilus.Distance (euclidean, squared_euclidean, manhattan, chebyshev, cosine_similarity, cosine_distance, mahalanobis, mahalanobis_squared)
import Std.Test (assert_close, assert_true)
def basis2(k: i64) -> tensor[2, f32] = to_tensor(map(fn (i: i64) -> if eq(i, k) then cast(1.0, f32) else cast(0.0, f32), range(cast(0, i64), cast(2, i64))))
def mk_2x2(a: f32, b: f32, c: f32, d: f32) -> tensor[2, 2, f32] = {
  e0 = basis2(cast(0, i64))
  e1 = basis2(cast(1, i64))
  row0 = to_tensor([a, b])
  row1 = to_tensor([c, d])
  m0 = einsum("i,j->ij", e0, row0)
  m1 = einsum("i,j->ij", e1, row1)
  add(m0, m1)
}
def test_euclidean_self_zero() -> unit ! { Test } = {
  v = to_tensor([cast(1.5, f32), cast(-2.0, f32), cast(3.25, f32)])
  d = euclidean(copy(v), copy(v))
  assert_close(d, cast(0.0, f32), cast(1e-6, f32), "euclidean(v, v) = 0")
}
def test_euclidean_3_4_5() -> unit ! { Test } = {
  a = to_tensor([cast(0.0, f32), cast(0.0, f32), cast(0.0, f32)])
  b = to_tensor([cast(3.0, f32), cast(4.0, f32), cast(0.0, f32)])
  d = euclidean(a, b)
  assert_close(d, cast(5.0, f32), cast(1e-6, f32), "euclidean 3-4-5 triangle = 5")
}
def test_euclidean_unit_square_diag() -> unit ! { Test } = {
  a = to_tensor([cast(0.0, f32), cast(0.0, f32)])
  b = to_tensor([cast(1.0, f32), cast(1.0, f32)])
  d = euclidean(a, b)
  assert_close(d, cast(1.4142135, f32), cast(1e-6, f32), "euclidean unit square diag = sqrt(2)")
}
def test_euclidean_4d_unit_hypercube() -> unit ! { Test } = {
  a = to_tensor([cast(0.0, f32), cast(0.0, f32), cast(0.0, f32), cast(0.0, f32)])
  b = to_tensor([cast(1.0, f32), cast(1.0, f32), cast(1.0, f32), cast(1.0, f32)])
  d = euclidean(a, b)
  assert_close(d, cast(2.0, f32), cast(1e-6, f32), "euclidean 4D unit hypercube diag = 2")
}
def test_euclidean_neg_v() -> unit ! { Test } = {
  v = to_tensor([cast(3.0, f32), cast(4.0, f32), cast(0.0, f32)])
  nv = to_tensor([cast(-3.0, f32), cast(-4.0, f32), cast(0.0, f32)])
  d = euclidean(v, nv)
  assert_close(d, cast(10.0, f32), cast(1e-6, f32), "euclidean(v, -v) = 2||v||")
}
def test_euclidean_symmetry() -> unit ! { Test } = {
  x = to_tensor([cast(1.0, f32), cast(-2.5, f32), cast(0.5, f32)])
  y = to_tensor([cast(3.0, f32), cast(0.5, f32), cast(-1.5, f32)])
  dxy = euclidean(copy(x), copy(y))
  dyx = euclidean(y, x)
  assert_close(dxy, dyx, cast(1e-6, f32), "euclidean is symmetric")
}
def test_manhattan_self_zero() -> unit ! { Test } = {
  v = to_tensor([cast(2.5, f32), cast(-1.0, f32), cast(0.75, f32)])
  d = manhattan(copy(v), copy(v))
  assert_close(d, cast(0.0, f32), cast(1e-6, f32), "manhattan(v, v) = 0")
}
def test_manhattan_3_4() -> unit ! { Test } = {
  a = to_tensor([cast(0.0, f32), cast(0.0, f32)])
  b = to_tensor([cast(3.0, f32), cast(4.0, f32)])
  d = manhattan(a, b)
  assert_close(d, cast(7.0, f32), cast(1e-6, f32), "manhattan(0, [3,4]) = 7")
}
def test_manhattan_mixed() -> unit ! { Test } = {
  a = to_tensor([cast(1.0, f32), cast(2.0, f32), cast(3.0, f32)])
  b = to_tensor([cast(4.0, f32), cast(6.0, f32), cast(3.0, f32)])
  d = manhattan(a, b)
  assert_close(d, cast(7.0, f32), cast(1e-6, f32), "manhattan([1,2,3],[4,6,3]) = 7")
}
def test_manhattan_symmetry() -> unit ! { Test } = {
  x = to_tensor([cast(1.0, f32), cast(-2.5, f32), cast(0.5, f32)])
  y = to_tensor([cast(3.0, f32), cast(0.5, f32), cast(-1.5, f32)])
  dxy = manhattan(copy(x), copy(y))
  dyx = manhattan(y, x)
  assert_close(dxy, dyx, cast(1e-6, f32), "manhattan is symmetric")
}
def test_chebyshev_self_zero() -> unit ! { Test } = {
  v = to_tensor([cast(2.0, f32), cast(-3.0, f32), cast(1.0, f32)])
  d = chebyshev(copy(v), copy(v))
  assert_close(d, cast(0.0, f32), cast(1e-6, f32), "chebyshev(v, v) = 0")
}
def test_chebyshev_max_coord() -> unit ! { Test } = {
  a = to_tensor([cast(0.0, f32), cast(0.0, f32), cast(0.0, f32)])
  b = to_tensor([cast(3.0, f32), cast(4.0, f32), cast(5.0, f32)])
  d = chebyshev(a, b)
  assert_close(d, cast(5.0, f32), cast(1e-6, f32), "chebyshev(0,[3,4,5]) = 5")
}
def test_chebyshev_symmetry() -> unit ! { Test } = {
  x = to_tensor([cast(1.0, f32), cast(-2.5, f32), cast(0.5, f32)])
  y = to_tensor([cast(3.0, f32), cast(0.5, f32), cast(-1.5, f32)])
  dxy = chebyshev(copy(x), copy(y))
  dyx = chebyshev(y, x)
  assert_close(dxy, dyx, cast(1e-6, f32), "chebyshev is symmetric")
}
def test_cosine_distance_self_zero() -> unit ! { Test } = {
  v = to_tensor([cast(1.0, f32), cast(2.0, f32), cast(3.0, f32)])
  d = cosine_distance(copy(v), copy(v))
  assert_close(d, cast(0.0, f32), cast(1e-6, f32), "cosine_distance(v, v) = 0")
}
def test_cosine_similarity_self_one() -> unit ! { Test } = {
  v = to_tensor([cast(1.0, f32), cast(2.0, f32), cast(3.0, f32)])
  s = cosine_similarity(copy(v), copy(v))
  assert_close(s, cast(1.0, f32), cast(1e-6, f32), "cosine_similarity(v, v) = 1")
}
def test_cosine_distance_scale_invariant() -> unit ! { Test } = {
  v = to_tensor([cast(1.0, f32), cast(2.0, f32), cast(3.0, f32)])
  v3 = to_tensor([cast(3.0, f32), cast(6.0, f32), cast(9.0, f32)])
  d = cosine_distance(v, v3)
  assert_close(d, cast(0.0, f32), cast(1e-6, f32), "cosine_distance(v, 3v) = 0")
}
def test_cosine_distance_orthogonal() -> unit ! { Test } = {
  e0 = to_tensor([cast(1.0, f32), cast(0.0, f32)])
  e1 = to_tensor([cast(0.0, f32), cast(1.0, f32)])
  d = cosine_distance(e0, e1)
  assert_close(d, cast(1.0, f32), cast(1e-6, f32), "cosine_distance([1,0],[0,1]) = 1")
}
def test_cosine_similarity_orthogonal() -> unit ! { Test } = {
  e0 = to_tensor([cast(1.0, f32), cast(0.0, f32)])
  e1 = to_tensor([cast(0.0, f32), cast(1.0, f32)])
  s = cosine_similarity(e0, e1)
  assert_close(s, cast(0.0, f32), cast(1e-6, f32), "cosine_similarity([1,0],[0,1]) = 0")
}
def test_mahalanobis_self_zero() -> unit ! { Test } = {
  v = to_tensor([cast(1.0, f32), cast(-2.0, f32)])
  cov_inv = mk_2x2(cast(2.0, f32), cast(0.0, f32), cast(0.0, f32), cast(0.5, f32))
  d = mahalanobis(copy(v), copy(v), cov_inv)
  assert_close(d, cast(0.0, f32), cast(1e-6, f32), "mahalanobis(v, v, C^{-1}) = 0")
}
def test_mahalanobis_identity_reduces_to_euclidean() -> unit ! { Test } = {
  x = to_tensor([cast(0.0, f32), cast(0.0, f32)])
  y = to_tensor([cast(3.0, f32), cast(4.0, f32)])
  id2 = mk_2x2(cast(1.0, f32), cast(0.0, f32), cast(0.0, f32), cast(1.0, f32))
  d = mahalanobis(x, y, id2)
  assert_close(d, cast(5.0, f32), cast(1e-6, f32), "mahalanobis(x,y,I) = euclidean(x,y) = 5")
}
def test_mahalanobis_squared_identity_reduces_to_squared_euclidean() -> unit ! { Test } = {
  a = to_tensor([cast(1.0, f32), cast(0.0, f32)])
  b = to_tensor([cast(0.0, f32), cast(1.0, f32)])
  id2 = mk_2x2(cast(1.0, f32), cast(0.0, f32), cast(0.0, f32), cast(1.0, f32))
  s = mahalanobis_squared(a, b, id2)
  assert_close(s, cast(2.0, f32), cast(1e-6, f32), "mahalanobis_squared(a,b,I) = |a-b|^2 = 2")
}
def test_mahalanobis_diag_scaling() -> unit ! { Test } = {
  x = to_tensor([cast(0.0, f32), cast(0.0, f32)])
  y = to_tensor([cast(3.0, f32), cast(4.0, f32)])
  cov_inv = mk_2x2(cast(4.0, f32), cast(0.0, f32), cast(0.0, f32), cast(4.0, f32))
  d = mahalanobis(x, y, cov_inv)
  assert_close(d, cast(10.0, f32), cast(0.00001, f32), "mahalanobis with cov_inv=4I = 2 * euclidean")
}
def test_euclidean_triangle_inequality() -> unit ! { Test } = {
  a = to_tensor([cast(0.0, f32), cast(0.0, f32)])
  b = to_tensor([cast(1.0, f32), cast(0.0, f32)])
  c = to_tensor([cast(0.0, f32), cast(1.0, f32)])
  dac = euclidean(copy(a), copy(c))
  dab = euclidean(a, copy(b))
  dbc = euclidean(b, c)
  sum_ab_bc = add(dab, dbc)
  assert_true(lte(dac, sum_ab_bc), "euclidean: d(a,c) <= d(a,b) + d(b,c)")
}
def test_squared_euclidean_self_zero() -> unit ! { Test } = {
  v = to_tensor([cast(1.5, f32), cast(-2.0, f32), cast(3.5, f32)])
  s = squared_euclidean(copy(v), v)
  assert_close(s, cast(0.0, f32), cast(1e-6, f32), "squared_euclidean(v, v) = 0")
}
def test_squared_euclidean_3_4_5() -> unit ! { Test } = {
  a = to_tensor([cast(0.0, f32), cast(0.0, f32)])
  b = to_tensor([cast(3.0, f32), cast(4.0, f32)])
  s = squared_euclidean(a, b)
  assert_close(s, cast(25.0, f32), cast(0.00001, f32), "squared_euclidean((0,0),(3,4)) = 25")
}
def test_squared_euclidean_matches_euclidean_squared() -> unit ! { Test } = {
  a = to_tensor([cast(1.0, f32), cast(2.0, f32), cast(3.0, f32)])
  b = to_tensor([cast(4.0, f32), cast(0.0, f32), cast(-1.0, f32)])
  s = squared_euclidean(copy(a), copy(b))
  e = euclidean(a, b)
  assert_close(s, mul(e, e), cast(0.0001, f32), "squared_euclidean = euclidean^2")
}
