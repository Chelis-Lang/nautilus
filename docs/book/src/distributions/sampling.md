# Sampling with Explicit Keys

Nautilus provides sampling functions for seven distribution families.
Every sampling function takes an explicit `key` as its first argument and
a template tensor that determines the output shape.

## Explicit keys

Chelis has no randomness effect. A random draw takes a key, and the key
determines the draw, so reproducibility is a property of the value you pass
rather than of an enclosing handler (`spec/02` §P5a).

```chelis-fragment
-- A sampler takes a key and passes it on
def my_sampler[n](k: key, t: tensor[n, f32]) -> tensor[n, f32] =
  normal_sample(k, t, cast(0.0, f32), cast(1.0, f32))
```

Build a root key from a seed. This complete module checks with a compiler
that supports explicit keys:

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
| Gamma | `gamma_sample` | Constant tensor; see #84 below |
| Chi-squared | `chi_squared_sample` | Constant tensor via gamma_sample(df/2, 2) |
| Student-t | `student_t_sample` | Normal draw divided by a constant |

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

## Notes

- `uniform_like` is the internal Chelis primitive that generates raw
  uniform variates. It is not part of the Nautilus public API.
- `gamma_sample` requires shape >= 1. No sampler covers shape < 1.
- Reproducibility comes from the key you pass, not from an enclosing
  handler and not from a Nautilus-level API.
- `normal_sample` derives two child keys internally, one per Box-Muller
  uniform draw.
- **`gamma_sample` does not use its drawn noise.** At finite shape >= 1
  and positive finite scale, every output element equals
  `(shape - 1/3) * scale` regardless of key. `chi_squared_sample` inherits
  a constant result; `student_t_sample` divides a normal draw by a constant.
  They do not sample their stated distributions. See
  [nautilus#84](https://github.com/Chelis-Lang/nautilus/issues/84).
