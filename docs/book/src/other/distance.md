# Distance

The `Nautilus.Distance` module provides 8 vector distance metrics over
`tensor[n, f32]` inputs. All are pure, polymorphic over length `n`, and
depend on `Nautilus.LinAlg` for inner products and norms. Every input is a
read-only borrow (`&tensor`), so the same vectors can be passed to several
metrics without `copy`:

```chelis
module Nautilus.BookDistances
import Nautilus.Distance (euclidean, manhattan, chebyshev, cosine_distance)
export (distances)
def distances[n](a: tensor[n, f32], b: tensor[n, f32]) -> (f32, f32, f32, f32) = (euclidean(a, b), manhattan(a, b), chebyshev(a, b), cosine_distance(a, b))
```

## Lp distances

```chelis-fragment
import Nautilus.Distance (euclidean, manhattan, chebyshev)

d2 = euclidean(a, b)    // L2: sqrt(sum((a_i - b_i)^2))
d1 = manhattan(a, b)    // L1: sum(|a_i - b_i|)
dinf = chebyshev(a, b)  // L-inf: max(|a_i - b_i|)
```

| Function | Formula | Signature |
|---|---|---|
| `squared_euclidean` | sum((a_i - b_i)^2) | `[n](a, b: &tensor[n, f32]) -> f32` |
| `euclidean` | sqrt(squared_euclidean) | same |
| `manhattan` | sum(\|a_i - b_i\|) | same |
| `chebyshev` | max(\|a_i - b_i\|) | same |

## Cosine distance

```chelis-fragment
import Nautilus.Distance (cosine_similarity, cosine_distance)

sim = cosine_similarity(a, b)  // dot(a,b) / (||a|| * ||b||)
dist = cosine_distance(a, b)   // 1 - sim
```

Uses `inner_product` and `l2_norm_vec` from `Nautilus.LinAlg` internally.
Returns values in [-1, 1] for similarity and [0, 2] for distance. Division
by zero (zero-norm vector) produces inf/NaN per IEEE 754.

## Mahalanobis distance

```chelis-fragment
import Nautilus.Distance (mahalanobis, mahalanobis_squared)

// Caller must supply the inverse covariance matrix
d = mahalanobis(a, b, cov_inv)
d2 = mahalanobis_squared(a, b, cov_inv)
```

**Signature:** `[n](a: &tensor[n, f32], b: &tensor[n, f32], cov_inv: &tensor[n, n, f32]) -> f32`

Computes `sqrt(diff^T * cov_inv * diff)` where `diff = a - b`. The caller
is responsible for providing the inverse covariance matrix; use `inv_2x2`
or `inv_3x3` from `Nautilus.LinAlg` to compute it, or `cg_solve` for
larger SPD systems.

Internally uses `matvec` and `inner_product` from LinAlg. The
`mahalanobis_squared` variant skips the final `sqrt`.
