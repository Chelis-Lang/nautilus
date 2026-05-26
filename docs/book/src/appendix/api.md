# API Reference

The full API surface for all Nautilus modules is maintained in
[SKILL.md, Section 6](https://github.com/Chelis-Lang/nautilus/blob/main/SKILL.md#6-api-surface).

That section contains signature tables for the active Nautilus surface,
arranged module by module. The current row counts below sum to the
shipped library surface plus the seven `Nautilus.Signal` stubs and the
`Nautilus.Core.version` metadata helper.

- **Nautilus.Special** -- 21 special functions (erf, erfc, gamma, Bessel, Airy, elliptic integrals)
- **Nautilus.Distributions** -- 38 exports across 12 distribution families
- **Nautilus.LinAlg** -- 29 linear algebra operations (fixed-size and general-n)
- **Nautilus.Stats** -- 14 descriptive statistics
- **Nautilus.Testing** -- 13 hypothesis-test helpers
- **Nautilus.Integrate** -- 8 quadrature methods
- **Nautilus.Distance** -- 8 distance metrics
- **Nautilus.Ode** -- 5 ODE solvers including an adaptive RK45 endpoint solver
- **Nautilus.Optim** -- 4 scalar optimizers
- **Nautilus.Roots** -- 3 root-finders
- **Nautilus.Interpolation** -- 3 interpolation methods
- **Nautilus.Sde** -- 2 stochastic ODE integrators
- **Nautilus.CurveFit** -- 2 Levenberg-Marquardt fitters
- **Nautilus.Signal** -- 7 stubs (blocked on complex numbers)

Each table in SKILL.md includes the function name, full type signature,
row-level stability label, and implementation notes (domain
restrictions, precision, effect annotations). The same row-level
surface is emitted in machine-readable form at `dist/stability.json`.

For usage patterns and worked examples, see the module-specific chapters
in this book and the 15 patterns in SKILL.md Section 3.
