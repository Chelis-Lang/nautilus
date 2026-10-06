`Nautilus.Distributions.normal_cdf` and `normal_cdf_t` now call the Chelis
`standard_normal_cdf` builtin on the standardized point `(x - mean) / std`
instead of computing `0.5 * (1 + erf(z))`. **Values change in the left tail.**

The previous spelling cancelled: as `erf(z)` approached `-1` the addition
destroyed the information, leaving an absolute error of about `0.5 * ulp(1.0)`
however accurate `erf` itself was. It therefore returned exactly `0.0` for every
standardized point below about `-6`, and carried no significant digits below
about `-5.3`. Measured at f32 against mpmath at 60 decimal digits over
`w` in [-12.6, -3], the worst error falls from 1.6e7 ulps to 79 ulps.

The builtin's own ~1.5 ulp figure is reached where `(x - mean) / std` is exact,
such as `mean = 0, std = 1`; otherwise the rounding of that quotient is
amplified by about `w^2` in the tail. The appendix records the measured bound
per parameterisation. `lognormal_cdf` and the `Nautilus.Testing` p-value
functions inherit the change through `normal_cdf`; a downstream oracle holding
golden values for deep-tail probabilities will need to be refreshed.

Addresses nautilus#113.
