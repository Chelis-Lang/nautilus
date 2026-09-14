module Nautilus.Tests.Ode
import Nautilus.Ode (euler_step, euler_solve, rk4_step, rk4_solve, rk45_adaptive_solve, rk45_adaptive_solve_grid)
import Nautilus.LinAlg (inner_product, la_basis_n)
import Std.Test (assert_close, assert_close_tensor, assert_true)
def decay_rhs(y: f32, t: f32) -> f32 = neg(y)
def zero_rhs(y: f32, t: f32) -> f32 = cast(0.0, f32)
def unit_rhs(y: f32, t: f32) -> f32 = cast(1.0, f32)
def decay_rhs_vec(y: tensor[1, f32], t: f32) -> tensor[1, f32] = neg(y)
def harmonic_rhs(y: tensor[2, f32], t: f32) -> tensor[2, f32] = {
  template = to_tensor([cast(0.0, f32), cast(0.0, f32)])
  e0 = la_basis_n(cast(0, int64), cast(1.0, f32), copy(template))
  e1 = la_basis_n(cast(1, int64), cast(1.0, f32), copy(template))
  y0 = inner_product(copy(y), e0)
  y1 = inner_product(y, e1)
  to_tensor([y1, neg(y0)])
}
def first_of_1(v: &tensor[1, f32]) -> f32 = inner_product(v, to_tensor([cast(1.0, f32)]))
def grid_col[n, p](g: &tensor[n, p, f32], template_p: &tensor[p, f32], j: int64) -> tensor[n, f32] = {
  basis = la_basis_n(j, cast(1.0, f32), template_p)
  einsum("ij,j->i", g, basis)
}
def test_decay_at_zero() -> unit ! { Test } = {
  result = rk45_adaptive_solve(decay_rhs, cast(1.0, f32), cast(0.0, f32), cast(0.0, f32), cast(1e-6, f32), cast(1e-8, f32))
  assert_close(result, cast(1.0, f32), cast(1e-6, f32), "decay y(0) = 1")
}
def test_decay_at_t1_rk45() -> unit ! { Test } = {
  result = rk45_adaptive_solve(decay_rhs, cast(1.0, f32), cast(0.0, f32), cast(1.0, f32), cast(1e-6, f32), cast(1e-8, f32))
  assert_close(result, cast(0.3678794, f32), cast(0.0001, f32), "decay y(1) = 1/e")
}
def test_decay_at_t2_rk45() -> unit ! { Test } = {
  result = rk45_adaptive_solve(decay_rhs, cast(1.0, f32), cast(0.0, f32), cast(2.0, f32), cast(1e-6, f32), cast(1e-8, f32))
  assert_close(result, cast(0.1353352, f32), cast(0.0001, f32), "decay y(2) = e^{-2}")
}
def test_decay_at_t5_rk45() -> unit ! { Test } = {
  result = rk45_adaptive_solve(decay_rhs, cast(1.0, f32), cast(0.0, f32), cast(5.0, f32), cast(1e-6, f32), cast(1e-8, f32))
  assert_close(result, cast(0.0067379, f32), cast(0.00001, f32), "decay y(5) = e^{-5}")
}
def test_decay_rk4_at_t1() -> unit ! { Test } = {
  result = rk4_solve(decay_rhs, cast(1.0, f32), cast(0.0, f32), cast(1.0, f32), cast(100, int64))
  assert_close(result, cast(0.3678794, f32), cast(0.00001, f32), "rk4 decay y(1) = 1/e")
}
def test_zero_rhs_preserves_initial_euler() -> unit ! { Test } = {
  c = cast(2.5, f32)
  result = euler_solve(zero_rhs, c, cast(0.0, f32), cast(3.0, f32), cast(50, int64))
  assert_close(result, c, cast(1e-6, f32), "y' = 0 preserves initial value (euler)")
}
def test_zero_rhs_preserves_initial_rk4() -> unit ! { Test } = {
  c = cast(7.25, f32)
  result = rk4_solve(zero_rhs, c, cast(0.0, f32), cast(4.0, f32), cast(20, int64))
  assert_close(result, c, cast(1e-6, f32), "y' = 0 preserves initial value (rk4)")
}
def test_zero_rhs_preserves_initial_rk45() -> unit ! { Test } = {
  c = cast(-1.5, f32)
  result = rk45_adaptive_solve(zero_rhs, c, cast(0.0, f32), cast(2.0, f32), cast(1e-6, f32), cast(1e-8, f32))
  assert_close(result, c, cast(1e-6, f32), "y' = 0 preserves initial value (rk45)")
}
def test_linear_growth_t1_rk4() -> unit ! { Test } = {
  result = rk4_solve(unit_rhs, cast(0.0, f32), cast(0.0, f32), cast(1.0, f32), cast(10, int64))
  assert_close(result, cast(1.0, f32), cast(1e-6, f32), "y' = 1 -> y(1) = 1 (rk4)")
}
def test_linear_growth_t5_rk4() -> unit ! { Test } = {
  result = rk4_solve(unit_rhs, cast(0.0, f32), cast(0.0, f32), cast(5.0, f32), cast(50, int64))
  assert_close(result, cast(5.0, f32), cast(0.00001, f32), "y' = 1 -> y(5) = 5 (rk4)")
}
def test_linear_growth_t1_euler() -> unit ! { Test } = {
  result = euler_solve(unit_rhs, cast(0.0, f32), cast(0.0, f32), cast(1.0, f32), cast(100, int64))
  assert_close(result, cast(1.0, f32), cast(0.00001, f32), "y' = 1 -> y(1) = 1 (euler)")
}
def test_linear_growth_t5_rk45() -> unit ! { Test } = {
  result = rk45_adaptive_solve(unit_rhs, cast(0.0, f32), cast(0.0, f32), cast(5.0, f32), cast(1e-6, f32), cast(1e-8, f32))
  assert_close(result, cast(5.0, f32), cast(0.0001, f32), "y' = 1 -> y(5) = 5 (rk45)")
}
def test_harmonic_at_zero() -> unit ! { Test } = {
  y0 = to_tensor([cast(1.0, f32), cast(0.0, f32)])
  t_out = to_tensor([cast(0.0, f32)])
  template_p = to_tensor([cast(0.0, f32)])
  grid = rk45_adaptive_solve_grid(harmonic_rhs, cast(0.0, f32), y0, cast(0.001, f32), cast(1e-6, f32), cast(1e-8, f32), to_tensor([cast(0.001, f32)]))
  col = grid_col(grid, to_tensor([cast(0.0, f32)]), cast(0, int64))
  expected = to_tensor([cast(1.0, f32), cast(-0.001, f32)])
  assert_close_tensor(col, expected, cast(0.001, f32), "harmonic y(0.001) ~ [1, -0.001]")
}
def test_harmonic_quarter_period() -> unit ! { Test } = {
  y0 = to_tensor([cast(1.0, f32), cast(0.0, f32)])
  t_end = cast(1.5707963, f32)
  grid = rk45_adaptive_solve_grid(harmonic_rhs, cast(0.0, f32), y0, t_end, cast(1e-7, f32), cast(1e-9, f32), to_tensor([t_end]))
  col = grid_col(grid, to_tensor([cast(0.0, f32)]), cast(0, int64))
  expected = to_tensor([cast(0.0, f32), cast(-1.0, f32)])
  assert_close_tensor(col, expected, cast(0.001, f32), "harmonic y(pi/2) = [0, -1]")
}
def test_harmonic_half_period() -> unit ! { Test } = {
  y0 = to_tensor([cast(1.0, f32), cast(0.0, f32)])
  t_end = cast(3.1415926, f32)
  grid = rk45_adaptive_solve_grid(harmonic_rhs, cast(0.0, f32), y0, t_end, cast(1e-7, f32), cast(1e-9, f32), to_tensor([t_end]))
  col = grid_col(grid, to_tensor([cast(0.0, f32)]), cast(0, int64))
  expected = to_tensor([cast(-1.0, f32), cast(0.0, f32)])
  assert_close_tensor(col, expected, cast(0.001, f32), "harmonic y(pi) = [-1, 0]")
}
def test_harmonic_full_period() -> unit ! { Test } = {
  y0 = to_tensor([cast(1.0, f32), cast(0.0, f32)])
  t_end = cast(6.2831853, f32)
  grid = rk45_adaptive_solve_grid(harmonic_rhs, cast(0.0, f32), y0, t_end, cast(1e-7, f32), cast(1e-9, f32), to_tensor([t_end]))
  col = grid_col(grid, to_tensor([cast(0.0, f32)]), cast(0, int64))
  expected = to_tensor([cast(1.0, f32), cast(0.0, f32)])
  assert_close_tensor(col, expected, cast(0.005, f32), "harmonic y(2*pi) = [1, 0] (full period)")
}
def test_grid_decay_at_t1() -> unit ! { Test } = {
  y0 = to_tensor([cast(1.0, f32)])
  t_out = to_tensor([cast(1.0, f32)])
  grid = rk45_adaptive_solve_grid(decay_rhs_vec, cast(0.0, f32), y0, cast(1.0, f32), cast(1e-7, f32), cast(1e-9, f32), t_out)
  col = grid_col(grid, to_tensor([cast(0.0, f32)]), cast(0, int64))
  expected = to_tensor([cast(0.3678794, f32)])
  assert_close_tensor(col, expected, cast(0.0001, f32), "grid decay y(1) = 1/e")
}
def test_grid_decay_at_t2() -> unit ! { Test } = {
  y0 = to_tensor([cast(1.0, f32)])
  t_out = to_tensor([cast(2.0, f32)])
  grid = rk45_adaptive_solve_grid(decay_rhs_vec, cast(0.0, f32), y0, cast(2.0, f32), cast(1e-7, f32), cast(1e-9, f32), t_out)
  col = grid_col(grid, to_tensor([cast(0.0, f32)]), cast(0, int64))
  expected = to_tensor([cast(0.1353352, f32)])
  assert_close_tensor(col, expected, cast(0.0001, f32), "grid decay y(2) = e^{-2}")
}
def test_grid_matches_scalar_decay() -> unit ! { Test } = {
  scalar_result = rk45_adaptive_solve(decay_rhs, cast(1.0, f32), cast(0.0, f32), cast(2.0, f32), cast(1e-7, f32), cast(1e-9, f32))
  y0 = to_tensor([cast(1.0, f32)])
  t_out = to_tensor([cast(2.0, f32)])
  grid = rk45_adaptive_solve_grid(decay_rhs_vec, cast(0.0, f32), y0, cast(2.0, f32), cast(1e-7, f32), cast(1e-9, f32), t_out)
  col = grid_col(grid, to_tensor([cast(0.0, f32)]), cast(0, int64))
  grid_result = first_of_1(col)
  assert_close(grid_result, scalar_result, cast(0.001, f32), "grid decay last value matches scalar rk45")
}
def test_euler_convergence_n100_bounded() -> unit ! { Test } = {
  exact = cast(0.3678794, f32)
  y_n100 = euler_solve(decay_rhs, cast(1.0, f32), cast(0.0, f32), cast(1.0, f32), cast(100, int64))
  err100 = sub(y_n100, exact)
  abs100 = if lt(err100, cast(0.0, f32)) then neg(err100) else err100
  assert_true(lt(abs100, cast(0.01, f32)), "euler n=100 error < 0.01")
}
def test_euler_convergence_order_one() -> unit ! { Test } = {
  exact = cast(0.3678794, f32)
  y_n100 = euler_solve(decay_rhs, cast(1.0, f32), cast(0.0, f32), cast(1.0, f32), cast(100, int64))
  y_n200 = euler_solve(decay_rhs, cast(1.0, f32), cast(0.0, f32), cast(1.0, f32), cast(200, int64))
  err100 = sub(y_n100, exact)
  err200 = sub(y_n200, exact)
  abs100 = if lt(err100, cast(0.0, f32)) then neg(err100) else err100
  abs200 = if lt(err200, cast(0.0, f32)) then neg(err200) else err200
  ratio = div(abs200, abs100)
  in_lo = gt(ratio, cast(0.4, f32))
  in_hi = lt(ratio, cast(0.6, f32))
  assert_true(and(in_lo, in_hi), "euler error ratio in (0.4, 0.6) (order 1 convergence)")
}
def test_rk4_more_accurate_than_euler() -> unit ! { Test } = {
  exact = cast(0.3678794, f32)
  y_euler = euler_solve(decay_rhs, cast(1.0, f32), cast(0.0, f32), cast(1.0, f32), cast(100, int64))
  y_rk4 = rk4_solve(decay_rhs, cast(1.0, f32), cast(0.0, f32), cast(1.0, f32), cast(100, int64))
  err_e = sub(y_euler, exact)
  err_r = sub(y_rk4, exact)
  abs_e = if lt(err_e, cast(0.0, f32)) then neg(err_e) else err_e
  abs_r = if lt(err_r, cast(0.0, f32)) then neg(err_r) else err_r
  assert_true(lt(abs_r, abs_e), "rk4 error < euler error (n=100)")
}
def test_step_consistency_rk4_vs_euler_small_h() -> unit ! { Test } = {
  y = cast(1.0, f32)
  t = cast(0.0, f32)
  h = cast(0.001, f32)
  y_e = euler_step(decay_rhs, y, t, h)
  y_r = rk4_step(decay_rhs, y, t, h)
  diff = sub(y_r, y_e)
  abs_diff = if lt(diff, cast(0.0, f32)) then neg(diff) else diff
  assert_true(lt(abs_diff, cast(0.00001, f32)), "rk4_step - euler_step is O(h^2) for small h")
}
def test_rk45_sub_ulp_step_plateau_locks_iterate() -> unit ! { Test } = {
  result = rk45_adaptive_solve(zero_rhs, cast(1.5, f32), cast(0.0, f32), cast(1e-10, f32), cast(1e-9, f32), cast(1e-10, f32))
  assert_close(result, cast(1.5, f32), cast(1e-6, f32), "rk45_adaptive_rec: plateau-stop holds iterate when sub-f32-ULP step yields y_next == y bit-exact")
}
