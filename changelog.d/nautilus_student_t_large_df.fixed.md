`student_t_cdf` no longer evaluates the regularized incomplete beta above `df`
of 1e7. It uses the t distribution's own large-`df` expansion,
`Phi(t) - phi(t)(t^3 + t)/(4 df)`, computed in f64 and returned as f32.
**Values change above `df` of 1e7.** The signature does not.

The incomplete beta's front factor is
`exp(lgamma(a+b) - lgamma(a) - lgamma(b) + ...)` with `a = df/2`, so its
exponent carries an absolute error of about one f64 ulp of the largest
log-gamma, and that error grows without bound in `df`. Measured on the old
path, worst over a `t` axis of -0.5 to -11 and +1: 1.2e-6 at `df = 1e8`,
9.1e-6 at 1e9, 2.3e-3 at 1e12, 2.6 at 1e14 and 2.6e27 at 1e20. At `t = 1`
alone those read 5.3e-8, 2.9e-7, 7.1e-5 and 41%, because `student_t_cdf(1, df)`
returned exactly 0.5 from `df = 1e16` upward. 0.5 is also the function's value
at `t = 0`, so the wrong answer was indistinguishable from a right one, and
`student_t_cdf(0, df)` returning 0.5 remains correct.

The figures in nautilus#145's own table are larger than these at the same `df`
because they were measured at `90d88fd`, before the incomplete beta moved to
f64; that change improved every row without removing the defect.

The left tail was further out than the 0.5 suggests, and that tail is what
`t_p_value_two_sided` and `t_p_value_upper` read: `student_t_cdf(-5, 1e18)`
returned 0.49981025 against a true 2.8665158e-7, and `student_t_cdf(-8, 1e18)`
returned 0.0. An infinite `df`, which is the normal distribution exactly, also
returned 0.5 and now returns `Phi(t)`.

The documented bound is unchanged at 2e-6, and `student_t_cdf` no longer
carries an upper limit on `df`. The accuracy gate's `df` axis now runs to 1e20
and its `student_t_cdf` cases count inside the documented range, so a
regression there fails the build; it measures a worst relative error of 1.44e-7
with this change and exits 1 on the previous code, where the same grid reaches
2.6e27. `docs/book`'s advice to
substitute `normal_cdf` by hand above `df` of about 1e9 is withdrawn, because
a bare `Phi(t)` is not accurate enough to be that substitute in the left tail
(4.3e-5 at `df = 1e8`, measured at `t = -11`); the `1/df` term is what makes
the expansion usable at a threshold the incomplete beta can still reach.

The accuracy gate's `student_t_cdf` reference moves from SciPy's `betainc` to
its `stdtr`. `betainc` shares both the saturation and the cancellation, so it
was 2.15 relative wrong at `df = 1e16` and agreed with the value under test;
`stdtr` is a different algorithm and stays within 1e-13 of a 50-digit mpmath
reference to `df = 1e18`. Part of nautilus#145.
