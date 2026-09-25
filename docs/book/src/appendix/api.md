# API Reference

The full API surface for all Nautilus modules is maintained in
[SKILL.md, Section 6](https://github.com/Chelis-Lang/nautilus/blob/main/SKILL.md#6-api-surface).

That section has one signature table per module. Nautilus exports 204
functions: 197 numerical functions, the `Nautilus.Core.version` metadata
helper, and six NaN-returning `Nautilus.Signal` placeholders.

- **Nautilus.Special** -- 23 special functions (erf, erfc, erfinv and their tensor forms, gamma family, Bessel, Airy, elliptic integrals), generic over the `Float` dtype family
- **Nautilus.Distributions** -- 41 exports across 12 distribution families
- **Nautilus.LinAlg** -- 34 linear algebra operations (fixed-size and general-n)
- **Nautilus.Stats** -- 28 descriptive, adjustment, likelihood, and matrix-statistics helpers
- **Nautilus.Testing** -- 13 hypothesis-test helpers
- **Nautilus.Integrate** -- 8 quadrature methods
- **Nautilus.Distance** -- 8 distance metrics
- **Nautilus.Ode** -- 6 ODE solvers including adaptive endpoint and grid solvers
- **Nautilus.Optim** -- 4 scalar optimizers
- **Nautilus.Roots** -- 3 root-finders
- **Nautilus.Interpolation** -- 5 interpolation and spline operations
- **Nautilus.Sde** -- 2 stochastic ODE integrators
- **Nautilus.CurveFit** -- 2 Levenberg-Marquardt fitters
- **Nautilus.Signal** -- 7 exports: `fftfreq`, plus 6 stubs [deferred until Chelis supports complex numbers](https://github.com/Chelis-Lang/nautilus/blob/main/spec/scope.md#deferrals)
- **Nautilus.Info** -- 3 information measures
- **Nautilus.Optimize** -- 3 entries: bracketed `minimize` and `root` wrappers and an AD smoke target
- **Nautilus.StateSpace** -- 6 scalar Kalman and local-level helpers
- **Nautilus.TimeSeries** -- 7 smoothing and AR/ARMA/ARIMA forecast helpers
- **Nautilus.Core** -- 1 package-version metadata helper

Each table in SKILL.md includes the function name, full type signature,
row-level stability label, and implementation notes (domain
restrictions, precision, effect annotations). The same row-level
surface is emitted in machine-readable form at `dist/stability.json`.

For worked examples, see the module chapters in this book and the core
patterns in SKILL.md Section 3.
