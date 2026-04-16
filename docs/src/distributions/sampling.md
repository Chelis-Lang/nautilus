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

The implementation computes cos(2*pi*u2) via the identity
sin(pi/2 - 2*pi*u2). (As of v0.1.7, `cos` is a builtin, but the
existing implementation predates that and works correctly.)

```chelis-fragment
import Nautilus.Distributions (normal_sample)

samples = normal_sample(template, cast(0.0, f32), cast(1.0, f32))
```

## Other sampling methods

| Distribution | Function | Method |
|---|---|---|
| Uniform | `uniform_sample` | Direct scaling of uniform variates |
| Exponential | `exponential_sample` | Inverse CDF: -ln(u) / rate |
| LogNormal | `lognormal_sample` | exp(normal_sample(mu, sigma)) |
| Gamma | `gamma_sample` | Marsaglia-Tsang (shape >= 1) |
| Chi-squared | `chi_squared_sample` | Via gamma_sample(df/2, 2) |
| Student-t | `student_t_sample` | Normal(0,1) / sqrt(ChiSq(df)/df) |

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

## Notes

- `uniform_like` is the internal Chelis primitive that generates raw
  uniform variates. It is not part of the Nautilus public API.
- `gamma_sample` requires shape >= 1. For shape < 1, no sampling
  function is currently provided.
- All sample functions draw independent samples. There is no
  correlation structure or seeding API exposed at the Nautilus level.
