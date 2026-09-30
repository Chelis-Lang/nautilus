# Normal Distribution

The normal (Gaussian) distribution is the most commonly used continuous
distribution in Nautilus. It provides PDF, CDF, inverse CDF, and
sampling. The CDF and inverse CDF are the workhorses for Black-Scholes
pricing, Value-at-Risk, and hypothesis testing.

## normal_pdf

**Signature:** `(x: f32, mean: f32, std: f32) -> f32`

Computes (1 / (std * sqrt(2*pi))) * exp(-0.5 * ((x - mean) / std)^2).

```chelis-fragment
import Nautilus.Distributions (normal_pdf)

p = normal_pdf(cast(0.0, f32), cast(0.0, f32), cast(1.0, f32))  -- approximately 0.3989
```

## normal_cdf

**Signature:** `(x: f32, mean: f32, std: f32) -> f32`

Computes P(X <= x) via the error function: 0.5 * (1 + erf(z / sqrt(2)))
where z = (x - mean) / std.

```chelis-fragment
import Nautilus.Distributions (normal_cdf)

p = normal_cdf(cast(1.96, f32), cast(0.0, f32), cast(1.0, f32))  -- approximately 0.975
```

## normal_inv_cdf

**Signature:** `(q: f32, mean: f32, std: f32) -> f32`

Returns x such that normal_cdf(x, mean, std) = q. Uses the Acklam
rational approximation via `erfinv`, with separate branches for
central and tail regions.

- **Domain:** q in (0, 1)
- **At q = 0:** returns -inf
- **At q = 1:** returns +inf
- **Outside [0, 1]:** returns NaN

```chelis-fragment
import Nautilus.Distributions (normal_inv_cdf)

x = normal_inv_cdf(cast(0.975, f32), cast(0.0, f32), cast(1.0, f32))  -- approximately 1.96
```

## normal_sample

**Signature:** `[n](k: key, template: tensor[n, f32], mean: f32, std: f32) -> tensor[n, f32]`

Generates n samples from Normal(mean, std) using the Box-Muller
transform. The `template` tensor determines the output shape; its
values are ignored. The key is consumed and split for two uniform draws.

```chelis-fragment
import Nautilus.Distributions (normal_sample)

-- template shape determines output length
samples = normal_sample(key_from_seed(42i64), zeros, cast(0.0, f32), cast(1.0, f32))
```

## Edge cases

| Input | `normal_pdf` | `normal_cdf` | `normal_inv_cdf` |
|---|---|---|---|
| x = mean | 1/(std*sqrt(2*pi)) | 0.5 | mean |
| x = +inf | 0.0 | 1.0 | n/a |
| x = -inf | 0.0 | 0.0 | n/a |
| q = 0 | n/a | n/a | -inf |
| q = 1 | n/a | n/a | +inf |
| q outside [0,1] | n/a | n/a | NaN |
