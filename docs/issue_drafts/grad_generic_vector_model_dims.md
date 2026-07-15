# grad wrapper over generic vector model collapses rigid `n` and `m` dimensions

**Target:** `Chelis-Lang/chelis`

**Status:** ready to file

**Filing condition:** File before the Nautilus remediation PR is marked ready,
unless upstream triage identifies an existing numbered issue that covers this
exact generic function-parameter witness. Replace every draft-path citation
with that issue number when filed or deduplicated.

## Summary

On Chelis 0.16.1, the generic Jacobian-row wrapper required by
`Nautilus.CurveFit.lm_scalar_nparam` fails checking because `grad` unifies the
independently declared parameter dimension `n` and observation dimension `m`.
The same wrapper with concrete dimensions checks cleanly, and a generic direct
multi-argument tensor grad without the arbitrary model function parameter also
checks, evaluates, and C-builds correctly.

## Reproducer

```chelis
def jacobian_row[n, m](
  model: &tensor[n, f32] -> &tensor[m, f32] -> tensor[m, f32],
  theta: tensor[n, f32],
  x_data: tensor[m, f32],
  output_seed: tensor[m, f32]
) -> tensor[n, f32] = {
  target = fn (
    theta_local: tensor[n, f32],
    x_local: tensor[m, f32],
    seed_local: tensor[m, f32]
  ) -> {
    prediction = model(theta_local, x_local)
    tensor_to_scalar(sum(mul(prediction, seed_local), cast(0, int32)))
  }
  grad(target, wrt=(theta_local))(theta, x_data, output_seed)
}
```

```text
$ chelis check repro.ch
DimensionMismatch: distinct declared dim parameters ... were unified by the
function body: declared dim parameters are rigid and must remain distinct
```

The executable Nautilus probe is
`tests_blocked/curvefit/lm_jacobian_generic_dims.ch`.

## Discriminators

- Replace `n=2`, `m=6` concretely: check passes, then eval/C lowering reaches
  the separate backward-DAG failure tracked by
  `docs/issue_drafts/grad_vector_model_wrapper_backward_dag.md`.
- Remove the arbitrary `model` function parameter and differentiate a direct
  generic objective over `(theta[n], x[m], seed[m])`: check, eval, C build,
  and generated-C compilation all pass; the gradient has shape `[n]` and the
  expected values.
- Upstream issue chelis#260 covers internal dim IDs in diagnostics, not the
  erroneous unification itself.

## Downstream impact

`lm_scalar_nparam` must retain its finite-difference Jacobian. Fixing only this
checker layer is not enough: the concrete wrapper's eval/C backend probe must
also pass before Nautilus can de-narrow to AD.

## Expected behavior

The wrapper checks without unifying `n` and `m`; `wrt=(theta_local)` returns a
`tensor[n, f32]` while `x_local`, `seed_local`, and the prediction retain
`tensor[m, f32]` independently.
