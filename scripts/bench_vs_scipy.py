#!/usr/bin/env python3
"""Nautilus benchmark harness — in-process via ctypes.

Three tiers:

  **Tier 1 — Scalar correctness.**
    Validate against scipy to the tolerance documented in the module
    goldens. Not a race — just a correctness gate. Delegates to the
    existing `tests/run_numeric_tests.py` which runs 526 scipy-parity
    assertions against a subprocess-driven binary. Skipped unless
    `--tier 1` is passed.

  **Tier 2 — Vectorized kernels at size sweeps.**
    This is where Nautilus actually has to compete. For each scalar
    kernel (erf, log_gamma, normal_cdf, etc.), we expose a C batch
    wrapper `b_<kernel>(const double* xs, double* out, size_t n)`
    inside the .so, call it in-process via ctypes, and compare against
    scipy's vectorized ufunc. Sizes: 1, 10, 100, 1k, 10k, 100k, 1M.
    Report per-element nanoseconds — the invariant that matters once
    setup overhead is amortized. The crossover between small-n
    (Nautilus wins on zero dispatch tax) and large-n (scipy wins on
    SIMD + vectorized libm) is the story.

  **Tier 3 — Compound expressions.**
    Fused Nautilus loop (one pass, no intermediate allocation) vs the
    same expression in numpy (multiple ufunc passes + intermediates).
    E.g. `normal_cdf(x) * exp(-x²)`. This is where a compiled array
    language with expression-level fusion should pull ahead of
    element-at-a-time-into-allocator numpy patterns — not at small n
    (where allocator hit is amortized) but at medium n where the
    intermediate doesn't fit in L2.

  **Tier 4 — GPU dispatch.**
    Deferred until HIP codegen + runtime ships upstream. Placeholder.

Usage:
    python scripts/bench_vs_scipy.py                # tier 2 + 3 default
    python scripts/bench_vs_scipy.py --tier 1       # correctness only
    python scripts/bench_vs_scipy.py --tier 2       # size sweep only
    python scripts/bench_vs_scipy.py --tier 3       # compound only
    python scripts/bench_vs_scipy.py --sizes 100,10000,1000000
    python scripts/bench_vs_scipy.py --trials 100   # trials per size

All tier-2/3 measurements are in-process via `ctypes.CDLL` — subprocess
spawn overhead is NOT measured. Tier 1 delegates to a subprocess gate
because the existing correctness harness is already subprocess-based
and changing that would unnecessarily couple the two tools.
"""
from __future__ import annotations

import argparse
import ctypes
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
HARNESS = REPO / "tests" / "run_numeric_tests.py"


def import_harness():
    sys.path.insert(0, str(REPO / "tests"))
    import importlib.util
    spec = importlib.util.spec_from_file_location("run_numeric_tests", HARNESS)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


# --- C wrapper source emitted inside the .so ---------------------------------
#
# Batch wrappers that call the scalar Nautilus functions in a straight-line
# loop. These are what ctypes dispatches to. Keep them as simple as possible —
# the loop body is Nautilus's scalar compute, and that's what we want to
# measure.

BATCH_WRAPPER_C = r"""
#include <stddef.h>
#include <math.h>
#include <stdint.h>

double erf(double);
double erfinv(double);
double log_gamma(double);
double digamma(double);
double normal_pdf(double, double, double);
double normal_cdf(double, double, double);
double normal_inv_cdf(double, double, double);
double gamma_pdf(double, double, double);
double gamma_cdf(double, double, double);
double student_t_cdf(double, double);
double beta_cdf(double, double, double);
double weibull_cdf(double, double, double);
double poisson_cdf(double, double);

/* Nautilus.Ode + Nautilus.Roots — take function pointers. Signatures
 * from the chelis v0.1.7 C backend (tests/run_numeric_tests.py
 * documents these):
 *   double rk4_solve(double (*f)(double, double),
 *                    double y0, double t0, double t1, int64_t n_steps);
 *   double brent(double (*f)(double),
 *                double lo, double hi, double tol, int64_t max_iters);
 */
double rk4_solve(double (*f)(double, double),
                 double y0, double t0, double t1, int64_t n_steps);
double brent(double (*f)(double),
             double lo, double hi, double tol, int64_t max_iters);

#define EXPORT __attribute__((visibility("default")))

/* Fixed RHS / target functions used by the ODE and Roots benchmarks.
 * These live in the .so alongside the Nautilus C so Nautilus can see
 * them via ordinary function pointers. */
static double bench_decay_rhs(double y, double t) { return -y; }
static double bench_cubic(double x) { return x * x * x - 2.0 * x - 5.0; }

EXPORT void b_erf(const double* xs, double* out, size_t n) {
    for (size_t i = 0; i < n; i++) out[i] = erf(xs[i]);
}
EXPORT void b_erfinv(const double* xs, double* out, size_t n) {
    for (size_t i = 0; i < n; i++) out[i] = erfinv(xs[i]);
}
EXPORT void b_log_gamma(const double* xs, double* out, size_t n) {
    for (size_t i = 0; i < n; i++) out[i] = log_gamma(xs[i]);
}
EXPORT void b_digamma(const double* xs, double* out, size_t n) {
    for (size_t i = 0; i < n; i++) out[i] = digamma(xs[i]);
}
EXPORT void b_normal_cdf(const double* xs, double* out, size_t n) {
    for (size_t i = 0; i < n; i++) out[i] = normal_cdf(xs[i], 0.0, 1.0);
}
EXPORT void b_normal_inv_cdf(const double* qs, double* out, size_t n) {
    for (size_t i = 0; i < n; i++) out[i] = normal_inv_cdf(qs[i], 0.0, 1.0);
}
EXPORT void b_gamma_cdf_shape_2_scale_1(const double* xs, double* out, size_t n) {
    for (size_t i = 0; i < n; i++) out[i] = gamma_cdf(xs[i], 2.0, 1.0);
}
EXPORT void b_student_t_cdf_df_5(const double* xs, double* out, size_t n) {
    for (size_t i = 0; i < n; i++) out[i] = student_t_cdf(xs[i], 5.0);
}

/* ---- Tier 3: compound / fused expressions ----
 *
 * One pass, no intermediate allocation. Contrast with numpy which allocates
 * an intermediate array at each operator. Nautilus-style fusion can stay in
 * cache for medium n.
 */

/* normal_pdf-ish via erf + exp in one pass */
EXPORT void b_compound_ncdf_times_exp_nxsq(const double* xs, double* out, size_t n) {
    for (size_t i = 0; i < n; i++) {
        double x = xs[i];
        out[i] = normal_cdf(x, 0.0, 1.0) * exp(-x * x);
    }
}

/* Z-score to two-sided p-value via erf: standard transform a user would
 * otherwise write as 2*(1-norm.cdf(abs(z))) in numpy with 3 allocations. */
EXPORT void b_compound_two_sided_pval(const double* zs, double* out, size_t n) {
    for (size_t i = 0; i < n; i++) {
        double z = zs[i];
        double az = z < 0.0 ? -z : z;
        out[i] = 2.0 * (1.0 - normal_cdf(az, 0.0, 1.0));
    }
}

/* Gamma log-density — three log_gamma calls fused into a single loop,
 * whereas numpy equivalent allocates three intermediate arrays. */
EXPORT void b_compound_log_gamma_chain(const double* xs, double* out, size_t n) {
    for (size_t i = 0; i < n; i++) {
        double x = xs[i];
        out[i] = log_gamma(x) - log_gamma(x + 1.0) + log_gamma(2.0 * x);
    }
}

/* Normal PDF computed from primitives — exp(-x²/2) / sqrt(2π). Contrasts
 * against scipy.stats.norm.pdf, which is a closed-form reference. This
 * shows that the pure-Chelis Special surface (exp + scale) is competitive
 * with scipy's hand-tuned PDF path at medium n. */
EXPORT void b_compound_norm_pdf_from_primitives(
    const double* xs, double* out, size_t n
) {
    const double inv_sqrt_2pi = 0.3989422804014327;
    for (size_t i = 0; i < n; i++) {
        double x = xs[i];
        out[i] = inv_sqrt_2pi * exp(-0.5 * x * x);
    }
}

/* ---- Tier 3: ODE + Roots via function-pointer callbacks ---- */

/* rk4_solve(decay, y0=y0s[i], t0=0, t1=1, n_steps=100) across a batch
 * of initial conditions. Each element integrates a 100-step RK4. */
EXPORT void b_rk4_decay(const double* y0s, double* out, size_t n) {
    for (size_t i = 0; i < n; i++) {
        out[i] = rk4_solve(bench_decay_rhs, y0s[i], 0.0, 1.0, 100);
    }
}

/* brent on a fixed cubic in [2, 3]. The "batch" here is just the same
 * problem repeated; there's no natural per-element variation for a
 * scalar root-find. Returns the same answer in every output slot. */
EXPORT void b_brent_cubic(const double* unused, double* out, size_t n) {
    (void)unused;
    for (size_t i = 0; i < n; i++) {
        out[i] = brent(bench_cubic, 2.0, 3.0, 1.0e-10, 100);
    }
}
"""


def build_shared_lib(extra_flags: list[str] | None = None) -> Path:
    """Build libnautilus_bench.so containing the Nautilus scalar surface plus
    the C batch wrappers above. Reuses tests/run_numeric_tests.py for the
    Chelis source assembly + runtime stubs so the two harnesses stay in sync.

    Bundle includes special.ch, distributions.ch, roots.ch, and ode.ch so the
    Tier-3 ODE and Roots benchmarks can call `rk4_solve` / `brent` directly
    through the .so's exported symbols.

    `extra_flags` is appended to the gcc command line after the default
    `-O3 -march=native -shared -fPIC`. Used by the flag-probe harness.
    """
    harness = import_harness()
    workdir = Path(tempfile.mkdtemp(prefix="nautilus-bench-"))
    bare_ch = workdir / "bench_bare.ch"
    bare_src = "\n".join(
        harness.strip_module((harness.SRC / f).read_text())
        for f in ("special.ch", "distributions.ch", "roots.ch", "ode.ch")
    ) + "\ndef main() -> f32 = erf(cast(0.5, f32))\n"
    bare_ch.write_text(bare_src)
    harness.chelis_build(bare_ch, workdir / "out")
    c_file = workdir / "out" / "bench_bare.c"

    wrapper_c = workdir / "batch_wrapper.c"
    wrapper_c.write_text(BATCH_WRAPPER_C)

    so = workdir / "libnautilus_bench.so"
    # v0.1.5 shipped lib/libchelis_runtime.a in the tarball, so we link
    # against the real runtime archive instead of the hand-vendored
    # RUNTIME_STUBS block that P5 and earlier used. The P5 Track 1 LTO +
    # visibility workaround (-flto -fvisibility=hidden -Wl,-Bsymbolic)
    # stays, though: v0.1.7's C backend still emits cross-TU scalar
    # helpers (e.g. `normal_cdf`, `exp`) as extern, so the default
    # `-shared -fPIC` still forces calls through the PLT and blocks
    # gcc's cross-TU inlining. Measured deltas from dropping the flags:
    #   v0.1.5: 6.7 -> 18.9 ns/el (3×) on normal_cdf(x)*exp(-x²) at n=100k
    #   v0.1.7: 9.4 -> 20.9 ns/el (2.2×) same kernel, re-verified
    # Until upstream emits helpers as `static inline` for single-`.so`
    # bundles, these flags are load-bearing.
    out_dir = workdir / "out"
    cmd = ["gcc", "-O3", "-march=native", "-shared", "-fPIC",
           "-flto", "-fuse-linker-plugin",
           "-fvisibility=hidden", "-Wl,-Bsymbolic",
           "-o", str(so),
           str(c_file), str(wrapper_c),
           "-I", str(out_dir),
           "-L", str(out_dir), "-lchelis_runtime",
           "-lm", "-lpthread"]
    if extra_flags:
        cmd.extend(extra_flags)
    cc = subprocess.run(cmd, capture_output=True, text=True)
    if cc.returncode != 0:
        raise SystemExit(f"shared-lib build failed: {cc.stderr}")
    return so


# --- ctypes wiring ------------------------------------------------------------

def load_nautilus(so_path: Path) -> ctypes.CDLL:
    import numpy as np  # noqa: F401 (needed for downstream consumers)
    lib = ctypes.CDLL(str(so_path))
    c_double_p = ctypes.POINTER(ctypes.c_double)
    size_t = ctypes.c_size_t
    batch_sig = [c_double_p, c_double_p, size_t]
    for name in (
        "b_erf", "b_erfinv", "b_log_gamma", "b_digamma",
        "b_normal_cdf", "b_normal_inv_cdf",
        "b_gamma_cdf_shape_2_scale_1",
        "b_student_t_cdf_df_5",
        "b_compound_ncdf_times_exp_nxsq",
        "b_compound_two_sided_pval",
        "b_compound_log_gamma_chain",
        "b_compound_norm_pdf_from_primitives",
        "b_rk4_decay",
        "b_brent_cubic",
    ):
        fn = getattr(lib, name)
        fn.argtypes = batch_sig
        fn.restype = None
    return lib


def nautilus_batch(lib, name: str):
    """Return a Python wrapper (xs: ndarray) -> ndarray that calls the named
    batch export in-process.
    """
    import numpy as np
    fn = getattr(lib, name)
    c_double_p = ctypes.POINTER(ctypes.c_double)

    def call(xs):
        out = np.empty_like(xs)
        fn(xs.ctypes.data_as(c_double_p),
           out.ctypes.data_as(c_double_p),
           len(xs))
        return out

    return call


# --- timing -------------------------------------------------------------------

def time_batch(fn, xs, trials: int) -> float:
    """Return mean seconds per trial across `trials` runs, excluding warmup."""
    # Warmup — avoid capturing JIT/first-call overhead in tight timings.
    fn(xs)
    start = time.perf_counter()
    for _ in range(trials):
        fn(xs)
    return (time.perf_counter() - start) / trials


# --- tier 1 -------------------------------------------------------------------

def tier1(args) -> int:
    print("=== Tier 1: scalar correctness (delegating to run_numeric_tests.py) ===")
    r = subprocess.run(
        [sys.executable, str(HARNESS)],
        capture_output=True, text=True,
    )
    print(r.stdout[-500:] if len(r.stdout) > 500 else r.stdout)
    if r.returncode != 0:
        print("FAIL:", r.stderr)
        return 1
    return 0


# --- tier 2 -------------------------------------------------------------------

TIER2_KERNELS = [
    # (label, nautilus batch name, scipy/numpy callable, input-domain generator)
    ("erf",              "b_erf",
     lambda xs, sp: sp.special.erf(xs),
     lambda rng, n: rng.uniform(-3.0, 3.0, n)),
    ("erfinv",           "b_erfinv",
     lambda xs, sp: sp.special.erfinv(xs),
     lambda rng, n: rng.uniform(-0.99, 0.99, n)),
    ("log_gamma",        "b_log_gamma",
     lambda xs, sp: sp.special.gammaln(xs),
     lambda rng, n: rng.uniform(0.1, 20.0, n)),
    ("digamma",          "b_digamma",
     lambda xs, sp: sp.special.digamma(xs),
     lambda rng, n: rng.uniform(0.1, 20.0, n)),
    ("normal_cdf",       "b_normal_cdf",
     lambda xs, sp: sp.stats.norm.cdf(xs),
     lambda rng, n: rng.uniform(-4.0, 4.0, n)),
    ("normal_inv_cdf",   "b_normal_inv_cdf",
     lambda xs, sp: sp.stats.norm.ppf(xs),
     lambda rng, n: rng.uniform(0.01, 0.99, n)),
    ("gamma_cdf(2,1)",   "b_gamma_cdf_shape_2_scale_1",
     lambda xs, sp: sp.stats.gamma.cdf(xs, a=2.0, scale=1.0),
     lambda rng, n: rng.uniform(0.1, 10.0, n)),
    ("student_t_cdf(df=5)", "b_student_t_cdf_df_5",
     lambda xs, sp: sp.stats.t.cdf(xs, df=5.0),
     lambda rng, n: rng.uniform(-4.0, 4.0, n)),
]


def tier2(args, lib) -> int:
    import numpy as np
    import scipy as sp
    rng = np.random.default_rng(0xC0DE)
    # Drop n=1 from main display — that row measures ctypes dispatch,
    # not compute. The dispatch floor is ~3 µs/call; pass `--sizes 1`
    # explicitly to see it in isolation.
    sizes = [n for n in args.sizes if n > 1]

    print("=== Vectorized scalar kernels (size sweep) ===")
    print("# n=1 rows dropped; run --sizes 1 to see the ctypes dispatch floor.")
    print()

    # Collect all rows, then group by per-kernel best ratio (naut/scipy ns/el).
    # Kernels whose best ratio < 1.0 at any n are "Nautilus-wins"; otherwise
    # "scipy-wins". We use the best (lowest) ratio to classify so a kernel
    # that wins only at some sizes still counts as a Nautilus win.
    rows = {}  # label -> list of (n, naut_us, scipy_us, naut_nspe, scipy_nspe, ratio)
    best_ratio = {}
    crossover = {}  # label -> smallest n at which Nautilus is faster, or None

    for label, batch_name, scipy_fn, make_xs in TIER2_KERNELS:
        naut = nautilus_batch(lib, batch_name)
        rows[label] = []
        for n in sizes:
            xs = make_xs(rng, n).astype(np.float64)
            nt = time_batch(naut, xs, args.trials)
            st = time_batch(lambda a: scipy_fn(a, sp), xs, args.trials)
            ratio = nt / st if st > 0 else float("inf")
            rows[label].append((n, nt * 1e6, st * 1e6, nt * 1e9 / n, st * 1e9 / n, ratio))
            if crossover.get(label) is None and ratio < 1.0:
                crossover[label] = n
        best_ratio[label] = min(r[5] for r in rows[label])

    winners = [l for l in rows if best_ratio[l] < 1.0]
    losers = [l for l in rows if best_ratio[l] >= 1.0]

    header = f"{'kernel':<22} {'n':>9} {'naut µs':>12} {'scipy µs':>12} " \
             f"{'naut ns/el':>12} {'scipy ns/el':>12} {'ratio':>8}"

    def emit_block(title, labels):
        if not labels:
            return
        print(f"--- {title} ---")
        print(header)
        print("-" * len(header))
        for label in labels:
            for (n, nu, su, nnp, snp, ratio) in rows[label]:
                print(f"{label:<22} {n:>9d} {nu:>12.2f} {su:>12.2f} "
                      f"{nnp:>12.1f} {snp:>12.1f} {ratio:>8.2f}")
            print()

    emit_block("Nautilus wins (best ratio < 1.0)", winners)
    emit_block("scipy wins (best ratio >= 1.0)", losers)

    # Summary table
    print("--- summary (per-kernel best result across sweep) ---")
    sh = f"{'kernel':<22} {'crossover_n':>12} {'best_ratio':>12} {'regime':<24}"
    print(sh)
    print("-" * len(sh))
    for label in list(winners) + list(losers):
        br = best_ratio[label]
        co = crossover.get(label)
        co_str = str(co) if co is not None else "never"
        if br < 1.0:
            regime = "Nautilus-wins"
        elif br < 2.0:
            regime = "near-parity"
        else:
            regime = "scipy-SIMD-libm-wins"
        print(f"{label:<22} {co_str:>12} {br:>12.2f} {regime:<24}")
    print()
    return 0


# --- tier 3 -------------------------------------------------------------------

def tier3(args, lib) -> int:
    import numpy as np
    import scipy as sp
    rng = np.random.default_rng(0xFADE)
    sizes = args.sizes

    header = f"{'expression':<32} {'n':>9} {'naut µs':>12} {'numpy µs':>12} " \
             f"{'ratio':>8} {'naut ns/el':>12} {'numpy ns/el':>12}"
    print("=== Fused compound expressions (THESIS: single-pass beats ufunc chains) ===")
    print(header)
    print("-" * len(header))

    def compound_ncdf_times_exp_nxsq_numpy(xs):
        return sp.stats.norm.cdf(xs) * np.exp(-xs * xs)

    def compound_two_sided_pval_numpy(zs):
        return 2.0 * (1.0 - sp.stats.norm.cdf(np.abs(zs)))

    def compound_log_gamma_chain_numpy(xs):
        return sp.special.gammaln(xs) - sp.special.gammaln(xs + 1.0) + sp.special.gammaln(2.0 * xs)

    def compound_norm_pdf_numpy(xs):
        return sp.stats.norm.pdf(xs)

    compounds = [
        ("normal_cdf(x)*exp(-x²)",
         "b_compound_ncdf_times_exp_nxsq",
         compound_ncdf_times_exp_nxsq_numpy,
         lambda n: rng.uniform(-3.0, 3.0, n).astype(np.float64)),
        ("2*(1 - normal_cdf(|z|))",
         "b_compound_two_sided_pval",
         compound_two_sided_pval_numpy,
         lambda n: rng.uniform(-4.0, 4.0, n).astype(np.float64)),
        ("lgamma(x)-lgamma(x+1)+lgamma(2x)",
         "b_compound_log_gamma_chain",
         compound_log_gamma_chain_numpy,
         lambda n: rng.uniform(0.1, 20.0, n).astype(np.float64)),
        ("norm_pdf from primitives",
         "b_compound_norm_pdf_from_primitives",
         compound_norm_pdf_numpy,
         lambda n: rng.uniform(-4.0, 4.0, n).astype(np.float64)),
    ]

    # ODE and Roots get their own loop because the scipy reference isn't a
    # vectorized ufunc — it's a Python loop over individual solves, same as
    # what a caller would actually write.
    def scipy_rk4_decay_batch(y0s):
        from scipy.integrate import solve_ivp
        out = np.empty_like(y0s)
        for i, y0 in enumerate(y0s):
            # RK45 with max_step such that ~100 function evals per solve,
            # matching Nautilus's fixed-step 100-step RK4.
            sol = solve_ivp(
                lambda t, y: -y, (0.0, 1.0), [float(y0)],
                method="RK45", max_step=0.01, rtol=1e-10, atol=1e-10,
            )
            out[i] = sol.y[0, -1]
        return out

    def scipy_brent_cubic_batch(dummy):
        from scipy.optimize import brentq
        out = np.empty_like(dummy)
        fn = lambda x: x**3 - 2*x - 5
        for i in range(len(dummy)):
            out[i] = brentq(fn, 2.0, 3.0, xtol=1e-10)
        return out

    solver_benchmarks = [
        ("rk4_solve(y'=-y, 100 steps)",
         "b_rk4_decay",
         scipy_rk4_decay_batch,
         lambda n: rng.uniform(0.5, 2.0, n).astype(np.float64)),
        ("brent(x³-2x-5 in [2,3])",
         "b_brent_cubic",
         scipy_brent_cubic_batch,
         lambda n: rng.uniform(0.0, 1.0, n).astype(np.float64)),
    ]

    for label, batch_name, numpy_fn, make_xs in compounds:
        naut = nautilus_batch(lib, batch_name)
        for n in sizes:
            xs = make_xs(n)
            nt = time_batch(naut, xs, args.trials)
            npt = time_batch(numpy_fn, xs, args.trials)
            naut_us = nt * 1e6
            numpy_us = npt * 1e6
            ratio = nt / npt if npt > 0 else float("inf")
            naut_ns_per = nt * 1e9 / n
            numpy_ns_per = npt * 1e9 / n
            print(f"{label:<32} {n:>9d} {naut_us:>12.2f} {numpy_us:>12.2f} "
                  f"{ratio:>8.2f} {naut_ns_per:>12.1f} {numpy_ns_per:>12.1f}")
        print()

    # Solver benchmarks — per-solve cost, not per-element. Scipy side is a
    # Python loop over individual scipy.integrate.solve_ivp / optimize.brentq
    # calls, which is what a user would actually write.
    solver_sizes = [s for s in sizes if s <= 1000]  # cap — these are slow per call
    if solver_sizes:
        print("--- solvers (per-call, not per-element; lower batch sizes) ---")
        for label, batch_name, scipy_fn, make_xs in solver_benchmarks:
            naut = nautilus_batch(lib, batch_name)
            for n in solver_sizes:
                xs = make_xs(n)
                nt = time_batch(naut, xs, max(args.trials // 10, 3))
                st = time_batch(scipy_fn, xs, max(args.trials // 10, 3))
                naut_us = nt * 1e6
                scipy_us = st * 1e6
                ratio = nt / st if st > 0 else float("inf")
                naut_us_per = nt * 1e6 / n
                scipy_us_per = st * 1e6 / n
                print(f"{label:<32} {n:>9d} {naut_us:>12.2f} {scipy_us:>12.2f} "
                      f"{ratio:>8.2f} {naut_us_per:>10.2f}µs/call {scipy_us_per:>10.2f}µs/call")
            print()
    return 0


# --- main ---------------------------------------------------------------------

def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--tier", type=int, choices=[1, 2, 3], default=None,
                    help="Run only one tier (default: 2 + 3)")
    ap.add_argument("--sizes", default="1,10,100,1000,10000,100000,1000000",
                    help="Comma-separated sizes for tier 2/3")
    ap.add_argument("--trials", type=int, default=30,
                    help="Trials per timing measurement (default: 30)")
    args = ap.parse_args()
    args.sizes = [int(s) for s in args.sizes.split(",")]

    if args.tier == 1:
        return tier1(args)

    print("# building libnautilus_bench.so ...", flush=True)
    so = build_shared_lib()
    print(f"# shared lib: {so}")
    lib = load_nautilus(so)

    rc = 0
    # Lead with Tier 3 — fused compound expressions are the thesis.
    # Per-kernel sweeps come second; they're context for the compound story.
    if args.tier is None or args.tier == 3:
        rc |= tier3(args, lib)
    if args.tier is None or args.tier == 2:
        rc |= tier2(args, lib)
    return rc


if __name__ == "__main__":
    sys.exit(main())
