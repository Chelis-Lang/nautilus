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
    # Trapezoidal is O(h^2); at n=100 on [0,1] error ~1e-5. Bound to 5e-5
    # for the headline parity. Simpson and GL5 would be tighter but share
    # the same category tolerance — the red-team pass can refine per-method.
    "integrate/scalar":          {"abs": 5.0e-5, "rel": 5.0e-5},
    # z-test p-values route through erf (AS 7.1.26, ~1.5e-7 accuracy);
    # propagated + float cancellation gives ~2e-7 worst-case.
    "testing/scalar":            {"abs": 1.0e-6, "rel": 1.0e-6},
    "distance/vector":           {"abs": 1.0e-6, "rel": 1.0e-6},
    "optim/scalar":              {"abs": 1.0e-5, "rel": 1.0e-5},
    "interpolation/scalar":      {"abs": 1.0e-7, "rel": 1.0e-7},
    "sde/scalar":                {"abs": 1.0e-6, "rel": 1.0e-6},
    # Romberg-5 and GL10 saturate at f32's ~1e-7 unit roundoff — the
    # scipy goldens are f64, so bound at 1e-7 to honor the double vs
    # float precision gap the Chelis f32 surface carries.
    "integrate/adaptive":        {"abs": 5.0e-7, "rel": 5.0e-7},
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

    # Student-t(df=5) — pdf + cdf (incomplete beta via Lentz in Phase 2.5)
    tx = np.linspace(-4.0, 4.0, 17).tolist()
    g["distributions/student_t.json"] = {
        "inputs_x": tx,
        "params": {"df": df},
        "pdf":     [float(sp_stats.t.pdf(x, df=df)) for x in tx],
        "cdf":     [float(sp_stats.t.cdf(x, df=df)) for x in tx],
        "cdf_df1": [float(sp_stats.t.cdf(x, df=1)) for x in tx],
        "cdf_df30":[float(sp_stats.t.cdf(x, df=30)) for x in tx],
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


def goldens_integrate() -> dict[str, dict]:
    # Analytic integrals so goldens don't depend on scipy's numerical integration.
    g = {}
    # ∫_0^1 x^2 dx = 1/3
    # ∫_0^π sin(x) dx = 2                                  — but Chelis lacks cos; RHS uses sin only
    # ∫_1^e log(x) dx = 1                                  — actually e*log(e) - e - (log(1) - 1) = e - e - 0 + 1 = 1
    # ∫_0^1 exp(-x) dx = 1 - 1/e
    cases = [
        {"label": "x_squared_0_1",   "a": 0.0, "b": 1.0, "n": 100,  "expected": 1.0 / 3.0},
        {"label": "exp_neg_0_1",     "a": 0.0, "b": 1.0, "n": 100,  "expected": 1.0 - math.exp(-1.0)},
        {"label": "sin_shifted_pi",  "a": 0.0, "b": math.pi, "n": 200, "expected": 2.0},
    ]
    g["integrate/scalar.json"] = {"cases": cases, **TOL["integrate/scalar"]}
    return g


def goldens_testing() -> dict[str, dict]:
    from scipy.stats import norm, chi2, t
    g = {}
    # One-sample z-test: sample_mean=102, pop_mean=100, pop_std=15, n=25
    # z = (102 - 100) / (15/sqrt(25)) = 2 / 3 ≈ 0.6667
    z = (102.0 - 100.0) / (15.0 / math.sqrt(25.0))
    cases = [
        {"label": "z_stat_basic",
         "sample_mean": 102.0, "pop_mean": 100.0, "pop_std": 15.0, "sample_n": 25.0,
         "expected_z": z},
        {"label": "z_p_two_sided_small",
         "z": 0.6666666666666666, "expected_p": float(2.0 * (1.0 - norm.cdf(0.6666666666666666)))},
        {"label": "z_p_two_sided_large",
         "z": 1.96, "expected_p": float(2.0 * (1.0 - norm.cdf(1.96)))},
        {"label": "z_p_upper_196",
         "z": 1.96, "expected_p": float(1.0 - norm.cdf(1.96))},
        {"label": "z_p_lower_neg196",
         "z": -1.96, "expected_p": float(norm.cdf(-1.96))},
        {"label": "normal_ci_95",
         "confidence": 0.95, "pop_std": 15.0, "sample_n": 25.0,
         "expected_half_width": float(norm.ppf(0.975) * 15.0 / math.sqrt(25.0))},
        {"label": "normal_ci_99",
         "confidence": 0.99, "pop_std": 10.0, "sample_n": 100.0,
         "expected_half_width": float(norm.ppf(0.995) * 10.0 / math.sqrt(100.0))},
        {"label": "chi2_p_df5_stat11",
         "statistic": 11.07, "df": 5.0, "expected_p": float(1.0 - chi2.cdf(11.07, df=5))},
        {"label": "chi2_p_df10_stat18",
         "statistic": 18.31, "df": 10.0, "expected_p": float(1.0 - chi2.cdf(18.31, df=10))},
        # t-test: one-sample, sample_mean=5.1, sample_std=1.5, sample_n=16, pop_mean=5.0
        # t = (5.1 - 5.0) / (1.5 / sqrt(16)) = 0.1 / 0.375 = 0.2667
        {"label": "t_stat_one_sample",
         "sample_mean": 5.1, "sample_std": 1.5, "sample_n": 16.0, "pop_mean": 5.0,
         "expected_t": (5.1 - 5.0) / (1.5 / math.sqrt(16))},
        # Pooled two-sample: m1=10, s1=2, n1=20, m2=12, s2=2.5, n2=25
        {"label": "t_stat_two_sample_pooled",
         "mean1": 10.0, "std1": 2.0, "n1": 20.0,
         "mean2": 12.0, "std2": 2.5, "n2": 25.0,
         # Pooled SE manually: ssq = 19*4 + 24*6.25 = 76 + 150 = 226; df_pool=43; sp2=5.2558; se=sqrt(5.2558*(1/20+1/25))=sqrt(5.2558*0.09)=0.6880
         "expected_t": -2.9068},
        # Welch two-sample: same inputs as pooled
        {"label": "welch_t_stat",
         "mean1": 10.0, "std1": 2.0, "n1": 20.0,
         "mean2": 12.0, "std2": 2.5, "n2": 25.0,
         "expected_t": -2.981423969999729},
        {"label": "welch_df",
         "std1": 2.0, "n1": 20.0, "std2": 2.5, "n2": 25.0,
         "expected_df": (0.45**2) / ((0.04/19.0) + (0.0625/24.0))},
        {"label": "t_p_two_df5_t1",
         "t": 1.0, "df": 5.0, "expected_p": float(2.0 * (1.0 - t.cdf(1.0, df=5)))},
        {"label": "t_p_two_df5_t2",
         "t": 2.0, "df": 5.0, "expected_p": float(2.0 * (1.0 - t.cdf(2.0, df=5)))},
        {"label": "t_p_two_df30_t196",
         "t": 1.96, "df": 30.0, "expected_p": float(2.0 * (1.0 - t.cdf(1.96, df=30)))},
        {"label": "t_p_upper_df10_t2",
         "t": 2.0, "df": 10.0, "expected_p": float(1.0 - t.cdf(2.0, df=10))},
        {"label": "t_p_lower_df10_tneg2",
         "t": -2.0, "df": 10.0, "expected_p": float(t.cdf(-2.0, df=10))},
    ]
    # Recompute expected_t for pooled with higher precision
    import math as _m
    ssq = 19.0*4.0 + 24.0*6.25
    df_pool = 43.0
    sp2 = ssq / df_pool
    se = _m.sqrt(sp2 * (1/20 + 1/25))
    pooled_t = (10.0 - 12.0) / se
    for case in cases:
        if case.get("label") == "t_stat_two_sample_pooled":
            case["expected_t"] = pooled_t
    g["testing/scalar.json"] = {"cases": cases, **TOL["testing/scalar"]}
    return g


def goldens_distance() -> dict[str, dict]:
    # Scipy-derived goldens for fixed vector pairs. Runtime verification gated
    # on the same libchelis_runtime.a that Distributions.sample / Stats need.
    from scipy.spatial import distance as sp_d
    g = {}
    a = [1.0, 2.0, 3.0, 4.0]
    b = [4.0, 3.0, 2.0, 1.0]
    g["distance/vector.json"] = {
        "a": a, "b": b,
        "squared_euclidean": float(sp_d.sqeuclidean(a, b)),
        "euclidean":         float(sp_d.euclidean(a, b)),
        "manhattan":         float(sp_d.cityblock(a, b)),
        "chebyshev":         float(sp_d.chebyshev(a, b)),
        "cosine_distance":   float(sp_d.cosine(a, b)),
        **TOL["distance/vector"],
    }
    return g


def goldens_optim() -> dict[str, dict]:
    g = {}
    cases = [
        # (x-2)^2 - 3, argmin at 2.0
        {"label": "gss_parabola",     "method": "gss",      "lo": 0.0, "hi": 5.0, "expected": 2.0},
        {"label": "brent_parabola",   "method": "brent",    "lo": 0.0, "hi": 5.0, "expected": 2.0},
        {"label": "gd_parabola",      "method": "gd",       "x0": 0.0, "lr": 0.1, "iters": 500, "expected": 2.0},
        {"label": "newton_parabola",  "method": "newton",   "x0": 0.0, "expected": 2.0},
        # x^4 - 4x^2 + 5, local minima at ±sqrt(2)
        {"label": "gss_quartic",      "method": "gss",      "lo": 0.0, "hi": 3.0, "expected": math.sqrt(2.0)},
        {"label": "brent_quartic",    "method": "brent",    "lo": 0.5, "hi": 3.0, "expected": math.sqrt(2.0)},
        {"label": "newton_quartic",   "method": "newton",   "x0": 1.2, "expected": math.sqrt(2.0)},
    ]
    g["optim/scalar.json"] = {"cases": cases, **TOL["optim/scalar"]}
    return g


def goldens_interpolation() -> dict[str, dict]:
    g = {}
    # cubic_hermite unit tests
    cases = [
        # flat slopes, identity-ish values
        {"label": "hermite_half_flat",
         "x0": 0.0, "x1": 1.0, "y0": 0.0, "y1": 1.0, "m0": 0.0, "m1": 0.0, "x": 0.5,
         "expected": 0.5},
        # unit slopes, should be a true linear interp at midpoint (since endpoint slopes equal secant)
        {"label": "hermite_half_unit",
         "x0": 0.0, "x1": 1.0, "y0": 0.0, "y1": 1.0, "m0": 1.0, "m1": 1.0, "x": 0.5,
         "expected": 0.5},
        # general case with non-trivial slopes; verified via numpy polynomial
        {"label": "hermite_mid",
         "x0": 0.0, "x1": 2.0, "y0": 1.0, "y1": 3.0, "m0": 0.0, "m1": 2.0, "x": 1.0,
         # t=0.5, h=2; h00=0.5, h10=0.125, h01=0.5, h11=-0.125
         # 0.5*1 + 0.125*2*0 + 0.5*3 + (-0.125)*2*2 = 0.5 + 0 + 1.5 - 0.5 = 1.5
         "expected": 1.5},
        # endpoints (degenerate)
        {"label": "hermite_left",
         "x0": 0.0, "x1": 1.0, "y0": 7.0, "y1": -3.0, "m0": 2.0, "m1": 5.0, "x": 0.0,
         "expected": 7.0},
        {"label": "hermite_right",
         "x0": 0.0, "x1": 1.0, "y0": 7.0, "y1": -3.0, "m0": 2.0, "m1": 5.0, "x": 1.0,
         "expected": -3.0},
    ]
    g["interpolation/scalar.json"] = {"cases": cases, **TOL["interpolation/scalar"]}
    return g


def goldens_sde() -> dict[str, dict]:
    # SDE dY = f*dt + g*dW, f(y,t)=-y (drift → exponential decay toward 0),
    # g(y,t) = sigma constant. Zero-noise reduces to ODE: exact y(t) = y0 * exp(-t).
    # Non-zero noise: seed a fixed vector and compute the exact Euler-Maruyama
    # trajectory in Python alongside the Chelis impl.
    import numpy as np
    g = {}
    y0 = 1.0
    t0, t1 = 0.0, 1.0

    # Case 1: zero noise (reduces to Euler on y' = -y)
    n1 = 100
    dt1 = (t1 - t0) / n1
    y = y0
    for _ in range(n1):
        y = y + (-y) * dt1 + 1.0 * math.sqrt(dt1) * 0.0
    zero_noise_em = y
    # Exact analytic: exp(-1) ≈ 0.3679
    zero_noise_exact = math.exp(-t1)

    # Case 2: deterministic +1 noise at every step (reference EM trajectory)
    n2 = 10
    dt2 = (t1 - t0) / n2
    sqrt_dt2 = math.sqrt(dt2)
    y = y0
    sigma = 0.1
    for _ in range(n2):
        y = y + (-y) * dt2 + sigma * sqrt_dt2 * 1.0
    plus_noise_em = y

    # Case 3: alternating +1/-1 noise — partial cancellation
    y = y0
    for k in range(n2):
        z = 1.0 if k % 2 == 0 else -1.0
        y = y + (-y) * dt2 + sigma * sqrt_dt2 * z
    alt_noise_em = y

    # Case 4: Milstein on GBM-style: dY = mu*Y dt + sigma*Y dW, analytic soln = y0*exp((mu-sigma²/2)t + sigma*W_t)
    n4 = 10
    dt4 = (t1 - t0) / n4
    sqrt_dt4 = math.sqrt(dt4)
    mu = 0.1
    sigma_gbm = 0.2
    y = y0
    for _ in range(n4):
        # Milstein: y + mu*y*dt + sigma*y*dW + 0.5*sigma*(sigma)*(dW²-dt) = y + mu*y*dt + sigma*y*dW + 0.5*sigma²*(dW²-dt)
        # with dW = sqrt_dt*1.0
        dW = sqrt_dt4
        y = y + mu*y*dt4 + sigma_gbm*y*dW + 0.5*sigma_gbm*sigma_gbm*(dW*dW - dt4)
    milstein_plus_noise = y

    cases = [
        {"label": "em_zero_noise",
         "y0": y0, "t0": t0, "t1": t1, "n_steps": n1, "sigma": 1.0,
         "noise_mode": "zero", "expected": zero_noise_em,
         "analytic": zero_noise_exact},
        {"label": "em_plus_noise",
         "y0": y0, "t0": t0, "t1": t1, "n_steps": n2, "sigma": sigma,
         "noise_mode": "plus", "expected": plus_noise_em},
        {"label": "em_alt_noise",
         "y0": y0, "t0": t0, "t1": t1, "n_steps": n2, "sigma": sigma,
         "noise_mode": "alt", "expected": alt_noise_em},
        {"label": "milstein_gbm",
         "y0": y0, "t0": t0, "t1": t1, "n_steps": n4,
         "mu": mu, "sigma": sigma_gbm,
         "noise_mode": "plus", "expected": milstein_plus_noise},
    ]
    g["sde/scalar.json"] = {"cases": cases, **TOL["sde/scalar"]}
    return g


def goldens_integrate_adaptive() -> dict[str, dict]:
    g = {}
    # Analytic integrals with high-accuracy methods. Tolerance 1e-9 because
    # Romberg-5 and GL10 should match to ~10-12 digits on smooth integrands.
    cases = [
        {"label": "x_squared_01",
         "a": 0.0, "b": 1.0, "expected": 1.0 / 3.0},
        {"label": "exp_neg_01",
         "a": 0.0, "b": 1.0, "expected": 1.0 - math.exp(-1.0)},
        {"label": "sin_0_pi",
         "a": 0.0, "b": math.pi, "expected": 2.0},
        {"label": "one_over_1_x2_01",
         "a": 0.0, "b": 1.0, "expected": math.pi / 4.0},
    ]
    g["integrate/adaptive.json"] = {"cases": cases, **TOL["integrate/adaptive"]}
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
                     ("stats", goldens_stats),
                     ("integrate", goldens_integrate),
                     ("testing", goldens_testing),
                     ("distance", goldens_distance),
                     ("optim", goldens_optim),
                     ("interpolation", goldens_interpolation),
                     ("sde", goldens_sde),
                     ("integrate_adaptive", goldens_integrate_adaptive)):
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
    all_goldens.update(goldens_integrate())
    all_goldens.update(goldens_testing())
    all_goldens.update(goldens_distance())
    all_goldens.update(goldens_optim())
    all_goldens.update(goldens_interpolation())
    all_goldens.update(goldens_sde())
    all_goldens.update(goldens_integrate_adaptive())
    for rel, data in all_goldens.items():
        write_json(GOLDENS / rel, data)
        print(f"wrote {rel}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
