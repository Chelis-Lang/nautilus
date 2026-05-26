# Greeks via Automatic Differentiation

Chelis supports `grad` as a language primitive. Because `black_scholes_call`
is a composition of differentiable Chelis primitives and library functions
(no FFI, no opaque runtime calls), `grad` can differentiate through it
to produce option Greeks.

## The composition pattern

```chelis-fragment
import Nautilus.Distributions (normal_cdf)

// Delta: dC/dS
def bs_delta(s: f32, k: f32, r: f32, sigma: f32, t: f32) -> f32 =
  grad(fn (s_: f32) -> black_scholes_call(s_, k, r, sigma, t))(s)

// Vega: dC/d(sigma)
def bs_vega(s: f32, k: f32, r: f32, sigma: f32, t: f32) -> f32 =
  grad(fn (sig: f32) -> black_scholes_call(s, k, r, sig, t))(sigma)

// Theta: -dC/dT (negative by convention)
def bs_theta(s: f32, k: f32, r: f32, sigma: f32, t: f32) -> f32 =
  neg(grad(fn (t_: f32) -> black_scholes_call(s, k, r, sigma, t_))(t))

// Rho: dC/dr
def bs_rho(s: f32, k: f32, r: f32, sigma: f32, t: f32) -> f32 =
  grad(fn (r_: f32) -> black_scholes_call(s, k, r_, sigma, t))(r)
```

Each Greek is computed by closing over the other parameters and
differentiating with respect to the one of interest.

## Gamma (second derivative)

```chelis-fragment
// Gamma: d^2 C / dS^2
def bs_gamma(s: f32, k: f32, r: f32, sigma: f32, t: f32) -> f32 =
  grad(fn (s_: f32) ->
    grad(fn (s__: f32) -> black_scholes_call(s__, k, r, sigma, t))(s_)
  )(s)
```

Nested `grad` calls produce higher-order derivatives. This works at the
type level in Chelis because `grad` returns a function of the same type.

## Current status: aspirational

This chapter describes a pattern that **type-checks** in Chelis today.
`grad` through composed scalar functions works at the type level, and the
evaluator (`chelis eval`) handles simple cases.

However, **runtime AD through the bare-build C backend path is not yet
verified** for compositions as deep as Black-Scholes. The bare-build
test harness concatenates modules into a single C translation unit and
does not exercise the AD system at runtime. Verifying that `grad` through
`normal_cdf` (which calls `erf`, which uses a Horner rational
approximation) produces correct numerical derivatives at runtime is a
future validation step.

The expected values for an ATM call (S=K=100, r=5%, sigma=20%, T=1y) are:

| Greek | Expected (f64 reference) |
|---|---|
| Delta | ~0.6368 |
| Vega | ~37.52 |
| Theta | ~-6.41 (annualized) |
| Gamma | ~0.0188 |

These can be cross-checked against finite differences once the runtime
AD path is validated.
