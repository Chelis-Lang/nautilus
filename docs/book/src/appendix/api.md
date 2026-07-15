# API Reference

The full API surface for all Nautilus modules is maintained in
[SKILL.md, Section 6](https://github.com/Chelis-Lang/nautilus/blob/main/SKILL.md#6-api-surface).

That section contains signature tables for the active Nautilus surface,
arranged module by module. The 192 current rows comprise 185
numerical/library exports, 1 `Nautilus.Core.version` metadata helper, and 6
NaN-returning `Nautilus.Signal` stubs (`fftfreq` is functional).

- **Nautilus.Special** -- 21 special functions (erf, erfc, gamma, Bessel, Airy, elliptic integrals)
- **Nautilus.Distributions** -- 38 exports across 12 distribution families
- **Nautilus.LinAlg** -- 31 linear algebra operations (fixed-size and general-n)
- **Nautilus.Stats** -- 24 descriptive, adjustment, likelihood, and matrix-statistics helpers
- **Nautilus.Testing** -- 13 hypothesis-test helpers
- **Nautilus.Integrate** -- 8 quadrature methods
- **Nautilus.Distance** -- 8 distance metrics
- **Nautilus.Ode** -- 6 ODE solvers including adaptive endpoint and grid solvers
- **Nautilus.Optim** -- 4 scalar optimizers
- **Nautilus.Roots** -- 3 root-finders
- **Nautilus.Interpolation** -- 5 interpolation and spline operations
- **Nautilus.Sde** -- 2 stochastic ODE integrators
- **Nautilus.CurveFit** -- 2 Levenberg-Marquardt fitters
- **Nautilus.Signal** -- 7 exports: 6 stubs under the [Phase 3j explicit deferral](https://github.com/Chelis-Lang/nautilus/blob/main/spec/phase3j.md#explicit-deferrals), plus functional `fftfreq`
- **Nautilus.Info** -- 3 information measures
- **Nautilus.Optimize** -- 3 stable optimization/root wrapper and AD-smoke entries
- **Nautilus.StateSpace** -- 6 scalar Kalman and local-level helpers
- **Nautilus.TimeSeries** -- 7 smoothing and AR/ARMA/ARIMA forecast helpers
- **Nautilus.Core** -- 1 package-version metadata helper

Each table in SKILL.md includes the function name, full type signature,
row-level stability label, and implementation notes (domain
restrictions, precision, effect annotations). The same row-level
surface is emitted in machine-readable form at `dist/stability.json`.

For usage patterns and worked examples, see the module-specific chapters
in this book and the 15 patterns in SKILL.md Section 3.
