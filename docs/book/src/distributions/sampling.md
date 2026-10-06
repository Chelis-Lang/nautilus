# Sampling with Explicit Keys

Nautilus provides sampling functions for seven distribution families.
Every sampling function takes an explicit `key` as its first argument and
a template tensor that determines the output shape.

## Explicit keys

Chelis random draws are pure functions of explicit keys. The same key and
inputs produce the same draw. A function that draws needs no randomness
effect annotation.

```chelis-fragment
-- A sampler takes a key and passes it on
def my_sampler[n](k: key, t: tensor[n, f32]) -> tensor[n, f32] =
  normal_sample(k, t, cast(0.0, f32), cast(1.0, f32))
```

Build a root key from a seed:

```chelis
module Nautilus.BookSampling
import Nautilus.Distributions (normal_sample)
export (draw_pair)
def draw_pair() -> tensor[2, f32] = {
  template = to_tensor([0.0f32, 0.0f32])
  normal_sample(key_from_seed(42i64), template, 0.0f32, 1.0f32)
}
```

Keys are affine: each key has at most one consuming use on every
control-flow path; a second consuming use of the same bound key is a type
error. Derive children for separate draws. Two fresh keys made from the same
seed intentionally replay the same draw. `split_key(k)` returns two child keys,
`split_keys(k, n)` returns `n` of them, and `fold_in(k, i)` derives the
child key of an integer.

```chelis-fragment
-- two independent draws from one key
ks = split_key(k)
a = normal_sample(ks.0, copy(template), cast(0.0, f32), cast(1.0, f32))
b = normal_sample(ks.1, template, cast(0.0, f32), cast(1.0, f32))
```

## Template tensors

Every sample function takes a `template: tensor[n, f32]` after its key. The template's shape determines how many samples are drawn.
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

samples = normal_sample(key_from_seed(42i64), template, cast(0.0, f32), cast(1.0, f32))
```

## Other sampling methods

| Distribution | Function | Current behavior |
|---|---|---|
| Uniform | `uniform_sample` | Direct scaling of uniform variates |
| Exponential | `exponential_sample` | Inverse CDF: -ln(u) / rate |
| LogNormal | `lognormal_sample` | exp(normal_sample(mu, sigma)) |
| Gamma | `gamma_sample` | Per-element keyed Marsaglia-Tsang trials for shape >= 1 |
| Chi-squared | `chi_squared_sample` | Gamma sample with shape df/2 and scale 2 for df >= 2 |
| Student-t | `student_t_sample` | Independent normal and chi-squared draws for df >= 2 |

## Signatures

```chelis-fragment
def uniform_sample[n](k: key, template: tensor[n, f32], lo: f32, hi: f32)
    -> tensor[n, f32]

def exponential_sample[n](k: key, template: tensor[n, f32], rate: f32)
    -> tensor[n, f32]

def normal_sample[n](k: key, template: tensor[n, f32], mean: f32, std: f32)
    -> tensor[n, f32]

def lognormal_sample[n](k: key, template: tensor[n, f32], mu: f32, sigma: f32)
    -> tensor[n, f32]

def gamma_sample[n](k: key, template: tensor[n, f32], shape: f32, scale: f32)
    -> tensor[n, f32]

def chi_squared_sample[n](k: key, template: tensor[n, f32], df: f32)
    -> tensor[n, f32]

def student_t_sample[n](k: key, template: tensor[n, f32], df: f32)
    -> tensor[n, f32]
```

## Sampling limits

- `uniform_like` is the internal Chelis primitive that generates raw
  uniform variates. It is not part of the Nautilus public API.
- `normal_sample` derives two child keys internally, one per Box-Muller
  uniform draw.
- `gamma_sample` supports finite shape >= 1 and positive finite scale.
  It derives a key for each element and 64 independent candidate keys per
  element. Each element takes its first accepted candidate. An element
  returns NaN if all 64 candidates reject.
- `chi_squared_sample` and `student_t_sample` require df >= 2 because
  they use `gamma_sample(df/2, 2)`. They inherit its rare exhausted-trial
  NaN result.
