# Special Functions

`Nautilus.Special` provides the mathematical special functions that
underlie probability distributions, physics simulations, and
numerical analysis. The module exposes the families listed below;
the [precision guide](../appendix/precision.md) describes their accuracy.

All functions are pure (no effects). Differentiability via `grad` is **not**
uniform across the module, and two separate limits apply.

First, `grad` needs a function whose dtype is already fixed. When needed, wrap
the Chelis `erf` builtin in a concrete-dtype definition:

```chelis-fragment
def erf_at(x: f64) -> f64 = erf(x)
def d_erf(x: f64) -> f64 = grad(erf_at)(x)
```

Second, only nine of the nineteen scalar Nautilus exports differentiate even
when wrapped: `erfinv` and the eight `bessel_*`. The other ten (`gamma`, `log_gamma`, `digamma`,
`trigamma`, `beta`, `lbeta`, `ellipk`, `ellipe`, `airy_ai`, `airy_bi`) fail
at lowering, because their bodies recurse or reach a primitive with no
reverse-mode adjoint.

Unlike the rest of Nautilus, its twenty special-function exports have an
explicit **`{f32, f64}` dtype-set bound**:

```chelis-fragment
import Nautilus.Special (erfinv)
def narrow(x: f32) -> f32 = erfinv(x)
def wide(x: f64) -> f64 = erfinv(x)
```

The bound rejects `f16` and `bf16` at checking. Their f32-tuned coefficients
could otherwise yield misleading values, so the accepted precisions are
exactly f32 and f64 (nautilus#75).

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
- `erf(x)`, `erfc(x)`: correctly rounded Chelis builtins; no import required
- `erfinv(x)`: inverse error function for x in (-1, 1), ~1e-8

### Gamma-related
- `gamma(x)`: the gamma function via Lanczos + reflection, +inf at non-positive integers
- `log_gamma(x)`: log of the gamma function (Lanczos, g=7), ~1e-9
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
