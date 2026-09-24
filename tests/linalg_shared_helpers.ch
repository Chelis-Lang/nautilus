module Nautilus.Tests.LinAlgSharedHelpers
import Std.Test (assert_close)
import Nautilus.LinAlg (la_basis_n, la_zeros_mat_like, la_tridiag_solve, l2_norm_vec, frobenius_norm)
def test_basis_two_entries() -> unit ! { Test } = {
  template = to_tensor([7.0f32, 8.0f32])
  actual = la_basis_n(1i64, -2.0f32, template)
  expected = to_tensor([0.0f32, -2.0f32])
  assert_close(l2_norm_vec(sub(actual, expected)), 0.0f32, 1e-6f32, "basis selects the requested entry")
}
def test_basis_three_entries() -> unit ! { Test } = {
  template = to_tensor([7.0f32, 8.0f32, 9.0f32])
  actual = la_basis_n(0i64, 3.0f32, template)
  expected = to_tensor([3.0f32, 0.0f32, 0.0f32])
  assert_close(l2_norm_vec(sub(actual, expected)), 0.0f32, 1e-6f32, "basis preserves the three-entry shape")
}
def test_zero_matrix_two_by_two() -> unit ! { Test } = {
  vector = to_tensor([2.0f32, -3.0f32])
  matrix = einsum("i,j->ij", vector, vector)
  assert_close(frobenius_norm(la_zeros_mat_like(matrix)), 0.0f32, 1e-6f32, "zero matrix from finite two-entry outer product")
}
def test_zero_matrix_three_by_three() -> unit ! { Test } = {
  vector = to_tensor([1.0f32, 4.0f32, -2.0f32])
  matrix = einsum("i,j->ij", vector, vector)
  assert_close(frobenius_norm(la_zeros_mat_like(matrix)), 0.0f32, 1e-6f32, "zero matrix from finite three-entry outer product")
}
def test_tridiagonal_two_equations() -> unit ! { Test } = {
  actual = la_tridiag_solve(to_tensor([0.0f32, 1.0f32]), to_tensor([2.0f32, 3.0f32]), to_tensor([1.0f32, 0.0f32]), to_tensor([4.0f32, 7.0f32]))
  assert_close(l2_norm_vec(sub(actual, to_tensor([1.0f32, 2.0f32]))), 0.0f32, 0.00001f32, "two-equation analytic solution")
}
def test_tridiagonal_three_equations() -> unit ! { Test } = {
  actual = la_tridiag_solve(to_tensor([0.0f32, -1.0f32, -1.0f32]), to_tensor([2.0f32, 2.0f32, 2.0f32]), to_tensor([-1.0f32, -1.0f32, 0.0f32]), to_tensor([0.0f32, 0.0f32, 4.0f32]))
  assert_close(l2_norm_vec(sub(actual, to_tensor([1.0f32, 2.0f32, 3.0f32]))), 0.0f32, 0.00001f32, "three-equation analytic solution")
}
