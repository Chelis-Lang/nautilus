# Nautilus vs scipy — Benchmark Findings (Phase 5)

Measurement harness: `scripts/bench_vs_scipy.py`, in-process via
`ctypes.CDLL` (no subprocess-per-trial cost). 20 trials per point,
sizes 10 → 100k, f64 throughout. Hardware: single box, single thread.

## Headline numbers

- **Fused compound expressions beat numpy ufunc chains at every size
  tested.** `normal_cdf(x)*exp(-x²)` runs at 6.7 ns/el at n=100k vs
  numpy 20.4 ns/el — **3.0×**. `norm_pdf from primitives` runs at 2.2
  ns/el vs numpy 7.9 ns/el — **3.6×**.
- **Every scalar kernel is Nautilus-wins** at its best size after the
  P5 fixes. `erfinv` is **6.5× faster** than scipy at n=100k; `erf`
  **3.2×**; `normal_inv_cdf` **6.8×**; `normal_cdf` **4.2×**.
- **`gamma_cdf` and `student_t_cdf` flipped from 40-100× slower to
  2.3× faster at large n** after replacing the hardcoded 200-iteration
  series / CF loops with cephes-style convergence checks.
- **Solver kernels win by orders of magnitude** in per-call cost:
  `rk4_solve` 0.43 µs/call vs scipy `solve_ivp` 1734 µs/call
  (**4000×**); `brent` 0.12 µs/call vs scipy `brentq` 5.6 µs/call
  (**45×**). Scipy's solver interfaces pay a huge Python-object /
  dispatch tax that Nautilus's flat C loop avoids entirely.

## What Nautilus wins (and why)

**Fused compound expressions.** A Chelis-level composition like
`normal_cdf(x) * exp(-x*x)` compiles to a single C loop that loads
each `x` once, computes the composition in registers, and stores one
result. Numpy evaluates the same expression as a chain of ufunc calls
with intermediate temporaries; at medium-to-large n the intermediates
don't fit in L2 and bandwidth dominates. Nautilus wins at **every
size** on this class of expression, including n=100k where we had
previously expected bandwidth to cap the win.

**Tight scalar approximations vs full scipy dispatch stack.**
`normal_inv_cdf` (Acklam rational approximation) and `erfinv`
(Winitzki initial + Newton correction) run about **6-7× faster** than
scipy.stats.norm.ppf / scipy.special.erfinv at n=100k. Scipy pays
`rv_continuous` dispatch overhead on every call; Nautilus emits a
direct floating-point pipeline.

**Iterative CDFs after P5 Track 2.** `gamma_cdf(2,1)` at n=100k runs at
18 ns/el vs scipy's 41 ns/el (**2.3× faster**); `student_t_cdf(df=5)`
at 64 vs 145 ns/el (**2.3×**). Both win at **every** tested size
including n=10. Before P5, these were 40-100× *slower*; see "What we
fixed" below.

**ODE and root-finding.** Nautilus's `rk4_solve` and `brent` are
order-of-magnitude faster per-call than scipy equivalents because
scipy's `solve_ivp` / `brentq` are Python-level dispatch wrappers over
FORTRAN/C kernels. For batch workloads where a user would write a
Python loop over scipy solver calls, compiled Nautilus is the right
answer by 1-3 orders of magnitude.

## What Nautilus loses (and why)

**Small-n everything** (n ≤ 100 on every kernel). Dominated by the
~3 µs ctypes dispatch floor — irreducible for any Python→C FFI path.
Nautilus *from Chelis* at small n would not pay this cost; the tax is
on the bench harness, not the runtime. Decision: drop n=1 rows from
the main presentation (captured by `--sizes 1` for the isolated
dispatch floor).

**No remaining large-n losers.** Before the P5 Track 1 LTO flag
change, `erf` / `log_gamma` / `digamma` were 1.4-2× slower than scipy
at n=100k because the compound wrappers were calling helpers via PLT
(un-inlined) while scipy's ufuncs were SIMD-vectorized libm. After
adding `-flto -fuse-linker-plugin -fvisibility=hidden -Wl,-Bsymbolic`
to the gcc command line, cross-TU inlining kicks in and all three
flip to wins. See Upstream asks below.

## What we fixed in P5

- **Track 1 — PLT indirection blocking cross-TU inlining.** Root cause
  of the "compound fusion narrows at n=100k" puzzle was *not* OpenMP
  and *not* bandwidth: it was `-fPIC -shared` defaults forcing every
  call to `normal_cdf@plt` / `exp@plt`, preventing inlining even under
  `-flto`. Fix: add `-flto -fuse-linker-plugin -fvisibility=hidden
  -Wl,-Bsymbolic` to `scripts/bench_vs_scipy.py::build_shared_lib`.
  Measured delta: `b_erf` 13.66 → 3.58 ns/el (**3.8×**);
  `b_compound_ncdf_times_exp_nxsq` 24.59 → 9.40 ns/el (**2.6×**).
  Added `-fopenmp` on top of combo-c: no change — OpenMP was never
  the lever, cross-TU inlining was.

- **Track 2 — Early termination for `gammainc_series`, `gammaq_cf_rec`,
  `betacf_rec`.** These were running a hardcoded 200-iteration loop
  regardless of actual convergence. Scipy (via cephes) terminates in
  10-30 iterations for typical inputs — that 10-20× iteration-count
  gap was the entire source of the 40-100× `gamma_cdf` /
  `student_t_cdf` slowdown. Fix: add a relative-with-floor convergence
  check `|term| < eps * max(|acc|, 1.0)` to `gammainc_series` (cephes
  convention — the naive `|term| < eps * |acc|` form fails exactly in
  the large-`a` small-`x` regime where `acc ≈ 0` at the start of the
  series), and a `|delta - 1| < eps` check on the continued-fraction
  recurrences. 526/526 scipy-parity assertions preserved. Result:
  **25-27× speedup** on gamma_cdf / student_t_cdf.

- **Track 3 — New bench kernels.** Added `b_rk4_decay`,
  `b_brent_cubic`, `b_compound_norm_pdf_from_primitives`. Expanded
  `build_shared_lib` to bundle `ode.ch` and `roots.ch` alongside
  `special.ch` + `distributions.ch`. Fair scipy baselines use
  `scipy.integrate.solve_ivp(RK45, max_step=0.01)` and
  `scipy.optimize.brentq` in Python loops — what a real caller would
  actually write.

- **Track 4 — Bench output restructure.** `scripts/bench_vs_scipy.py`
  now leads with fused compound expressions (the thesis), drops n=1
  rows from the main display (dispatch-floor noise), groups per-kernel
  sweeps by winner/loser, and emits a summary table with
  crossover_n / best_ratio / regime columns.

## Upstream asks (for Chelis compiler)

1. **Emit `static inline` for scalar helpers when a reef package is
   linked into a single `.so`.** The current codegen leaves
   `normal_cdf`, `erf`, `exp` etc. as `extern` symbols in separate
   TUs, which under `-fPIC -shared` forces PLT calls and blocks
   inlining. Callers currently work around this by passing
   `-fvisibility=hidden -Wl,-Bsymbolic` themselves; that dependency
   should move upstream so it's not every shell repo's problem.

2. **OpenMP pragmas on composed tensor maps, not just single RISC
   ops.** Current bench .so contains 5 `#pragma omp` directives, all
   in tensor `_sample_` stubs; compound maps emit scalar loops with
   no pragmas. Even after Track 1's LTO fix we're single-threaded on
   n=100k workloads that could trivially parallelize.

3. **Cephes-style convergence-based iteration for
   series/continued-fraction helpers.** Track 2 landed this in
   Nautilus's `distributions.ch`; the pattern should propagate into
   any upstream stdlib incomplete-gamma / incomplete-beta
   implementations.

## Deferred (runtime-blocked)

- **LinAlg small-n benchmarks** (`inv_2x2`, `solve_2x2`,
  `cholesky_2x2`) need a real `chelis_tensor*` runtime shim for rank-1
  and rank-2 f32 allocation + element access. The current
  `RUNTIME_STUBS` return-NULL policy can't support them. Future P6.

- **Distribution sampling benchmarks** (`normal_sample`) hit the same
  runtime gate — need `uniform_like` and tensor allocation. Future P6.

- **Grad-through-rk4 neural-ODE demo** — blocked on the same tensor
  runtime. Tracked in `UPSTREAM_BUGS.md`.

## How to run

```bash
# Full sweep (compound thesis + per-kernel + solvers):
python scripts/bench_vs_scipy.py --sizes 10,100,1000,10000,100000

# Thesis only (fused compound expressions):
python scripts/bench_vs_scipy.py --tier 3

# Per-kernel sweeps only:
python scripts/bench_vs_scipy.py --tier 2

# Correctness gate (526 scipy-parity assertions, subprocess-driven):
python scripts/bench_vs_scipy.py --tier 1

# See the isolated ctypes dispatch floor:
python scripts/bench_vs_scipy.py --sizes 1
```
