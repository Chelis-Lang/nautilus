# API Reference

The full API surface for all Nautilus modules is maintained in
[SKILL.md, Section 6](https://github.com/Chelis-Lang/nautilus/blob/main/SKILL.md#6-api-surface).

That section contains signature tables for all 153 non-stub exports
across 14 modules:

- **Nautilus.Special** -- 19 special functions (erf, Bessel, Airy, elliptic integrals)
- **Nautilus.Distributions** -- 37 exports across 12 distribution families
- **Nautilus.LinAlg** -- 25 linear algebra operations (fixed-size and general-n)
- **Nautilus.Stats** -- 14 descriptive statistics
- **Nautilus.Testing** -- 13 hypothesis-test helpers
- **Nautilus.Integrate** -- 8 quadrature methods
- **Nautilus.Distance** -- 8 distance metrics
- **Nautilus.ODE** -- 4 fixed-step ODE solvers
- **Nautilus.Optim** -- 4 scalar optimizers
- **Nautilus.Roots** -- 3 root-finders
- **Nautilus.Interpolation** -- 3 interpolation methods
- **Nautilus.SDE** -- 2 stochastic ODE integrators
- **Nautilus.CurveFit** -- 1 Levenberg-Marquardt fitter
- **Nautilus.Signal** -- 7 stubs (blocked on complex numbers)

Each table in SKILL.md includes the function name, full type signature,
and implementation notes (domain restrictions, precision, effect
annotations).

For usage patterns and worked examples, see the module-specific chapters
in this book and the 15 patterns in SKILL.md Section 3.
