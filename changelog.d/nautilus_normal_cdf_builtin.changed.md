`Nautilus.Distributions.normal_cdf` and `normal_cdf_t` now call the Chelis
`standard_normal_cdf` builtin on the standardized point `(x - mean) / std`
instead of computing `0.5 * (1 + erf(z))`. **Values change in the left tail.**

The previous spelling cancelled: as `erf(z)` approached `-1` the addition
destroyed the information, leaving an absolute error of about `0.5 * ulp(1.0)`
however accurate `erf` itself was. It therefore returned exactly `0.0` for every
standardized point below about `-6`, and carried no significant digits below
about `-5.3`. Measured at f32 against mpmath at 60 decimal digits over
`w` in [-12.6, -3], the worst error falls from about 1.6e7 ulps to below one ulp
where `(x - mean) / std` is exact, and to order 10^2 ulps where it is not. The
difference is structural, not statistical: an exact quotient leaves no argument
error for `w^2` to amplify.

`lognormal_cdf` and `Nautilus.Testing.z_p_value_lower` inherit the improvement
through `normal_cdf`. `z_p_value_upper` and `z_p_value_two_sided` consume
`normal_cdf` too, so their values shift, but this change did not repair them:
they computed `1 - normal_cdf(z)`, which cancels on the right tail in the mirror
image of the defect fixed here. That right-tail half is nautilus#137, and it is
fixed separately in this same release -- see the right-tail p-value entry. A
downstream oracle holding golden values for deep-tail probabilities will need to
be refreshed.

Addresses nautilus#113.
