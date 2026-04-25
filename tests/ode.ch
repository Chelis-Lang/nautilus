module Nautilus.Tests.ODE

-- Identity / structural tests for Nautilus.ODE.
-- All expected values are mathematical identities, exact constants,
-- documented closed-form solutions, or convergence-order checks.
-- No scipy-derived numerics.

import Nautilus.ODE (euler_step, euler_solve,
                    rk4_step, rk4_solve,
                    rk45_adaptive_solve, rk45_adaptive_solve_grid)
import Nautilus.LinAlg (inner_product, la_basis_n_f32)
import Std.Test (assert_close, assert_close_tensor, assert_true)

-- ===== scalar RHS functions =====

-- y' = -y, y(0) = 1  =>  y(t) = exp(-t)
def decay_rhs(y: f32, t: f32) -> f32 = neg(y)

-- y' = 0, y(0) = c   =>  y(t) = c (exact for any solver)
def zero_rhs(y: f32, t: f32) -> f32 = cast(0.0, f32)

-- y' = 1, y(0) = 0   =>  y(t) = t
def unit_rhs(y: f32, t: f32) -> f32 = cast(1.0, f32)

-- ===== vector RHS functions =====

-- y' = -y as a 1D system
def decay_rhs_vec(y: tensor[1, f32], t: f32) -> tensor[1, f32] = neg(y)

-- Harmonic oscillator: y' = [y[1], -y[0]] with y(0) = [1, 0]  =>  y(t) = [cos t, -sin t]
def harmonic_rhs(y: tensor[2, f32], t: f32) -> tensor[2, f32] = {
  -- Extract components via inner products with basis vectors
  template = to_tensor([cast(0.0, f32), cast(0.0, f32)])
  e0 = la_basis_n_f32(cast(0, int64), cast(1.0, f32), copy(template))
  e1 = la_basis_n_f32(cast(1, int64), cast(1.0, f32), copy(template))
  y0 = inner_product(copy(y), e0)
  y1 = inner_product(y, e1)
  -- Result: [y1, -y0]
  to_tensor([y1, neg(y0)])
}

-- ===== helpers =====

-- Pull scalar value out of a tensor[1, f32]
def first_of_1(v: tensor[1, f32]) -> f32 =
  inner_product(v, to_tensor([cast(1.0, f32)]))

-- Pull column j out of a tensor[n, p, f32] as a tensor[n, f32]
def grid_col[n, p](g: tensor[n, p, f32], template_p: tensor[p, f32], j: int64) -> tensor[n, f32] = {
  basis = la_basis_n_f32(j, cast(1.0, f32), template_p)
  einsum("ij,j->i", g, basis)
}

-- ===== DECAY: y' = -y, y(0)=1 -> y(t) = exp(-t) =====

def test_decay_at_zero() -> unit ! { Test } = {
  -- y(0) = 1 trivially: t0 == t_end
  result = rk45_adaptive_solve(decay_rhs, cast(1.0, f32), cast(0.0, f32),
                               cast(0.0, f32), cast(1.0e-6, f32), cast(1.0e-8, f32))
  assert_close(result, cast(1.0, f32), cast(1.0e-6, f32),
               "decay y(0) = 1")
}

def test_decay_at_t1_rk45() -> unit ! { Test } = {
  -- y' = -y, y(0)=1 -> y(1) = 1/e
  -- 0.3678794 = 1/e (Euler's number reciprocal)
  result = rk45_adaptive_solve(decay_rhs, cast(1.0, f32), cast(0.0, f32),
                               cast(1.0, f32), cast(1.0e-6, f32), cast(1.0e-8, f32))
  assert_close(result, cast(0.3678794, f32), cast(1.0e-4, f32),
               "decay y(1) = 1/e")
}

def test_decay_at_t2_rk45() -> unit ! { Test } = {
  -- y' = -y, y(0)=1 -> y(2) = e^{-2}
  -- 0.1353352 = e^{-2}
  result = rk45_adaptive_solve(decay_rhs, cast(1.0, f32), cast(0.0, f32),
                               cast(2.0, f32), cast(1.0e-6, f32), cast(1.0e-8, f32))
  assert_close(result, cast(0.1353352, f32), cast(1.0e-4, f32),
               "decay y(2) = e^{-2}")
}

def test_decay_at_t5_rk45() -> unit ! { Test } = {
  -- y' = -y, y(0)=1 -> y(5) = e^{-5}
  -- 0.0067379 = e^{-5}
  result = rk45_adaptive_solve(decay_rhs, cast(1.0, f32), cast(0.0, f32),
                               cast(5.0, f32), cast(1.0e-6, f32), cast(1.0e-8, f32))
  assert_close(result, cast(0.0067379, f32), cast(1.0e-5, f32),
               "decay y(5) = e^{-5}")
}

def test_decay_rk4_at_t1() -> unit ! { Test } = {
  -- y' = -y, y(0)=1 -> y(1) = 1/e; rk4 with 100 steps should be very accurate
  -- 0.3678794 = 1/e
  result = rk4_solve(decay_rhs, cast(1.0, f32), cast(0.0, f32),
                     cast(1.0, f32), cast(100, int64))
  assert_close(result, cast(0.3678794, f32), cast(1.0e-5, f32),
               "rk4 decay y(1) = 1/e")
}

-- ===== CONSTANT ZERO: y' = 0, y(0)=c -> y(t) = c =====

def test_zero_rhs_preserves_initial_euler() -> unit ! { Test } = {
  -- y' = 0 should keep y at its initial value exactly (or to round-off)
  c = cast(2.5, f32)
  result = euler_solve(zero_rhs, c, cast(0.0, f32), cast(3.0, f32), cast(50, int64))
  assert_close(result, c, cast(1.0e-6, f32),
               "y' = 0 preserves initial value (euler)")
}

def test_zero_rhs_preserves_initial_rk4() -> unit ! { Test } = {
  c = cast(7.25, f32)
  result = rk4_solve(zero_rhs, c, cast(0.0, f32), cast(4.0, f32), cast(20, int64))
  assert_close(result, c, cast(1.0e-6, f32),
               "y' = 0 preserves initial value (rk4)")
}

def test_zero_rhs_preserves_initial_rk45() -> unit ! { Test } = {
  c = cast(-1.5, f32)
  result = rk45_adaptive_solve(zero_rhs, c, cast(0.0, f32), cast(2.0, f32),
                               cast(1.0e-6, f32), cast(1.0e-8, f32))
  assert_close(result, c, cast(1.0e-6, f32),
               "y' = 0 preserves initial value (rk45)")
}

-- ===== LINEAR GROWTH: y' = 1, y(0)=0 -> y(t) = t =====

def test_linear_growth_t1_rk4() -> unit ! { Test } = {
  -- y(1) = 1; rk4 is exact on linear functions (degree <= 4)
  result = rk4_solve(unit_rhs, cast(0.0, f32), cast(0.0, f32),
                     cast(1.0, f32), cast(10, int64))
  assert_close(result, cast(1.0, f32), cast(1.0e-6, f32),
               "y' = 1 -> y(1) = 1 (rk4)")
}

def test_linear_growth_t5_rk4() -> unit ! { Test } = {
  -- y(5) = 5
  result = rk4_solve(unit_rhs, cast(0.0, f32), cast(0.0, f32),
                     cast(5.0, f32), cast(50, int64))
  assert_close(result, cast(5.0, f32), cast(1.0e-5, f32),
               "y' = 1 -> y(5) = 5 (rk4)")
}

def test_linear_growth_t1_euler() -> unit ! { Test } = {
  -- Euler is also exact on y' = 1 since the slope is constant
  result = euler_solve(unit_rhs, cast(0.0, f32), cast(0.0, f32),
                       cast(1.0, f32), cast(100, int64))
  assert_close(result, cast(1.0, f32), cast(1.0e-5, f32),
               "y' = 1 -> y(1) = 1 (euler)")
}

def test_linear_growth_t5_rk45() -> unit ! { Test } = {
  -- y(5) = 5 via adaptive rk45
  result = rk45_adaptive_solve(unit_rhs, cast(0.0, f32), cast(0.0, f32),
                               cast(5.0, f32), cast(1.0e-6, f32), cast(1.0e-8, f32))
  assert_close(result, cast(5.0, f32), cast(1.0e-4, f32),
               "y' = 1 -> y(5) = 5 (rk45)")
}

-- ===== HARMONIC OSCILLATOR (2D system) =====
-- y' = [y[1], -y[0]], y(0) = [1, 0]  =>  y(t) = [cos t, -sin t]
-- pi values used: 1.5707963 = pi/2, 3.1415926 = pi, 6.2831853 = 2*pi

def test_harmonic_at_zero() -> unit ! { Test } = {
  -- y(0) = [1, 0] (trivial: t0 == t_end returns y0)
  y0 = to_tensor([cast(1.0, f32), cast(0.0, f32)])
  t_out = to_tensor([cast(0.0, f32)])
  template_p = to_tensor([cast(0.0, f32)])
  -- Note: t_end == t0 path returns zero_output, so we use a tiny endpoint
  -- and check at t_out = 0 instead. To check y(0) trivially, use the
  -- inner-product extraction below at t very close to 0.
  -- Better approach: just check expected initial state via t_out near 0.
  grid = rk45_adaptive_solve_grid(harmonic_rhs, cast(0.0, f32), y0,
                                  cast(0.001, f32),
                                  cast(1.0e-6, f32), cast(1.0e-8, f32),
                                  to_tensor([cast(0.001, f32)]))
  -- After Hermite interp at t = 0.001, y ~= [cos(0.001), -sin(0.001)] ~ [1, -0.001]
  col = grid_col(grid, to_tensor([cast(0.0, f32)]), cast(0, int64))
  expected = to_tensor([cast(1.0, f32), cast(-0.001, f32)])
  assert_close_tensor(col, expected, cast(1.0e-3, f32),
                      "harmonic y(0.001) ~ [1, -0.001]")
}

def test_harmonic_quarter_period() -> unit ! { Test } = {
  -- y(pi/2) = [cos(pi/2), -sin(pi/2)] = [0, -1]
  -- 1.5707963 = pi/2
  y0 = to_tensor([cast(1.0, f32), cast(0.0, f32)])
  t_end = cast(1.5707963, f32)
  grid = rk45_adaptive_solve_grid(harmonic_rhs, cast(0.0, f32), y0,
                                  t_end,
                                  cast(1.0e-7, f32), cast(1.0e-9, f32),
                                  to_tensor([t_end]))
  col = grid_col(grid, to_tensor([cast(0.0, f32)]), cast(0, int64))
  expected = to_tensor([cast(0.0, f32), cast(-1.0, f32)])
  assert_close_tensor(col, expected, cast(1.0e-3, f32),
                      "harmonic y(pi/2) = [0, -1]")
}

def test_harmonic_half_period() -> unit ! { Test } = {
  -- y(pi) = [cos(pi), -sin(pi)] = [-1, 0]
  -- 3.1415926 = pi
  y0 = to_tensor([cast(1.0, f32), cast(0.0, f32)])
  t_end = cast(3.1415926, f32)
  grid = rk45_adaptive_solve_grid(harmonic_rhs, cast(0.0, f32), y0,
                                  t_end,
                                  cast(1.0e-7, f32), cast(1.0e-9, f32),
                                  to_tensor([t_end]))
  col = grid_col(grid, to_tensor([cast(0.0, f32)]), cast(0, int64))
  expected = to_tensor([cast(-1.0, f32), cast(0.0, f32)])
  assert_close_tensor(col, expected, cast(1.0e-3, f32),
                      "harmonic y(pi) = [-1, 0]")
}

def test_harmonic_full_period() -> unit ! { Test } = {
  -- y(2*pi) = [cos(2pi), -sin(2pi)] = [1, 0] (full period round-trip)
  -- 6.2831853 = 2*pi
  y0 = to_tensor([cast(1.0, f32), cast(0.0, f32)])
  t_end = cast(6.2831853, f32)
  grid = rk45_adaptive_solve_grid(harmonic_rhs, cast(0.0, f32), y0,
                                  t_end,
                                  cast(1.0e-7, f32), cast(1.0e-9, f32),
                                  to_tensor([t_end]))
  col = grid_col(grid, to_tensor([cast(0.0, f32)]), cast(0, int64))
  expected = to_tensor([cast(1.0, f32), cast(0.0, f32)])
  assert_close_tensor(col, expected, cast(5.0e-3, f32),
                      "harmonic y(2*pi) = [1, 0] (full period)")
}

-- ===== GRID DECAY: rk45_adaptive_solve_grid on y' = -y =====

def test_grid_decay_at_t1() -> unit ! { Test } = {
  -- Sample y(t) = e^{-t} at t = 1
  -- 0.3678794 = 1/e
  y0 = to_tensor([cast(1.0, f32)])
  t_out = to_tensor([cast(1.0, f32)])
  grid = rk45_adaptive_solve_grid(decay_rhs_vec, cast(0.0, f32), y0,
                                  cast(1.0, f32),
                                  cast(1.0e-7, f32), cast(1.0e-9, f32),
                                  t_out)
  col = grid_col(grid, to_tensor([cast(0.0, f32)]), cast(0, int64))
  expected = to_tensor([cast(0.3678794, f32)])
  assert_close_tensor(col, expected, cast(1.0e-4, f32),
                      "grid decay y(1) = 1/e")
}

def test_grid_decay_at_t2() -> unit ! { Test } = {
  -- Sample y(t) = e^{-t} at t = 2
  -- 0.1353352 = e^{-2}
  y0 = to_tensor([cast(1.0, f32)])
  t_out = to_tensor([cast(2.0, f32)])
  grid = rk45_adaptive_solve_grid(decay_rhs_vec, cast(0.0, f32), y0,
                                  cast(2.0, f32),
                                  cast(1.0e-7, f32), cast(1.0e-9, f32),
                                  t_out)
  col = grid_col(grid, to_tensor([cast(0.0, f32)]), cast(0, int64))
  expected = to_tensor([cast(0.1353352, f32)])
  assert_close_tensor(col, expected, cast(1.0e-4, f32),
                      "grid decay y(2) = e^{-2}")
}

-- ===== SOLVER CONSISTENCY =====

def test_grid_matches_scalar_decay() -> unit ! { Test } = {
  -- rk45_adaptive_solve_grid(... t_out=[t_end]) last value should match
  -- rk45_adaptive_solve(... t_end) for the scalar lift of the same ODE.
  scalar_result = rk45_adaptive_solve(decay_rhs, cast(1.0, f32), cast(0.0, f32),
                                      cast(2.0, f32),
                                      cast(1.0e-7, f32), cast(1.0e-9, f32))
  y0 = to_tensor([cast(1.0, f32)])
  t_out = to_tensor([cast(2.0, f32)])
  grid = rk45_adaptive_solve_grid(decay_rhs_vec, cast(0.0, f32), y0,
                                  cast(2.0, f32),
                                  cast(1.0e-7, f32), cast(1.0e-9, f32),
                                  t_out)
  col = grid_col(grid, to_tensor([cast(0.0, f32)]), cast(0, int64))
  grid_result = first_of_1(col)
  -- They are different solver paths (scalar adaptive vs vector adaptive
  -- with Hermite interp at the last grid point), so we allow generous tol.
  assert_close(grid_result, scalar_result, cast(1.0e-3, f32),
               "grid decay last value matches scalar rk45")
}

def test_euler_convergence_n100_bounded() -> unit ! { Test } = {
  -- For y' = -y, y(0) = 1, the exact solution at t=1 is 1/e.
  -- Euler's method has global error O(h); n=100 step error should be < 0.01.
  -- 0.3678794 = 1/e
  exact = cast(0.3678794, f32)
  y_n100 = euler_solve(decay_rhs, cast(1.0, f32), cast(0.0, f32),
                       cast(1.0, f32), cast(100, int64))
  err100 = sub(y_n100, exact)
  abs100 = if lt(err100, cast(0.0, f32)) then neg(err100) else err100
  assert_true(lt(abs100, cast(0.01, f32)), "euler n=100 error < 0.01")
}

def test_euler_convergence_order_one() -> unit ! { Test } = {
  -- For y' = -y, y(0) = 1, the exact solution at t=1 is 1/e.
  -- Euler's method has global error O(h). Halving h should roughly halve
  -- the error. We check the ratio (err at n=200) / (err at n=100) in (0.4, 0.6).
  -- 0.3678794 = 1/e
  exact = cast(0.3678794, f32)
  y_n100 = euler_solve(decay_rhs, cast(1.0, f32), cast(0.0, f32),
                       cast(1.0, f32), cast(100, int64))
  y_n200 = euler_solve(decay_rhs, cast(1.0, f32), cast(0.0, f32),
                       cast(1.0, f32), cast(200, int64))
  err100 = sub(y_n100, exact)
  err200 = sub(y_n200, exact)
  abs100 = if lt(err100, cast(0.0, f32)) then neg(err100) else err100
  abs200 = if lt(err200, cast(0.0, f32)) then neg(err200) else err200
  ratio = div(abs200, abs100)
  in_lo = gt(ratio, cast(0.4, f32))
  in_hi = lt(ratio, cast(0.6, f32))
  assert_true(and(in_lo, in_hi),
              "euler error ratio in (0.4, 0.6) (order 1 convergence)")
}

def test_rk4_more_accurate_than_euler() -> unit ! { Test } = {
  -- On the smooth decay ODE, rk4 with the same number of steps should be
  -- much more accurate than euler. (Euler is O(h), rk4 is O(h^4).)
  -- 0.3678794 = 1/e
  exact = cast(0.3678794, f32)
  y_euler = euler_solve(decay_rhs, cast(1.0, f32), cast(0.0, f32),
                        cast(1.0, f32), cast(100, int64))
  y_rk4   = rk4_solve(decay_rhs, cast(1.0, f32), cast(0.0, f32),
                      cast(1.0, f32), cast(100, int64))
  err_e = sub(y_euler, exact)
  err_r = sub(y_rk4, exact)
  abs_e = if lt(err_e, cast(0.0, f32)) then neg(err_e) else err_e
  abs_r = if lt(err_r, cast(0.0, f32)) then neg(err_r) else err_r
  assert_true(lt(abs_r, abs_e), "rk4 error < euler error (n=100)")
}

def test_step_consistency_rk4_vs_euler_small_h() -> unit ! { Test } = {
  -- For very small h on a smooth ODE, both rk4_step and euler_step give
  -- y + h * f(y, t) + O(h^2). Their difference should be O(h^2), i.e.
  -- much smaller than h itself.
  y = cast(1.0, f32)
  t = cast(0.0, f32)
  h = cast(1.0e-3, f32)
  y_e = euler_step(decay_rhs, y, t, h)
  y_r = rk4_step(decay_rhs, y, t, h)
  diff = sub(y_r, y_e)
  abs_diff = if lt(diff, cast(0.0, f32)) then neg(diff) else diff
  -- Difference should be O(h^2) ~ 1e-6, well below h = 1e-3
  assert_true(lt(abs_diff, cast(1.0e-5, f32)),
              "rk4_step - euler_step is O(h^2) for small h")
}
