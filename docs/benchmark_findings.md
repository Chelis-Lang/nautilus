# Benchmark Findings

This file records two sets of performance measurements. Neither is a current
executable gate. The current correctness gate is the SciPy parity run:

```bash
uv run --project parity --frozen python parity/run_parity.py --strict
```

## Nautilus vs SciPy (April 2026)

**Measurement context.** Measured on 2026-04-15 against Nautilus 0.1.0 built
with Chelis 0.1.3, using an in-process `ctypes.CDLL` harness
(`scripts/bench_vs_scipy.py`, since removed; recoverable from Git at commit
`11943b6`). The kernels were compiled into a shared library with
`gcc -O3 -march=native`, called on float64 arrays, and timed over 20 trials per
point at sizes from 10 to 100,000 elements, on a single machine and a single
thread. Nautilus has since moved to f32 and the compiler has changed
substantially, so these numbers describe that build, not the current release.

### Scalar kernels at n = 100,000

| Kernel | Nautilus ns/el | SciPy ns/el | Speedup | Throughput |
|---|---:|---:|---:|---:|
| `erfinv` | 2.2 | 14.7 | 6.5x | 450M/s |
| `normal_inv_cdf` | 2.7 | 18.5 | 6.8x | 370M/s |
| `normal_cdf` | 4.6 | 19.2 | 4.2x | 220M/s |
| `erf` | 3.5 | 11.3 | 3.2x | 285M/s |
| `gamma_cdf(2, 1)` | 18.2 | 41.1 | 2.3x | 55M/s |
| `student_t_cdf(df=5)` | 64.4 | 144.5 | 2.3x | 15.5M/s |

`normal_inv_cdf` (Acklam's rational approximation) and `erfinv` avoided the
per-call `rv_continuous` dispatch that `scipy.stats.norm.ppf` and
`scipy.special.erfinv` pay. `gamma_cdf` and `student_t_cdf` won at every
tested size, including n = 10.

### Fused compound expressions

| Expression at n = 100,000 | Nautilus ns/el | NumPy ns/el | Speedup | Throughput |
|---|---:|---:|---:|---:|
| `normal_cdf(x) * exp(-x^2)` | 6.7 | 20.4 | 3.0x | 150M/s |
| normal PDF from primitives | 2.2 | 7.9 | 3.6x | 450M/s |

A Chelis composition such as `normal_cdf(x) * exp(-x*x)` compiled to a single
C loop that loaded each `x` once and kept intermediates in registers. NumPy
evaluates the same expression as a chain of ufunc calls with temporary arrays,
which at medium and large n no longer fit in L2 cache. Nautilus won at every
tested size, including n = 100,000, where memory bandwidth had been expected
to erase the advantage.

### Solver calls

| Solver | Nautilus | SciPy | Ratio |
|---|---:|---:|---:|
| `rk4_solve`, 100 steps | 0.43 µs | 1734 µs (`solve_ivp`, RK45) | 4000x |
| `brent` root-find | 0.12 µs | 5.6 µs (`brentq`) | 45x |

These ratios measure Python dispatch overhead, not numerical method quality.
`solve_ivp` adds adaptive step control, event handling, dense output, and
argument validation, none of which a fixed-step RK4 does; a fair RK4-to-RK4
comparison against a hand-written C loop would be much closer. The 4000x is
the real cost a Python caller paid for one solve in a loop, but not a claim
about the method.

### What drove the results

**Cross-translation-unit inlining.** At the time, the C backend emitted scalar
helpers (`normal_cdf`, `erf`, `exp`) as `extern` symbols in separate
translation units. Under `-fPIC -shared`, every call went through the
procedure linkage table and could not be inlined, even with `-flto`. Adding
`-flto -fuse-linker-plugin -fvisibility=hidden -Wl,-Bsymbolic` to the
benchmark's library build improved `erf` 3.8x (13.66 to 3.58 ns/el) and the
`normal_cdf(x) * exp(-x^2)` compound 2.6x (24.59 to 9.40 ns/el) without any
change to Chelis source; adding `-fopenmp` changed nothing. Before these flags,
`erf`, `log_gamma`, and `digamma` were 1.4 to 2x slower than SciPy at
n = 100,000. The flags applied only to the benchmark build, not to the test
harness or to consumer builds.

**Early termination in the incomplete gamma and beta functions.** The series
and continued-fraction helpers (`gammainc_series`, `gammaq_cf_rec`,
`betacf_rec` in `src/distributions.ch`) had run a fixed 200 iterations where
Cephes, which SciPy uses, typically stops after 10 to 30. Switching them to
convergence checks gave a 25 to 27x speedup and turned `gamma_cdf` and
`student_t_cdf` from 40 to 100x slower than SciPy into 2.3x faster. The
series check needs a floor to be correct:

```
scale     = max(|acc_next|, 1.0)
converged = |term_next| < eps * scale
```

For `gammainc_series(a, x)` with large `a` and small `x`, the partial sum
starts near zero, so the textbook test `|term| < eps * |acc|` never fires and
the loop runs all 200 iterations. The floor makes the test absolute until the
sum passes 1 and relative afterwards. The continued-fraction helpers need no
floor, because they test the correction ratio `|delta - 1|`, which is of order
one throughout. The change preserved all 526 SciPy parity assertions of the
time, and a further 142 adversarial probes at 10x tighter than the golden
tolerances (`gammap(100, 1)`, `betai(0.5, 0.5, 0.001)`, Cauchy tails of
`student_t_cdf(df=1)`, and similar) found no regressions. These convergence
checks remain in the current source.

**Small n.** At n <= 100, every kernel was dominated by the roughly 3 µs
`ctypes` call overhead, a cost of calling from Python rather than of the
compiled code; Chelis callers do not pay it.

### Not measured

Small fixed-size LinAlg (`inv_2x2`, `solve_2x2`, `cholesky_2x2`), distribution
sampling (`normal_sample`), and a gradient-through-`rk4_solve` demonstration
were not benchmarked: the harness's runtime stubs could not allocate Chelis
tensors.

## Host `List` round trip vs native tensor operations (August 2026)

**Measurement context.** Measured on 2026-08-27 with Chelis 0.18.5 on
darwin-arm64, `clang -O2 -march=native`, in the compiled C lane (nautilus#47).

Two definitions with identical signatures, one using the native tensor
operation and one converting through host lists:

```chelis-fragment
def lane_native_add[n](a: &tensor[n, f32], b: &tensor[n, f32]) -> tensor[n, f32] = add(a, b)
def lane_listform_add[n](a: &tensor[n, f32], b: &tensor[n, f32]) -> tensor[n, f32] =
  to_tensor(map(fn (pair: (f32, f32)) -> add(pair.0, pair.1), zip(to_list(a), to_list(b))))
```

Both were built with `chelis build --target c`, linked against the emitted
`libchelis_runtime.a`, and driven from a C `main` that called each in a loop
and divided by the repetition count, with the same inputs and allocator state
(both paths warmed once first).

| n | native | List round trip | ratio |
|---:|---:|---:|---:|
| 10,000 | 0.007 ms | 1.647 ms | 221x |
| 100,000 | 0.027 ms | 15.040 ms | 565x |
| 1,000,000 | 0.206 ms | 169.357 ms | 823x |
| 10,000,000 | 3.044 ms | 2,228.796 ms | 732x |

The gap is structural rather than a constant factor. The emitted C for the
round-trip form calls `chelis_list_from_tensor` twice, allocates a zip, boxes
and unboxes every element through `chelis_value_as_f`, `chelis_value_from_f`,
and `chelis_value_as_tuple`, grows the result with `chelis_list_push`, and
converts back; the native form does none of this. At the 20-million-element
scale of nautilus#45's workload, one vector add in the round-trip form costs
roughly 4.5 s against roughly 6 ms native. Nautilus#48 moved ten elementwise
definitions in LinAlg, Distributions, and Distance to the native form; other
tensor-returning definitions in `src/` still use the List form.

This difference does not show up under `chelis test`: at 300,000 elements the
two forms measured 2.97 s and 2.94 s there, because the test harness is
dominated by fixed costs (`uniform_like`, converting the result with
`to_list`, and about 2.87 s of interpreter startup). Measure the compiled
lane.
