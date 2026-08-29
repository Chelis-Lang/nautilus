module Nautilus.Tests.LinAlg
import Std.Test (assert_close)
import Nautilus.LinAlg (matvec, vecmat, inner_product, l2_norm_vec, scale_vec, la_vec_add, la_vec_sub, la_vec_saxpy, diag, trace_scalar)
-- chelis:provenance/v1 oracle
-- id = NAUT-GATE-CHELIS-TEST
-- oracle-kind = test
-- runner-id = chelis-test
-- runner-version = 0.18.5
-- runner-digest = xxh3-128:cb9c68f2993c94b098afedeb8d7044b1
-- runner-configuration-digest = xxh3-128:42fb84f4054d7d0ad4b6c8e19e015c02
-- selection-schema = nautilus-oracle-selection/v1
-- selection = chelis test tests/ --timeout 600 --jobs auto
-- normalization-schema = nautilus-oracle-normalization/v1
-- normalization = chelis test exit status; zero is pass, nonzero is fail
-- configuration-digest = xxh3-128:ae3dfc4c0cfdd00cc99d50805da0931e
-- scope-schema = nautilus-oracle-scope/v1
-- scope = the committed Chelis-native positive corpus under tests/
def basis2(k: int64) -> tensor[2, f32] = to_tensor(map(fn (i: int64) -> if eq(i, k) then cast(1.0, f32) else cast(0.0, f32), range(cast(0, int64), cast(2, int64))))
-- chelis:provenance/v1 carrier
-- id = NAUT-CARRIER-LINALG-TESTS
-- role = positive
-- atoms = NAUT-MOD-LINALG@xxh3-128:49dca51dd2b5269319d41eaa1523c417
-- item-digest = xxh3-128:184f1cf13b5e64d7ac8c1af5a2dd1a69
-- oracle-id = NAUT-GATE-CHELIS-TEST
-- oracle-digest = xxh3-128:a6bf22d60ac853d26caa1417a727cd42
-- configuration-digest = xxh3-128:ae3dfc4c0cfdd00cc99d50805da0931e
-- scope-schema = nautilus-carrier-scope/v1
-- scope = the exact linear-algebra assertions in tests/linalg.ch
def basis3(k: int64) -> tensor[3, f32] = to_tensor(map(fn (i: int64) -> if eq(i, k) then cast(1.0, f32) else cast(0.0, f32), range(cast(0, int64), cast(3, int64))))
def mk_2x2(a: f32, b: f32, c: f32, d: f32) -> tensor[2, 2, f32] = {
  e0 = basis2(cast(0, int64))
  e1 = basis2(cast(1, int64))
  m0 = einsum("i,j->ij", e0, to_tensor([a, b]))
  m1 = einsum("i,j->ij", e1, to_tensor([c, d]))
  add(m0, m1)
}
def mk_3x3(a00: f32, a01: f32, a02: f32, a10: f32, a11: f32, a12: f32, a20: f32, a21: f32, a22: f32) -> tensor[3, 3, f32] = {
  e0 = basis3(cast(0, int64))
  e1 = basis3(cast(1, int64))
  e2 = basis3(cast(2, int64))
  m0 = einsum("i,j->ij", e0, to_tensor([a00, a01, a02]))
  m1 = einsum("i,j->ij", e1, to_tensor([a10, a11, a12]))
  m2 = einsum("i,j->ij", e2, to_tensor([a20, a21, a22]))
  add(add(m0, m1), m2)
}
def eye3() -> tensor[3, 3, f32] = mk_3x3(cast(1.0, f32), cast(0.0, f32), cast(0.0, f32), cast(0.0, f32), cast(1.0, f32), cast(0.0, f32), cast(0.0, f32), cast(0.0, f32), cast(1.0, f32))
def test_l2_norm_zero_is_zero() -> unit ! { Test } = {
  zero3 = to_tensor([cast(0.0, f32), cast(0.0, f32), cast(0.0, f32)])
  assert_close(l2_norm_vec(zero3), cast(0.0, f32), cast(1e-6, f32), "||0|| = 0")
}
def test_l2_norm_3_4_5_triangle() -> unit ! { Test } = {
  v = to_tensor([cast(3.0, f32), cast(4.0, f32)])
  assert_close(l2_norm_vec(v), cast(5.0, f32), cast(0.00001, f32), "||(3,4)|| = 5")
}
def test_l2_norm_homogeneous() -> unit ! { Test } = {
  v = to_tensor([cast(1.0, f32), cast(-2.0, f32), cast(2.0, f32)])
  scaled = scale_vec(copy(v), cast(-2.5, f32))
  assert_close(l2_norm_vec(scaled), mul(cast(2.5, f32), l2_norm_vec(copy(v))), cast(0.00001, f32), "||c v|| = |c| ||v||")
}
def test_dot_zero_is_zero() -> unit ! { Test } = {
  v = to_tensor([cast(1.0, f32), cast(2.0, f32), cast(3.0, f32)])
  zero3 = to_tensor([cast(0.0, f32), cast(0.0, f32), cast(0.0, f32)])
  assert_close(inner_product(v, zero3), cast(0.0, f32), cast(1e-6, f32), "dot(v, 0) = 0")
}
def test_dot_self_is_norm_squared() -> unit ! { Test } = {
  v = to_tensor([cast(3.0, f32), cast(4.0, f32)])
  d = inner_product(copy(v), copy(v))
  n = l2_norm_vec(copy(v))
  assert_close(d, mul(n, n), cast(0.00001, f32), "dot(v, v) = ||v||^2")
}
def test_dot_symmetric() -> unit ! { Test } = {
  v = to_tensor([cast(1.0, f32), cast(2.0, f32), cast(3.0, f32)])
  w = to_tensor([cast(4.0, f32), cast(-1.0, f32), cast(2.0, f32)])
  l = inner_product(copy(v), copy(w))
  r = inner_product(copy(w), copy(v))
  assert_close(l, r, cast(0.00001, f32), "dot symmetric")
}
def test_dot_basis_orthogonal() -> unit ! { Test } = {
  d = inner_product(basis3(cast(0, int64)), basis3(cast(1, int64)))
  assert_close(d, cast(0.0, f32), cast(1e-6, f32), "e_0 . e_1 = 0")
}
def test_dot_basis_self_one() -> unit ! { Test } = {
  d = inner_product(basis3(cast(2, int64)), basis3(cast(2, int64)))
  assert_close(d, cast(1.0, f32), cast(1e-6, f32), "e_2 . e_2 = 1")
}
def test_dot_bilinear_in_first() -> unit ! { Test } = {
  v = to_tensor([cast(1.0, f32), cast(2.0, f32), cast(3.0, f32)])
  w = to_tensor([cast(4.0, f32), cast(-1.0, f32), cast(2.0, f32)])
  c = cast(3.0, f32)
  l = inner_product(scale_vec(copy(v), c), copy(w))
  r = mul(c, inner_product(copy(v), copy(w)))
  assert_close(l, r, cast(0.00001, f32), "dot bilinear in first arg")
}
def test_vec_add_commutes() -> unit ! { Test } = {
  v = to_tensor([cast(1.0, f32), cast(2.0, f32), cast(3.0, f32)])
  w = to_tensor([cast(4.0, f32), cast(-1.0, f32), cast(2.0, f32)])
  vw = la_vec_add(copy(v), copy(w))
  wv = la_vec_add(copy(w), copy(v))
  assert_close(l2_norm_vec(la_vec_sub(vw, wv)), cast(0.0, f32), cast(1e-6, f32), "la_vec_add commutes")
}
def test_vec_add_zero_identity() -> unit ! { Test } = {
  v = to_tensor([cast(1.0, f32), cast(2.0, f32), cast(3.0, f32)])
  zero3 = to_tensor([cast(0.0, f32), cast(0.0, f32), cast(0.0, f32)])
  s = la_vec_add(copy(v), zero3)
  assert_close(l2_norm_vec(la_vec_sub(s, copy(v))), cast(0.0, f32), cast(1e-6, f32), "v + 0 = v")
}
def test_vec_sub_self_is_zero() -> unit ! { Test } = {
  v = to_tensor([cast(1.0, f32), cast(2.0, f32), cast(3.0, f32)])
  d = la_vec_sub(copy(v), copy(v))
  assert_close(l2_norm_vec(d), cast(0.0, f32), cast(1e-6, f32), "v - v = 0")
}
def test_vec_add_associative() -> unit ! { Test } = {
  v = to_tensor([cast(1.0, f32), cast(2.0, f32), cast(3.0, f32)])
  w = to_tensor([cast(4.0, f32), cast(-1.0, f32), cast(2.0, f32)])
  u = to_tensor([cast(2.0, f32), cast(0.0, f32), cast(-1.0, f32)])
  l = la_vec_add(la_vec_add(copy(v), copy(w)), copy(u))
  r = la_vec_add(copy(v), la_vec_add(copy(w), copy(u)))
  assert_close(l2_norm_vec(la_vec_sub(l, r)), cast(0.0, f32), cast(0.00001, f32), "(v+w)+u = v+(w+u)")
}
def test_scale_zero_is_zero() -> unit ! { Test } = {
  v = to_tensor([cast(1.0, f32), cast(2.0, f32), cast(3.0, f32)])
  s = scale_vec(v, cast(0.0, f32))
  assert_close(l2_norm_vec(s), cast(0.0, f32), cast(1e-6, f32), "scale_vec(v, 0) = 0")
}
def test_scale_one_is_identity() -> unit ! { Test } = {
  v = to_tensor([cast(1.0, f32), cast(2.0, f32), cast(3.0, f32)])
  s = scale_vec(copy(v), cast(1.0, f32))
  assert_close(l2_norm_vec(la_vec_sub(s, copy(v))), cast(0.0, f32), cast(1e-6, f32), "scale_vec(v, 1) = v")
}
def test_scale_composes() -> unit ! { Test } = {
  v = to_tensor([cast(1.0, f32), cast(2.0, f32), cast(3.0, f32)])
  l = scale_vec(scale_vec(copy(v), cast(2.0, f32)), cast(3.0, f32))
  r = scale_vec(copy(v), cast(6.0, f32))
  assert_close(l2_norm_vec(la_vec_sub(l, r)), cast(0.0, f32), cast(0.00001, f32), "scale composes (a*b)")
}
def test_saxpy_alpha_zero() -> unit ! { Test } = {
  x = to_tensor([cast(1.0, f32), cast(2.0, f32), cast(3.0, f32)])
  y = to_tensor([cast(4.0, f32), cast(-1.0, f32), cast(2.0, f32)])
  s = la_vec_saxpy(cast(0.0, f32), copy(x), y)
  assert_close(l2_norm_vec(la_vec_sub(s, copy(x))), cast(0.0, f32), cast(1e-6, f32), "saxpy(0, x, y) = x")
}
def test_saxpy_alpha_one() -> unit ! { Test } = {
  x = to_tensor([cast(1.0, f32), cast(2.0, f32), cast(3.0, f32)])
  y = to_tensor([cast(4.0, f32), cast(-1.0, f32), cast(2.0, f32)])
  s = la_vec_saxpy(cast(1.0, f32), copy(x), copy(y))
  expected = la_vec_add(copy(x), copy(y))
  assert_close(l2_norm_vec(la_vec_sub(s, expected)), cast(0.0, f32), cast(1e-6, f32), "saxpy(1, x, y) = x + y")
}
def test_saxpy_alpha_neg_one() -> unit ! { Test } = {
  x = to_tensor([cast(1.0, f32), cast(2.0, f32), cast(3.0, f32)])
  y = to_tensor([cast(4.0, f32), cast(-1.0, f32), cast(2.0, f32)])
  s = la_vec_saxpy(cast(-1.0, f32), copy(x), copy(y))
  expected = la_vec_sub(copy(x), copy(y))
  assert_close(l2_norm_vec(la_vec_sub(s, expected)), cast(0.0, f32), cast(0.00001, f32), "saxpy(-1, x, y) = x - y")
}
def test_matvec_identity_preserves_vector() -> unit ! { Test } = {
  v = to_tensor([cast(1.0, f32), cast(2.0, f32), cast(3.0, f32)])
  out = matvec(eye3(), copy(v))
  assert_close(l2_norm_vec(la_vec_sub(out, copy(v))), cast(0.0, f32), cast(0.00001, f32), "I * v = v")
}
def test_matvec_zero_matrix() -> unit ! { Test } = {
  zero33 = mk_3x3(cast(0.0, f32), cast(0.0, f32), cast(0.0, f32), cast(0.0, f32), cast(0.0, f32), cast(0.0, f32), cast(0.0, f32), cast(0.0, f32), cast(0.0, f32))
  v = to_tensor([cast(1.0, f32), cast(2.0, f32), cast(3.0, f32)])
  out = matvec(zero33, v)
  assert_close(l2_norm_vec(out), cast(0.0, f32), cast(1e-6, f32), "0 * v = 0")
}
def test_matvec_basis_extracts_column() -> unit ! { Test } = {
  a = mk_3x3(cast(1.0, f32), cast(2.0, f32), cast(3.0, f32), cast(4.0, f32), cast(5.0, f32), cast(6.0, f32), cast(7.0, f32), cast(8.0, f32), cast(9.0, f32))
  out = matvec(a, basis3(cast(0, int64)))
  expected = to_tensor([cast(1.0, f32), cast(4.0, f32), cast(7.0, f32)])
  assert_close(l2_norm_vec(la_vec_sub(out, expected)), cast(0.0, f32), cast(0.00001, f32), "A * e_0 = column 0 of A")
}
def test_matvec_basis_extracts_column_2() -> unit ! { Test } = {
  a = mk_3x3(cast(1.0, f32), cast(2.0, f32), cast(3.0, f32), cast(4.0, f32), cast(5.0, f32), cast(6.0, f32), cast(7.0, f32), cast(8.0, f32), cast(9.0, f32))
  out = matvec(a, basis3(cast(2, int64)))
  expected = to_tensor([cast(3.0, f32), cast(6.0, f32), cast(9.0, f32)])
  assert_close(l2_norm_vec(la_vec_sub(out, expected)), cast(0.0, f32), cast(0.00001, f32), "A * e_2 = column 2 of A")
}
def test_vecmat_basis_extracts_row() -> unit ! { Test } = {
  a = mk_3x3(cast(1.0, f32), cast(2.0, f32), cast(3.0, f32), cast(4.0, f32), cast(5.0, f32), cast(6.0, f32), cast(7.0, f32), cast(8.0, f32), cast(9.0, f32))
  out = vecmat(basis3(cast(1, int64)), a)
  expected = to_tensor([cast(4.0, f32), cast(5.0, f32), cast(6.0, f32)])
  assert_close(l2_norm_vec(la_vec_sub(out, expected)), cast(0.0, f32), cast(0.00001, f32), "e_1^T A = row 1")
}
def test_vecmat_zero_vector() -> unit ! { Test } = {
  a = mk_3x3(cast(1.0, f32), cast(2.0, f32), cast(3.0, f32), cast(4.0, f32), cast(5.0, f32), cast(6.0, f32), cast(7.0, f32), cast(8.0, f32), cast(9.0, f32))
  zero3 = to_tensor([cast(0.0, f32), cast(0.0, f32), cast(0.0, f32)])
  out = vecmat(zero3, a)
  assert_close(l2_norm_vec(out), cast(0.0, f32), cast(1e-6, f32), "0^T A = 0")
}
def test_trace_identity_is_n() -> unit ! { Test } = {
  t = trace_scalar(eye3())
  assert_close(t, cast(3.0, f32), cast(1e-6, f32), "trace(I_3) = 3")
}
def test_diag_extracts_diagonal() -> unit ! { Test } = {
  m = mk_3x3(cast(1.0, f32), cast(2.0, f32), cast(3.0, f32), cast(4.0, f32), cast(5.0, f32), cast(6.0, f32), cast(7.0, f32), cast(8.0, f32), cast(9.0, f32))
  d = diag(m)
  expected = to_tensor([cast(1.0, f32), cast(5.0, f32), cast(9.0, f32)])
  assert_close(l2_norm_vec(la_vec_sub(d, expected)), cast(0.0, f32), cast(0.00001, f32), "diag([[1..9]]) = [1, 5, 9]")
}
def test_trace_zero_matrix_is_zero() -> unit ! { Test } = {
  zero33 = mk_3x3(cast(0.0, f32), cast(0.0, f32), cast(0.0, f32), cast(0.0, f32), cast(0.0, f32), cast(0.0, f32), cast(0.0, f32), cast(0.0, f32), cast(0.0, f32))
  t = trace_scalar(zero33)
  assert_close(t, cast(0.0, f32), cast(1e-6, f32), "trace(0) = 0")
}
def test_trace_arbitrary_3x3() -> unit ! { Test } = {
  a = mk_3x3(cast(1.0, f32), cast(2.0, f32), cast(3.0, f32), cast(4.0, f32), cast(5.0, f32), cast(6.0, f32), cast(7.0, f32), cast(8.0, f32), cast(9.0, f32))
  t = trace_scalar(a)
  assert_close(t, cast(15.0, f32), cast(0.00001, f32), "trace = sum of diagonal")
}
def linearity_owned_norm[n](v: tensor[n, f32]) -> f32 = l2_norm_vec(v)
def linearity_copy_from_borrow[n](v: &tensor[n, f32]) -> f32 = linearity_owned_norm(copy(v))
def test_linearity_required_owned_from_borrowed_copy() -> unit ! { Test } = {
  v = to_tensor([cast(3.0, f32), cast(4.0, f32)])
  assert_close(linearity_copy_from_borrow(v), cast(5.0, f32), cast(0.00001, f32), "copy converts a borrowed tensor to the required fresh owner")
}
