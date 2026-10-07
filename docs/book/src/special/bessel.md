# Bessel functions

Eight Bessel functions covering orders 0 and 1 for all four kinds: J
(first kind), Y (second kind), I (modified first kind), and K (modified
second kind). All use polynomial or rational approximations with
separate small-argument and large-argument branches.

## First kind: bessel_j0, bessel_j1

**Signatures:** `[prec: {f32, f64}](x: prec) -> prec`

J0 is even; J1 is odd. For |x| < 8, a rational polynomial in x^2 is
used. For |x| >= 8, an asymptotic trigonometric form sqrt(2/(pi*x)) *
cos/sin(...) is used. Near function zeros, compare absolute errors;
relative error divides by a value approaching zero.

```chelis-fragment
import Nautilus.Special (bessel_j0, bessel_j1)

j0_0 = bessel_j0(cast(0.0, f32))    -- 1.0
j1_0 = bessel_j1(cast(0.0, f32))    -- 0.0
j0_5 = bessel_j0(cast(5.0, f32))    -- approximately -0.1776
j1_5 = bessel_j1(cast(5.0, f32))    -- approximately -0.3276
```

## Second kind: bessel_y0, bessel_y1

**Signatures:** `[prec: {f32, f64}](x: prec) -> prec`

Defined for x > 0 only. For x < 8, a rational polynomial with a
log-singularity term involving J0/J1 is used. For x >= 8, the same
asymptotic trigonometric form as J0/J1 applies.

- **Domain:** x > 0
- **At x = 0:** returns -inf
- **For x < 0:** returns NaN
- `bessel_y1` switches to the large-x branch at `x >= 7.5` rather than 8.
  Just below that seam, around x = 7.4, its absolute error is about 1.2e-4
  at either dtype. Relative error also grows near zeros, as expected for
  rational approximations.

```chelis-fragment
import Nautilus.Special (bessel_y0, bessel_y1)

y0_1 = bessel_y0(cast(1.0, f32))    -- approximately 0.0883
y1_1 = bessel_y1(cast(1.0, f32))    -- approximately -0.7812
```

## Modified first kind: bessel_i0, bessel_i1

**Signatures:** `[prec: {f32, f64}](x: prec) -> prec`

I0 is even; I1 is odd. For |x| < 3.75, a polynomial in (x/3.75)^2 is
used. For |x| >= 3.75, an asymptotic form exp(|x|)/sqrt(|x|) * poly
is used.

```chelis-fragment
import Nautilus.Special (bessel_i0, bessel_i1)

i0_0 = bessel_i0(cast(0.0, f32))    -- 1.0
i1_0 = bessel_i1(cast(0.0, f32))    -- 0.0
i0_2 = bessel_i0(cast(2.0, f32))    -- approximately 2.2796
```

## Modified second kind: bessel_k0, bessel_k1

**Signatures:** `[prec: {f32, f64}](x: prec) -> prec`

Defined for x > 0 only. For x <= 2, a polynomial with a log term
involving I0/I1 is used. For x > 2, an asymptotic form
exp(-x)/sqrt(x) * poly is used.

- **Domain:** x > 0
- **At x = 0:** returns +inf
- **For x < 0:** returns NaN

```chelis-fragment
import Nautilus.Special (bessel_k0, bessel_k1)

k0_1 = bessel_k0(cast(1.0, f32))    -- approximately 0.4211
k1_1 = bessel_k1(cast(1.0, f32))    -- approximately 0.6019
```

## Edge cases

| Function | x = 0 | x < 0 | x = NaN |
|---|---|---|---|
| `bessel_j0` | 1.0 | J0(\|x\|) (even) | NaN |
| `bessel_j1` | 0.0 | -J1(\|x\|) (odd) | NaN |
| `bessel_y0` | -inf | NaN | NaN |
| `bessel_y1` | -inf | NaN | NaN |
| `bessel_i0` | 1.0 | I0(\|x\|) (even) | NaN |
| `bessel_i1` | 0.0 | -I1(\|x\|) (odd) | NaN |
| `bessel_k0` | +inf | NaN | NaN |
| `bessel_k1` | +inf | NaN | NaN |
