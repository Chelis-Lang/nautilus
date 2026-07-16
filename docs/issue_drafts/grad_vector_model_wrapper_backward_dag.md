# grad over a function-valued vector model emits a malformed backward DAG

**Target:** `Chelis-Lang/chelis`, likely as an extension/comment on chelis#676
or as a new residue issue if upstream considers function capture distinct.

**Status:** ready to file or deduplicate

**Filing condition:** Before the Nautilus remediation PR is marked ready, ask
upstream whether chelis#676 includes a closure that captures a function-valued
model while all tensor data are direct target arguments. If yes, post this
witness there and replace draft citations with `chelis#676`; otherwise file it
as a new issue and replace citations with the new number.

## Summary

On Chelis 0.16.1, the concrete vector-model wrapper needed to compute a
Jacobian row for `Nautilus.CurveFit.lm_scalar_nparam` checks at score 1 but
fails in both evaluator and C-backend lowering while constructing the backward
DAG:

```text
failed to construct backward DAG (grad: constructed backward DAG failed
verification: binary op at node 2 has mismatched dimension count: 0 vs 1)
```

This is the same verifier class as open chelis#676, but that issue's isolated
trigger is a tensor-capturing closure. This witness captures the arbitrary
function-valued model; `theta`, observations, and output seed are direct target
arguments.

## Reproducer shape

```chelis
def jacobian_row(
  model: &tensor[2, f32] -> &tensor[6, f32] -> tensor[6, f32],
  theta: tensor[2, f32],
  x_data: tensor[6, f32],
  output_seed: tensor[6, f32]
) -> tensor[2, f32] = {
  target = fn (
    theta_local: tensor[2, f32],
    x_local: tensor[6, f32],
    seed_local: tensor[6, f32]
  ) -> {
    prediction = model(theta_local, x_local)
    tensor_to_scalar(sum(mul(prediction, seed_local), cast(0, int32)))
  }
  grad(target, wrt=(theta_local))(theta, x_data, output_seed)
}
```

The full executable witness, including a two-parameter linear model and the
expected Jacobian row `[1, 1]`, is
`tests_blocked/curvefit/lm_jacobian_model_wrapper.ch`.

## Commands and results

```text
chelis check repro.ch             # PASS, score 1
chelis eval --file repro.ch       # FAIL, malformed backward DAG
chelis build --target c repro.ch  # FAIL, same verifier class
```

## Discriminators

- A capture-free generic direct objective over `(theta, x, seed)` passes eval,
  builds to C, and returns the expected tensor gradient.
- The upstream scalar-observation function-parameter wrapper builds to
  compilable C. The vector-output projection surface is the distinguishing
  downstream requirement.
- Passing the function-valued model as target argument 0 instead of capturing
  it is not a workaround: the checker resolves `wrt=(theta_local)` as index 0
  and rejects it as non-differentiable.

## Downstream impact

`lm_scalar_nparam` retains a finite-difference Jacobian with `eps=1e-5`. This
has f32 cancellation/scaling limitations and cannot be presented as the
permanent AD implementation.

## Expected behavior

The concrete wrapper evaluates and C-builds, returning the Jacobian row
`tensor(shape=[2], data=[1.0, 1.0])` for the pinned linear witness.
