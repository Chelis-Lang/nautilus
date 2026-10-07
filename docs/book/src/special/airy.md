# Airy functions

The Airy functions Ai(x) and Bi(x) are solutions to the Airy
differential equation y'' - x*y = 0. They arise in quantum mechanics
(WKB approximation), optics (diffraction near caustics), and fluid
dynamics.

## airy_ai

**Signature:** `[prec: {f32, f64}](x: prec) -> prec`

Computes the Airy function of the first kind. For |x| <= 5, a
convergent power series in x^3 is used (up to 50 terms with early
termination at 1e-8 relative tolerance). For x > 5, an exponentially
decaying asymptotic form exp(-2/3 * x^(3/2)) / (2*sqrt(pi) * x^(1/4))
is used.

- **Domain:** all reals
- **Precision:** f32-grade at either dtype. Above x = 5 only the leading asymptotic term is used, so f64 gains nothing there; below it, f64 is substantially better.
- **Known limitation:** for large negative x (x < -5), only the power
  series is available. The oscillatory regime works for moderate |x|
  but degrades for very large negative x.

```chelis-fragment
import Nautilus.Special (airy_ai)

ai_0 = airy_ai(cast(0.0, f32))     -- approximately 0.3550
ai_1 = airy_ai(cast(1.0, f32))     -- approximately 0.1353
ai_neg = airy_ai(cast(-1.0, f32))  -- approximately 0.5356
```

## airy_bi

**Signature:** `[prec: {f32, f64}](x: prec) -> prec`

Computes the Airy function of the second kind. Uses the same power
series as Ai(x) for |x| <= 5, combined with a sqrt(3) scaling factor.
For x > 5, an exponentially growing asymptotic form
exp(2/3 * x^(3/2)) / (sqrt(pi) * x^(1/4)) is used.

- **Domain:** all reals
- **Precision:** f32-grade at either dtype above x = 5; see `airy_ai`.

```chelis-fragment
import Nautilus.Special (airy_bi)

bi_0 = airy_bi(cast(0.0, f32))     -- approximately 0.6149
bi_1 = airy_bi(cast(1.0, f32))     -- approximately 1.2074
```

## Edge cases

| Input | `airy_ai` | `airy_bi` |
|---|---|---|
| 0.0 | 0.3550 | 0.6149 |
| large positive | approaches 0 (exponential decay) | grows (exponential) |
| large negative | oscillates (series only) | oscillates (series only) |
| NaN | NaN | NaN |
