# Performance Results

Archived Phase 5 benchmark findings measured with the retired in-process
`ctypes.CDLL` harness. The run used 20 trials per point, sizes 10 to 100k, f64
throughout, on a single box and thread. Git history preserves the exact
measurement harness.

## Headline numbers

| Kernel | Nautilus ns/el | scipy ns/el | Speedup | Throughput |
|---|---|---|---|---|
| `erfinv` (n=100k) | 2.2 | 14.7 | **6.5x** | 450M/s |
| `normal_inv_cdf` (n=100k) | 2.7 | 18.5 | **6.8x** | 370M/s |
| `normal_cdf` (n=100k) | 4.6 | 19.2 | **4.2x** | 220M/s |
| `erf` (n=100k) | 3.5 | 11.3 | **3.2x** | 285M/s |
| `gamma_cdf(2,1)` (n=100k) | 18.2 | 41.1 | **2.3x** | 55M/s |
| `student_t_cdf(df=5)` (n=100k) | 64.4 | 144.5 | **2.3x** | 15.5M/s |

Every scalar kernel is Nautilus-wins at large n after the P5 fixes.

## Fused compound expressions

This is the dominant performance story. A Chelis-level composition like
`normal_cdf(x) * exp(-x*x)` compiles to a single C loop that loads each
`x` once, computes the composition in registers, and stores one result.
Numpy evaluates the same expression as a chain of ufunc calls with
intermediate temporaries; at medium-to-large n the intermediates don't
fit in L2 and bandwidth dominates.

| Compound expression | Nautilus ns/el | numpy ns/el | Speedup | Throughput |
|---|---|---|---|---|
| `normal_cdf(x)*exp(-x^2)` (n=100k) | 6.7 | 20.4 | **3.0x** | 150M/s |
| `norm_pdf` from primitives (n=100k) | 2.2 | 7.9 | **3.6x** | 450M/s |

Nautilus wins at **every size tested** on fused compounds, including
n=100k where we had previously expected bandwidth to cap the win.

## LTO: the biggest single lever

Adding `-flto -fuse-linker-plugin -fvisibility=hidden -Wl,-Bsymbolic`
to the bench shared-object build improves `erf` by **3.8x** (13.66 to
3.58 ns/el) and the compound `normal_cdf(x)*exp(-x^2)` by **2.6x**
(24.59 to 9.40 ns/el) -- without touching a line of Chelis source.

This is larger than any algorithmic change in Phase 5.

### Why LTO matters

The Chelis C backend emits scalar helpers (`normal_cdf`, `erf`, `exp`)
as `extern` symbols in separate translation units. Under `-fPIC -shared`
defaults, every call goes through the PLT (procedure linkage table),
blocking gcc's cross-TU inlining. The LTO flags fix this:

- `-flto` enables link-time optimization across TUs
- `-fvisibility=hidden` prevents symbol export
- `-Wl,-Bsymbolic` resolves symbols at link time, not load time

### Current status

These flags were a **workaround** in the then-current benchmark harness only.
They were not applied in the test harness or any consumer-facing
build path. The proper fix is upstream: the Chelis compiler should emit
scalar helpers as `static inline` when a reef package is linked into a
single shared object.

Measured regression from dropping the flags:

- v0.1.5: 6.7 to 18.9 ns/el (3x) on compound at n=100k
- v0.1.6: 9.4 to 20.9 ns/el (2.2x) same kernel

## Early termination fix (P5 Track 2)

`gamma_cdf` and `student_t_cdf` flipped from **40-100x slower** to
**2.3x faster** than scipy at large n after replacing hardcoded
200-iteration series/continued-fraction loops with cephes-style
convergence checks.

The key correctness detail: **relative-with-floor termination**.

The naive textbook check `|term| < eps * |acc|` fails when the
accumulator starts near zero (e.g., `gammainc_series(a, x)` with a large
and x small). The floor pins the threshold:

    scale    = max(|acc_next|, 1.0)
    converged = |term_next| < eps * scale

This falls back to absolute tolerance until the accumulator grows past
unity, then switches to relative. For continued-fraction helpers
(`gammaq_cf_rec`, `betacf_rec`), no floor is needed: those measure
convergence on the correction ratio `|delta - 1|`, which is order-unity
during CF convergence by construction.

**Correctness gate:** 526/526 scipy-parity assertions preserved. A
follow-up red-team round ran 142 additional probes at 10x tighter than
golden tolerance across extreme parameter regimes -- zero regressions.

## Solver caveats

| Solver | Nautilus | scipy | Ratio | Caveat |
|---|---|---|---|---|
| `rk4_solve` (100 steps) | 0.43 us | 1734 us | 4000x | Fixed-step RK4 vs adaptive RK45 + Python dispatch |
| `brent` root-find | 0.12 us | 5.6 us | 45x | Compiled C vs Python `brentq` wrapper |

These numbers measure **Python dispatch overhead**, not numerical-method
quality. scipy's `solve_ivp` includes adaptive step control, event
handling, dense output, and argument validation -- none of which
Nautilus's fixed-step RK4 does. A fair RK4-vs-RK4 comparison against a
hand-written C loop would be much closer to parity.

The 4000x number is the real cost a Python user pays today, but it is
not a claim about the numerical method itself.

## What Nautilus loses

**Small-n everything** (n <= 100). Dominated by the ~3 us ctypes
dispatch floor -- irreducible for any Python-to-C FFI path. Nautilus
from Chelis at small n would not pay this cost; the tax is on the bench
harness, not the runtime.

No remaining large-n losers after LTO and early-termination fixes.

## Deferred benchmarks

- **LinAlg small-n** (`inv_2x2`, `solve_2x2`, `cholesky_2x2`): need a
  real `chelis_tensor*` runtime shim. The current RUNTIME_STUBS
  return-NULL policy cannot support them.
- **Distribution sampling** (`normal_sample`): same runtime gate.
- **Grad-through-rk4 neural-ODE demo**: blocked on tensor runtime.

## Reproduction status

The original measurement harness was retired during parity consolidation; use
Git history to reproduce these historical numbers. The current external
correctness gate is:

```bash
uv run --project parity --frozen python parity/run_parity.py --strict
```
