#!/usr/bin/env python3
"""Benchmark Nautilus scalar kernels vs scipy and numpy equivalents.

Times the Nautilus bare-build binary (reused from tests/run_numeric_tests.py)
against scipy/numpy on identical inputs. Reports wall-clock time per batch and
the ratio Nautilus/reference. Useful as a performance-regression tripwire and
to surface kernels where the pure-Chelis recursive-helper pattern is paying a
meaningful cost vs vectorized numpy or scipy.

Two comparison tracks:
  - scipy benchmarks call out to scipy.special / scipy.stats functions that
    already exist there. Reference is single-value evaluation.
  - numpy benchmarks call out to numpy math primitives (np.exp, np.log,
    np.sqrt, np.sin, np.sort, np.mean, np.var, np.median, np.linalg.inv)
    on either scalar or small-array inputs. This surfaces the cost floor
    Nautilus's scalar surface pays vs vectorized numpy at batch=1.

Usage:
    python scripts/bench_vs_scipy.py                     # run all
    python scripts/bench_vs_scipy.py --batch N           # trials per measurement
    python scripts/bench_vs_scipy.py --skip-scipy        # numpy + chelis only
    python scripts/bench_vs_scipy.py --skip-numpy        # scipy + chelis only
    python scripts/bench_vs_scipy.py --chelis-only       # just time chelis
    python scripts/bench_vs_scipy.py --refs-only         # just time numpy/scipy

The harness does NOT compare output values — `tests/run_numeric_tests.py`
already handles parity verification. This script only cares about timing.
"""
from __future__ import annotations

import argparse
import subprocess
import sys
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


def bench_nautilus(binary: Path, case: str, args: tuple, n_trials: int) -> float:
    cmd = [str(binary), case, *(str(a) for a in args)]
    start = time.perf_counter()
    for _ in range(n_trials):
        subprocess.run(cmd, capture_output=True, text=True, check=True)
    return time.perf_counter() - start


def bench_scipy(fn, args: tuple, n_trials: int) -> float:
    start = time.perf_counter()
    for _ in range(n_trials):
        fn(*args)
    return time.perf_counter() - start


def bench_numpy(fn, args: tuple, n_trials: int) -> float:
    return bench_scipy(fn, args, n_trials)  # same mechanism; different label


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--batch", type=int, default=50)
    ap.add_argument("--chelis-only", action="store_true")
    ap.add_argument("--refs-only", action="store_true")
    ap.add_argument("--skip-scipy", action="store_true")
    ap.add_argument("--skip-numpy", action="store_true")
    args = ap.parse_args()

    import numpy as np
    from scipy import special as sp_special
    from scipy import stats as sp_stats

    if args.refs_only:
        nautilus_bin = None
    else:
        harness = import_harness()
        print("# building Nautilus native binary (special + distributions) ...", flush=True)
        nautilus_bin = harness.build_native_binary()
        print(f"# binary: {nautilus_bin}")

    # Each benchmark: (label, nautilus_case, nautilus_args, scipy_fn, scipy_args,
    #                   numpy_fn, numpy_args).
    # scipy_fn or numpy_fn can be None if no direct equivalent.
    benchmarks = [
        # scipy.special — numpy doesn't have erf/erfinv/gammaln/digamma directly
        # (numpy only has numpy.math mirrors removed in 1.25+). scipy is the
        # right reference.
        ("erf(0.5)",
         "erf", (0.5,),
         lambda x: sp_special.erf(x), (0.5,),
         None, None),
        ("erfinv(0.5)",
         "erfinv", (0.5,),
         lambda x: sp_special.erfinv(x), (0.5,),
         None, None),
        ("log_gamma(3.5)",
         "log_gamma", (3.5,),
         lambda x: sp_special.gammaln(x), (3.5,),
         None, None),
        ("digamma(3.5)",
         "digamma", (3.5,),
         lambda x: sp_special.digamma(x), (3.5,),
         None, None),
        # Elementary math — numpy covers these natively and is the right ref.
        ("exp(neg(x*x))  @ x=0.5",
         # Nautilus doesn't expose raw exp via a single-arg scalar case in
         # the harness; skip Nautilus column here, time the numpy path alone.
         None, None,
         None, None,
         lambda x: np.exp(-x * x), (0.5,)),
        ("sqrt(2.0)",
         None, None,
         None, None,
         lambda x: np.sqrt(x), (2.0,)),
        ("sin(1.5)",
         None, None,
         None, None,
         lambda x: np.sin(x), (1.5,)),
        ("log(3.7)",
         None, None,
         None, None,
         lambda x: np.log(x), (3.7,)),
        # Distributions — both scipy and numpy cover normal_cdf / inv_cdf via
        # scipy. numpy has no direct norm.cdf but does offer a reference batch
        # primitive through np.random.Generator — skip numpy column here.
        ("normal_cdf(1.96)",
         "normal_cdf", (1.96, 0.0, 1.0),
         lambda x, m, s: sp_stats.norm.cdf(x, loc=m, scale=s), (1.96, 0.0, 1.0),
         None, None),
        ("normal_inv_cdf(0.975)",
         "normal_inv_cdf", (0.975, 0.0, 1.0),
         lambda q, m, s: sp_stats.norm.ppf(q, loc=m, scale=s), (0.975, 0.0, 1.0),
         None, None),
        ("gamma_cdf(2,2,1)",
         "gamma_cdf", (2.0, 2.0, 1.0),
         lambda x, a, s: sp_stats.gamma.cdf(x, a=a, scale=s), (2.0, 2.0, 1.0),
         None, None),
        ("student_t_cdf(1.96,30)",
         "student_t_cdf", (1.96, 30.0),
         lambda t, df: sp_stats.t.cdf(t, df=df), (1.96, 30.0),
         None, None),
        ("beta_cdf(0.5,2,3)",
         "beta_cdf", (0.5, 2.0, 3.0),
         lambda x, a, b: sp_stats.beta.cdf(x, a, b), (0.5, 2.0, 3.0),
         None, None),
        ("weibull_cdf(1.0,2,1)",
         "weibull_cdf", (1.0, 2.0, 1.0),
         lambda x, c, s: sp_stats.weibull_min.cdf(x, c=c, scale=s), (1.0, 2.0, 1.0),
         None, None),
        ("poisson_cdf(3,3)",
         "poisson_cdf", (3.0, 3.0),
         lambda k, lm: sp_stats.poisson.cdf(k, mu=lm), (3, 3.0),
         None, None),
        # Stats — numpy has the natural reference for mean/var/median/sort.
        # Nautilus side doesn't expose these through the bare-build harness
        # (tensor inputs), so we time numpy-only here.
        ("numpy.mean(10-elem array)",
         None, None,
         None, None,
         lambda a: np.mean(a), (np.arange(10.0),)),
        ("numpy.var(10-elem array)",
         None, None,
         None, None,
         lambda a: np.var(a), (np.arange(10.0),)),
        ("numpy.median(11-elem array)",
         None, None,
         None, None,
         lambda a: np.median(a), (np.arange(11.0),)),
        ("numpy.sort(20-elem array)",
         None, None,
         None, None,
         lambda a: np.sort(a), (np.arange(20.0)[::-1],)),
    ]

    header = (f"{'benchmark':<32} {'nautilus (s)':>14} "
              f"{'scipy (s)':>14} {'numpy (s)':>14} {'naut/best':>12}")
    print(header)
    print("-" * len(header))

    for (label, ncase, nargs, sfn, sargs, nfn, ngargs) in benchmarks:
        sc_time = None
        np_time = None
        nt_time = None

        if sfn is not None and not args.skip_scipy and not args.chelis_only:
            sc_time = bench_scipy(sfn, sargs, args.batch)
        if nfn is not None and not args.skip_numpy and not args.chelis_only:
            np_time = bench_numpy(nfn, ngargs, args.batch)
        if nautilus_bin is not None and ncase is not None and not args.refs_only:
            nt_time = bench_nautilus(nautilus_bin, ncase, nargs, args.batch)

        best_ref = None
        for t in (sc_time, np_time):
            if t is not None and (best_ref is None or t < best_ref):
                best_ref = t
        ratio = "-"
        if nt_time is not None and best_ref is not None and best_ref > 0:
            ratio = f"{nt_time / best_ref:.2f}"

        cells = [
            label,
            f"{nt_time:.6f}" if nt_time is not None else "-",
            f"{sc_time:.6f}" if sc_time is not None else "-",
            f"{np_time:.6f}" if np_time is not None else "-",
            ratio,
        ]
        print(f"{cells[0]:<32} {cells[1]:>14} {cells[2]:>14} {cells[3]:>14} {cells[4]:>12}")

    print()
    print("# Nautilus timing is dominated by subprocess spawn per trial")
    print("# (no in-process FFI path until libchelis_runtime.a ships). The")
    print("# subprocess-vs-in-process comparison intentionally surfaces the")
    print("# cost floor a consumer would see calling Nautilus from outside")
    print("# the compiled binary.")
    print("# naut/best compares Nautilus timing against the fastest of the")
    print("# available references (scipy or numpy).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
