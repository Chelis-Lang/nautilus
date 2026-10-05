# Complete Elliptic Integrals

The complete elliptic integrals of the first and second kind, K(m) and
E(m), arise in pendulum motion, magnetic field calculations, and
conformal mapping. Both are computed via the arithmetic-geometric mean
(AGM) recurrence, which converges quadratically in about 10 iterations.

## ellipk

**Signature:** `[prec: {f32, f64}](m: prec) -> prec`

Computes the complete elliptic integral of the first kind,
K(m) = integral(0, pi/2, dt / sqrt(1 - m*sin^2(t))).
Uses K(m) = pi / (2 * AGM(1, sqrt(1-m))).

- **Domain:** m in [0, 1)
- **At m = 1:** returns +inf (logarithmic singularity)
- **Outside [0, 1]:** returns NaN
- **Precision:** ~1e-8 relative at f32. The AGM converges to whatever width it is given, so this reaches f64 grade when called at f64.

```chelis-fragment
import Nautilus.Special (ellipk)

k0 = ellipk(cast(0.0, f32))       -- pi/2 = approximately 1.5708
k_half = ellipk(cast(0.5, f32))   -- approximately 1.8541
```

## ellipe

**Signature:** `[prec: {f32, f64}](m: prec) -> prec`

Computes the complete elliptic integral of the second kind,
E(m) = integral(0, pi/2, sqrt(1 - m*sin^2(t)) dt).
Uses the AGM recurrence with an accumulated sum of squared differences.

- **Domain:** m in [0, 1]
- **At m = 0:** returns pi/2
- **At m = 1:** returns 1.0
- **Outside [0, 1]:** returns NaN
- **Precision:** ~1e-8 relative at f32. The AGM converges to whatever width it is given, so this reaches f64 grade when called at f64.

```chelis-fragment
import Nautilus.Special (ellipe)

e0 = ellipe(cast(0.0, f32))       -- pi/2 = approximately 1.5708
e_half = ellipe(cast(0.5, f32))   -- approximately 1.3506
e1 = ellipe(cast(1.0, f32))       -- 1.0
```

## Edge cases

| Input m | `ellipk` | `ellipe` |
|---|---|---|
| 0.0 | pi/2 | pi/2 |
| 1.0 | +inf | 1.0 |
| negative | NaN | NaN |
| > 1.0 | NaN | NaN |
| NaN | NaN | NaN |
