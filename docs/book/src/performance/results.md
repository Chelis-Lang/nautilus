# Performance Results

Nautilus has no current performance gate. This chapter summarizes the
recorded measurements; the full record, with methodology, is
[`docs/benchmark_findings.md`](https://github.com/Chelis-Lang/nautilus/blob/main/docs/benchmark_findings.md).

## Nautilus vs SciPy

**Measurement context.** Measured on 2026-04-15 against Nautilus 0.1.0 built
with Chelis 0.1.3: an in-process `ctypes` harness calling a
`gcc -O3 -march=native` shared library on float64 arrays, 20 trials per
point, sizes 10 to 100,000, one machine, one thread. Nautilus has since moved
to f32 and the compiler has changed substantially, so these numbers describe
that build, not the current release.

| Kernel at n = 100,000 | Nautilus ns/el | SciPy/NumPy ns/el | Speedup |
|---|---:|---:|---:|
| `erfinv` | 2.2 | 14.7 | 6.5x |
| `normal_inv_cdf` | 2.7 | 18.5 | 6.8x |
| `normal_cdf` | 4.6 | 19.2 | 4.2x |
| `erf` | 3.5 | 11.3 | 3.2x |
| `gamma_cdf(2, 1)` | 18.2 | 41.1 | 2.3x |
| `student_t_cdf(df=5)` | 64.4 | 144.5 | 2.3x |
| `normal_cdf(x) * exp(-x^2)` (vs NumPy) | 6.7 | 20.4 | 3.0x |
| normal PDF from primitives (vs NumPy) | 2.2 | 7.9 | 3.6x |

Three things drove these results:

- **Fusion.** A composed Chelis expression compiled to one C loop with its
  intermediates in registers, while NumPy chains ufuncs through temporary
  arrays. Nautilus won on compound expressions at every tested size.
- **Cross-unit inlining.** Building the library with
  `-flto -fuse-linker-plugin -fvisibility=hidden -Wl,-Bsymbolic` let the C
  compiler inline scalar helpers across translation units, improving `erf`
  3.8x and the compound expression 2.6x without changing Chelis source. The
  flags applied only to the benchmark build.
- **Early termination.** The incomplete gamma and beta helpers stop on
  convergence rather than after a fixed 200 iterations, using a floored
  relative test (`|term| < eps * max(|acc|, 1)`) that stays correct when the
  partial sum starts near zero. This turned `gamma_cdf` and `student_t_cdf`
  from 40 to 100x slower than SciPy into 2.3x faster, and it remains in the
  current source.

Per-call solver timings (`rk4_solve` 0.43 µs against `solve_ivp` 1734 µs;
`brent` 0.12 µs against `brentq` 5.6 µs) measure Python dispatch overhead
rather than numerical method quality. Below about n = 100, every kernel was
dominated by the roughly 3 µs `ctypes` call cost, which Chelis callers do
not pay.

## Host `List` round trip vs native tensor operations

**Measurement context.** Measured on 2026-08-27 with Chelis 0.18.5 on
darwin-arm64, `clang -O2 -march=native`, in the compiled C lane.

Writing elementwise tensor arithmetic as
`to_tensor(map(..., zip(to_list(a), to_list(b))))` instead of the native
tensor operation was 221x slower at n = 10,000 and 823x slower at
n = 1,000,000, because every element is boxed and unboxed through the host
list runtime. `chelis test` does not reveal the difference, since its fixed
startup cost dominates; measure the compiled lane.
