# Error Functions

The error function and its inverse are the building blocks for normal
distribution CDF/inverse-CDF computations. All three are pure scalar
functions with no effects, generic over the `Float` family, so they can be
called at f32 or f64.

`erf` gains least of all from f64: its coefficients cap it near 1.4e-7 at f64,
where f32 reaches 4.4e-7, so the dtype buys a factor of three rather than the
orders of magnitude it buys elsewhere in the module. `erfc` is the opposite and
gains a working tail -- at f32 it underflows to exactly 0 from about x = 3.92, and at
f64 it keeps returning values to about x = 5.5. See the
[precision guide](../appendix/precision.md).

## erf

**Signature:** `[prec: Float](x: prec) -> prec`

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

## erfc

**Signature:** `[prec: Float](x: prec) -> prec`

Computes the complementary error function `erfc(x) = 1 - erf(x)`. Implemented
as a one-line subtraction off `erf`, so it shares `erf`'s precision and domain.
Prefer `erfc` over `1 - erf(x)` only when you would otherwise lose significant
digits in the subtraction (large positive `x`, where `erf(x)` is close to 1).

- **Domain:** all reals
- **Range:** (0, 2)
- **Precision:** ~1e-7 relative (inherits `erf`'s tolerance)

```chelis-fragment
import Nautilus.Special (erfc)

tail = erfc(cast(2.0, f32))      -- approximately 0.0047
```

## erfinv

**Signature:** `[prec: Float](x: prec) -> prec`

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

| Input | `erf` result | `erfc` result | `erfinv` result |
|---|---|---|---|
| 0.0 | 0.0 | 1.0 | 0.0 |
| +large | approaches 1.0 | approaches 0.0 | n/a (outside domain) |
| -large | approaches -1.0 | approaches 2.0 | n/a (outside domain) |
| NaN | NaN | NaN | NaN |
| 1.0 | n/a | n/a | +inf |
| -1.0 | n/a | n/a | -inf |
