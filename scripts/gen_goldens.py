#!/usr/bin/env python3
"""Generate scipy golden JSONs for Nautilus numerical parity tests.

Usage:
    python scripts/gen_goldens.py           # regenerate all goldens
    python scripts/gen_goldens.py --check   # diff-check checked-in goldens vs scipy
"""
import argparse
import json
import math
import os
import sys
from pathlib import Path

import numpy as np
from scipy import special as sp_special
from scipy import stats as sp_stats

REPO = Path(__file__).resolve().parent.parent
GOLDENS = REPO / "tests" / "goldens"

# Per-function tolerances — honest about each approximation's accuracy floor.
TOL = {
    "special/erf":         {"abs": 2.0e-7, "rel": 2.0e-7},
    "special/erfinv":      {"abs": 2.0e-8, "rel": 2.0e-6},
    "special/log_gamma":   {"abs": 1.0e-9, "rel": 1.0e-9},
    "special/digamma":     {"abs": 1.0e-7, "rel": 1.0e-7},
    "special/beta":        {"abs": 1.0e-9, "rel": 1.0e-9},
    "distributions/normal":      {"abs": 2.0e-7, "rel": 2.0e-7},
    "distributions/uniform":     {"abs": 1.0e-9, "rel": 1.0e-9},
    "distributions/exponential": {"abs": 1.0e-7, "rel": 1.0e-7},
    "distributions/lognormal":   {"abs": 2.0e-7, "rel": 2.0e-7},
    "distributions/gamma":       {"abs": 5.0e-5, "rel": 5.0e-5},  # CF + series + Newton residuals
    "distributions/chi_squared": {"abs": 5.0e-5, "rel": 5.0e-5},
    "distributions/student_t":   {"abs": 1.0e-6, "rel": 1.0e-6},
    "linalg/basic":              {"abs": 1.0e-5, "rel": 1.0e-5},
    "roots/scalar":              {"abs": 1.0e-8, "rel": 1.0e-8},
    "ode/scalar":                {"abs": 5.0e-7, "rel": 5.0e-7},
    "stats/vector":              {"abs": 1.0e-6, "rel": 1.0e-6},
}


def write_json(path: Path, data: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2) + "\n")


def goldens_special() -> dict[str, dict]:
    goldens = {}
    xs_erf = np.linspace(-3.0, 3.0, 25).tolist()
    goldens["special/erf.json"] = {
        "inputs": xs_erf,
        "outputs": [float(sp_special.erf(x)) for x in xs_erf],
        **TOL["special/erf"],
    }
    qs = np.linspace(-0.99, 0.99, 21).tolist()
    goldens["special/erfinv.json"] = {
        "inputs": qs,
        "outputs": [float(sp_special.erfinv(q)) for q in qs],
        **TOL["special/erfinv"],
    }
    xs_lg = [0.1, 0.5, 1.0, 1.5, 2.0, 3.0, 5.0, 10.0, 25.0, 50.0]
    goldens["special/log_gamma.json"] = {
        "inputs": xs_lg,
        "outputs": [float(sp_special.gammaln(x)) for x in xs_lg],
        **TOL["special/log_gamma"],
    }
    goldens["special/digamma.json"] = {
        "inputs": xs_lg,
        "outputs": [float(sp_special.digamma(x)) for x in xs_lg],
        **TOL["special/digamma"],
    }
    beta_pairs = [(1.0, 1.0), (2.0, 3.0), (0.5, 0.5), (4.0, 2.0), (5.0, 5.0), (10.0, 0.5)]
    goldens["special/beta.json"] = {
        "inputs": [list(p) for p in beta_pairs],
        "outputs": [float(sp_special.beta(a, b)) for (a, b) in beta_pairs],
        **TOL["special/beta"],
    }
    return goldens


def goldens_distributions() -> dict[str, dict]:
    g = {}

    xs = np.linspace(-3.0, 3.0, 13).tolist()
    qs = [0.01, 0.1, 0.25, 0.5, 0.75, 0.9, 0.99]

    # Normal(0, 1)
    g["distributions/normal.json"] = {
        "inputs_x": xs,
        "inputs_q": qs,
        "params": {"mean": 0.0, "std": 1.0},
        "pdf":     [float(sp_stats.norm.pdf(x)) for x in xs],
        "cdf":     [float(sp_stats.norm.cdf(x)) for x in xs],
        "inv_cdf": [float(sp_stats.norm.ppf(q)) for q in qs],
        **TOL["distributions/normal"],
    }

    # Uniform(-2, 5)
    lo, hi = -2.0, 5.0
    ux = np.linspace(-3.0, 6.0, 19).tolist()
    g["distributions/uniform.json"] = {
        "inputs_x": ux,
        "inputs_q": qs,
        "params": {"lo": lo, "hi": hi},
        "pdf":     [float(sp_stats.uniform.pdf(x, loc=lo, scale=hi-lo)) for x in ux],
        "cdf":     [float(sp_stats.uniform.cdf(x, loc=lo, scale=hi-lo)) for x in ux],
        "inv_cdf": [float(sp_stats.uniform.ppf(q, loc=lo, scale=hi-lo)) for q in qs],
        **TOL["distributions/uniform"],
    }

    # Exponential(rate=2)
    rate = 2.0
    ex = np.linspace(0.0, 4.0, 17).tolist()
    g["distributions/exponential.json"] = {
        "inputs_x": ex,
        "inputs_q": qs,
        "params": {"rate": rate},
        "pdf":     [float(sp_stats.expon.pdf(x, scale=1/rate)) for x in ex],
        "cdf":     [float(sp_stats.expon.cdf(x, scale=1/rate)) for x in ex],
        "inv_cdf": [float(sp_stats.expon.ppf(q, scale=1/rate)) for q in qs],
        **TOL["distributions/exponential"],
    }

    # LogNormal(mu=0, sigma=1)
    mu, sigma = 0.0, 1.0
    lx = np.linspace(0.1, 5.0, 17).tolist()
    g["distributions/lognormal.json"] = {
        "inputs_x": lx,
        "inputs_q": qs,
        "params": {"mu": mu, "sigma": sigma},
        "pdf":     [float(sp_stats.lognorm.pdf(x, s=sigma, scale=math.exp(mu))) for x in lx],
        "cdf":     [float(sp_stats.lognorm.cdf(x, s=sigma, scale=math.exp(mu))) for x in lx],
        "inv_cdf": [float(sp_stats.lognorm.ppf(q, s=sigma, scale=math.exp(mu))) for q in qs],
        **TOL["distributions/lognormal"],
    }

    # Gamma(shape=2, scale=3)
    k, theta = 2.0, 3.0
    gx = np.linspace(0.1, 15.0, 17).tolist()
    g["distributions/gamma.json"] = {
        "inputs_x": gx,
        "inputs_q": qs,
        "params": {"shape": k, "scale": theta},
        "pdf":     [float(sp_stats.gamma.pdf(x, a=k, scale=theta)) for x in gx],
        "cdf":     [float(sp_stats.gamma.cdf(x, a=k, scale=theta)) for x in gx],
        "inv_cdf": [float(sp_stats.gamma.ppf(q, a=k, scale=theta)) for q in qs],
        **TOL["distributions/gamma"],
    }

    # Chi-squared(df=5)
    df = 5.0
    cx = np.linspace(0.1, 15.0, 17).tolist()
    g["distributions/chi_squared.json"] = {
        "inputs_x": cx,
        "inputs_q": qs,
        "params": {"df": df},
        "pdf":     [float(sp_stats.chi2.pdf(x, df=df)) for x in cx],
        "cdf":     [float(sp_stats.chi2.cdf(x, df=df)) for x in cx],
        "inv_cdf": [float(sp_stats.chi2.ppf(q, df=df)) for q in qs],
        **TOL["distributions/chi_squared"],
    }

    # Student-t(df=5) — PDF only (CDF via incomplete beta not in scope)
    tx = np.linspace(-4.0, 4.0, 17).tolist()
    g["distributions/student_t.json"] = {
        "inputs_x": tx,
        "params": {"df": df},
        "pdf":     [float(sp_stats.t.pdf(x, df=df)) for x in tx],
        **TOL["distributions/student_t"],
    }

    return g


def goldens_linalg() -> dict[str, dict]:
    g = {}
    rng = np.random.default_rng(42)

    A = rng.standard_normal((3, 4)).astype(np.float64)
    B = rng.standard_normal((4, 2)).astype(np.float64)
    g["linalg/basic.json"] = {
        "A_3x4": A.tolist(),
        "B_4x2": B.tolist(),
        "A_T_4x3":        A.T.tolist(),
        "AB_3x2":         (A @ B).tolist(),
        "gram_AtA_4x4":   (A.T @ A).tolist(),
        "aat_3x3":        (A @ A.T).tolist(),
        "frobenius_A":    float(np.linalg.norm(A)),
        "frobenius_sq_A": float((A * A).sum()),
        "trace_AtA":      float(np.trace(A.T @ A)),
        "diag_AtA":       np.diag(A.T @ A).tolist(),
        **TOL["linalg/basic"],
    }

    # 2x2 determinant battery
    M2 = [
        [[2.0, 1.0], [1.0, 3.0]],
        [[1.0, 2.0], [3.0, 4.0]],
        [[5.0, 0.0], [0.0, 5.0]],
        [[0.5, -0.3], [0.1, 0.7]],
    ]
    g["linalg/det_2x2.json"] = {
        "matrices": M2,
        "dets":     [float(np.linalg.det(m)) for m in M2],
        **TOL["linalg/basic"],
    }

    # 3x3 determinant battery
    M3 = [
        [[1.0, 2.0, 3.0], [4.0, 5.0, 6.0], [7.0, 8.0, 10.0]],
        [[2.0, 0.0, 0.0], [0.0, 3.0, 0.0], [0.0, 0.0, 4.0]],
        [[1.0, 0.5, 0.2], [0.5, 2.0, 0.3], [0.2, 0.3, 3.0]],
    ]
    g["linalg/det_3x3.json"] = {
        "matrices": M3,
        "dets":     [float(np.linalg.det(m)) for m in M3],
        **TOL["linalg/basic"],
    }

    # 4-dim vector inner product + l2
    v = rng.standard_normal(5).astype(np.float64)
    w = rng.standard_normal(5).astype(np.float64)
    g["linalg/vector.json"] = {
        "v": v.tolist(),
        "w": w.tolist(),
        "inner_vw": float(v @ w),
        "l2_v":     float(np.linalg.norm(v)),
        "l2_w":     float(np.linalg.norm(w)),
        **TOL["linalg/basic"],
    }

    return g


def goldens_roots() -> dict[str, dict]:
    from scipy.optimize import brentq, newton as sci_newton, bisect
    g = {}
    g["roots/scalar.json"] = {
        "cases": [
            # label, function, bracket/start, expected
            {"label": "sqrt2_bisect",     "method": "bisect",  "lo": 1.0, "hi": 2.0, "expected": float(bisect(lambda x: x*x - 2.0, 1.0, 2.0))},
            {"label": "sqrt2_brent",      "method": "brent",   "lo": 1.0, "hi": 2.0, "expected": float(brentq(lambda x: x*x - 2.0, 1.0, 2.0))},
            {"label": "sqrt2_newton",     "method": "newton",  "x0": 1.5, "expected": float(sci_newton(lambda x: x*x - 2.0, 1.5, fprime=lambda x: 2*x))},
            {"label": "cubic_brent",      "method": "brent",   "lo": 2.0, "hi": 3.0, "expected": float(brentq(lambda x: x**3 - 2*x - 5.0, 2.0, 3.0))},
            {"label": "cubic_newton",     "method": "newton",  "x0": 2.0, "expected": float(sci_newton(lambda x: x**3 - 2*x - 5.0, 2.0, fprime=lambda x: 3*x*x - 2))},
            {"label": "cosmx_newton",     "method": "newton",  "x0": 0.5, "expected": float(sci_newton(lambda x: math.cos(x) - x, 0.5, fprime=lambda x: -math.sin(x) - 1))},
        ],
        **TOL["roots/scalar"],
    }
    return g


def goldens_ode() -> dict[str, dict]:
    g = {}
    # y' = -y, y(0) = 1 → y(t) = exp(-t)
    t1 = 1.0
    decay_true = math.exp(-t1)
    # y' = -y + cos(t), y(0) = 0 → y(t) = 0.5 * (sin t + cos t - exp(-t))
    forced_true = 0.5 * (math.sin(t1) + math.cos(t1) - math.exp(-t1))
    g["ode/scalar.json"] = {
        "decay_analytic":  decay_true,
        "forced_analytic": forced_true,
        "rk4_cases": [
            {"label": "decay_rk4_n10",    "n_steps": 10,   "expected_abs_err": 5e-7},
            {"label": "decay_rk4_n100",   "n_steps": 100,  "expected_abs_err": 1e-10},
            {"label": "decay_rk4_n1000",  "n_steps": 1000, "expected_abs_err": 1e-13},
        ],
        "euler_cases": [
            {"label": "decay_euler_n100",  "n_steps": 100,  "expected_abs_err": 2.5e-3},
            {"label": "decay_euler_n1000", "n_steps": 1000, "expected_abs_err": 2.5e-4},
        ],
        **TOL["ode/scalar"],
    }
    return g


def goldens_stats() -> dict[str, dict]:
    # Scipy-derived goldens for the fixed test vector [0,1,2,3,4,5,6] and a random vector.
    from scipy.stats import skew, kurtosis, pearsonr
    g = {}
    v = np.array([0.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0], dtype=np.float64)
    g["stats/vector.json"] = {
        "v": v.tolist(),
        "mean":        float(np.mean(v)),
        "var_ddof0":   float(np.var(v, ddof=0)),
        "var_ddof1":   float(np.var(v, ddof=1)),
        "std_ddof0":   float(np.std(v, ddof=0)),
        "std_ddof1":   float(np.std(v, ddof=1)),
        "skew":        float(skew(v, bias=True)),
        "kurtosis":    float(kurtosis(v, bias=True, fisher=True)),
        "median":      float(np.median(v)),
        **TOL["stats/vector"],
    }
    return g


def check_close(have: float, want: float, abs_tol: float, rel_tol: float) -> bool:
    if math.isnan(have) or math.isnan(want):
        return False
    return abs(have - want) <= max(abs_tol, rel_tol * abs(want))


def check_goldens() -> int:
    drift = 0
    for cat, gen in (("special", goldens_special),
                     ("distributions", goldens_distributions),
                     ("linalg", goldens_linalg),
                     ("roots", goldens_roots),
                     ("ode", goldens_ode),
                     ("stats", goldens_stats)):
        for rel, fresh in gen().items():
            path = GOLDENS / rel
            if not path.exists():
                print(f"MISSING {rel}")
                drift += 1
                continue
            existing = json.loads(path.read_text())
            tol_abs = existing.get("abs", 1e-9)
            tol_rel = existing.get("rel", 1e-9)
            for k, v in fresh.items():
                if k in ("abs", "rel", "params", "inputs", "inputs_x", "inputs_q",
                          "matrices", "A_3x4", "B_4x2", "v", "w",
                          "cases", "rk4_cases", "euler_cases"):
                    if existing.get(k) != v:
                        print(f"DRIFT {rel}:{k} (inputs changed)")
                        drift += 1
                    continue
                ev = existing.get(k)
                if ev is None:
                    continue
                if isinstance(v, list):
                    try:
                        flat_fresh = np.array(v, dtype=float).ravel().tolist()
                        flat_exist = np.array(ev, dtype=float).ravel().tolist()
                    except (TypeError, ValueError):
                        continue
                    for a, b in zip(flat_fresh, flat_exist):
                        if not check_close(a, b, tol_abs, tol_rel):
                            print(f"DRIFT {rel}:{k} have={b} fresh={a}")
                            drift += 1
                            break
                elif isinstance(v, (int, float)):
                    if not check_close(v, ev, tol_abs, tol_rel):
                        print(f"DRIFT {rel}:{k} have={ev} fresh={v}")
                        drift += 1
    return drift


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true",
                    help="Verify checked-in goldens still match scipy output.")
    args = ap.parse_args()

    if args.check:
        drift = check_goldens()
        if drift:
            print(f"\n{drift} drift(s) detected; regenerate with: python scripts/gen_goldens.py")
            return 1
        print("goldens OK")
        return 0

    all_goldens = {}
    all_goldens.update(goldens_special())
    all_goldens.update(goldens_distributions())
    all_goldens.update(goldens_linalg())
    all_goldens.update(goldens_roots())
    all_goldens.update(goldens_ode())
    all_goldens.update(goldens_stats())
    for rel, data in all_goldens.items():
        write_json(GOLDENS / rel, data)
        print(f"wrote {rel}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
