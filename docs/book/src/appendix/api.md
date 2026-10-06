# API Map

Nautilus 0.7.49 exports functions from the modules below. Each source module
contains the exact signatures for this package; the book chapters explain
common calls and limits. Use the [package source tree](https://github.com/Chelis-Lang/nautilus/tree/main/src)
when you need an export beyond a chapter's examples.

| Module | Start here |
|---|---|
| `Nautilus.Special` | [Special functions](../special/overview.md) |
| `Nautilus.Distributions` | [Distributions](../distributions/overview.md) and [sampling limits](../distributions/sampling.md#sampling-limits) |
| `Nautilus.LinAlg` | [Linear algebra](../linalg/overview.md) and [conjugate gradient](../linalg/cg-solve.md) |
| `Nautilus.Stats` | [Descriptive statistics](../stats/descriptive.md) |
| `Nautilus.Testing` | [Hypothesis testing](../stats/testing.md) |
| `Nautilus.Integrate` | [Numerical quadrature](../solvers/integrate.md) |
| `Nautilus.Distance` | [Distance metrics](../other/distance.md) |
| `Nautilus.Ode` | [ODE solvers](../solvers/ode.md) |
| `Nautilus.Optim` | [Scalar optimization](../solvers/optim.md) |
| `Nautilus.Roots` | [Root finding](../solvers/roots.md) |
| `Nautilus.Interpolation` | [Interpolation](../other/interpolation.md) |
| `Nautilus.Sde` | [SDE solvers](../solvers/sde.md) |
| `Nautilus.CurveFit` | [Curve fitting](../other/curvefit.md) |
| `Nautilus.Signal` | [`fftfreq` and placeholders](../other/signal.md) |
| `Nautilus.Info` | [Package source](https://github.com/Chelis-Lang/nautilus/blob/main/src/info.ch) |
| `Nautilus.Optimize` | [Package source](https://github.com/Chelis-Lang/nautilus/blob/main/src/optimize.ch) |
| `Nautilus.StateSpace` | [Package source](https://github.com/Chelis-Lang/nautilus/blob/main/src/statespace.ch) |
| `Nautilus.TimeSeries` | [Package source](https://github.com/Chelis-Lang/nautilus/blob/main/src/timeseries.ch) |
| `Nautilus.Core` | [Package source](https://github.com/Chelis-Lang/nautilus/blob/main/src/core.ch) |

The [stability inventory](https://github.com/Chelis-Lang/nautilus/blob/main/dist/stability.json)
lists machine-readable `stable` and `alpha` labels for exports. Review
an `alpha` function's domain and numerical limits before relying on it.
