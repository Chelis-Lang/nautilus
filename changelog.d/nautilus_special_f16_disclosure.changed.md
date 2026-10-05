- **The `Nautilus.Special` f16/bf16 hazard is now described accurately, and
  tracked as a release blocker rather than a language gap** (nautilus#75).
  `docs/CHELIS_SURFACE.md` said "the language cannot narrow the bound today";
  it can, on chelis `main`. chelis#2443 added an explicit dtype-set bound
  (`[prec: {f32, f64}]`, spec/04 §5.9) in chelis#2827 / `a762596b8`, which
  landed 2026-10-02 and which v0.18.12 (2026-09-30) predates, and the release
  that would carry it also moves `SHELL_FORMAT_VERSION` 5 -> 6, so it forces a
  shell re-publish wave (chelis#3156). `docs/UPSTREAM_BUGS.md` now carries the
  entry, the reproducer, and the de-narrowing steps for the next pin bump, and
  `tests_blocked/README.md` records why the probe cannot be executable.

  The hazard itself is unchanged and still disclosed. Measured at the
  `=0.18.12` pin through the built package: `gamma(5.5bf16)` = 58.0 against a
  true 52.34277778455352, `bessel_y1(2.2bf16)` = 0.0059814453125 against
  0.0014877892897632759, and `bessel_j0(5.0f16)`, `bessel_j1(1.5f16)`,
  `bessel_y0(1.5f16)` all NaN, while `gamma(5.5f32)` = 52.342891693115234 and
  `gamma(5.5f64)` = 52.342777784553576 are correct (the latter 8 ulp above
  the correctly rounded 52.34277778455352). The module still
  typechecks only because its 35 coefficients outside f16's range carry an
  explicit `f64` suffix, which satisfies `[04-LIT-2]` and moves the overflow
  from compile time to run time.

  The book's `special/overview.md` and `appendix/precision.md` now carry the
  disclosure that `appendix/limitations.md` already had.
