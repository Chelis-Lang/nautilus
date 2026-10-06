# Distributions

`Nautilus.Distributions` provides functions for 12 probability distribution
families. The table shows which operations each family exposes.

## Distribution families

| Distribution | PDF | CDF | Survival | Inverse CDF | Sample |
|---|---|---|---|---|---|
| Normal | `normal_pdf` | `normal_cdf` | | `normal_inv_cdf` | `normal_sample` |
| LogNormal | `lognormal_pdf` | `lognormal_cdf` | | `lognormal_inv_cdf` | `lognormal_sample` |
| Uniform | `uniform_pdf` | `uniform_cdf` | | `uniform_inv_cdf` | `uniform_sample` |
| Exponential | `exponential_pdf` | `exponential_cdf` | | `exponential_inv_cdf` | `exponential_sample` |
| Gamma | `gamma_pdf` | `gamma_cdf` | `gamma_sf` | `gamma_inv_cdf` | `gamma_sample` |
| Chi-squared | `chi_squared_pdf` | `chi_squared_cdf` | `chi_squared_sf` | `chi_squared_inv_cdf` | `chi_squared_sample` |
| Student-t | `student_t_pdf` | `student_t_cdf` | | | `student_t_sample` |
| Poisson | `poisson_pmf` | `poisson_cdf` | | | |
| Binomial | `binomial_pmf` | `binomial_cdf` | | | |
| Beta | `beta_pdf` | `beta_cdf` | | | |
| F | `f_pdf` | `f_cdf` | | | |
| Weibull | `weibull_pdf` | `weibull_cdf` | | `weibull_inv_cdf` | |

Only the gamma family carries a survival function. For the others, take the
upper tail from the symmetry of the distribution where it has one, and never as
`1 - cdf`, which loses the whole tail to `0.5 * ulp(1.0)`:

- Standard normal: `normal_cdf(neg(z), 0, 1)` is the exact upper tail at `z`.
- Student-t: `student_t_cdf(neg(t), df)` is the exact upper tail at `t`, for
  every `df`, because the distribution is symmetric about zero. (Symmetric, not
  merely centred -- at `df <= 1` the mean does not exist and the identity still
  holds.)
- A **non-standard** normal needs the mean reflected too, not just the point:
  the upper tail of `N(mu, sigma)` at `x` is `Phi((mu - x) / sigma)`, so write
  `normal_cdf(neg(x), neg(mean), std)`. Negating only the point gives
  `Phi((-x - mu) / sigma)`, which is a different number entirely -- for
  `N(10, 2)` at `x = 13` it returns `6.6e-31` where the answer is `0.0668`.

See [Right-tail accuracy](../stats/testing.md#right-tail-accuracy).

## Parameter conventions

- Normal: `(x, mean, std)`, even for the standard normal
- Gamma: `(x, shape, scale)`, SciPy's convention, not `(x, shape, rate)`
- Exponential: `(x, rate)`, unlike SciPy's `scale = 1/rate`
- Chi-squared: `(x, df)` where df is degrees of freedom
- Student-t: `(x, df)`
- Poisson: `(k, lambda)` where k is the count
- Binomial: `(k, n, p)` where n is trials and p is probability
- Beta: `(x, a, b)` where a, b are shape parameters
- F: `(x, d1, d2)`
- Weibull: `(x, shape, scale)`

## Sampling with explicit keys

The seven `_sample` functions take a `key` as their first argument:

```chelis-fragment
def normal_sample[n](k: key, template: tensor[n, f32], mean: f32, std: f32) -> tensor[n, f32]
```

The `template` tensor determines the output shape. The actual values
in the template are ignored; only its shape is used. See
[Sampling with Explicit Keys](sampling.md) for key derivation, methods,
and the gamma, chi-squared, and Student-t sampling limits.

## Imports

```chelis-fragment
import Nautilus.Distributions (normal_pdf, normal_cdf, normal_inv_cdf)
import Nautilus.Distributions (gamma_cdf, student_t_cdf, chi_squared_cdf)
import Nautilus.Distributions (poisson_cdf, binomial_cdf, beta_cdf)
```

## Common usage

The most frequently used functions are `normal_cdf` and `normal_inv_cdf`,
which appear in Black-Scholes pricing, Value-at-Risk computation, and
hypothesis testing. `gamma_cdf` and `student_t_cdf` underpin chi-squared
and t-test p-values through the `Nautilus.Testing` module.
