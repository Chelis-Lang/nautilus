module Nautilus.Tests.Distance

-- Identity / structural tests for Nautilus.Distance.
-- All expected values are mathematical identities, exact constants,
-- or symmetry / triangle-inequality properties. No external numerics.

import Nautilus.Distance (euclidean, manhattan, chebyshev,
                          cosine_similarity, cosine_distance,
                          mahalanobis, mahalanobis_squared)
import Std.Test (assert_close, assert_true)

-- ----- helpers -----

def basis2(k: int64) -> tensor[2, f32] =
  to_tensor(map(fn (i: int64) -> if eq(i, k) then cast(1.0, f32) else cast(0.0, f32),
                  range(cast(0, int64), cast(2, int64))))

-- Build a 2x2 matrix from rows via einsum-of-outer-products.
def mk_2x2(a: f32, b: f32, c: f32, d: f32) -> tensor[2, 2, f32] = {
  e0 = basis2(cast(0, int64))
  e1 = basis2(cast(1, int64))
  row0 = to_tensor([a, b])
  row1 = to_tensor([c, d])
  m0 = einsum("i,j->ij", e0, row0)
  m1 = einsum("i,j->ij", e1, row1)
  add(m0, m1)
}

-- ===== EUCLIDEAN =====

def test_euclidean_self_zero() -> unit ! { Test } = {
  -- euclidean(v, v) = 0
  v = to_tensor([cast(1.5, f32), cast(-2.0, f32), cast(3.25, f32)])
  d = euclidean(copy(v), copy(v))
  assert_close(d, cast(0.0, f32), cast(1.0e-6, f32),
               "euclidean(v, v) = 0")
}

def test_euclidean_3_4_5() -> unit ! { Test } = {
  -- 3-4-5 right triangle: ||(3,4,0)|| = 5
  a = to_tensor([cast(0.0, f32), cast(0.0, f32), cast(0.0, f32)])
  b = to_tensor([cast(3.0, f32), cast(4.0, f32), cast(0.0, f32)])
  d = euclidean(a, b)
  assert_close(d, cast(5.0, f32), cast(1.0e-6, f32),
               "euclidean 3-4-5 triangle = 5")
}

def test_euclidean_unit_square_diag() -> unit ! { Test } = {
  -- ||(1,1)|| = sqrt(2)
  -- 1.4142135623730951 = sqrt(2)
  a = to_tensor([cast(0.0, f32), cast(0.0, f32)])
  b = to_tensor([cast(1.0, f32), cast(1.0, f32)])
  d = euclidean(a, b)
  assert_close(d, cast(1.4142135, f32), cast(1.0e-6, f32),
               "euclidean unit square diag = sqrt(2)")
}

def test_euclidean_4d_unit_hypercube() -> unit ! { Test } = {
  -- ||(1,1,1,1)|| = 2
  a = to_tensor([cast(0.0, f32), cast(0.0, f32), cast(0.0, f32), cast(0.0, f32)])
  b = to_tensor([cast(1.0, f32), cast(1.0, f32), cast(1.0, f32), cast(1.0, f32)])
  d = euclidean(a, b)
  assert_close(d, cast(2.0, f32), cast(1.0e-6, f32),
               "euclidean 4D unit hypercube diag = 2")
}

def test_euclidean_neg_v() -> unit ! { Test } = {
  -- euclidean(v, -v) = 2 * ||v||;  for v=(3,4,0), ||v||=5, expected 10
  v  = to_tensor([cast(3.0, f32), cast(4.0, f32), cast(0.0, f32)])
  nv = to_tensor([cast(-3.0, f32), cast(-4.0, f32), cast(0.0, f32)])
  d = euclidean(v, nv)
  assert_close(d, cast(10.0, f32), cast(1.0e-6, f32),
               "euclidean(v, -v) = 2||v||")
}

def test_euclidean_symmetry() -> unit ! { Test } = {
  -- euclidean(x, y) = euclidean(y, x)
  x = to_tensor([cast(1.0, f32), cast(-2.5, f32), cast(0.5, f32)])
  y = to_tensor([cast(3.0, f32), cast(0.5, f32), cast(-1.5, f32)])
  dxy = euclidean(copy(x), copy(y))
  dyx = euclidean(y, x)
  assert_close(dxy, dyx, cast(1.0e-6, f32),
               "euclidean is symmetric")
}

-- ===== MANHATTAN =====

def test_manhattan_self_zero() -> unit ! { Test } = {
  v = to_tensor([cast(2.5, f32), cast(-1.0, f32), cast(0.75, f32)])
  d = manhattan(copy(v), copy(v))
  assert_close(d, cast(0.0, f32), cast(1.0e-6, f32),
               "manhattan(v, v) = 0")
}

def test_manhattan_3_4() -> unit ! { Test } = {
  -- |3| + |4| = 7
  a = to_tensor([cast(0.0, f32), cast(0.0, f32)])
  b = to_tensor([cast(3.0, f32), cast(4.0, f32)])
  d = manhattan(a, b)
  assert_close(d, cast(7.0, f32), cast(1.0e-6, f32),
               "manhattan(0, [3,4]) = 7")
}

def test_manhattan_mixed() -> unit ! { Test } = {
  -- |1-4| + |2-6| + |3-3| = 3 + 4 + 0 = 7
  a = to_tensor([cast(1.0, f32), cast(2.0, f32), cast(3.0, f32)])
  b = to_tensor([cast(4.0, f32), cast(6.0, f32), cast(3.0, f32)])
  d = manhattan(a, b)
  assert_close(d, cast(7.0, f32), cast(1.0e-6, f32),
               "manhattan([1,2,3],[4,6,3]) = 7")
}

def test_manhattan_symmetry() -> unit ! { Test } = {
  x = to_tensor([cast(1.0, f32), cast(-2.5, f32), cast(0.5, f32)])
  y = to_tensor([cast(3.0, f32), cast(0.5, f32), cast(-1.5, f32)])
  dxy = manhattan(copy(x), copy(y))
  dyx = manhattan(y, x)
  assert_close(dxy, dyx, cast(1.0e-6, f32),
               "manhattan is symmetric")
}

-- ===== CHEBYSHEV =====

def test_chebyshev_self_zero() -> unit ! { Test } = {
  v = to_tensor([cast(2.0, f32), cast(-3.0, f32), cast(1.0, f32)])
  d = chebyshev(copy(v), copy(v))
  assert_close(d, cast(0.0, f32), cast(1.0e-6, f32),
               "chebyshev(v, v) = 0")
}

def test_chebyshev_max_coord() -> unit ! { Test } = {
  -- max(|3|, |4|, |5|) = 5
  a = to_tensor([cast(0.0, f32), cast(0.0, f32), cast(0.0, f32)])
  b = to_tensor([cast(3.0, f32), cast(4.0, f32), cast(5.0, f32)])
  d = chebyshev(a, b)
  assert_close(d, cast(5.0, f32), cast(1.0e-6, f32),
               "chebyshev(0,[3,4,5]) = 5")
}

def test_chebyshev_symmetry() -> unit ! { Test } = {
  x = to_tensor([cast(1.0, f32), cast(-2.5, f32), cast(0.5, f32)])
  y = to_tensor([cast(3.0, f32), cast(0.5, f32), cast(-1.5, f32)])
  dxy = chebyshev(copy(x), copy(y))
  dyx = chebyshev(y, x)
  assert_close(dxy, dyx, cast(1.0e-6, f32),
               "chebyshev is symmetric")
}

-- ===== COSINE SIMILARITY / DISTANCE =====

def test_cosine_distance_self_zero() -> unit ! { Test } = {
  -- cos angle between v and v is 1, so cosine_distance = 0
  v = to_tensor([cast(1.0, f32), cast(2.0, f32), cast(3.0, f32)])
  d = cosine_distance(copy(v), copy(v))
  assert_close(d, cast(0.0, f32), cast(1.0e-6, f32),
               "cosine_distance(v, v) = 0")
}

def test_cosine_similarity_self_one() -> unit ! { Test } = {
  v = to_tensor([cast(1.0, f32), cast(2.0, f32), cast(3.0, f32)])
  s = cosine_similarity(copy(v), copy(v))
  assert_close(s, cast(1.0, f32), cast(1.0e-6, f32),
               "cosine_similarity(v, v) = 1")
}

def test_cosine_distance_scale_invariant() -> unit ! { Test } = {
  -- cosine is scale-invariant under positive scaling
  v  = to_tensor([cast(1.0, f32), cast(2.0, f32), cast(3.0, f32)])
  v3 = to_tensor([cast(3.0, f32), cast(6.0, f32), cast(9.0, f32)])
  d = cosine_distance(v, v3)
  assert_close(d, cast(0.0, f32), cast(1.0e-6, f32),
               "cosine_distance(v, 3v) = 0")
}

def test_cosine_distance_orthogonal() -> unit ! { Test } = {
  -- orthogonal axes: cosine_distance = 1
  e0 = to_tensor([cast(1.0, f32), cast(0.0, f32)])
  e1 = to_tensor([cast(0.0, f32), cast(1.0, f32)])
  d = cosine_distance(e0, e1)
  assert_close(d, cast(1.0, f32), cast(1.0e-6, f32),
               "cosine_distance([1,0],[0,1]) = 1")
}

def test_cosine_similarity_orthogonal() -> unit ! { Test } = {
  e0 = to_tensor([cast(1.0, f32), cast(0.0, f32)])
  e1 = to_tensor([cast(0.0, f32), cast(1.0, f32)])
  s = cosine_similarity(e0, e1)
  assert_close(s, cast(0.0, f32), cast(1.0e-6, f32),
               "cosine_similarity([1,0],[0,1]) = 0")
}

-- ===== MAHALANOBIS =====

def test_mahalanobis_self_zero() -> unit ! { Test } = {
  -- mahalanobis(v, v, cov_inv) = 0
  v = to_tensor([cast(1.0, f32), cast(-2.0, f32)])
  -- arbitrary SPD-ish cov_inv (diag positive)
  cov_inv = mk_2x2(cast(2.0, f32), cast(0.0, f32),
                   cast(0.0, f32), cast(0.5, f32))
  d = mahalanobis(copy(v), copy(v), cov_inv)
  assert_close(d, cast(0.0, f32), cast(1.0e-6, f32),
               "mahalanobis(v, v, C^{-1}) = 0")
}

def test_mahalanobis_identity_reduces_to_euclidean() -> unit ! { Test } = {
  -- cov_inv = I  =>  mahalanobis(x, y, I) = euclidean(x, y).
  -- For x=[0,0], y=[3,4], expected = 5.
  x = to_tensor([cast(0.0, f32), cast(0.0, f32)])
  y = to_tensor([cast(3.0, f32), cast(4.0, f32)])
  id2 = mk_2x2(cast(1.0, f32), cast(0.0, f32),
               cast(0.0, f32), cast(1.0, f32))
  d = mahalanobis(x, y, id2)
  assert_close(d, cast(5.0, f32), cast(1.0e-6, f32),
               "mahalanobis(x,y,I) = euclidean(x,y) = 5")
}

def test_mahalanobis_squared_identity_reduces_to_squared_euclidean() -> unit ! { Test } = {
  -- a=[1,0], b=[0,1], cov_inv=I  =>  mahalanobis_squared = |a-b|^2 = 2
  a = to_tensor([cast(1.0, f32), cast(0.0, f32)])
  b = to_tensor([cast(0.0, f32), cast(1.0, f32)])
  id2 = mk_2x2(cast(1.0, f32), cast(0.0, f32),
               cast(0.0, f32), cast(1.0, f32))
  s = mahalanobis_squared(a, b, id2)
  assert_close(s, cast(2.0, f32), cast(1.0e-6, f32),
               "mahalanobis_squared(a,b,I) = |a-b|^2 = 2")
}

def test_mahalanobis_diag_scaling() -> unit ! { Test } = {
  -- cov_inv = diag(4, 4) corresponds to cov = diag(0.25, 0.25):
  -- mahalanobis distance scales by sqrt(4) = 2 vs euclidean.
  -- For x=[0,0], y=[3,4], euclidean = 5, expected mahalanobis = 10.
  x = to_tensor([cast(0.0, f32), cast(0.0, f32)])
  y = to_tensor([cast(3.0, f32), cast(4.0, f32)])
  cov_inv = mk_2x2(cast(4.0, f32), cast(0.0, f32),
                   cast(0.0, f32), cast(4.0, f32))
  d = mahalanobis(x, y, cov_inv)
  assert_close(d, cast(10.0, f32), cast(1.0e-5, f32),
               "mahalanobis with cov_inv=4I = 2 * euclidean")
}

-- ===== TRIANGLE INEQUALITY =====

def test_euclidean_triangle_inequality() -> unit ! { Test } = {
  -- For a=(0,0), b=(1,0), c=(0,1):
  --   d(a,c) = sqrt(2),  d(a,b) + d(b,c) = 1 + sqrt(2)
  -- so d(a,c) <= d(a,b) + d(b,c) holds strictly.
  a = to_tensor([cast(0.0, f32), cast(0.0, f32)])
  b = to_tensor([cast(1.0, f32), cast(0.0, f32)])
  c = to_tensor([cast(0.0, f32), cast(1.0, f32)])
  dac = euclidean(copy(a), copy(c))
  dab = euclidean(a, copy(b))
  dbc = euclidean(b, c)
  sum_ab_bc = add(dab, dbc)
  assert_true(lte(dac, sum_ab_bc),
              "euclidean: d(a,c) <= d(a,b) + d(b,c)")
}
