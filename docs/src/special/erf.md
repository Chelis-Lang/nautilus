# Error Functions

The error function and its inverse are the building blocks for normal
distribution CDF/inverse-CDF computations. Both are pure f32 scalar
functions with no effects.

## erf

**Signature:** `(x: f32) -> f32`

Computes the error function erf(x) = (2/sqrt(pi)) * integral(0, x, exp(-t^2) dt).
Uses the Abramowitz & Stegun rational (Horner) approximation with a linear
fallback for |x| < 1e-5. The function is odd: erf(-x) = -erf(x).

- **Domain:** all reals
- **Range:** (-1, 1)
- **Precision:** ~1e-7 relative

```chelis-fragment
import Nautilus.Special (erf)

val = erf(cast(0.5, f32))        -- approximately 0.5205
neg_val = erf(cast(-1.0, f32))   -- approximately -0.8427
```

## erfinv

**Signature:** `(x: f32) -> f32`

Computes the inverse error function: if y = erf(x), then x = erfinv(y).
Internally delegates to the Acklam rational approximation of the normal
inverse CDF, then rescales by 1/sqrt(2).

- **Domain:** (-1, 1) strictly; values at or beyond the boundary produce inf/NaN
- **Precision:** ~1e-8 relative

```chelis-fragment
import Nautilus.Special (erfinv)

x = erfinv(cast(0.5, f32))      -- approximately 0.4769
```

## Edge cases

| Input | `erf` result | `erfinv` result |
|---|---|---|
| 0.0 | 0.0 | 0.0 |
| +large | approaches 1.0 | n/a (outside domain) |
| -large | approaches -1.0 | n/a (outside domain) |
| NaN | NaN | NaN |
| 1.0 | n/a | +inf |
| -1.0 | n/a | -inf |
