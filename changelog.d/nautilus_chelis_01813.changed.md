Prepare Nautilus 0.7.48 for Chelis 0.18.13. `Nautilus.Special` now accepts
exactly f32 and f64 through an explicit dtype-set bound, so f16 and bf16 calls
are rejected at checking instead of reaching coefficients that produce
misleading values. `Nautilus.Rolling` inlines four `Option` helpers whose named
forms were needed by an earlier C lowering limitation. All workflow compiler
pins, shell conformance assets, Reef schema, negative diagnostic expectations,
and current compiler capability notes follow the new release. The remaining
exact-AD CurveFit, match ownership, and generic downstream C limitations are
recorded in `docs/UPSTREAM_BUGS.md` with their 0.18.13 probe results.
