module Nautilus.Tests.LinAlgSharedHelpers
import Std.Test (assert_close, assert_true)
import Nautilus.LinAlg (la_basis_n_f32, la_zeros_mat_like, la_tridiag_solve, l2_norm_vec, frobenius_norm)
def test_basis_two_entries() -> unit ! { Test } = {
  template = to_tensor([7.0f32, 8.0f32])
  actual = la_basis_n_f32(1i64, -2.0f32, template)
  expected = to_tensor([0.0f32, -2.0f32])
  assert_close(l2_norm_vec(sub(actual, expected)), 0.0f32, 1e-6f32, "basis selects the requested entry")
}
def test_basis_three_entries() -> unit ! { Test } = {
  template = to_tensor([7.0f32, 8.0f32, 9.0f32])
  actual = la_basis_n_f32(0i64, 3.0f32, template)
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
def test_tridiagonal_nonsingular_small_pivots() -> unit ! { Test } = {
  s = 1e-31f32
  actual = la_tridiag_solve(to_tensor([0.0f32, s]), to_tensor([mul(2.0f32, s), mul(3.0f32, s)]), to_tensor([s, 0.0f32]), to_tensor([mul(4.0f32, s), mul(7.0f32, s)]))
  values = to_list(actual)
  _ = assert_close(index(values, 0i64), 1.0f32, 0.00001f32, "small nonzero first pivot preserves the analytic solution")
  assert_close(index(values, 1i64), 2.0f32, 0.00001f32, "small nonzero eliminated pivot preserves the analytic solution")
}
def tridiag_is_nan(x: f32) -> bool = not(eq(x, x))
def test_tridiagonal_rejects_zero_first_pivot() -> unit ! { Test } = {
  actual = la_tridiag_solve(to_tensor([0.0f32, 1.0f32]), to_tensor([0.0f32, 2.0f32]), to_tensor([1.0f32, 0.0f32]), to_tensor([1.0f32, 2.0f32]))
  values = to_list(actual)
  _ = assert_true(tridiag_is_nan(index(values, 0i64)), "zero first pivot has no nonpivoting Thomas solution")
  assert_true(tridiag_is_nan(index(values, 1i64)), "zero first pivot rejects the entire result")
}
def test_tridiagonal_rejects_zero_eliminated_pivot() -> unit ! { Test } = {
  actual = la_tridiag_solve(to_tensor([0.0f32, 1.0f32]), to_tensor([1.0f32, 1.0f32]), to_tensor([1.0f32, 0.0f32]), to_tensor([2.0f32, 2.0f32]))
  values = to_list(actual)
  _ = assert_true(tridiag_is_nan(index(values, 0i64)), "singular final pivot rejects the entire result")
  assert_true(tridiag_is_nan(index(values, 1i64)), "singular final pivot is rejected")
}
def test_tridiagonal_rejects_nonfinite_first_pivot() -> unit ! { Test } = {
  inf = div(1.0f32, 0.0f32)
  nan = div(0.0f32, 0.0f32)
  inf_result = la_tridiag_solve(to_tensor([0.0f32, 1.0f32]), to_tensor([inf, 2.0f32]), to_tensor([1.0f32, 0.0f32]), to_tensor([1.0f32, 2.0f32]))
  nan_result = la_tridiag_solve(to_tensor([0.0f32, 1.0f32]), to_tensor([nan, 2.0f32]), to_tensor([1.0f32, 0.0f32]), to_tensor([1.0f32, 2.0f32]))
  _ = assert_true(tridiag_is_nan(index(to_list(inf_result), 0i64)), "infinite pivot rejects the result")
  assert_true(tridiag_is_nan(index(to_list(nan_result), 0i64)), "NaN pivot rejects the result")
}
