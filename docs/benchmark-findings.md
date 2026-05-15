# Nautilus vs scipy — Benchmark Findings (Phase 5)

Measurement harness: `scripts/bench_vs_scipy.py`, in-process via
`ctypes.CDLL` (no subprocess-per-trial cost). 20 trials per point,
sizes 10 → 100k, f64 throughout. Hardware: single box, single thread.

## Headline numbers

- **Compiler codegen + link-time optimization is the biggest single
  lever.** Adding `-flto -fuse-linker-plugin -fvisibility=hidden
  -Wl,-Bsymbolic` to the bench .so build alone improves `erf` by
  **3.8×** (13.66 → 3.58 ns/el) and the `normal_cdf(x)*exp(-x²)`
  compound by **2.6×** (24.59 → 9.40 ns/el) — without touching a line
  of Chelis source. This is a larger improvement than any algorithmic
  change in the phase, and it is the dominant story for the paper.
- **Fused compound expressions beat numpy ufunc chains at every size
  tested.** `normal_cdf(x)*exp(-x²)` runs at 6.7 ns/el at n=100k vs
  numpy 20.4 ns/el — **3.0×** (≈ **150M evals/s/core**). `norm_pdf
  from primitives` runs at 2.2 ns/el vs numpy 7.9 ns/el — **3.6×**
  (≈ **450M evals/s/core**).
- **Every scalar kernel is Nautilus-wins** at its best size after the
  P5 fixes. `erfinv` is **6.5× faster** than scipy at n=100k
  (≈ **450M/s**); `erf` **3.2×** (≈ **285M/s**); `normal_inv_cdf`
  **6.8×** (≈ **370M/s**); `normal_cdf` **4.2×** (≈ **220M/s**).
- **`gamma_cdf` and `student_t_cdf` flipped from 40-100× slower to
  2.3× faster at large n** after replacing the hardcoded 200-iteration
  series / CF loops with cephes-style convergence checks **using a
  relative-with-floor termination criterion** (see Track 2 below) —
  the floor is what makes the fix correct in the parameter regime
  where the speedup matters most. **526 / 526 scipy-parity
  assertions preserved** through the change.
- **Solver kernels (`rk4_solve`, `brent`) measure Python-vs-compiled
  dispatch cost, not numerical-method cost.** Per-call timings: `rk4`
  0.43 µs vs scipy `solve_ivp` 1734 µs (**4000×**); `brent` 0.12 µs
  vs scipy `brentq` 5.6 µs (**45×**). **Caveat:** scipy `solve_ivp`
  is an adaptive RK45 with Python-level argument validation, event
  handling, dense output, and step control — none of which Nautilus's
  fixed-step compiled RK4 does. The fair "RK4 vs RK4" comparison
  against a hand-written C loop called via ctypes would be much
  closer to parity. The 4000× number is the real cost a Python user
  pays today, but it is **not** a claim about the numerical method
  itself.

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
  `student_t_cdf` slowdown.

  **The non-obvious correctness fix — relative-with-floor termination.**
  The naive textbook check `|term| < eps * |acc|` is *wrong* in the
  exact regime where the speedup matters most. For
  `gammainc_series(a, x)` with `a` large and `x` small (the slowest CF
  regime), the partial sum `acc` starts very near zero, so `eps * |acc|`
  is also near zero and the check never fires — the loop still runs the
  full 200 iterations and the speedup evaporates. Cephes handles this
  with a *floored* relative tolerance:

  ```
  abs_term = |term_next|
  scale    = max(|acc_next|, 1.0)        // floor pins the threshold
  converged = abs_term < eps * scale
  ```

  The floor falls back to absolute tolerance until the accumulator
  grows past unity, then switches to relative. This is the difference
  between "we made it faster" and "we made it faster without breaking
  edge cases." For the continued-fraction helpers (`gammaq_cf_rec`,
  `betacf_rec`) no floor is needed: those measure convergence on the
  correction ratio `|delta - 1|`, which is always order-unity during
  CF convergence by construction.

  **Correctness gate.** **526 / 526 scipy-parity assertions preserved**
  through the change, and a follow-up adversarial red-team round
  ran 142 additional probes at **10× tighter than golden tolerance**
  across extreme parameter regimes (`gammap(100, 1)`, `betai(0.5, 0.5,
  0.001)`, `student_t_cdf(df=1)` Cauchy tails, etc.) — zero
  regressions.

  **Result:** **25-27× speedup** on gamma_cdf / student_t_cdf, both
  flipping from 40-100× *slower* than scipy to **2.3× faster** at
  large n.

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
  runtime. Tracked in `upstream-bugs.md`.

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
