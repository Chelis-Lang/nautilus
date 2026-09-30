# Sampling and the Random Effect

Nautilus provides sampling functions for seven distribution families.
All sampling functions carry the `! { Random }` effect and use a
template tensor to determine the output shape.

## The Random effect

In Chelis, side effects are tracked in the type system. Any function
that generates random values must declare `! { Random }` in its return
type. Callers must either handle the effect or propagate it.

```chelis-fragment
-- This function propagates the Random effect
def my_sampler[n](t: tensor[n, f32]) -> tensor[n, f32] ! { Random } =
  normal_sample(t, cast(0.0, f32), cast(1.0, f32))
```

To handle the effect, wrap the call in Chelis's `seed` handler. The same seed
gives the same draws:

```chelis-fragment
draws = with seed(42i64) { my_sampler(template) }
```

## Template tensors

Every sample function takes a `template: tensor[n, f32]` as its first
argument. The template's shape determines how many samples are drawn.
The actual values in the template are ignored. This pattern avoids
runtime integer-to-shape conversion, which Chelis's type system does
not support.

## Box-Muller transform (normal_sample)

`normal_sample` uses the Box-Muller transform to convert pairs of
uniform random variates into normally distributed samples. Given
u1 ~ Uniform(0,1) and u2 ~ Uniform(0,1):

```
z = sqrt(-2 * ln(u1)) * cos(2 * pi * u2)
result = mean + std * z
```

The implementation evaluates cos(2*pi*u2) as sin(pi/2 - 2*pi*u2) over the
whole tensor.

```chelis-fragment
import Nautilus.Distributions (normal_sample)

samples = normal_sample(template, cast(0.0, f32), cast(1.0, f32))
```

## Other sampling methods

| Distribution | Function | Current behavior |
|---|---|---|
| Uniform | `uniform_sample` | Direct scaling of uniform variates |
| Exponential | `exponential_sample` | Inverse CDF: -ln(u) / rate |
| LogNormal | `lognormal_sample` | exp(normal_sample(mu, sigma)) |
| Gamma | `gamma_sample` | Constant tensor for shape >= 1; see limits below |
| Chi-squared | `chi_squared_sample` | Constant tensor via `gamma_sample(df/2, 2)` |
| Student-t | `student_t_sample` | Normal draw divided by a constant, not a Student-t draw |

## Signatures

```chelis-fragment
def uniform_sample[n](template: tensor[n, f32], lo: f32, hi: f32)
    -> tensor[n, f32] ! { Random }

def exponential_sample[n](template: tensor[n, f32], rate: f32)
    -> tensor[n, f32] ! { Random }

def normal_sample[n](template: tensor[n, f32], mean: f32, std: f32)
    -> tensor[n, f32] ! { Random }

def lognormal_sample[n](template: tensor[n, f32], mu: f32, sigma: f32)
    -> tensor[n, f32] ! { Random }

def gamma_sample[n](template: tensor[n, f32], shape: f32, scale: f32)
    -> tensor[n, f32] ! { Random }

def chi_squared_sample[n](template: tensor[n, f32], df: f32)
    -> tensor[n, f32] ! { Random }

def student_t_sample[n](template: tensor[n, f32], df: f32)
    -> tensor[n, f32] ! { Random }
```

## Sampling limits

- `gamma_sample` requires shape >= 1. Its current acceptance step discards
  the generated random values. For finite shape >= 1 and positive finite
  scale, every element equals `(shape - 1/3) * scale` regardless of the
  seed. Do not use it to sample a gamma distribution.
- `chi_squared_sample` uses `gamma_sample`, and `student_t_sample` uses
  `chi_squared_sample`. The chi-squared result is a constant tensor, and
  the Student-t result uses a constant denominator instead of a
  chi-squared draw. Do not use either function for those distributions.
  They need df >= 2 to meet the gamma sampler's shape requirement.
- `uniform_sample`, `exponential_sample`, `normal_sample`, and
  `lognormal_sample` generate a tensor of draws from the Chelis random
  stream. The `seed` handler makes that stream reproducible.
