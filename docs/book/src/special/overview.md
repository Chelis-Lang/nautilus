# Special Functions

`Nautilus.Special` provides the mathematical special functions that
underlie probability distributions, physics simulations, and
numerical analysis. It replaces `scipy.special` for Chelis programs.

All functions are pure (no effects), operate on f32 scalars, and are
safe to differentiate via `grad`.

## Imports

```chelis-fragment
import Nautilus.Special (erf, erfc, erfinv, gamma, log_gamma, digamma, trigamma, beta, lbeta)
import Nautilus.Special (bessel_j0, bessel_j1, bessel_y0, bessel_y1)
import Nautilus.Special (bessel_i0, bessel_i1, bessel_k0, bessel_k1)
import Nautilus.Special (airy_ai, airy_bi, ellipk, ellipe)
```

## Function families

### Error functions
- `erf(x)`: the error function, ~1e-7 relative precision
- `erfc(x)`: complementary error function `1 - erf(x)`, same precision domain as `erf`
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
