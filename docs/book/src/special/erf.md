# Error functions

Chelis provides correctly rounded `erf` and `erfc` builtins. Call them directly
without an import from Nautilus. They accept scalar or tensor inputs at the
active float dtypes. Nautilus provides `erfinv` for the inverse error function
at f32 and f64.

## erf

**Chelis builtin:** `erf(x)` preserves the input shape and dtype.

Computes the error function erf(x) = (2/sqrt(pi)) * integral(0, x, exp(-t^2) dt).
The function is odd: erf(-x) = -erf(x).

- **Domain:** all reals
- **Range:** [-1, 1] at finite precision; values round to the endpoints
  for sufficiently large magnitudes
- **Precision:** correctly rounded at f32 and f64

```chelis-fragment
val = erf(cast(0.5, f32))        -- approximately 0.5205
neg_val = erf(cast(-1.0, f32))   -- approximately -0.8427
```

## erfc

**Chelis builtin:** `erfc(x)` preserves the input shape and dtype.

Computes the complementary error function `erfc(x) = 1 - erf(x)` directly.
It keeps relative precision in the positive tail, where the subtraction
loses it.

- **Domain:** all reals
- **Range:** [0, 2] at finite precision; the result can round to either
  endpoint
- **Precision:** correctly rounded at f32 and f64

```chelis-fragment
tail = erfc(cast(2.0, f32))      -- approximately 0.0047
```

## erfinv

**Signature:** `[prec: {f32, f64}](x: prec) -> prec`

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
