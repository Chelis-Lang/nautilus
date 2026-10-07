# Normal distribution

`Nautilus.Distributions` provides the normal PDF, CDF, inverse CDF, and
sampler, plus tensor versions of the first three. The CDF appears in
Black-Scholes pricing; the inverse CDF gives normal quantiles for
value-at-risk and hypothesis tests.

```chelis-fragment
import Nautilus.Distributions (normal_pdf, normal_cdf, normal_inv_cdf, normal_sample)

density = normal_pdf(0.0f32, 0.0f32, 1.0f32)
p = normal_cdf(1.96f32, 0.0f32, 1.0f32)
x = normal_inv_cdf(0.975f32, 0.0f32, 1.0f32)
draws = normal_sample(key_from_seed(42i64), to_tensor([0.0f32, 0.0f32, 0.0f32, 0.0f32]), 10.0f32, 2.0f32)
```

`chelis eval --file` prints:

```text
density = 0.3989423
p = 0.9750021
x = 1.9598706
draws = tensor(shape=[4], data=[10.56278, 7.0699587, 7.9746065, 9.512872])
```

## Contract

| Function | Signature | Returns |
|---|---|---|
| `normal_pdf` | `(x: f32, mean: f32, std: f32) -> f32` | (1 / (std * sqrt(2*pi))) * exp(-0.5 * ((x - mean) / std)^2) |
| `normal_cdf` | `(x: f32, mean: f32, std: f32) -> f32` | P(X <= x) |
| `normal_inv_cdf` | `(q: f32, mean: f32, std: f32) -> f32` | x such that `normal_cdf(x, mean, std) = q` |
| `normal_sample` | `[n](k: key, template: tensor[n, f32], mean: f32, std: f32) -> tensor[n, f32]` | n draws from Normal(mean, std) |

`std` is the standard deviation, not the variance, and must be positive and
finite. None of the four functions checks it. The formulas run as written,
so a bad `std` gives a value, not an error:

| `std` | `normal_pdf` | `normal_cdf` | `normal_inv_cdf` and `normal_sample` |
|---|---|---|---|
| `0` | NaN | 1.0 for x > mean, 0.0 for x < mean, NaN at x = mean | `mean` for every q in (0, 1) and every draw |
| negative | a negative number | the upper tail of Normal(mean, abs(std)) | mirrored about `mean` |

`normal_pdf(1, 0, -1)` is `-0.24197073` and `normal_cdf(1, 0, -1)` is
`0.15865526`. Validate `std` before the call when it is computed. A NaN in any
argument gives NaN.

`normal_inv_cdf` takes a probability `q`:

| `q` | Result |
|---|---|
| in (0, 1) | the quantile |
| exactly 0 | -inf |
| exactly 1 | +inf |
| below 0 or above 1 | NaN |

## normal_cdf

`normal_cdf` standardizes to z = (x - mean) / std and calls the Chelis
`standard_normal_cdf` builtin, which evaluates Phi through `erfc`. It has no
`1 - erf` cancellation, so the lower tail keeps its digits down to the f32
subnormal range. For an upper tail, call `normal_cdf(neg(z), 0, 1)` instead of
subtracting from 1; see [Distributions](overview.md).
The rounding of `(x - mean) / std` adds error for a shifted or scaled
normal; the [precision guide](../appendix/precision.md) gives the
figures.

## normal_inv_cdf

Evaluates `mean + std * sqrt(2) * erfinv(2q - 1)`, with `erfinv` from
`Nautilus.Special` (an Acklam rational approximation). Relative error is
about 1e-7 in the central region.

## normal_sample

`normal_sample` draws with the Box-Muller transform. The `template` tensor
fixes the output length `n`; its values are ignored. The key is consumed:
the function splits it into two child keys, one per uniform draw. The same
key and inputs always give the same draws, so pass a fresh key, or a child
from `split_key`, for each independent sample. See
[Sampling with explicit keys](sampling.md).

## Tensor versions

`normal_pdf_t`, `normal_cdf_t`, and `normal_inv_cdf_t` apply the same
formulas elementwise. Each has the signature
`[n](x: &tensor[n, f32], mean: f32, std: f32) -> tensor[n, f32]` and borrows
its input. Use them on a tensor of Monte Carlo paths instead of converting to
a list and back.

```chelis-fragment
import Nautilus.Distributions (normal_cdf_t, normal_inv_cdf_t)

probs = normal_cdf_t(to_tensor([-1.0f32, 0.0f32, 1.96f32]), 0.0f32, 1.0f32)
quants = normal_inv_cdf_t(to_tensor([0.0f32, 0.025f32, 0.5f32, 1.0f32, 1.5f32]), 0.0f32, 1.0f32)
```

```text
probs = tensor(shape=[3], data=[0.15865526, 0.5, 0.9750021])
quants = tensor(shape=[5], data=[-inf, -1.9598264, 0.0, inf, NaN])
```

`normal_inv_cdf_t` applies the scalar boundary rules lane by lane: -inf at
0, +inf at 1, and NaN outside [0, 1].
