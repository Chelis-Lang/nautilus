# Gamma-Related Functions

Six functions related to the gamma function: the gamma function itself,
its log, its first and second derivatives (digamma, trigamma), and the
beta function in both regular and log forms.

## gamma

**Signature:** `[prec: Float](x: prec) -> prec`

Computes the gamma function `Gamma(x)` using the Lanczos approximation
with `g=7` and 8-term series. For `x < 0.5`, the reflection formula
`Gamma(x) = pi / (sin(pi x) * Gamma(1 - x))` is applied, sharing the
same Lanczos-sum core that `log_gamma` uses.

- **Domain:** all reals except non-positive integers
- **Precision:** ~1e-7 relative at f32. This one is bounded by f32 rounding, not by the Lanczos coefficients, so it reaches f64 grade when called at f64.
- **At non-positive integers:** returns +inf (poles)

```chelis-fragment
import Nautilus.Special (gamma)

g5 = gamma(cast(5.0, f32))   -- 4! = 24
```

If you need the log-magnitude only (for very small or very large `x`
where `Gamma(x)` would underflow or overflow), prefer `log_gamma`.

## log_gamma

**Signature:** `[prec: Float](x: prec) -> prec`

Computes ln(Gamma(x)) using the Lanczos approximation with g=7 and
8-term series. For x < 0.5, the reflection formula via sin(pi*x) is
applied.

- **Domain:** all reals except non-positive integers
- **Precision:** ~1e-9 relative at f32; f64 grade when called at f64
- **At non-positive integers:** returns +inf

```chelis-fragment
import Nautilus.Special (log_gamma)

lg5 = log_gamma(cast(5.0, f32))   -- ln(24) = approximately 3.1781
```

## digamma

**Signature:** `[prec: Float](x: prec) -> prec`

Computes the digamma (psi) function, the logarithmic derivative of the
gamma function. Uses upward recurrence to shift x >= 6, then applies
an asymptotic expansion.

- **Domain:** all reals except non-positive integers
- **Precision:** ~1e-7 relative
- **At non-positive integers:** returns NaN

```chelis-fragment
import Nautilus.Special (digamma)

psi1 = digamma(cast(1.0, f32))    -- -0.5772 (negative Euler-Mascheroni)
```

## trigamma

**Signature:** `[prec: Float](x: prec) -> prec`

Computes the trigamma function, the derivative of digamma. Uses the same
recurrence-then-asymptotic strategy with threshold at x >= 6.

- **Domain:** x > 0 (returns NaN for x <= 0)
- **Precision:** ~1e-6 relative

```chelis-fragment
import Nautilus.Special (trigamma)

tg1 = trigamma(cast(1.0, f32))    -- pi^2/6 = approximately 1.6449
```

## beta

**Signature:** `[prec: Float](a: prec, b: prec) -> prec`

Computes the beta function B(a, b) = Gamma(a) * Gamma(b) / Gamma(a+b)
as exp(lbeta(a, b)).

- **Domain:** a > 0, b > 0 (NaN otherwise)

```chelis-fragment
import Nautilus.Special (beta)

b23 = beta(cast(2.0, f32), cast(3.0, f32))  -- 1/12 = approximately 0.0833
```

## lbeta

**Signature:** `[prec: Float](a: prec, b: prec) -> prec`

Computes ln(B(a, b)) = log_gamma(a) + log_gamma(b) - log_gamma(a+b).
Preferred over `beta` when the result would overflow or underflow in
linear scale.

- **Domain:** a > 0, b > 0 (NaN otherwise)

```chelis-fragment
import Nautilus.Special (lbeta)

lb = lbeta(cast(2.0, f32), cast(3.0, f32))  -- ln(1/12) = approximately -2.485
```

## Edge cases

| Input | Result |
|---|---|
| `log_gamma(0.0)` | +inf (pole) |
| `log_gamma(-1.0)` | +inf (non-positive integer) |
| `digamma(0.0)` | NaN |
| `digamma(-2.0)` | NaN |
| `trigamma(-1.0)` | NaN |
| `beta(0, 1)` | NaN |
| `lbeta(-1, 2)` | NaN |
