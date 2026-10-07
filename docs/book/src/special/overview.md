# Special functions

`Nautilus.Special` provides inverse error, gamma, Bessel, Airy, and elliptic
functions. The [precision guide](../appendix/precision.md)
describes their accuracy.

All functions are pure, with no effects.

The twenty exports use the dtype bound `{f32, f64}`, so `erfinv`
accepts f32 and f64 inputs:

```chelis-fragment
import Nautilus.Special (erfinv)
def narrow(x: f32) -> f32 = erfinv(x)
def wide(x: f64) -> f64 = erfinv(x)
```

The dtype bound excludes `f16` and `bf16`. Calling these functions with
half-precision inputs is a type error, not an approximate calculation.

A single call still uses one dtype throughout: `beta(a: f32, b: f64)` is a
precision mismatch, not an implicit promotion. Generic signatures also do
not promise f64 accuracy for every Nautilus approximation.
See the [precision guide](../appendix/precision.md).

## Imports

```chelis-fragment
import Nautilus.Special (erfinv, gamma, log_gamma, digamma, trigamma, beta, lbeta)
import Nautilus.Special (bessel_j0, bessel_j1, bessel_y0, bessel_y1)
import Nautilus.Special (bessel_i0, bessel_i1, bessel_k0, bessel_k1)
import Nautilus.Special (airy_ai, airy_bi, ellipk, ellipe)
```

## Function families

### Error functions

- `erf(x)`, `erfc(x)`: correctly rounded Chelis builtins with no import
  required. See [Error functions](erf.md).
- `erfinv(x)`: inverse error function for x in (-1, 1), ~1e-8

### Gamma-related

- `gamma(x)`: the gamma function via Lanczos + reflection, +inf at non-positive integers
- `log_gamma(x)`: log of the magnitude of the gamma function (Lanczos, g=7), ~1e-9
- `digamma(x)`: psi function (derivative of log_gamma), ~1e-7
- `trigamma(x)`: derivative of digamma, ~1e-6
- `beta(a, b)`: the beta function B(a, b) = Gamma(a)Gamma(b)/Gamma(a+b)
- `lbeta(a, b)`: log of the beta function

### Bessel functions

- `bessel_j0(x)`, `bessel_j1(x)`: Bessel functions of the first kind (all reals, J0 even, J1 odd)
- `bessel_y0(x)`, `bessel_y1(x)`: Bessel functions of the second kind (x > 0, -inf at 0)
- `bessel_i0(x)`, `bessel_i1(x)`: modified Bessel, first kind (all reals)
- `bessel_k0(x)`, `bessel_k1(x)`: modified Bessel, second kind (x > 0, +inf at 0)

### Airy functions

- `airy_ai(x)`: Airy Ai (power series for |x| <= 5, asymptotic for x > 5)
- `airy_bi(x)`: Airy Bi

### Elliptic integrals

- `ellipk(m)`: complete elliptic integral of the first kind, m in [0, 1)
- `ellipe(m)`: complete elliptic integral of the second kind, m in [0, 1]

Both use the arithmetic-geometric mean (AGM) recurrence, which
converges quadratically in about 10 iterations.

## Differentiation

`grad` needs a function with a fixed floating type, so wrap a generic export
in a concrete definition before differentiating it. Calling `grad(erfinv)`
directly fails to type-check with `grad requires a scalar floating output`.

```chelis-fragment
import Nautilus.Special (erfinv, bessel_j0)

def erfinv_at(x: f64) -> f64 = erfinv(x)
def j0_at(x: f64) -> f64 = bessel_j0(x)
d_erfinv = grad(erfinv_at)(0.5f64)
d_j0 = grad(j0_at)(0.5f64)
```

```text
d_erfinv = 1.1125848087047903
d_j0 = -0.2422684661906818
```

`erfinv` and the eight `bessel_*` functions differentiate. The others do
not: `gamma`, `log_gamma`, `digamma`, `trigamma`, `beta`, `lbeta`, `ellipk`,
`ellipe`, `airy_ai`, and `airy_bi` reach a primitive with no derivative or
recurse a run-time number of times, and `grad` fails when it is lowered. For
`gamma` the error is `grad: cast_trunc is non-differentiable`. Where you need
the derivative of one of these, use its closed form: the derivative of
`log_gamma` is `digamma`, and the derivative of `digamma` is `trigamma`.
