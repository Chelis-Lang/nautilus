# Curve fitting

`Nautilus.CurveFit` exports two Levenberg-Marquardt fitters:

- `lm_scalar_1param`, which takes an analytical scalar derivative;
- `lm_scalar_nparam`, which fits a tensor parameter vector using a
  finite-difference Jacobian.

## `lm_scalar_1param`

```chelis-fragment
lm_scalar_1param(
  model: f32 -> f32 -> f32,    -- model(x, theta) -> predicted y
  dmodel: f32 -> f32 -> f32,   -- dmodel(x, theta) -> d(predicted_y)/d(theta)
  xs: &tensor[n, f32],
  ys: &tensor[n, f32],
  theta0: f32,
  lambda0: f32,
  tol: f32,
  max_iters: i64
) -> f32
```

Each iteration applies the damped Gauss-Newton update
`theta += sum(J * r) / (sum(J^2) * (1 + lambda0))`, where `J` is
`dmodel(x, theta)` and `r` the residual `y - model(x, theta)` at each point.
`lambda0` is fixed for the whole run.

| Situation | Result |
|---|---|
| `abs(theta_next - theta) < tol`, or an update that leaves theta unchanged | the current theta |
| `max_iters` iterations without that | the last theta, with no signal that it did not converge |
| `max_iters <= 0` | `theta0` |
| empty `xs` | NaN |
| `sum(J^2) * (1 + lambda0)` below 1e-30 in magnitude | theta unchanged, so the fit stops at `theta0` when the derivative is zero everywhere |
| a NaN from `model` or `dmodel` | NaN |

Use `lambda0 >= 0`. `lambda0 = -1` makes every step zero, and
`lambda0 < -1` reverses the step direction. A larger `lambda0` shortens each
step; it slows convergence but does not change the fixed point.

### Example: fitting a slope

```chelis-fragment
import Nautilus.CurveFit (lm_scalar_1param)

def linear_model(x: f32, theta: f32) -> f32 = mul(theta, x)
def linear_dmodel(x: f32, theta: f32) -> f32 = x
def xs() -> tensor[5, f32] = to_tensor([1.0f32, 2.0f32, 3.0f32, 4.0f32, 5.0f32])
def ys() -> tensor[5, f32] = to_tensor([2.1f32, 3.9f32, 6.2f32, 7.8f32, 10.1f32])
slope = lm_scalar_1param(linear_model, linear_dmodel, xs(), ys(), 0.0f32, 0.01f32, 1e-8f32, 100i64)
slope_one_iter = lm_scalar_1param(linear_model, linear_dmodel, xs(), ys(), 0.0f32, 0.01f32, 1e-8f32, 1i64)
```

```text
slope = 2.0036364
slope_one_iter = 1.9837984
```

The least-squares slope through the origin is `sum(x*y) / sum(x^2) =
110.2 / 55 = 2.003636`. One iteration from 0 lands 1% short because of the
damping factor `1 / (1 + 0.01)`; later iterations close the gap.

## `lm_scalar_nparam`

```chelis-fragment
lm_scalar_nparam(
  model: &tensor[n, f32] -> &tensor[m, f32] -> tensor[m, f32],
  x: &tensor[m, f32],
  y: &tensor[m, f32],
  theta0: tensor[n, f32],
  tol: f32,
  max_iters: i64
) -> tensor[n, f32]
```

`model(theta, x)` predicts the `m` observations. The fitter forms
`J^T J + 0.01 I`, solves the damped normal equations with conjugate gradient
(tolerance 1e-6 on the squared residual, at most 50 iterations), and adds
the solution to the `n` parameters. It runs exactly `max_iters` iterations;
`tol` is unused and does not stop iterations early. `max_iters <= 0` returns
`theta0`.

```chelis-fragment
import Nautilus.CurveFit (lm_scalar_nparam)

def xs() -> tensor[5, f32] = to_tensor([1.0f32, 2.0f32, 3.0f32, 4.0f32, 5.0f32])
def ys() -> tensor[5, f32] = to_tensor([2.1f32, 3.9f32, 6.2f32, 7.8f32, 10.1f32])
def line(theta: &tensor[2, f32], x: &tensor[5, f32]) -> tensor[5, f32] = {
  a = index(to_list(theta), 0i64)
  b = index(to_list(theta), 1i64)
  to_tensor(map(fn (xi: f32) -> add(a, mul(b, xi)), to_list(x)))
}
line_fit = lm_scalar_nparam(line, xs(), ys(), to_tensor([0.0f32, 0.0f32]), 1e-6f32, 20i64)
```

```text
line_fit = tensor(shape=[2], data=[0.045314897, 1.9912884])
```

The exact least-squares line is intercept 0.05, slope 1.99. After 20 fixed
iterations the fit is within 0.005 of both.

The result carries no convergence flag. If the inner conjugate-gradient
solve does not reach its tolerance in 50 iterations, the step uses whatever
it reached; a NaN prediction makes every later parameter NaN. Compute the
residual of the returned parameters yourself when the fit matters.

The Jacobian uses forward differences with `eps=1e-5`. The fitter does
not differentiate through the full optimization loop.

Scale parameters and predictions to roughly O(1). At larger magnitudes an
`eps=1e-5` perturbation can fall below an f32 ULP, produce a zero Jacobian
column, and permanently stall the fit.

## Limitations

- Both APIs are f32-only.
- `lm_scalar_1param` requires an analytical derivative and keeps its supplied
  damping factor fixed.
- `lm_scalar_nparam` keeps lambda fixed at `0.01`, does not use `tol` for
  early exit, and uses finite differences for the Jacobian.
