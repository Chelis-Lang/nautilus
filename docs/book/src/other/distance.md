# Distance

The `Nautilus.Distance` module provides 8 vector distance metrics over
`tensor[n, f32]` inputs. All are pure, polymorphic over length `n`, and
depend on `Nautilus.LinAlg` for inner products and norms. Every input is a
read-only borrow (`&tensor`), so the same vectors can be passed to several
metrics without `copy`, as the example below does.

## Lp distances

```chelis-fragment
import Nautilus.Distance (euclidean, manhattan, chebyshev, cosine_distance)

def a() -> tensor[2, f32] = to_tensor([1.0f32, 2.0f32])
def b() -> tensor[2, f32] = to_tensor([4.0f32, 6.0f32])
all4 = (euclidean(a(), b()), manhattan(a(), b()), chebyshev(a(), b()), cosine_distance(a(), b()))
```

```text
a = tensor(shape=[2], data=[1.0, 2.0])
b = tensor(shape=[2], data=[4.0, 6.0])
all4.0 = 5.0
all4.1 = 7.0
all4.2 = 4.0
all4.3 = 0.0077221394
```

The difference is `[-3, -4]`: L2 distance 5, L1 distance 7, L-infinity
distance 4. The two vectors point in nearly the same direction, so their
cosine distance is small.

| Function | Formula | Signature |
|---|---|---|
| `squared_euclidean` | sum((a_i - b_i)^2) | `[n](a, b: &tensor[n, f32]) -> f32` |
| `euclidean` | sqrt(squared_euclidean) | same |
| `manhattan` | sum(\|a_i - b_i\|) | same |
| `chebyshev` | max(\|a_i - b_i\|) | same |

## Cosine distance

| Function | Formula | Signature |
|---|---|---|
| `cosine_similarity` | dot(a, b) / (\|a\| * \|b\|) | `[n](a, b: &tensor[n, f32]) -> f32` |
| `cosine_distance` | 1 - cosine_similarity | same |

```chelis-fragment
import Nautilus.Distance (cosine_similarity, cosine_distance)

sim = cosine_similarity(to_tensor([1.0f32, 2.0f32]), to_tensor([4.0f32, 6.0f32]))
dist = cosine_distance(to_tensor([1.0f32, 2.0f32]), to_tensor([4.0f32, 6.0f32]))
```

```text
sim = 0.99227786
dist = 0.0077221394
```

Uses `inner_product` and `l2_norm_vec` from `Nautilus.LinAlg` internally.
Returns values in [-1, 1] for similarity and [0, 2] for distance. A zero
vector has no direction: `cosine_distance([0, 0], [4, 6])` is NaN. Check
norms first if zero vectors can occur.

## Mahalanobis distance

```chelis-fragment
import Nautilus.Distance (mahalanobis, mahalanobis_squared)
import Nautilus.LinAlg (inv_2x2)

def a() -> tensor[2, f32] = to_tensor([1.0f32, 2.0f32])
def b() -> tensor[2, f32] = to_tensor([4.0f32, 6.0f32])
def cov_inv() -> tensor[2, 2, f32] = inv_2x2(to_tensor([[4.0f32, 0.0f32], [0.0f32, 16.0f32]]))
d = mahalanobis(a(), b(), cov_inv())
d2 = mahalanobis_squared(a(), b(), cov_inv())
```

```text
cov_inv = tensor(shape=[2, 2], data=[0.25, 0.0, 0.0, 0.0625])
d = 1.8027756
d2 = 3.25
```

The covariance has variances 4 and 16, so the difference `[-3, -4]` scales
to `-3/2` and `-4/4` standard deviations: `d2 = 2.25 + 1 = 3.25`. The
Euclidean distance between the same points is 5.

**Signature:** `[n](a: &tensor[n, f32], b: &tensor[n, f32], cov_inv: &tensor[n, n, f32]) -> f32`

Computes `sqrt(diff^T * cov_inv * diff)` where `diff = a - b`. The caller
is responsible for providing the inverse covariance matrix. `inv_2x2`
and `inv_3x3` from `Nautilus.LinAlg` cover those small sizes. `cg_solve`
solves `Ax = b` for one vector; it does not return an inverse matrix.
For a larger positive-definite covariance matrix, solve
`covariance * x = a - b` and compute `sqrt((a - b)^T * x)` directly,
checking the solve's residual.

Internally uses `matvec` and `inner_product` from LinAlg. The
`mahalanobis_squared` variant skips the final `sqrt`. `cov_inv` is not
checked: a matrix that is not positive definite can make the squared
distance negative, and `mahalanobis` then returns NaN.
