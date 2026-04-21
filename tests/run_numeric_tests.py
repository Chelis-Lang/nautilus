#!/usr/bin/env python3
"""End-to-end numerical test harness for Nautilus P0.

Workflow per test:
  1. Concatenate src/special.ch + src/distributions.ch + src/linalg.ch with
     module/import/export directives stripped.
  2. Append a no-op `main` so chelis build emits a standalone C compilation
     unit (no runtime ABI wrapping).
  3. Run chelis build → C.
  4. Patch Chelis's emitted `main` symbol so we can link our own C driver.
  5. Compile + link with a generated driver that exercises every scalar
     function at the inputs listed in tests/goldens/.
  6. Parse the driver output and compare against goldens within per-function
     tolerance.

This bypasses the broken `chelis eval --file` path — the bare scalar
functions still build through the normal chelis C backend and link
against the shipped runtime archive.

The scalar binary covers Nautilus.Special and Nautilus.Distributions.
Separate binaries in this same harness cover the scalar solver modules
and the tensor-path LinAlg / Stats / Distance / SDE / Interpolation /
CurveFit surface. Clean HEAD on the validated `chelis v0.1.13` toolchain
passes 895 / 895 numerical assertions.
"""
from __future__ import annotations

import json
import math
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
SRC = REPO / "src"
GOLDENS = REPO / "tests" / "goldens"
sys.path.insert(0, str(REPO))

from scripts.chelis_toolchain import resolve_chelis_bin


CHELIS = resolve_chelis_bin()


def native_link_cmd(binary: Path, sources: list[Path], out_dir: Path) -> list[str]:
    """Choose a host C compiler/link flag set that works on this platform."""
    cc_env = os.environ.get("CC")
    if cc_env:
        prefix = [cc_env, "-O2"]
    elif sys.platform == "darwin":
        libomp = Path("/opt/homebrew/opt/libomp")
        if libomp.exists():
            prefix = [
                "clang",
                "-O2",
                "-Xpreprocessor",
                "-fopenmp",
                f"-I{libomp / 'include'}",
                f"-L{libomp / 'lib'}",
            ]
        else:
            prefix = ["clang", "-O2"]
    else:
        prefix = ["gcc", "-O2", "-fopenmp"]

    cmd = [
        *prefix,
        "-o",
        str(binary),
        *(str(source) for source in sources),
        "-I",
        str(out_dir),
        "-L",
        str(out_dir),
        "-lchelis_runtime",
        "-lm",
        "-lpthread",
    ]
    if sys.platform == "darwin" and Path("/opt/homebrew/opt/libomp").exists() and "clang" in prefix[0]:
        cmd.append("-lomp")
    return cmd


def strip_module(src: str) -> str:
    src = re.sub(r"^module .*\n", "", src, flags=re.M)
    src = re.sub(r"^import .*\n", "", src, flags=re.M)
    src = re.sub(r"^export \([^)]*\)\s*\n", "", src, flags=re.M | re.S)
    return src


def chelis_build(bare_ch: Path, outdir: Path) -> Path:
    if outdir.exists():
        shutil.rmtree(outdir)
    proc = subprocess.run(
        [CHELIS, "build", str(bare_ch), "-o", str(outdir)],
        capture_output=True, text=True,
    )
    msg = (proc.stdout + proc.stderr).strip()
    if "cannot find libchelis_runtime.a" not in msg and proc.returncode != 0:
        raise SystemExit(f"chelis build failed: {msg}")
    c_file = outdir / f"{bare_ch.stem}.c"
    h_file = outdir / f"{bare_ch.stem}.h"
    if not c_file.exists():
        raise SystemExit(f"no C output produced: {c_file}")
    txt = c_file.read_text()
    txt = txt.replace("double main", "double chelis_entry")
    c_file.write_text(txt)
    if h_file.exists():
        ht = h_file.read_text()
        ht = ht.replace("double main", "double chelis_entry")
        h_file.write_text(ht)
    return c_file


SIGNATURES = [
    # special
    ("erf",        ("double",), "double"),
    ("erfinv",     ("double",), "double"),
    ("log_gamma",  ("double",), "double"),
    ("digamma",    ("double",), "double"),
    ("beta",       ("double", "double"), "double"),
    ("lbeta",      ("double", "double"), "double"),
    ("trigamma",   ("double",), "double"),
    ("bessel_i0",  ("double",), "double"),
    ("bessel_i1",  ("double",), "double"),
    ("bessel_k0",  ("double",), "double"),
    ("bessel_k1",  ("double",), "double"),
    ("bessel_j0",  ("double",), "double"),
    ("bessel_j1",  ("double",), "double"),
    ("bessel_y0",  ("double",), "double"),
    ("bessel_y1",  ("double",), "double"),
    ("airy_ai",    ("double",), "double"),
    ("airy_bi",    ("double",), "double"),
    ("ellipk",     ("double",), "double"),
    ("ellipe",     ("double",), "double"),
    # distributions
    ("normal_pdf",        ("double", "double", "double"), "double"),
    ("normal_cdf",        ("double", "double", "double"), "double"),
    ("normal_inv_cdf",    ("double", "double", "double"), "double"),
    ("uniform_pdf",       ("double", "double", "double"), "double"),
    ("uniform_cdf",       ("double", "double", "double"), "double"),
    ("uniform_inv_cdf",   ("double", "double", "double"), "double"),
    ("exponential_pdf",       ("double", "double"), "double"),
    ("exponential_cdf",       ("double", "double"), "double"),
    ("exponential_inv_cdf",   ("double", "double"), "double"),
    ("lognormal_pdf",       ("double", "double", "double"), "double"),
    ("lognormal_cdf",       ("double", "double", "double"), "double"),
    ("lognormal_inv_cdf",   ("double", "double", "double"), "double"),
    ("gamma_pdf",        ("double", "double", "double"), "double"),
    ("gamma_cdf",        ("double", "double", "double"), "double"),
    ("gamma_inv_cdf",    ("double", "double", "double"), "double"),
    ("chi_squared_pdf",     ("double", "double"), "double"),
    ("chi_squared_cdf",     ("double", "double"), "double"),
    ("chi_squared_inv_cdf", ("double", "double"), "double"),
    ("student_t_pdf",       ("double", "double"), "double"),
    ("student_t_cdf",       ("double", "double"), "double"),
    ("poisson_pmf",         ("double", "double"), "double"),
    ("poisson_cdf",         ("double", "double"), "double"),
    ("binomial_pmf",        ("double", "double", "double"), "double"),
    ("binomial_cdf",        ("double", "double", "double"), "double"),
    ("beta_pdf",            ("double", "double", "double"), "double"),
    ("beta_cdf",            ("double", "double", "double"), "double"),
    ("f_pdf",               ("double", "double", "double"), "double"),
    ("f_cdf",               ("double", "double", "double"), "double"),
    ("weibull_pdf",         ("double", "double", "double"), "double"),
    ("weibull_cdf",         ("double", "double", "double"), "double"),
    ("weibull_inv_cdf",     ("double", "double", "double"), "double"),
]


def driver_c() -> str:
    decls = "\n".join(
        f"{ret} {name}({', '.join(args)});"
        for name, args, ret in SIGNATURES
    )
    return f"""\
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
{decls}

int main(int argc, char** argv) {{
    if (argc < 2) {{ fprintf(stderr, "usage: driver FN ARG...\\n"); return 1; }}
    const char* fn = argv[1];
    double a[8] = {{0}};
    int n_args = argc - 2;
    for (int i = 0; i < n_args && i < 8; i++) a[i] = atof(argv[2+i]);
""" + "".join(
        f'    if (!strcmp(fn, "{name}")) {{ printf("%.10g\\n", {name}({", ".join(f"a[{i}]" for i in range(len(args)))})); return 0; }}\n'
        for name, args, _ in SIGNATURES
    ) + """\
    fprintf(stderr, "unknown function: %s\\n", fn);
    return 2;
}
"""


# v0.1.5+ ships lib/libchelis_runtime.a and include/chelis_runtime.h in
# the release tarball, and `chelis build` now copies both into its output
# directory alongside the generated .c / .h files. The previous
# RUNTIME_STUBS block (hand-written NULL-returning stubs for every
# chelis_* symbol the emitted C happened to reference) is no longer
# required — we link against the real archive instead.


def build_native_binary() -> Path:
    # Bundle only Special + Distributions: linalg.ch / roots.ch / ode.ch / stats.ch
    # need runtime symbols or function-pointer call paths that have their own
    # integration gates. LinAlg correctness is covered by the type-level api
    # smoke check (src/apismoke.ch). Roots + ODE are covered by build_p1_binary().
    bare = "\n".join(
        strip_module((SRC / f).read_text())
        for f in ("special.ch", "distributions.ch")
    ) + "\ndef main() -> f32 = erf(cast(0.5, f32))\n"
    workdir = Path(tempfile.mkdtemp(prefix="nautilus-num-"))
    bare_ch = workdir / "nautilus_bare.ch"
    bare_ch.write_text(bare)
    chelis_build(bare_ch, workdir / "out")
    c_file = workdir / "out" / "nautilus_bare.c"
    drv_c = workdir / "driver.c"
    drv_c.write_text(driver_c())
    binary = workdir / "nautilus_test_bin"
    out_dir = workdir / "out"
    cc = subprocess.run(
        native_link_cmd(binary, [c_file, drv_c], out_dir),
        capture_output=True, text=True,
    )
    if cc.returncode != 0:
        raise SystemExit(f"gcc failed: {cc.stderr}")
    return binary


P1_TEST_HELPERS_CH = r"""
def p1_poly1(x: f32) -> f32 = {
  x2 = mul(x, x)
  sub(x2, cast(2.0, f32))
}
def p1_dpoly1(x: f32) -> f32 = mul(cast(2.0, f32), x)
def p1_poly2(x: f32) -> f32 = {
  x2 = mul(x, x)
  x3 = mul(x2, x)
  sub(sub(x3, mul(cast(2.0, f32), x)), cast(5.0, f32))
}
def p1_dpoly2(x: f32) -> f32 = {
  x2 = mul(x, x)
  sub(mul(cast(3.0, f32), x2), cast(2.0, f32))
}
def p1_cos_minus_x(x: f32) -> f32 = sub(sin(add(x, cast(1.5707963267948966, f32))), x)
def p1_dcos_minus_x(x: f32) -> f32 = sub(neg(sin(x)), cast(1.0, f32))
def p1_decay(y: f32, t: f32) -> f32 = neg(y)
def p1_decay2(y: f32, t: f32) -> f32 = neg(mul(cast(2.0, f32), y))

def p2_x_squared(x: f32) -> f32 = mul(x, x)
def p2_exp_neg(x: f32) -> f32 = {
  nx = neg(x)
  exp(nx)
}
def p2_sin_shifted(x: f32) -> f32 = sin(x)

def opt_parab(x: f32) -> f32 = {
  d = sub(x, cast(2.0, f32))
  d2 = mul(d, d)
  sub(d2, cast(3.0, f32))
}
def opt_dparab(x: f32) -> f32 = mul(cast(2.0, f32), sub(x, cast(2.0, f32)))
def opt_ddparab(x: f32) -> f32 = cast(2.0, f32)

def opt_quartic(x: f32) -> f32 = {
  x2 = mul(x, x)
  x4 = mul(x2, x2)
  four_x2 = mul(cast(4.0, f32), x2)
  add(sub(x4, four_x2), cast(5.0, f32))
}
def opt_dquartic(x: f32) -> f32 = {
  x2 = mul(x, x)
  x3 = mul(x2, x)
  sub(mul(cast(4.0, f32), x3), mul(cast(8.0, f32), x))
}
def opt_ddquartic(x: f32) -> f32 = {
  x2 = mul(x, x)
  sub(mul(cast(12.0, f32), x2), cast(8.0, f32))
}

def sde_drift(y: f32, t: f32) -> f32 = neg(y)
def sde_diff_const(y: f32, t: f32) -> f32 = cast(0.1, f32)
def sde_drift_gbm(y: f32, t: f32) -> f32 = mul(cast(0.1, f32), y)
def sde_diff_gbm(y: f32, t: f32) -> f32 = mul(cast(0.2, f32), y)
def sde_dg_dy_gbm(y: f32, t: f32) -> f32 = cast(0.2, f32)

def sde_noise_zero_100() -> tensor[100, f32] =
  to_tensor(map(fn (i: int64) -> cast(0.0, f32), range(cast(0, int64), cast(100, int64))))
def sde_noise_plus_10() -> tensor[10, f32] =
  to_tensor(map(fn (i: int64) -> cast(1.0, f32), range(cast(0, int64), cast(10, int64))))
def sde_noise_alt_10() -> tensor[10, f32] =
  to_tensor(map(fn (i: int64) ->
    if eq(mod(i, cast(2, int64)), cast(0, int64)) then cast(1.0, f32) else cast(-1.0, f32),
    range(cast(0, int64), cast(10, int64))))

def sde_em_zero_noise() -> f32 =
  euler_maruyama_fixed(sde_drift, sde_diff_const,
    cast(1.0, f32), cast(0.0, f32), cast(1.0, f32), sde_noise_zero_100())
def sde_em_plus_noise() -> f32 =
  euler_maruyama_fixed(sde_drift, sde_diff_const,
    cast(1.0, f32), cast(0.0, f32), cast(1.0, f32), sde_noise_plus_10())
def sde_em_alt_noise() -> f32 =
  euler_maruyama_fixed(sde_drift, sde_diff_const,
    cast(1.0, f32), cast(0.0, f32), cast(1.0, f32), sde_noise_alt_10())
def sde_milstein_gbm() -> f32 =
  milstein_fixed(sde_drift_gbm, sde_diff_gbm, sde_dg_dy_gbm,
    cast(1.0, f32), cast(0.0, f32), cast(1.0, f32), sde_noise_plus_10())

def int_x_squared(x: f32) -> f32 = mul(x, x)
def int_exp_neg(x: f32) -> f32 = {
  nx = neg(x)
  exp(nx)
}
def int_sin_x(x: f32) -> f32 = sin(x)
def int_inv_1_x2(x: f32) -> f32 = {
  x2 = mul(x, x)
  div(cast(1.0, f32), add(cast(1.0, f32), x2))
}

def p4_one(x: f32) -> f32 = cast(1.0, f32)
def p4_x(x: f32) -> f32 = x
def p4_x2(x: f32) -> f32 = mul(x, x)
def p4_x3(x: f32) -> f32 = mul(mul(x, x), x)
def p4_x4(x: f32) -> f32 = {
  x2 = mul(x, x)
  mul(x2, x2)
}
"""

P1_DRIVER_C = r"""
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <math.h>
double bisection(double (*f)(double), double, double, double, int64_t);
double newton(double (*f)(double), double (*df)(double), double, double, int64_t);
double brent(double (*f)(double), double, double, double, int64_t);
double euler_solve(double (*f)(double, double), double, double, double, int64_t);
double rk4_solve(double (*f)(double, double), double, double, double, int64_t);
double rk45_adaptive_solve(double (*f)(double, double), double, double, double, double, double);
double trapezoidal(double (*f)(double), double, double, int64_t);
double simpsons(double (*f)(double), double, double, int64_t);
double gauss_legendre_5(double (*f)(double), double, double, int64_t);
double z_statistic(double, double, double, double);
double z_p_value_two_sided(double);
double z_p_value_upper(double);
double z_p_value_lower(double);
double normal_ci_half_width(double, double, double);
double chi_squared_p_value(double, double);
double t_statistic_one_sample(double, double, double, double);
double t_statistic_two_sample_pooled(double, double, double, double, double, double);
double welch_t_statistic(double, double, double, double, double, double);
double welch_t_df(double, double, double, double);
double t_p_value_two_sided(double, double);
double t_p_value_upper(double, double);
double t_p_value_lower(double, double);
double golden_section_search(double (*)(double), double, double, double, int64_t);
double brent_minimize(double (*)(double), double, double, double, int64_t);
double gradient_descent_1d(double (*)(double), double (*)(double), double, double, int64_t);
double newton_minimize_1d(double (*)(double), double (*)(double), double (*)(double), double, double, int64_t);
double cubic_hermite(double, double, double, double, double, double, double);
double adaptive_simpson(double (*f)(double), double, double, double, int64_t);
double romberg_5(double (*f)(double), double, double);
double gauss_legendre_10(double (*f)(double), double, double);
double gauss_hermite_10(double (*f)(double));
double gauss_laguerre_10(double (*f)(double));

double p4_one(double), p4_x(double), p4_x2(double), p4_x3(double), p4_x4(double);

double opt_parab(double), opt_dparab(double), opt_ddparab(double);
double opt_quartic(double), opt_dquartic(double), opt_ddquartic(double);

double sde_em_zero_noise(void);
double sde_em_plus_noise(void);
double sde_em_alt_noise(void);
double sde_milstein_gbm(void);

double int_x_squared(double), int_exp_neg(double), int_sin_x(double), int_inv_1_x2(double);

double p1_poly1(double), p1_dpoly1(double);
double p1_poly2(double), p1_dpoly2(double);
double p1_cos_minus_x(double), p1_dcos_minus_x(double);
double p1_decay(double, double);
double p1_decay2(double, double);
double p2_x_squared(double), p2_exp_neg(double), p2_sin_shifted(double);

int main(int argc, char** argv) {
    if (argc < 2) { fprintf(stderr, "usage: p1_driver CASE [...]\n"); return 1; }
    const char* c = argv[1];
    if (!strcmp(c, "sqrt2_bisect"))  { printf("%.15g\n", bisection(p1_poly1, 1.0, 2.0, 1e-10, 200)); return 0; }
    if (!strcmp(c, "sqrt2_brent"))   { printf("%.15g\n", brent(p1_poly1, 1.0, 2.0, 1e-10, 200)); return 0; }
    if (!strcmp(c, "sqrt2_newton"))  { printf("%.15g\n", newton(p1_poly1, p1_dpoly1, 1.5, 1e-12, 50)); return 0; }
    if (!strcmp(c, "cubic_brent"))   { printf("%.15g\n", brent(p1_poly2, 2.0, 3.0, 1e-10, 200)); return 0; }
    if (!strcmp(c, "cubic_newton"))  { printf("%.15g\n", newton(p1_poly2, p1_dpoly2, 2.0, 1e-12, 50)); return 0; }
    if (!strcmp(c, "cosmx_newton"))  { printf("%.15g\n", newton(p1_cos_minus_x, p1_dcos_minus_x, 0.5, 1e-12, 50)); return 0; }
    if (!strcmp(c, "decay_rk4"))     { int64_t n = atoll(argv[2]); printf("%.15g\n", rk4_solve(p1_decay, 1.0, 0.0, 1.0, n)); return 0; }
    if (!strcmp(c, "decay_euler"))   { int64_t n = atoll(argv[2]); printf("%.15g\n", euler_solve(p1_decay, 1.0, 0.0, 1.0, n)); return 0; }
    if (!strcmp(c, "decay_rk45"))    { printf("%.15g\n", rk45_adaptive_solve(p1_decay2, 1.0, 0.0, 2.0, 1e-6, 1e-8)); return 0; }

    // Integrate
    if (!strcmp(c, "trap_x2"))       { printf("%.15g\n", trapezoidal(p2_x_squared, 0.0, 1.0, 100)); return 0; }
    if (!strcmp(c, "trap_expneg"))   { printf("%.15g\n", trapezoidal(p2_exp_neg,   0.0, 1.0, 100)); return 0; }
    if (!strcmp(c, "trap_sin"))      { printf("%.15g\n", trapezoidal(p2_sin_shifted, 0.0, 3.141592653589793, 200)); return 0; }
    if (!strcmp(c, "simp_x2"))       { printf("%.15g\n", simpsons(p2_x_squared, 0.0, 1.0, 100)); return 0; }
    if (!strcmp(c, "simp_expneg"))   { printf("%.15g\n", simpsons(p2_exp_neg,   0.0, 1.0, 100)); return 0; }
    if (!strcmp(c, "simp_sin"))      { printf("%.15g\n", simpsons(p2_sin_shifted, 0.0, 3.141592653589793, 200)); return 0; }
    if (!strcmp(c, "gl5_x2"))        { printf("%.15g\n", gauss_legendre_5(p2_x_squared, 0.0, 1.0, 5)); return 0; }
    if (!strcmp(c, "gl5_expneg"))    { printf("%.15g\n", gauss_legendre_5(p2_exp_neg,   0.0, 1.0, 5)); return 0; }
    if (!strcmp(c, "gl5_sin"))       { printf("%.15g\n", gauss_legendre_5(p2_sin_shifted, 0.0, 3.141592653589793, 5)); return 0; }

    // Testing (scalar)
    if (!strcmp(c, "z_stat"))        { printf("%.15g\n", z_statistic(atof(argv[2]), atof(argv[3]), atof(argv[4]), atof(argv[5]))); return 0; }
    if (!strcmp(c, "z_p_two"))       { printf("%.15g\n", z_p_value_two_sided(atof(argv[2]))); return 0; }
    if (!strcmp(c, "z_p_upper"))     { printf("%.15g\n", z_p_value_upper(atof(argv[2]))); return 0; }
    if (!strcmp(c, "z_p_lower"))     { printf("%.15g\n", z_p_value_lower(atof(argv[2]))); return 0; }
    if (!strcmp(c, "ci_half"))       { printf("%.15g\n", normal_ci_half_width(atof(argv[2]), atof(argv[3]), atof(argv[4]))); return 0; }
    if (!strcmp(c, "chi2_p"))        { printf("%.15g\n", chi_squared_p_value(atof(argv[2]), atof(argv[3]))); return 0; }
    if (!strcmp(c, "t_stat_one"))    { printf("%.15g\n", t_statistic_one_sample(atof(argv[2]), atof(argv[3]), atof(argv[4]), atof(argv[5]))); return 0; }
    if (!strcmp(c, "t_stat_pool"))   { printf("%.15g\n", t_statistic_two_sample_pooled(atof(argv[2]), atof(argv[3]), atof(argv[4]), atof(argv[5]), atof(argv[6]), atof(argv[7]))); return 0; }
    if (!strcmp(c, "welch_t"))       { printf("%.15g\n", welch_t_statistic(atof(argv[2]), atof(argv[3]), atof(argv[4]), atof(argv[5]), atof(argv[6]), atof(argv[7]))); return 0; }
    if (!strcmp(c, "welch_df"))      { printf("%.15g\n", welch_t_df(atof(argv[2]), atof(argv[3]), atof(argv[4]), atof(argv[5]))); return 0; }
    if (!strcmp(c, "t_p_two"))       { printf("%.15g\n", t_p_value_two_sided(atof(argv[2]), atof(argv[3]))); return 0; }
    if (!strcmp(c, "t_p_upper"))     { printf("%.15g\n", t_p_value_upper(atof(argv[2]), atof(argv[3]))); return 0; }
    if (!strcmp(c, "t_p_lower"))     { printf("%.15g\n", t_p_value_lower(atof(argv[2]), atof(argv[3]))); return 0; }

    // Optim
    if (!strcmp(c, "gss_parab"))     { printf("%.15g\n", golden_section_search(opt_parab, 0.0, 5.0, 1e-8, 200)); return 0; }
    if (!strcmp(c, "brent_parab"))   { printf("%.15g\n", brent_minimize(opt_parab, 0.0, 5.0, 1e-8, 200)); return 0; }
    if (!strcmp(c, "gd_parab"))      { printf("%.15g\n", gradient_descent_1d(opt_parab, opt_dparab, 0.0, 0.1, 500)); return 0; }
    if (!strcmp(c, "newton_parab"))  { printf("%.15g\n", newton_minimize_1d(opt_parab, opt_dparab, opt_ddparab, 0.0, 1e-10, 50)); return 0; }
    if (!strcmp(c, "gss_quartic"))   { printf("%.15g\n", golden_section_search(opt_quartic, 0.0, 3.0, 1e-8, 200)); return 0; }
    if (!strcmp(c, "brent_quartic")) { printf("%.15g\n", brent_minimize(opt_quartic, 0.5, 3.0, 1e-8, 200)); return 0; }
    if (!strcmp(c, "newton_quartic")){ printf("%.15g\n", newton_minimize_1d(opt_quartic, opt_dquartic, opt_ddquartic, 1.2, 1e-10, 100)); return 0; }

    // Interpolation: cubic_hermite (scalar)
    if (!strcmp(c, "hermite")) {
        printf("%.15g\n", cubic_hermite(atof(argv[2]), atof(argv[3]), atof(argv[4]),
                                         atof(argv[5]), atof(argv[6]), atof(argv[7]), atof(argv[8])));
        return 0;
    }

    // SDE
    if (!strcmp(c, "sde_em_zero"))   { printf("%.15g\n", sde_em_zero_noise()); return 0; }
    if (!strcmp(c, "sde_em_plus"))   { printf("%.15g\n", sde_em_plus_noise()); return 0; }
    if (!strcmp(c, "sde_em_alt"))    { printf("%.15g\n", sde_em_alt_noise()); return 0; }
    if (!strcmp(c, "sde_milstein"))  { printf("%.15g\n", sde_milstein_gbm()); return 0; }

    // Adaptive integration
    if (!strcmp(c, "adapt_x2"))      { printf("%.15g\n", adaptive_simpson(int_x_squared, 0.0, 1.0, 1e-12, 20)); return 0; }
    if (!strcmp(c, "adapt_expneg"))  { printf("%.15g\n", adaptive_simpson(int_exp_neg, 0.0, 1.0, 1e-12, 20)); return 0; }
    if (!strcmp(c, "adapt_sin"))     { printf("%.15g\n", adaptive_simpson(int_sin_x, 0.0, 3.141592653589793, 1e-12, 20)); return 0; }
    if (!strcmp(c, "adapt_inv"))     { printf("%.15g\n", adaptive_simpson(int_inv_1_x2, 0.0, 1.0, 1e-12, 20)); return 0; }
    if (!strcmp(c, "romb_x2"))       { printf("%.15g\n", romberg_5(int_x_squared, 0.0, 1.0)); return 0; }
    if (!strcmp(c, "romb_expneg"))   { printf("%.15g\n", romberg_5(int_exp_neg, 0.0, 1.0)); return 0; }
    if (!strcmp(c, "romb_sin"))      { printf("%.15g\n", romberg_5(int_sin_x, 0.0, 3.141592653589793)); return 0; }
    if (!strcmp(c, "romb_inv"))      { printf("%.15g\n", romberg_5(int_inv_1_x2, 0.0, 1.0)); return 0; }
    if (!strcmp(c, "gl10_x2"))       { printf("%.15g\n", gauss_legendre_10(int_x_squared, 0.0, 1.0)); return 0; }
    if (!strcmp(c, "gl10_expneg"))   { printf("%.15g\n", gauss_legendre_10(int_exp_neg, 0.0, 1.0)); return 0; }
    if (!strcmp(c, "gl10_sin"))      { printf("%.15g\n", gauss_legendre_10(int_sin_x, 0.0, 3.141592653589793)); return 0; }
    if (!strcmp(c, "gl10_inv"))      { printf("%.15g\n", gauss_legendre_10(int_inv_1_x2, 0.0, 1.0)); return 0; }

    // Gauss-Hermite
    if (!strcmp(c, "gh_one"))  { printf("%.15g\n", gauss_hermite_10(p4_one)); return 0; }
    if (!strcmp(c, "gh_x2"))   { printf("%.15g\n", gauss_hermite_10(p4_x2)); return 0; }
    if (!strcmp(c, "gh_x4"))   { printf("%.15g\n", gauss_hermite_10(p4_x4)); return 0; }

    // Gauss-Laguerre
    if (!strcmp(c, "gl_one"))  { printf("%.15g\n", gauss_laguerre_10(p4_one)); return 0; }
    if (!strcmp(c, "gl_x"))    { printf("%.15g\n", gauss_laguerre_10(p4_x));   return 0; }
    if (!strcmp(c, "gl_x2"))   { printf("%.15g\n", gauss_laguerre_10(p4_x2));  return 0; }
    if (!strcmp(c, "gl_x3"))   { printf("%.15g\n", gauss_laguerre_10(p4_x3));  return 0; }

    fprintf(stderr, "unknown case: %s\n", c);
    return 2;
}
"""


def build_p1_binary() -> Path:
    bare = "\n".join(
        strip_module((SRC / f).read_text())
        for f in ("special.ch", "distributions.ch", "roots.ch", "ode.ch", "integrate.ch", "testing.ch", "optim.ch", "interpolation.ch", "sde.ch")
    ) + P1_TEST_HELPERS_CH + "\ndef main() -> f32 = p1_poly1(cast(1.0, f32))\n"
    workdir = Path(tempfile.mkdtemp(prefix="nautilus-p1-"))
    bare_ch = workdir / "p1_bare.ch"
    bare_ch.write_text(bare)
    chelis_build(bare_ch, workdir / "out")
    c_file = workdir / "out" / "p1_bare.c"
    drv_c = workdir / "p1_driver.c"
    drv_c.write_text(P1_DRIVER_C)
    binary = workdir / "p1_test_bin"
    out_dir = workdir / "out"
    cc = subprocess.run(
        native_link_cmd(binary, [c_file, drv_c], out_dir),
        capture_output=True, text=True,
    )
    if cc.returncode != 0:
        raise SystemExit(f"p1 gcc failed: {cc.stderr}")
    return binary


LINALG_DRIVER_C = r"""
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <math.h>
#include "chelis_runtime.h"

/* scalar-output, single-tensor-input */
double det_2x2(chelis_tensor* a);
double det_3x3(chelis_tensor* a);
double trace_scalar(chelis_tensor* a);
double l2_norm_vec(chelis_tensor* v);
double frobenius_sq(chelis_tensor* a);
double frobenius_norm(chelis_tensor* a);

/* scalar-output, two-tensor-input */
double inner_product(chelis_tensor* a, chelis_tensor* b);

/* tensor-output, two-tensor-input */
chelis_tensor* la_vec_add(chelis_tensor* a, chelis_tensor* b);
chelis_tensor* la_vec_sub(chelis_tensor* a, chelis_tensor* b);

/* tensor-output, single-tensor-input */
chelis_tensor* inv_2x2(chelis_tensor* a);
chelis_tensor* inv_3x3(chelis_tensor* a);
chelis_tensor* gram(chelis_tensor* a);
chelis_tensor* aat(chelis_tensor* a);
chelis_tensor* transpose(chelis_tensor* a);
chelis_tensor* diag(chelis_tensor* a);
chelis_tensor* trace_mat(chelis_tensor* a);
chelis_tensor* cholesky_2x2(chelis_tensor* a);

/* tensor-output, two-tensor-input (matrix) */
chelis_tensor* matmul_wrap(chelis_tensor* a, chelis_tensor* b);
chelis_tensor* vecmat(chelis_tensor* v, chelis_tensor* a);
chelis_tensor* scale_vec(chelis_tensor* v, double s);
chelis_tensor* matvec(chelis_tensor* a, chelis_tensor* v);
chelis_tensor* la_vec_saxpy(double alpha, chelis_tensor* x, chelis_tensor* y);

/* cg_solve: matrix + vec + vec + tol + max_iters -> vec */
chelis_tensor* cg_solve(chelis_tensor* a, chelis_tensor* b, chelis_tensor* x0,
                        double tol, int64_t max_iters);

/* eig_2x2_real: 2x2 matrix -> chelis_tuple* of two f32 eigenvalues */
chelis_tuple* eig_2x2_real(chelis_tensor* a);

/* distance: mahalanobis */
double mahalanobis_squared(chelis_tensor* a, chelis_tensor* b, chelis_tensor* cov_inv);
double mahalanobis(chelis_tensor* a, chelis_tensor* b, chelis_tensor* cov_inv);

/* interpolation */
double linear_interp_uniform(chelis_tensor* ys, double x_min, double x_max, double x_query);
double linear_interp_sorted(chelis_tensor* xs, chelis_tensor* ys, double x_query);

/* curvefit test wrappers */
double test_lm_linear(chelis_tensor* xs, chelis_tensor* ys, double theta0);
double test_lm_exp(chelis_tensor* xs, chelis_tensor* ys, double theta0);

/* distribution sample test wrappers */
chelis_tensor* test_uniform_sample(chelis_tensor* t);
chelis_tensor* test_normal_sample(chelis_tensor* t);
chelis_tensor* test_exponential_sample(chelis_tensor* t);
chelis_tensor* test_lognormal_sample(chelis_tensor* t);

/* SDE: scalar + tensor -> scalar (test wrappers defined in harness source) */
double test_em_decay_s1(double y0, double t0, double t1, chelis_tensor* noise);
double test_em_decay_s01(double y0, double t0, double t1, chelis_tensor* noise);
double test_milstein_gbm(double y0, double t0, double t1, chelis_tensor* noise);
double test_em_gbm_realistic(double y0, double t0, double t1, chelis_tensor* noise);

/* tensor-output, two-tensor-input */
chelis_tensor* solve_2x2(chelis_tensor* a, chelis_tensor* b);
chelis_tensor* solve_3x3(chelis_tensor* a, chelis_tensor* b);

/* stats: single-tensor-input, scalar output */
double mean_vec(chelis_tensor* v);
double variance_vec(chelis_tensor* v, int64_t ddof);
double std_vec(chelis_tensor* v, int64_t ddof);
double skewness_vec(chelis_tensor* v);
double kurtosis_vec(chelis_tensor* v);
double median_vec(chelis_tensor* v);
double min_vec(chelis_tensor* v);
double max_vec(chelis_tensor* v);
double range_vec(chelis_tensor* v);

/* stats: two-tensor-input, scalar output */
double covariance_scalar(chelis_tensor* a, chelis_tensor* b, int64_t ddof);
double correlation_scalar(chelis_tensor* a, chelis_tensor* b);

/* stats: tensor + scalar -> scalar */
double quantile_vec(chelis_tensor* v, double q);
double percentile_vec(chelis_tensor* v, double p);
double trimmed_mean_vec(chelis_tensor* v, double proportion);

/* distance: two-tensor-input, scalar output */
double squared_euclidean(chelis_tensor* a, chelis_tensor* b);
double euclidean(chelis_tensor* a, chelis_tensor* b);
double manhattan(chelis_tensor* a, chelis_tensor* b);
double chebyshev(chelis_tensor* a, chelis_tensor* b);
double cosine_similarity(chelis_tensor* a, chelis_tensor* b);
double cosine_distance(chelis_tensor* a, chelis_tensor* b);

static chelis_tensor* make_vec(int n, double* vals) {
    chelis_tensor* t = chelis_alloc(1, (int[]){n}, 0);
    for (int i = 0; i < n; i++) t->data[i] = (float)vals[i];
    return t;
}

static chelis_tensor* make_mat(int rows, int cols, double* vals) {
    chelis_tensor* t = chelis_alloc(2, (int[]){rows, cols}, 0);
    for (int i = 0; i < rows * cols; i++) t->data[i] = (float)vals[i];
    return t;
}

static void print_scalar(double v) { printf("%.15g\n", v); }

static void print_vec(chelis_tensor* t) {
    for (int i = 0; i < t->size; i++) {
        if (i > 0) printf(" ");
        printf("%.15g", (double)t->data[i]);
    }
    printf("\n");
}

static void print_mat(chelis_tensor* t) {
    int total = t->size;
    for (int i = 0; i < total; i++) {
        if (i > 0) printf(" ");
        printf("%.15g", (double)t->data[i]);
    }
    printf("\n");
}

int main(int argc, char** argv) {
    if (argc < 2) { fprintf(stderr, "usage: la_driver FN ARGS...\n"); return 1; }
    const char* fn = argv[1];
    double a[256] = {0};
    int nargs = argc - 2;
    for (int i = 0; i < nargs && i < 256; i++) a[i] = atof(argv[2+i]);

    /* det_2x2: 4 elements -> scalar */
    if (!strcmp(fn, "det_2x2")) {
        chelis_tensor* m = make_mat(2, 2, a);
        print_scalar(det_2x2(m));
        return 0;
    }
    /* det_3x3: 9 elements -> scalar */
    if (!strcmp(fn, "det_3x3")) {
        chelis_tensor* m = make_mat(3, 3, a);
        print_scalar(det_3x3(m));
        return 0;
    }
    /* trace_scalar: NxN -> scalar, argv[2] = N, then N*N elements */
    if (!strcmp(fn, "trace_scalar")) {
        int n = (int)a[0];
        chelis_tensor* m = make_mat(n, n, a+1);
        print_scalar(trace_scalar(m));
        return 0;
    }
    /* l2_norm_vec: N elements -> scalar, argv[2] = N, then N elements */
    if (!strcmp(fn, "l2_norm_vec")) {
        int n = (int)a[0];
        chelis_tensor* v = make_vec(n, a+1);
        print_scalar(l2_norm_vec(v));
        return 0;
    }
    /* inner_product: N elements each, argv[2]=N, then 2*N elements */
    if (!strcmp(fn, "inner_product")) {
        int n = (int)a[0];
        chelis_tensor* va = make_vec(n, a+1);
        chelis_tensor* vb = make_vec(n, a+1+n);
        print_scalar(inner_product(va, vb));
        return 0;
    }
    /* frobenius_sq: M,N, then M*N elements -> scalar */
    if (!strcmp(fn, "frobenius_sq")) {
        int m = (int)a[0]; int n = (int)a[1];
        chelis_tensor* mat = make_mat(m, n, a+2);
        print_scalar(frobenius_sq(mat));
        return 0;
    }
    /* frobenius_norm: M,N, then M*N elements -> scalar */
    if (!strcmp(fn, "frobenius_norm")) {
        int m = (int)a[0]; int n = (int)a[1];
        chelis_tensor* mat = make_mat(m, n, a+2);
        print_scalar(frobenius_norm(mat));
        return 0;
    }
    /* la_vec_add: N, then 2*N elements -> vec */
    if (!strcmp(fn, "la_vec_add")) {
        int n = (int)a[0];
        chelis_tensor* va = make_vec(n, a+1);
        chelis_tensor* vb = make_vec(n, a+1+n);
        chelis_tensor* r = la_vec_add(va, vb);
        print_vec(r);
        return 0;
    }
    /* la_vec_sub: N, then 2*N elements -> vec */
    if (!strcmp(fn, "la_vec_sub")) {
        int n = (int)a[0];
        chelis_tensor* va = make_vec(n, a+1);
        chelis_tensor* vb = make_vec(n, a+1+n);
        chelis_tensor* r = la_vec_sub(va, vb);
        print_vec(r);
        return 0;
    }
    /* inv_2x2: 4 elements -> 4 elements */
    if (!strcmp(fn, "inv_2x2")) {
        chelis_tensor* m = make_mat(2, 2, a);
        chelis_tensor* r = inv_2x2(m);
        print_mat(r);
        return 0;
    }
    /* inv_3x3: 9 elements -> 9 elements */
    if (!strcmp(fn, "inv_3x3")) {
        chelis_tensor* m = make_mat(3, 3, a);
        chelis_tensor* r = inv_3x3(m);
        print_mat(r);
        return 0;
    }
    /* solve_2x2: 4 elements (A) + 2 elements (b) -> 2 elements */
    if (!strcmp(fn, "solve_2x2")) {
        chelis_tensor* m = make_mat(2, 2, a);
        chelis_tensor* b = make_vec(2, a+4);
        chelis_tensor* r = solve_2x2(m, b);
        print_vec(r);
        return 0;
    }
    /* solve_3x3: 9 elements (A) + 3 elements (b) -> 3 elements */
    if (!strcmp(fn, "solve_3x3")) {
        chelis_tensor* m = make_mat(3, 3, a);
        chelis_tensor* b = make_vec(3, a+9);
        chelis_tensor* r = solve_3x3(m, b);
        print_vec(r);
        return 0;
    }
    /* scale_vec: s, N, then N elements -> vec */
    if (!strcmp(fn, "scale_vec")) {
        double s = a[0];
        int n = (int)a[1];
        chelis_tensor* v = make_vec(n, a+2);
        chelis_tensor* r = scale_vec(v, s);
        print_vec(r);
        return 0;
    }
    /* matvec: M, N, then M*N + N elements -> vec(M) */
    if (!strcmp(fn, "matvec")) {
        int m = (int)a[0]; int n = (int)a[1];
        chelis_tensor* mat = make_mat(m, n, a+2);
        chelis_tensor* v = make_vec(n, a+2+m*n);
        chelis_tensor* r = matvec(mat, v);
        print_vec(r);
        return 0;
    }

    /* stats: N, then N elements -> scalar */
    if (!strcmp(fn, "mean_vec")) {
        int n = (int)a[0];
        chelis_tensor* v = make_vec(n, a+1);
        print_scalar(mean_vec(v));
        return 0;
    }
    if (!strcmp(fn, "variance_vec_ddof0")) {
        int n = (int)a[0];
        chelis_tensor* v = make_vec(n, a+1);
        print_scalar(variance_vec(v, 0));
        return 0;
    }
    if (!strcmp(fn, "variance_vec_ddof1")) {
        int n = (int)a[0];
        chelis_tensor* v = make_vec(n, a+1);
        print_scalar(variance_vec(v, 1));
        return 0;
    }
    if (!strcmp(fn, "std_vec_ddof0")) {
        int n = (int)a[0];
        chelis_tensor* v = make_vec(n, a+1);
        print_scalar(std_vec(v, 0));
        return 0;
    }
    if (!strcmp(fn, "std_vec_ddof1")) {
        int n = (int)a[0];
        chelis_tensor* v = make_vec(n, a+1);
        print_scalar(std_vec(v, 1));
        return 0;
    }
    if (!strcmp(fn, "skewness_vec")) {
        int n = (int)a[0];
        chelis_tensor* v = make_vec(n, a+1);
        print_scalar(skewness_vec(v));
        return 0;
    }
    if (!strcmp(fn, "kurtosis_vec")) {
        int n = (int)a[0];
        chelis_tensor* v = make_vec(n, a+1);
        print_scalar(kurtosis_vec(v));
        return 0;
    }
    if (!strcmp(fn, "median_vec")) {
        int n = (int)a[0];
        chelis_tensor* v = make_vec(n, a+1);
        print_scalar(median_vec(v));
        return 0;
    }
    if (!strcmp(fn, "min_vec")) {
        int n = (int)a[0];
        chelis_tensor* v = make_vec(n, a+1);
        print_scalar(min_vec(v));
        return 0;
    }
    if (!strcmp(fn, "max_vec")) {
        int n = (int)a[0];
        chelis_tensor* v = make_vec(n, a+1);
        print_scalar(max_vec(v));
        return 0;
    }
    if (!strcmp(fn, "range_vec")) {
        int n = (int)a[0];
        chelis_tensor* v = make_vec(n, a+1);
        print_scalar(range_vec(v));
        return 0;
    }
    /* distance: N, then 2*N elements -> scalar */
    if (!strcmp(fn, "squared_euclidean")) {
        int n = (int)a[0];
        chelis_tensor* va = make_vec(n, a+1);
        chelis_tensor* vb = make_vec(n, a+1+n);
        print_scalar(squared_euclidean(va, vb));
        return 0;
    }
    if (!strcmp(fn, "euclidean")) {
        int n = (int)a[0];
        chelis_tensor* va = make_vec(n, a+1);
        chelis_tensor* vb = make_vec(n, a+1+n);
        print_scalar(euclidean(va, vb));
        return 0;
    }
    if (!strcmp(fn, "manhattan")) {
        int n = (int)a[0];
        chelis_tensor* va = make_vec(n, a+1);
        chelis_tensor* vb = make_vec(n, a+1+n);
        print_scalar(manhattan(va, vb));
        return 0;
    }
    if (!strcmp(fn, "chebyshev")) {
        int n = (int)a[0];
        chelis_tensor* va = make_vec(n, a+1);
        chelis_tensor* vb = make_vec(n, a+1+n);
        print_scalar(chebyshev(va, vb));
        return 0;
    }
    if (!strcmp(fn, "cosine_distance")) {
        int n = (int)a[0];
        chelis_tensor* va = make_vec(n, a+1);
        chelis_tensor* vb = make_vec(n, a+1+n);
        print_scalar(cosine_distance(va, vb));
        return 0;
    }
    if (!strcmp(fn, "cosine_similarity")) {
        int n = (int)a[0];
        chelis_tensor* va = make_vec(n, a+1);
        chelis_tensor* vb = make_vec(n, a+1+n);
        print_scalar(cosine_similarity(va, vb));
        return 0;
    }
    /* quantile_vec: N, q, then N elements -> scalar */
    if (!strcmp(fn, "quantile_vec")) {
        int n = (int)a[0];
        double q = a[1];
        chelis_tensor* v = make_vec(n, a+2);
        print_scalar(quantile_vec(v, q));
        return 0;
    }
    /* percentile_vec: N, p, then N elements -> scalar */
    if (!strcmp(fn, "percentile_vec")) {
        int n = (int)a[0];
        double p = a[1];
        chelis_tensor* v = make_vec(n, a+2);
        print_scalar(percentile_vec(v, p));
        return 0;
    }
    /* trimmed_mean_vec: N, proportion, then N elements -> scalar */
    if (!strcmp(fn, "trimmed_mean_vec")) {
        int n = (int)a[0];
        double prop = a[1];
        chelis_tensor* v = make_vec(n, a+2);
        print_scalar(trimmed_mean_vec(v, prop));
        return 0;
    }
    /* covariance_scalar: N, ddof, then 2*N elements -> scalar */
    if (!strcmp(fn, "covariance_scalar")) {
        int n = (int)a[0];
        int64_t ddof = (int64_t)a[1];
        chelis_tensor* va = make_vec(n, a+2);
        chelis_tensor* vb = make_vec(n, a+2+n);
        print_scalar(covariance_scalar(va, vb, ddof));
        return 0;
    }
    /* correlation_scalar: N, then 2*N elements -> scalar */
    if (!strcmp(fn, "correlation_scalar")) {
        int n = (int)a[0];
        chelis_tensor* va = make_vec(n, a+1);
        chelis_tensor* vb = make_vec(n, a+1+n);
        print_scalar(correlation_scalar(va, vb));
        return 0;
    }
    /* la_vec_saxpy: alpha, N, then 2*N elements -> vec */
    if (!strcmp(fn, "la_vec_saxpy")) {
        double alpha = a[0];
        int n = (int)a[1];
        chelis_tensor* x = make_vec(n, a+2);
        chelis_tensor* y = make_vec(n, a+2+n);
        chelis_tensor* r = la_vec_saxpy(alpha, x, y);
        print_vec(r);
        return 0;
    }
    /* SDE test wrappers: y0, t0, t1, N, then N noise values -> scalar */
    if (!strcmp(fn, "test_em_decay_s1")) {
        double y0 = a[0], t0 = a[1], t1 = a[2];
        int n = (int)a[3];
        chelis_tensor* noise = make_vec(n, a+4);
        print_scalar(test_em_decay_s1(y0, t0, t1, noise));
        return 0;
    }
    if (!strcmp(fn, "test_em_decay_s01")) {
        double y0 = a[0], t0 = a[1], t1 = a[2];
        int n = (int)a[3];
        chelis_tensor* noise = make_vec(n, a+4);
        print_scalar(test_em_decay_s01(y0, t0, t1, noise));
        return 0;
    }
    if (!strcmp(fn, "test_milstein_gbm")) {
        double y0 = a[0], t0 = a[1], t1 = a[2];
        int n = (int)a[3];
        chelis_tensor* noise = make_vec(n, a+4);
        print_scalar(test_milstein_gbm(y0, t0, t1, noise));
        return 0;
    }
    if (!strcmp(fn, "test_em_gbm_realistic")) {
        double y0 = a[0], t0 = a[1], t1 = a[2];
        int n = (int)a[3];
        chelis_tensor* noise = make_vec(n, a+4);
        print_scalar(test_em_gbm_realistic(y0, t0, t1, noise));
        return 0;
    }

    /* gram: M, N, then M*N elements -> mat(N,N) */
    if (!strcmp(fn, "gram")) {
        int m = (int)a[0]; int n = (int)a[1];
        chelis_tensor* mat = make_mat(m, n, a+2);
        chelis_tensor* r = gram(mat);
        print_mat(r);
        return 0;
    }
    /* aat: M, N, then M*N elements -> mat(M,M) */
    if (!strcmp(fn, "aat")) {
        int m = (int)a[0]; int n = (int)a[1];
        chelis_tensor* mat = make_mat(m, n, a+2);
        chelis_tensor* r = aat(mat);
        print_mat(r);
        return 0;
    }
    /* transpose: M, N, then M*N elements -> mat(N,M) */
    if (!strcmp(fn, "transpose")) {
        int m = (int)a[0]; int n = (int)a[1];
        chelis_tensor* mat = make_mat(m, n, a+2);
        chelis_tensor* r = transpose(mat);
        print_mat(r);
        return 0;
    }
    /* matmul_wrap: M, K, N, then M*K + K*N elements -> mat(M,N) */
    if (!strcmp(fn, "matmul_wrap")) {
        int m = (int)a[0]; int k = (int)a[1]; int n = (int)a[2];
        chelis_tensor* ma = make_mat(m, k, a+3);
        chelis_tensor* mb = make_mat(k, n, a+3+m*k);
        chelis_tensor* r = matmul_wrap(ma, mb);
        print_mat(r);
        return 0;
    }
    /* diag: N, then N*N elements -> vec(N) */
    if (!strcmp(fn, "diag")) {
        int n = (int)a[0];
        chelis_tensor* mat = make_mat(n, n, a+1);
        chelis_tensor* r = diag(mat);
        print_vec(r);
        return 0;
    }
    /* trace_mat: N, then N*N elements -> scalar (0-dim tensor) */
    if (!strcmp(fn, "trace_mat")) {
        int n = (int)a[0];
        chelis_tensor* mat = make_mat(n, n, a+1);
        chelis_tensor* r = trace_mat(mat);
        printf("%.15g\n", (double)r->data[0]);
        return 0;
    }
    /* vecmat: M, N, then M + M*N elements -> vec(N) */
    if (!strcmp(fn, "vecmat")) {
        int m = (int)a[0]; int n = (int)a[1];
        chelis_tensor* v = make_vec(m, a+2);
        chelis_tensor* mat = make_mat(m, n, a+2+m);
        chelis_tensor* r = vecmat(v, mat);
        print_vec(r);
        return 0;
    }
    /* cholesky_2x2: 4 elements -> mat(2,2) */
    if (!strcmp(fn, "cholesky_2x2")) {
        chelis_tensor* mat = make_mat(2, 2, a);
        chelis_tensor* r = cholesky_2x2(mat);
        print_mat(r);
        return 0;
    }

    /* cg_solve: N, tol, max_iters, N*N (A), N (b), N (x0) -> vec(N) */
    if (!strcmp(fn, "cg_solve")) {
        int n = (int)a[0];
        double tol = a[1];
        int64_t max_iters = (int64_t)a[2];
        chelis_tensor* mat = make_mat(n, n, a+3);
        chelis_tensor* b = make_vec(n, a+3+n*n);
        chelis_tensor* x0 = make_vec(n, a+3+n*n+n);
        chelis_tensor* r = cg_solve(mat, b, x0, tol, max_iters);
        print_vec(r);
        return 0;
    }
    /* eig_2x2_real: 4 elements -> two eigenvalues as "lam1 lam2" */
    if (!strcmp(fn, "eig_2x2_real")) {
        chelis_tensor* mat = make_mat(2, 2, a);
        chelis_tuple* tup = eig_2x2_real(mat);
        chelis_value v0 = chelis_tuple_get(tup, 0);
        chelis_value v1 = chelis_tuple_get(tup, 1);
        printf("%.15g %.15g\n", chelis_value_as_f64(v0), chelis_value_as_f64(v1));
        return 0;
    }

    /* mahalanobis_squared: N, then N + N + N*N elements -> scalar */
    if (!strcmp(fn, "mahalanobis_squared")) {
        int n = (int)a[0];
        chelis_tensor* va = make_vec(n, a+1);
        chelis_tensor* vb = make_vec(n, a+1+n);
        chelis_tensor* ci = make_mat(n, n, a+1+2*n);
        print_scalar(mahalanobis_squared(va, vb, ci));
        return 0;
    }
    if (!strcmp(fn, "mahalanobis")) {
        int n = (int)a[0];
        chelis_tensor* va = make_vec(n, a+1);
        chelis_tensor* vb = make_vec(n, a+1+n);
        chelis_tensor* ci = make_mat(n, n, a+1+2*n);
        print_scalar(mahalanobis(va, vb, ci));
        return 0;
    }
    /* linear_interp_uniform: N, x_min, x_max, x_query, then N ys -> scalar */
    if (!strcmp(fn, "linear_interp_uniform")) {
        int n = (int)a[0];
        double x_min = a[1], x_max = a[2], x_query = a[3];
        chelis_tensor* ys = make_vec(n, a+4);
        print_scalar(linear_interp_uniform(ys, x_min, x_max, x_query));
        return 0;
    }
    /* linear_interp_sorted: N, x_query, then N xs + N ys -> scalar */
    if (!strcmp(fn, "linear_interp_sorted")) {
        int n = (int)a[0];
        double x_query = a[1];
        chelis_tensor* xs = make_vec(n, a+2);
        chelis_tensor* ys = make_vec(n, a+2+n);
        print_scalar(linear_interp_sorted(xs, ys, x_query));
        return 0;
    }
    /* test_lm_linear: N, theta0, then N xs + N ys -> scalar (fitted theta) */
    if (!strcmp(fn, "test_lm_linear")) {
        int n = (int)a[0];
        double theta0 = a[1];
        chelis_tensor* xs = make_vec(n, a+2);
        chelis_tensor* ys = make_vec(n, a+2+n);
        print_scalar(test_lm_linear(xs, ys, theta0));
        return 0;
    }
    if (!strcmp(fn, "test_lm_exp")) {
        int n = (int)a[0];
        double theta0 = a[1];
        chelis_tensor* xs = make_vec(n, a+2);
        chelis_tensor* ys = make_vec(n, a+2+n);
        print_scalar(test_lm_exp(xs, ys, theta0));
        return 0;
    }

    /* sample wrappers: N -> vec(N) (template is zeros) */
    if (!strcmp(fn, "test_uniform_sample")) {
        int n = (int)a[0];
        chelis_tensor* t = make_vec(n, a+1);
        chelis_tensor* r = test_uniform_sample(t);
        print_vec(r);
        return 0;
    }
    if (!strcmp(fn, "test_normal_sample")) {
        int n = (int)a[0];
        chelis_tensor* t = make_vec(n, a+1);
        chelis_tensor* r = test_normal_sample(t);
        print_vec(r);
        return 0;
    }
    if (!strcmp(fn, "test_exponential_sample")) {
        int n = (int)a[0];
        chelis_tensor* t = make_vec(n, a+1);
        chelis_tensor* r = test_exponential_sample(t);
        print_vec(r);
        return 0;
    }
    if (!strcmp(fn, "test_lognormal_sample")) {
        int n = (int)a[0];
        chelis_tensor* t = make_vec(n, a+1);
        chelis_tensor* r = test_lognormal_sample(t);
        print_vec(r);
        return 0;
    }

    fprintf(stderr, "unknown function: %s\n", fn);
    return 2;
}
"""


def _dedup_defs(bare: str) -> str:
    """Auto-detect and strip duplicate top-level `def` definitions from
    concatenated bare Chelis source. Keeps the first occurrence, drops
    subsequent ones, and warns on stderr so collisions are visible."""
    seen: dict[str, int] = {}
    out: list[str] = []
    deduped: list[str] = []
    for lineno, line in enumerate(bare.split("\n"), 1):
        m = re.match(r"^def\s+(\w+)\b", line)
        if m:
            name = m.group(1)
            if name in seen:
                deduped.append(f"  {name} (first at line {seen[name]}, dup at line {lineno})")
                continue
            seen[name] = lineno
        out.append(line)
    if deduped:
        print(f"[dedup] stripped {len(deduped)} duplicate def(s) from concatenated source:",
              file=sys.stderr)
        for d in deduped:
            print(d, file=sys.stderr)
    return "\n".join(out)


TEST_HELPERS_CH = r"""
def sde_test_drift_decay(y: f32, t: f32) -> f32 = neg(y)
def sde_test_diff_one(y: f32, t: f32) -> f32 = cast(1.0, f32)
def sde_test_diff_01(y: f32, t: f32) -> f32 = cast(0.1, f32)
def sde_test_drift_gbm(y: f32, t: f32) -> f32 = mul(cast(0.1, f32), y)
def sde_test_diff_gbm(y: f32, t: f32) -> f32 = mul(cast(0.2, f32), y)
def sde_test_ddiff_gbm(y: f32, t: f32) -> f32 = cast(0.2, f32)

def test_em_decay_s1[n](y0: f32, t0: f32, t1: f32, noise: tensor[n, f32]) -> f32 =
  euler_maruyama_fixed(sde_test_drift_decay, sde_test_diff_one, y0, t0, t1, noise)

def test_em_decay_s01[n](y0: f32, t0: f32, t1: f32, noise: tensor[n, f32]) -> f32 =
  euler_maruyama_fixed(sde_test_drift_decay, sde_test_diff_01, y0, t0, t1, noise)

def test_milstein_gbm[n](y0: f32, t0: f32, t1: f32, noise: tensor[n, f32]) -> f32 =
  milstein_fixed(sde_test_drift_gbm, sde_test_diff_gbm, sde_test_ddiff_gbm, y0, t0, t1, noise)

def sde_test_drift_gbm_005(y: f32, t: f32) -> f32 = mul(cast(0.05, f32), y)
def sde_test_diff_gbm_02(y: f32, t: f32) -> f32 = mul(cast(0.2, f32), y)

def test_em_gbm_realistic[n](y0: f32, t0: f32, t1: f32, noise: tensor[n, f32]) -> f32 =
  euler_maruyama_fixed(sde_test_drift_gbm_005, sde_test_diff_gbm_02, y0, t0, t1, noise)

def test_uniform_sample[n](t: tensor[n, f32]) -> tensor[n, f32] =
  uniform_sample(t, cast(2.0, f32), cast(5.0, f32))
def test_normal_sample[n](t: tensor[n, f32]) -> tensor[n, f32] =
  normal_sample(t, cast(0.0, f32), cast(1.0, f32))
def test_exponential_sample[n](t: tensor[n, f32]) -> tensor[n, f32] =
  exponential_sample(t, cast(2.0, f32))
def test_lognormal_sample[n](t: tensor[n, f32]) -> tensor[n, f32] =
  lognormal_sample(t, cast(0.0, f32), cast(0.5, f32))

def cf_test_model(x: f32, theta: f32) -> f32 = mul(theta, x)
def cf_test_dmodel(x: f32, theta: f32) -> f32 = x

def test_lm_linear[n](xs: tensor[n, f32], ys: tensor[n, f32], theta0: f32) -> f32 =
  lm_scalar_1param(cf_test_model, cf_test_dmodel, xs, ys, theta0, cast(0.01, f32), cast(1.0e-8, f32), cast(100, int64))

def cf_test_exp_model(x: f32, theta: f32) -> f32 = {
  nt = neg(mul(theta, x))
  exp(nt)
}
def cf_test_exp_dmodel(x: f32, theta: f32) -> f32 = {
  nt = neg(mul(theta, x))
  e = exp(nt)
  mul(neg(x), e)
}

def test_lm_exp[n](xs: tensor[n, f32], ys: tensor[n, f32], theta0: f32) -> f32 =
  lm_scalar_1param(cf_test_exp_model, cf_test_exp_dmodel, xs, ys, theta0, cast(0.01, f32), cast(1.0e-6, f32), cast(200, int64))
"""


def build_linalg_binary() -> Path:
    """Build a binary for tensor-path linalg + stats + distance + SDE functions."""
    bare = "\n".join(
        strip_module((SRC / f).read_text())
        for f in ("special.ch", "distributions.ch", "linalg.ch", "stats.ch", "distance.ch", "sde.ch", "interpolation.ch", "curvefit.ch")
    ) + TEST_HELPERS_CH + "\ndef main() -> f32 = cast(0.0, f32)\n"
    bare = _dedup_defs(bare)
    workdir = Path(tempfile.mkdtemp(prefix="nautilus-la-"))
    bare_ch = workdir / "la_bare.ch"
    bare_ch.write_text(bare)
    chelis_build(bare_ch, workdir / "out")
    c_file = workdir / "out" / "la_bare.c"
    drv_c = workdir / "la_driver.c"
    drv_c.write_text(LINALG_DRIVER_C)
    binary = workdir / "la_test_bin"
    out_dir = workdir / "out"
    cc = subprocess.run(
        native_link_cmd(binary, [c_file, drv_c], out_dir),
        capture_output=True, text=True,
    )
    if cc.returncode != 0:
        raise SystemExit(f"linalg gcc failed: {cc.stderr}")
    return binary


def call_la_fn(binary: Path, fn: str, *args: float) -> str:
    """Call a linalg function and return raw stdout."""
    res = subprocess.run(
        [str(binary), fn, *(str(a) for a in args)],
        capture_output=True, text=True, check=True,
    )
    return res.stdout.strip()


def call_fn(binary: Path, fn: str, *args: float) -> float:
    res = subprocess.run(
        [str(binary), fn, *(str(a) for a in args)],
        capture_output=True, text=True, check=True,
    )
    return float(res.stdout.strip())


def close(have: float, want: float, atol: float, rtol: float) -> bool:
    if math.isnan(have) or math.isnan(want):
        return False
    return abs(have - want) <= max(atol, rtol * abs(want))


def golden(name: str) -> dict:
    return json.loads((GOLDENS / name).read_text())


def main() -> int:
    binary = build_native_binary()
    print(f"# binary: {binary}")
    fails = 0
    total = 0

    def run(label, fn, args, expected, atol, rtol):
        nonlocal fails, total
        total += 1
        got = call_fn(binary, fn, *args)
        ok = close(got, expected, atol, rtol)
        if not ok:
            fails += 1
            print(f"  FAIL {label}: got {got!r}, want {expected!r}, atol={atol}, rtol={rtol}")
        else:
            pass  # quiet on pass

    print("== Special ==")
    g = golden("special/erf.json")
    for x, y in zip(g["inputs"], g["outputs"]):
        run(f"erf({x})", "erf", (x,), y, g["abs"], g["rel"])
    g = golden("special/erfinv.json")
    for x, y in zip(g["inputs"], g["outputs"]):
        run(f"erfinv({x})", "erfinv", (x,), y, g["abs"], g["rel"])
    g = golden("special/log_gamma.json")
    for x, y in zip(g["inputs"], g["outputs"]):
        run(f"log_gamma({x})", "log_gamma", (x,), y, g["abs"], g["rel"])
    g = golden("special/digamma.json")
    for x, y in zip(g["inputs"], g["outputs"]):
        run(f"digamma({x})", "digamma", (x,), y, g["abs"], g["rel"])
    g = golden("special/beta.json")
    for (a, b), y in zip(g["inputs"], g["outputs"]):
        run(f"beta({a},{b})", "beta", (a, b), y, g["abs"], g["rel"])
    for fn in ("trigamma", "bessel_i0", "bessel_i1", "bessel_k0", "bessel_k1",
               "bessel_j0", "bessel_j1", "bessel_y0", "bessel_y1",
               "airy_ai", "airy_bi", "ellipk", "ellipe"):
        g = golden(f"special/{fn}.json")
        for x, y in zip(g["inputs"], g["outputs"]):
            run(f"{fn}({x})", fn, (x,), y, g["abs"], g["rel"])

    print("== Distributions: Normal ==")
    g = golden("distributions/normal.json")
    p = g["params"]
    for x, y in zip(g["inputs_x"], g["pdf"]):
        run(f"normal_pdf({x})", "normal_pdf", (x, p["mean"], p["std"]), y, g["abs"], g["rel"])
    for x, y in zip(g["inputs_x"], g["cdf"]):
        run(f"normal_cdf({x})", "normal_cdf", (x, p["mean"], p["std"]), y, g["abs"], g["rel"])
    for q, y in zip(g["inputs_q"], g["inv_cdf"]):
        run(f"normal_inv_cdf({q})", "normal_inv_cdf", (q, p["mean"], p["std"]), y, g["abs"], g["rel"])

    print("== Distributions: Uniform ==")
    g = golden("distributions/uniform.json")
    p = g["params"]
    for x, y in zip(g["inputs_x"], g["pdf"]):
        run(f"uniform_pdf({x})", "uniform_pdf", (x, p["lo"], p["hi"]), y, g["abs"], g["rel"])
    for x, y in zip(g["inputs_x"], g["cdf"]):
        run(f"uniform_cdf({x})", "uniform_cdf", (x, p["lo"], p["hi"]), y, g["abs"], g["rel"])
    for q, y in zip(g["inputs_q"], g["inv_cdf"]):
        run(f"uniform_inv_cdf({q})", "uniform_inv_cdf", (q, p["lo"], p["hi"]), y, g["abs"], g["rel"])

    print("== Distributions: Exponential ==")
    g = golden("distributions/exponential.json")
    p = g["params"]
    for x, y in zip(g["inputs_x"], g["pdf"]):
        run(f"exponential_pdf({x})", "exponential_pdf", (x, p["rate"]), y, g["abs"], g["rel"])
    for x, y in zip(g["inputs_x"], g["cdf"]):
        run(f"exponential_cdf({x})", "exponential_cdf", (x, p["rate"]), y, g["abs"], g["rel"])
    for q, y in zip(g["inputs_q"], g["inv_cdf"]):
        run(f"exponential_inv_cdf({q})", "exponential_inv_cdf", (q, p["rate"]), y, g["abs"], g["rel"])

    print("== Distributions: LogNormal ==")
    g = golden("distributions/lognormal.json")
    p = g["params"]
    for x, y in zip(g["inputs_x"], g["pdf"]):
        run(f"lognormal_pdf({x})", "lognormal_pdf", (x, p["mu"], p["sigma"]), y, g["abs"], g["rel"])
    for x, y in zip(g["inputs_x"], g["cdf"]):
        run(f"lognormal_cdf({x})", "lognormal_cdf", (x, p["mu"], p["sigma"]), y, g["abs"], g["rel"])
    for q, y in zip(g["inputs_q"], g["inv_cdf"]):
        run(f"lognormal_inv_cdf({q})", "lognormal_inv_cdf", (q, p["mu"], p["sigma"]), y, g["abs"], g["rel"])

    print("== Distributions: Gamma ==")
    g = golden("distributions/gamma.json")
    p = g["params"]
    for x, y in zip(g["inputs_x"], g["pdf"]):
        run(f"gamma_pdf({x})", "gamma_pdf", (x, p["shape"], p["scale"]), y, g["abs"], g["rel"])
    for x, y in zip(g["inputs_x"], g["cdf"]):
        run(f"gamma_cdf({x})", "gamma_cdf", (x, p["shape"], p["scale"]), y, g["abs"], g["rel"])
    for q, y in zip(g["inputs_q"], g["inv_cdf"]):
        run(f"gamma_inv_cdf({q})", "gamma_inv_cdf", (q, p["shape"], p["scale"]), y, g["abs"], g["rel"])

    print("== Distributions: Chi-squared ==")
    g = golden("distributions/chi_squared.json")
    p = g["params"]
    for x, y in zip(g["inputs_x"], g["pdf"]):
        run(f"chi_squared_pdf({x})", "chi_squared_pdf", (x, p["df"]), y, g["abs"], g["rel"])
    for x, y in zip(g["inputs_x"], g["cdf"]):
        run(f"chi_squared_cdf({x})", "chi_squared_cdf", (x, p["df"]), y, g["abs"], g["rel"])
    for q, y in zip(g["inputs_q"], g["inv_cdf"]):
        run(f"chi_squared_inv_cdf({q})", "chi_squared_inv_cdf", (q, p["df"]), y, g["abs"], g["rel"])

    print("== Distributions: Poisson / Binomial / Beta / F / Weibull ==")
    g = golden("distributions/discrete.json")
    for case in g["poisson_cases"]:
        run(f"poisson_pmf(k={case['k']},lam={case['lambda']})", "poisson_pmf",
             (case["k"], case["lambda"]), case["pmf"], g["abs"], g["rel"])
        run(f"poisson_cdf(k={case['k']},lam={case['lambda']})", "poisson_cdf",
             (case["k"], case["lambda"]), case["cdf"], g["abs"], g["rel"])
    for case in g["binomial_cases"]:
        run(f"binom_pmf(k={case['k']},n={case['n']},p={case['p']})", "binomial_pmf",
             (case["k"], case["n"], case["p"]), case["pmf"], g["abs"], g["rel"])
        run(f"binom_cdf(k={case['k']},n={case['n']},p={case['p']})", "binomial_cdf",
             (case["k"], case["n"], case["p"]), case["cdf"], g["abs"], g["rel"])
    g = golden("distributions/continuous_p4.json")
    for case in g["beta_cases"]:
        run(f"beta_pdf", "beta_pdf", (case["x"], case["a"], case["b"]),
             case["pdf"], g["abs"], g["rel"])
        run(f"beta_cdf", "beta_cdf", (case["x"], case["a"], case["b"]),
             case["cdf"], g["abs"], g["rel"])
    for case in g["f_cases"]:
        run(f"f_pdf", "f_pdf", (case["x"], case["d1"], case["d2"]),
             case["pdf"], g["abs"], g["rel"])
        run(f"f_cdf", "f_cdf", (case["x"], case["d1"], case["d2"]),
             case["cdf"], g["abs"], g["rel"])
    for case in g["weibull_cases"]:
        run(f"weibull_pdf", "weibull_pdf", (case["x"], case["shape"], case["scale"]),
             case["pdf"], g["abs"], g["rel"])
        run(f"weibull_cdf", "weibull_cdf", (case["x"], case["shape"], case["scale"]),
             case["cdf"], g["abs"], g["rel"])
    for case in g["weibull_inv_cdf"]:
        run(f"weibull_inv_cdf", "weibull_inv_cdf",
             (case["q"], case["shape"], case["scale"]),
             case["expected"], g["abs"], g["rel"])

    print("== Distributions: Student-t ==")
    g = golden("distributions/student_t.json")
    p = g["params"]
    for x, y in zip(g["inputs_x"], g["pdf"]):
        run(f"student_t_pdf({x})", "student_t_pdf", (x, p["df"]), y, g["abs"], g["rel"])
    for x, y in zip(g["inputs_x"], g["cdf"]):
        run(f"student_t_cdf({x},df=5)", "student_t_cdf", (x, p["df"]), y, g["abs"], g["rel"])
    for x, y in zip(g["inputs_x"], g["cdf_df1"]):
        run(f"student_t_cdf({x},df=1)", "student_t_cdf", (x, 1.0), y, g["abs"], g["rel"])
    for x, y in zip(g["inputs_x"], g["cdf_df30"]):
        run(f"student_t_cdf({x},df=30)", "student_t_cdf", (x, 30.0), y, g["abs"], g["rel"])

    # --- P1: Roots + ODE via a separate binary (function-pointer ABI) ---
    p1_binary = build_p1_binary()
    print(f"# p1_binary: {p1_binary}")

    def p1_run(label, case, args, expected, atol, rtol):
        nonlocal fails, total
        total += 1
        res = subprocess.run(
            [str(p1_binary), case, *(str(a) for a in args)],
            capture_output=True, text=True, check=True,
        )
        got = float(res.stdout.strip())
        if not close(got, expected, atol, rtol):
            fails += 1
            print(f"  FAIL {label}: got {got!r}, want {expected!r}, atol={atol}, rtol={rtol}")

    print("== Roots ==")
    g = golden("roots/scalar.json")
    for case in g["cases"]:
        p1_run(case["label"], case["label"], (), case["expected"], g["abs"], g["rel"])

    print("== ODE ==")
    g = golden("ode/scalar.json")
    decay_true = g["decay_analytic"]
    for case in g["rk4_cases"]:
        p1_run(case["label"], "decay_rk4", (case["n_steps"],), decay_true,
                case["expected_abs_err"], 0.0)
    for case in g["euler_cases"]:
        p1_run(case["label"], "decay_euler", (case["n_steps"],), decay_true,
                case["expected_abs_err"], 0.0)
    for case in g["adaptive_cases"]:
        p1_run(case["label"], "decay_rk45", (), case["expected"],
                case["expected_abs_err"], 0.0)

    print("== Integrate ==")
    g = golden("integrate/scalar.json")
    for case in g["cases"]:
        short = case["label"]
        prefix_map = {"x_squared_0_1": "x2", "exp_neg_0_1": "expneg", "sin_shifted_pi": "sin"}
        short_tag = prefix_map[short]
        for method in ("trap", "simp", "gl5"):
            p1_run(f"{method}_{short}", f"{method}_{short_tag}", (),
                    case["expected"], g["abs"], g["rel"])

    print("== Testing ==")
    g = golden("testing/scalar.json")
    for case in g["cases"]:
        label = case["label"]
        if label == "z_stat_basic":
            p1_run(label, "z_stat",
                    (case["sample_mean"], case["pop_mean"], case["pop_std"], case["sample_n"]),
                    case["expected_z"], g["abs"], g["rel"])
        elif label.startswith("z_p_two_sided"):
            p1_run(label, "z_p_two", (case["z"],), case["expected_p"], g["abs"], g["rel"])
        elif label == "z_p_upper_196":
            p1_run(label, "z_p_upper", (case["z"],), case["expected_p"], g["abs"], g["rel"])
        elif label == "z_p_lower_neg196":
            p1_run(label, "z_p_lower", (case["z"],), case["expected_p"], g["abs"], g["rel"])
        elif label.startswith("normal_ci"):
            p1_run(label, "ci_half",
                    (case["confidence"], case["pop_std"], case["sample_n"]),
                    case["expected_half_width"], g["abs"], g["rel"])
        elif label.startswith("chi2_p"):
            p1_run(label, "chi2_p",
                    (case["statistic"], case["df"]),
                    case["expected_p"], g["abs"], g["rel"])
        elif label == "t_stat_one_sample":
            p1_run(label, "t_stat_one",
                    (case["sample_mean"], case["sample_std"], case["sample_n"], case["pop_mean"]),
                    case["expected_t"], g["abs"], g["rel"])
        elif label == "t_stat_two_sample_pooled":
            p1_run(label, "t_stat_pool",
                    (case["mean1"], case["std1"], case["n1"], case["mean2"], case["std2"], case["n2"]),
                    case["expected_t"], g["abs"], g["rel"])
        elif label == "welch_t_stat":
            p1_run(label, "welch_t",
                    (case["mean1"], case["std1"], case["n1"], case["mean2"], case["std2"], case["n2"]),
                    case["expected_t"], g["abs"], g["rel"])
        elif label == "welch_df":
            p1_run(label, "welch_df",
                    (case["std1"], case["n1"], case["std2"], case["n2"]),
                    case["expected_df"], g["abs"], g["rel"])
        elif label.startswith("t_p_two"):
            p1_run(label, "t_p_two", (case["t"], case["df"]),
                    case["expected_p"], g["abs"], g["rel"])
        elif label.startswith("t_p_upper"):
            p1_run(label, "t_p_upper", (case["t"], case["df"]),
                    case["expected_p"], g["abs"], g["rel"])
        elif label.startswith("t_p_lower"):
            p1_run(label, "t_p_lower", (case["t"], case["df"]),
                    case["expected_p"], g["abs"], g["rel"])

    print("== Optim ==")
    g = golden("optim/scalar.json")
    case_tag = {
        "gss_parabola": "gss_parab", "brent_parabola": "brent_parab",
        "gd_parabola": "gd_parab",  "newton_parabola": "newton_parab",
        "gss_quartic": "gss_quartic", "brent_quartic": "brent_quartic",
        "newton_quartic": "newton_quartic",
    }
    for case in g["cases"]:
        p1_run(case["label"], case_tag[case["label"]], (), case["expected"], g["abs"], g["rel"])

    print("== Interpolation ==")
    g = golden("interpolation/scalar.json")
    for case in g["cases"]:
        p1_run(case["label"], "hermite",
                (case["x0"], case["x1"], case["y0"], case["y1"], case["m0"], case["m1"], case["x"]),
                case["expected"], g["abs"], g["rel"])

    # SDE runtime verification is blocked the same way Distributions.sample
    # is: the Chelis-side noise vector construction via `range + map +
    # to_tensor` requires real runtime symbols (chelis_range_i64 et al.)
    # that the NULL-returning stubs can't honor. Type-level coverage via
    # `src/apismoke.ch:smoke_sde` is the honest gate; goldens stay in
    # tree for documentation + future runtime-enabled harness wiring.

    print("== Integrate: Hermite + Laguerre ==")
    g = golden("integrate/hermite_laguerre.json")
    for case in g["cases"]:
        p1_run(case["label"], case["label"], (), case["expected"], g["abs"], g["rel"])

    print("== Integrate: adaptive + romberg + gauss_legendre_10 ==")
    g = golden("integrate/adaptive.json")
    label_tag = {
        "x_squared_01": "x2", "exp_neg_01": "expneg",
        "sin_0_pi": "sin",    "one_over_1_x2_01": "inv",
    }
    for case in g["cases"]:
        tag = label_tag[case["label"]]
        for method in ("adapt", "romb", "gl10"):
            p1_run(f"{method}_{case['label']}", f"{method}_{tag}", (),
                    case["expected"], g["abs"], g["rel"])

    # --- LinAlg tensor-path tests via a separate binary ---
    la_binary = build_linalg_binary()
    print(f"# la_binary: {la_binary}")

    def la_run_scalar(label, fn, args, expected, atol, rtol):
        nonlocal fails, total
        total += 1
        raw = call_la_fn(la_binary, fn, *args)
        got = float(raw)
        if not close(got, expected, atol, rtol):
            fails += 1
            print(f"  FAIL {label}: got {got!r}, want {expected!r}, atol={atol}, rtol={rtol}")

    def la_run_vec(label, fn, args, expected_list, atol, rtol):
        nonlocal fails, total
        raw = call_la_fn(la_binary, fn, *args)
        got_list = [float(x) for x in raw.split()]
        if len(got_list) != len(expected_list):
            total += 1
            fails += 1
            print(f"  FAIL {label}: length mismatch got {len(got_list)}, want {len(expected_list)}")
            return
        for i, (got, want) in enumerate(zip(got_list, expected_list)):
            total += 1
            if not close(got, want, atol, rtol):
                fails += 1
                print(f"  FAIL {label}[{i}]: got {got!r}, want {want!r}")

    def la_run_vec_all_nan(label, fn, args, expected_len):
        nonlocal fails, total
        raw = call_la_fn(la_binary, fn, *args)
        got_list = [float(x) for x in raw.split()]
        if len(got_list) != expected_len:
            total += 1
            fails += 1
            print(f"  FAIL {label}: length mismatch got {len(got_list)}, want {expected_len}")
            return
        for i, got in enumerate(got_list):
            total += 1
            if not math.isnan(got):
                fails += 1
                print(f"  FAIL {label}[{i}]: got {got!r}, want NaN")

    print("== LinAlg: det_2x2 ==")
    g = golden("linalg/det_2x2.json")
    atol_la, rtol_la = g["abs"], g["rel"]
    for mat, det_exp in zip(g["matrices"], g["dets"]):
        flat = [x for row in mat for x in row]
        la_run_scalar(f"det_2x2({flat})", "det_2x2", flat, det_exp, atol_la, rtol_la)

    print("== LinAlg: det_3x3 ==")
    g = golden("linalg/det_3x3.json")
    atol_la, rtol_la = g["abs"], g["rel"]
    for mat, det_exp in zip(g["matrices"], g["dets"]):
        flat = [x for row in mat for x in row]
        la_run_scalar(f"det_3x3({flat[:3]}...)", "det_3x3", flat, det_exp, atol_la, rtol_la)

    print("== LinAlg: vector ops ==")
    g = golden("linalg/vector.json")
    atol_la, rtol_la = g["abs"], g["rel"]
    v = g["v"]
    w = g["w"]
    n = len(v)
    la_run_scalar("l2_norm_vec(v)", "l2_norm_vec", [n] + v, g["l2_v"], atol_la, rtol_la)
    la_run_scalar("l2_norm_vec(w)", "l2_norm_vec", [n] + w, g["l2_w"], atol_la, rtol_la)
    la_run_scalar("inner_product(v,w)", "inner_product", [n] + v + w, g["inner_vw"], atol_la, rtol_la)

    # vec add / sub: v + w and v - w (check against python-computed values)
    v_plus_w = [a_ + b_ for a_, b_ in zip(v, w)]
    v_minus_w = [a_ - b_ for a_, b_ in zip(v, w)]
    la_run_vec("la_vec_add(v,w)", "la_vec_add", [n] + v + w, v_plus_w, atol_la, rtol_la)
    la_run_vec("la_vec_sub(v,w)", "la_vec_sub", [n] + v + w, v_minus_w, atol_la, rtol_la)

    # scale_vec: 2.0 * v
    scale = 2.0
    scaled_v = [scale * x for x in v]
    la_run_vec("scale_vec(2.0,v)", "scale_vec", [scale, n] + v, scaled_v, atol_la, rtol_la)

    print("== LinAlg: basic.json (frobenius, trace) ==")
    g = golden("linalg/basic.json")
    atol_la, rtol_la = g["abs"], g["rel"]

    # frobenius_sq and frobenius_norm of A_3x4
    flat_a = [x for row in g["A_3x4"] for x in row]
    la_run_scalar("frobenius_sq(A)", "frobenius_sq", [3, 4] + flat_a,
                  g["frobenius_sq_A"], atol_la, rtol_la)
    la_run_scalar("frobenius_norm(A)", "frobenius_norm", [3, 4] + flat_a,
                  g["frobenius_A"], atol_la, rtol_la)

    # trace_scalar of AtA_4x4
    flat_ata = [x for row in g["gram_AtA_4x4"] for x in row]
    la_run_scalar("trace_scalar(AtA)", "trace_scalar", [4] + flat_ata,
                  g["trace_AtA"], atol_la, rtol_la)

    print("== LinAlg: inv_2x2 + solve_2x2 ==")
    # Use det_2x2 matrices that are invertible
    g = golden("linalg/det_2x2.json")
    atol_la, rtol_la = g["abs"], g["rel"]
    for mat in g["matrices"]:
        flat = [x for row in mat for x in row]
        a00, a01, a10, a11 = flat
        det = a00 * a11 - a01 * a10
        if abs(det) < 1e-10:
            continue
        inv_exp = [a11 / det, -a01 / det, -a10 / det, a00 / det]
        la_run_vec(f"inv_2x2({flat})", "inv_2x2", flat, inv_exp, 1e-4, 1e-4)

        # solve_2x2: A x = b  where b = [1, 0]
        b = [1.0, 0.0]
        x_exp = [inv_exp[0], inv_exp[2]]  # first column of A^-1
        la_run_vec(f"solve_2x2({flat},b)", "solve_2x2", flat + b, x_exp, 1e-4, 1e-4)

    print("== LinAlg: inv_3x3 + solve_3x3 ==")
    g = golden("linalg/det_3x3.json")
    atol_la, rtol_la = g["abs"], g["rel"]
    for mat, det_val in zip(g["matrices"], g["dets"]):
        flat = [x for row in mat for x in row]
        if abs(det_val) < 1e-10:
            continue
        # Compute expected inverse: inv(A) = adj(A)/det = cofactor^T / det
        m = mat
        cof = [
            [m[1][1]*m[2][2]-m[1][2]*m[2][1], -(m[1][0]*m[2][2]-m[1][2]*m[2][0]), m[1][0]*m[2][1]-m[1][1]*m[2][0]],
            [-(m[0][1]*m[2][2]-m[0][2]*m[2][1]), m[0][0]*m[2][2]-m[0][2]*m[2][0], -(m[0][0]*m[2][1]-m[0][1]*m[2][0])],
            [m[0][1]*m[1][2]-m[0][2]*m[1][1], -(m[0][0]*m[1][2]-m[0][2]*m[1][0]), m[0][0]*m[1][1]-m[0][1]*m[1][0]],
        ]
        # adjugate = cofactor transposed
        inv_exp = [cof[c][r] / det_val for r in range(3) for c in range(3)]
        la_run_vec(f"inv_3x3(det={det_val:.2f})", "inv_3x3", flat, inv_exp, 1e-3, 1e-3)

        # solve_3x3: A x = [1,0,0] => x = first column of A^-1
        b = [1.0, 0.0, 0.0]
        x_exp = [inv_exp[0], inv_exp[3], inv_exp[6]]
        la_run_vec(f"solve_3x3(det={det_val:.2f},b)", "solve_3x3", flat + b, x_exp, 1e-3, 1e-3)

    print("== LinAlg: matvec ==")
    # Use A_3x4 * first column of B_4x2 from basic.json
    g = golden("linalg/basic.json")
    atol_la, rtol_la = g["abs"], g["rel"]
    flat_a = [x for row in g["A_3x4"] for x in row]
    # Extract first column of B_4x2
    b_col0 = [row[0] for row in g["B_4x2"]]
    # Expected: first column of AB_3x2
    ab_col0 = [row[0] for row in g["AB_3x2"]]
    la_run_vec("matvec(A,b_col0)", "matvec", [3, 4] + flat_a + b_col0,
               ab_col0, atol_la, rtol_la)
    # Second column
    b_col1 = [row[1] for row in g["B_4x2"]]
    ab_col1 = [row[1] for row in g["AB_3x2"]]
    la_run_vec("matvec(A,b_col1)", "matvec", [3, 4] + flat_a + b_col1,
               ab_col1, atol_la, rtol_la)

    # --- Stats tensor-path tests ---
    print("== Stats ==")
    g = golden("stats/vector.json")
    atol_s, rtol_s = g["abs"], g["rel"]
    v = g["v"]
    n = len(v)
    la_run_scalar("mean_vec", "mean_vec", [n] + v, g["mean"], atol_s, rtol_s)
    la_run_scalar("variance_vec(ddof=0)", "variance_vec_ddof0", [n] + v, g["var_ddof0"], atol_s, rtol_s)
    la_run_scalar("variance_vec(ddof=1)", "variance_vec_ddof1", [n] + v, g["var_ddof1"], atol_s, rtol_s)
    la_run_scalar("std_vec(ddof=0)", "std_vec_ddof0", [n] + v, g["std_ddof0"], atol_s, rtol_s)
    la_run_scalar("std_vec(ddof=1)", "std_vec_ddof1", [n] + v, g["std_ddof1"], atol_s, rtol_s)
    la_run_scalar("skewness_vec", "skewness_vec", [n] + v, g["skew"], atol_s, rtol_s)
    la_run_scalar("kurtosis_vec", "kurtosis_vec", [n] + v, g["kurtosis"], atol_s, rtol_s)
    la_run_scalar("median_vec", "median_vec", [n] + v, g["median"], atol_s, rtol_s)
    la_run_scalar("min_vec", "min_vec", [n] + v, g["min"], atol_s, rtol_s)
    la_run_scalar("max_vec", "max_vec", [n] + v, g["max"], atol_s, rtol_s)
    la_run_scalar("range_vec", "range_vec", [n] + v, g["range"], atol_s, rtol_s)
    la_run_scalar("quantile_vec(0.25)", "quantile_vec", [n, 0.25] + v, g["quantile_25"], atol_s, rtol_s)
    la_run_scalar("quantile_vec(0.50)", "quantile_vec", [n, 0.50] + v, g["quantile_50"], atol_s, rtol_s)
    la_run_scalar("quantile_vec(0.75)", "quantile_vec", [n, 0.75] + v, g["quantile_75"], atol_s, rtol_s)
    la_run_scalar("percentile_vec(10)", "percentile_vec", [n, 10.0] + v, g["percentile_10"], atol_s, rtol_s)
    la_run_scalar("percentile_vec(90)", "percentile_vec", [n, 90.0] + v, g["percentile_90"], atol_s, rtol_s)
    la_run_scalar("trimmed_mean_vec(0.1)", "trimmed_mean_vec", [n, 0.1] + v, g["trimmed_mean_10"], atol_s, rtol_s)
    w = g["w"]
    la_run_scalar("covariance_scalar(ddof=0)", "covariance_scalar", [n, 0] + v + w, g["cov_ddof0"], atol_s, rtol_s)
    la_run_scalar("covariance_scalar(ddof=1)", "covariance_scalar", [n, 1] + v + w, g["cov_ddof1"], atol_s, rtol_s)
    la_run_scalar("correlation_scalar", "correlation_scalar", [n] + v + w, g["correlation"], atol_s, rtol_s)

    # --- Distance tensor-path tests ---
    print("== Distance ==")
    g = golden("distance/vector.json")
    atol_d, rtol_d = g["abs"], g["rel"]
    a_vec = g["a"]
    b_vec = g["b"]
    nd = len(a_vec)
    la_run_scalar("squared_euclidean", "squared_euclidean", [nd] + a_vec + b_vec, g["squared_euclidean"], atol_d, rtol_d)
    la_run_scalar("euclidean", "euclidean", [nd] + a_vec + b_vec, g["euclidean"], atol_d, rtol_d)
    la_run_scalar("manhattan", "manhattan", [nd] + a_vec + b_vec, g["manhattan"], atol_d, rtol_d)
    la_run_scalar("chebyshev", "chebyshev", [nd] + a_vec + b_vec, g["chebyshev"], atol_d, rtol_d)
    la_run_scalar("cosine_similarity", "cosine_similarity", [nd] + a_vec + b_vec, g["cosine_similarity"], atol_d, rtol_d)
    la_run_scalar("cosine_distance", "cosine_distance", [nd] + a_vec + b_vec, g["cosine_distance"], atol_d, rtol_d)

    # --- la_vec_saxpy ---
    print("== LinAlg: la_vec_saxpy ==")
    g = golden("linalg/vector.json")
    atol_la, rtol_la = g["abs"], g["rel"]
    v = g["v"]
    w = g["w"]
    n = len(v)
    alpha = 2.5
    saxpy_exp = [x + alpha * y for x, y in zip(v, w)]
    la_run_vec("la_vec_saxpy(2.5,v,w)", "la_vec_saxpy", [alpha, n] + v + w, saxpy_exp, atol_la, rtol_la)

    # --- LinAlg: gram, aat, transpose, matmul_wrap, diag, trace_mat, vecmat, cholesky_2x2 ---
    print("== LinAlg: gram ==")
    g = golden("linalg/basic.json")
    atol_la, rtol_la = g["abs"], g["rel"]
    flat_a = [x for row in g["A_3x4"] for x in row]
    flat_gram = [x for row in g["gram_AtA_4x4"] for x in row]
    la_run_vec("gram(A_3x4)", "gram", [3, 4] + flat_a, flat_gram, atol_la, rtol_la)

    print("== LinAlg: aat ==")
    flat_aat = [x for row in g["aat_3x3"] for x in row]
    la_run_vec("aat(A_3x4)", "aat", [3, 4] + flat_a, flat_aat, atol_la, rtol_la)

    print("== LinAlg: transpose ==")
    flat_at = [x for row in g["A_T_4x3"] for x in row]
    la_run_vec("transpose(A_3x4)", "transpose", [3, 4] + flat_a, flat_at, atol_la, rtol_la)

    print("== LinAlg: matmul_wrap ==")
    flat_b = [x for row in g["B_4x2"] for x in row]
    flat_ab = [x for row in g["AB_3x2"] for x in row]
    la_run_vec("matmul_wrap(A_3x4,B_4x2)", "matmul_wrap",
               [3, 4, 2] + flat_a + flat_b, flat_ab, atol_la, rtol_la)

    print("== LinAlg: diag ==")
    flat_ata = [x for row in g["gram_AtA_4x4"] for x in row]
    la_run_vec("diag(AtA_4x4)", "diag", [4] + flat_ata, g["diag_AtA"], atol_la, rtol_la)

    print("== LinAlg: trace_mat ==")
    la_run_scalar("trace_mat(AtA_4x4)", "trace_mat", [4] + flat_ata,
                  g["trace_AtA"], atol_la, rtol_la)

    print("== LinAlg: vecmat ==")
    # vecmat[m,n](v: tensor[m,f32], a: tensor[m,n,f32]) -> tensor[n,f32]
    # v = first column of A_3x4 (3 elements), multiply v^T by A_3x4 (3x4) -> 4 elements
    A = g["A_3x4"]
    v_col0 = [A[i][0] for i in range(3)]
    vecmat_expected = [
        sum(v_col0[i] * A[i][j] for i in range(3))
        for j in range(4)
    ]
    la_run_vec("vecmat(col0,A_3x4)", "vecmat", [3, 4] + v_col0 + flat_a,
               vecmat_expected, atol_la, rtol_la)

    print("== LinAlg: cholesky_2x2 ==")
    import math as _math
    chol_input = [4.0, 2.0, 2.0, 3.0]
    chol_expected = [2.0, 0.0, 1.0, _math.sqrt(2.0)]
    la_run_vec("cholesky_2x2([[4,2],[2,3]])", "cholesky_2x2",
               chol_input, chol_expected, 1e-5, 1e-5)

    print("== LinAlg: negative cases ==")
    la_run_vec_all_nan("solve_2x2(singular)", "solve_2x2",
                       [1.0, 2.0, 2.0, 4.0, 1.0, 0.0], 2)
    la_run_vec_all_nan("solve_3x3(singular)", "solve_3x3",
                       [1.0, 2.0, 3.0,
                        2.0, 4.0, 6.0,
                        0.0, 1.0, 1.0,
                        1.0, 0.0, 0.0], 3)
    la_run_vec_all_nan("cholesky_2x2(non_psd)", "cholesky_2x2",
                       [1.0, 2.0, 2.0, 1.0], 4)

    # --- SDE tensor-path tests ---
    print("== SDE ==")
    g = golden("sde/scalar.json")
    atol_sde, rtol_sde = g["abs"], g["rel"]
    for case in g["cases"]:
        label = case["label"]
        y0, t0, t1 = case["y0"], case["t0"], case["t1"]
        ns = case["n_steps"]
        mode = case["noise_mode"]
        if mode == "zero":
            noise = [0.0] * ns
        elif mode == "plus":
            noise = [1.0] * ns
        elif mode == "alt":
            noise = [1.0 if i % 2 == 0 else -1.0 for i in range(ns)]
        else:
            continue
        expected = case["expected"]
        if label.startswith("em_"):
            sigma = case.get("sigma", 1.0)
            fn_tag = "test_em_decay_s1" if sigma == 1.0 else "test_em_decay_s01"
            la_run_scalar(label, fn_tag, [y0, t0, t1, ns] + noise,
                          expected, atol_sde, rtol_sde)
        elif label == "milstein_gbm":
            la_run_scalar(label, "test_milstein_gbm", [y0, t0, t1, ns] + noise,
                          expected, atol_sde, rtol_sde)

    # --- cg_solve ---
    print("== LinAlg: cg_solve ==")
    # Use cholesky_2x2 test matrix [[4,2],[2,3]] — it's SPD.
    # Ax = b → x = A^{-1} b
    # A^{-1} = [[3,-2],[-2,4]] / 8 = [[0.375,-0.25],[-0.25,0.5]]
    # b = [1, 2] → x = [0.375*1 + (-0.25)*2, -0.25*1 + 0.5*2] = [-0.125, 0.75]
    cg_a = [4.0, 2.0, 2.0, 3.0]
    cg_b = [1.0, 2.0]
    cg_x0 = [0.0, 0.0]
    cg_expected = [-0.125, 0.75]
    la_run_vec("cg_solve(2x2)", "cg_solve",
               [2, 1e-7, 100] + cg_a + cg_b + cg_x0,
               cg_expected, 1e-4, 1e-4)
    # 3x3 SPD: [[2,1,0],[1,3,1],[0,1,2]], b=[1,2,3]
    # inv = [[5,-2,-1],[-2,4,-2],[-1,-2,5]] / 8
    # x = inv @ [1,2,3] = [(5-4-3)/8, (-2+8-6)/8, (-1-4+15)/8] = [-0.25, 0.0, 1.25]
    cg_a3 = [2.0, 1.0, 0.0, 1.0, 3.0, 1.0, 0.0, 1.0, 2.0]
    cg_b3 = [1.0, 2.0, 3.0]
    cg_x03 = [0.0, 0.0, 0.0]
    cg_exp3 = [0.5, 0.0, 1.5]
    la_run_vec("cg_solve(3x3)", "cg_solve",
               [3, 1e-7, 100] + cg_a3 + cg_b3 + cg_x03,
               cg_exp3, 1e-3, 1e-3)

    # --- eig_2x2_real ---
    print("== LinAlg: eig_2x2_real ==")
    # [[2, 1], [1, 2]] → eigenvalues 3 and 1
    la_run_vec("eig_2x2_real([[2,1],[1,2]])", "eig_2x2_real",
               [2.0, 1.0, 1.0, 2.0], [3.0, 1.0], 1e-5, 1e-5)
    # [[5, 4], [1, 2]] → eigenvalues 6 and 1 (trace=7, det=6, disc=25, sqrt=5)
    la_run_vec("eig_2x2_real([[5,4],[1,2]])", "eig_2x2_real",
               [5.0, 4.0, 1.0, 2.0], [6.0, 1.0], 1e-5, 1e-5)
    # [[1, 0], [0, 3]] → eigenvalues 3 and -1? No: trace=4, det=3, disc=1, sqrt=1 → 2.5, 1.5
    # Actually: t/2=2, disc = 4-3 = 1, sqrt=1, so lam1=3, lam2=1
    la_run_vec("eig_2x2_real([[1,0],[0,3]])", "eig_2x2_real",
               [1.0, 0.0, 0.0, 3.0], [3.0, 1.0], 1e-5, 1e-5)

    # --- Mahalanobis distance ---
    print("== Distance: mahalanobis ==")
    # a=[1,0], b=[0,1], cov_inv=I_2x2 → mahalanobis_squared = |a-b|^2 = 2, mahalanobis = sqrt(2)
    import math as _math
    cov_inv_id = [1.0, 0.0, 0.0, 1.0]
    la_run_scalar("mahalanobis_sq(id)", "mahalanobis_squared",
                  [2, 1.0, 0.0, 0.0, 1.0] + cov_inv_id, 2.0, 1e-5, 1e-5)
    la_run_scalar("mahalanobis(id)", "mahalanobis",
                  [2, 1.0, 0.0, 0.0, 1.0] + cov_inv_id, _math.sqrt(2.0), 1e-5, 1e-5)
    # Non-identity: cov_inv = [[2, 0], [0, 0.5]], a=[3,1], b=[1,1]
    # diff=[2,0], d^T cov_inv d = 2*4 + 0.5*0 = 8
    la_run_scalar("mahalanobis_sq(diag)", "mahalanobis_squared",
                  [2, 3.0, 1.0, 1.0, 1.0, 2.0, 0.0, 0.0, 0.5], 8.0, 1e-5, 1e-5)
    la_run_scalar("mahalanobis(diag)", "mahalanobis",
                  [2, 3.0, 1.0, 1.0, 1.0, 2.0, 0.0, 0.0, 0.5], _math.sqrt(8.0), 1e-5, 1e-5)

    # --- Interpolation ---
    print("== Interpolation: linear_interp ==")
    # uniform grid: ys=[0, 1, 4, 9] on x in [0, 3] (values are x^2 at 0,1,2,3)
    # query x=1.5 → between ys[1]=1 and ys[2]=4, frac=0.5 → 2.5
    la_run_scalar("linear_interp_uniform(1.5)", "linear_interp_uniform",
                  [4, 0.0, 3.0, 1.5, 0.0, 1.0, 4.0, 9.0], 2.5, 1e-5, 1e-5)
    # query x=0.0 (left edge) → 0.0
    la_run_scalar("linear_interp_uniform(0.0)", "linear_interp_uniform",
                  [4, 0.0, 3.0, 0.0, 0.0, 1.0, 4.0, 9.0], 0.0, 1e-5, 1e-5)
    # query x=3.0 (right edge) → 9.0
    la_run_scalar("linear_interp_uniform(3.0)", "linear_interp_uniform",
                  [4, 0.0, 3.0, 3.0, 0.0, 1.0, 4.0, 9.0], 9.0, 1e-5, 1e-5)
    # query x=2.25 → between ys[2]=4 and ys[3]=9, frac=0.25 → 4 + 0.25*5 = 5.25
    la_run_scalar("linear_interp_uniform(2.25)", "linear_interp_uniform",
                  [4, 0.0, 3.0, 2.25, 0.0, 1.0, 4.0, 9.0], 5.25, 1e-5, 1e-5)

    # sorted grid: xs=[1, 2, 4, 8], ys=[10, 20, 40, 80] (linear y=10*x)
    # query x=3 → between (2,20) and (4,40), frac=(3-2)/(4-2)=0.5 → 30
    la_run_scalar("linear_interp_sorted(3)", "linear_interp_sorted",
                  [4, 3.0, 1.0, 2.0, 4.0, 8.0, 10.0, 20.0, 40.0, 80.0], 30.0, 1e-5, 1e-5)
    # query x=1 (left edge) → 10
    la_run_scalar("linear_interp_sorted(1)", "linear_interp_sorted",
                  [4, 1.0, 1.0, 2.0, 4.0, 8.0, 10.0, 20.0, 40.0, 80.0], 10.0, 1e-5, 1e-5)
    # query x=6 → between (4,40) and (8,80), frac=(6-4)/(8-4)=0.5 → 60
    la_run_scalar("linear_interp_sorted(6)", "linear_interp_sorted",
                  [4, 6.0, 1.0, 2.0, 4.0, 8.0, 10.0, 20.0, 40.0, 80.0], 60.0, 1e-5, 1e-5)

    # --- CurveFit ---
    print("== CurveFit: lm_scalar_1param ==")
    # Fit y = theta * x. Data: xs=[1,2,3,4], ys=[2,4,6,8]. True theta = 2.0.
    la_run_scalar("lm_linear(theta=2)", "test_lm_linear",
                  [4, 0.5, 1.0, 2.0, 3.0, 4.0, 2.0, 4.0, 6.0, 8.0], 2.0, 1e-4, 1e-4)
    # Fit y = exp(-theta*x). Data: xs=[0,1,2,3], ys=[1.0, e^-0.5, e^-1, e^-1.5].
    # True theta = 0.5.
    import math as _m
    exp_ys = [1.0, _m.exp(-0.5), _m.exp(-1.0), _m.exp(-1.5)]
    la_run_scalar("lm_exp(theta=0.5)", "test_lm_exp",
                  [4, 1.0, 0.0, 1.0, 2.0, 3.0] + exp_ys, 0.5, 1e-3, 1e-3)

    # --- Track 2: cg_solve on ill-conditioned systems ---
    print("== LinAlg: cg_solve (ill-conditioned) ==")
    # cond ~200: A=[[1,0.99],[0.99,1]], b=[1,1] → x≈[0.5025, 0.5025]
    la_run_vec("cg_solve(cond~200)", "cg_solve",
               [2, 1e-5, 500, 1.0, 0.99, 0.99, 1.0, 1.0, 1.0, 0.0, 0.0],
               [0.50251256281407, 0.50251256281407], 1e-3, 1e-3)
    # cond ~2000: A=[[1,0.999],[0.999,1]], b=[1,1] → x≈[0.5003, 0.5003]
    la_run_vec("cg_solve(cond~2000)", "cg_solve",
               [2, 1e-5, 500, 1.0, 0.999, 0.999, 1.0, 1.0, 1.0, 0.0, 0.0],
               [0.500250125062538, 0.500250125062538], 1e-2, 1e-2)

    # --- Track 3: mahalanobis with dense covariance inverse ---
    print("== Distance: mahalanobis (dense cov_inv) ==")
    # cov_inv=[[2,-1],[-1,2]], a=[3,1], b=[1,2], diff=[2,-1]
    # diff^T cov_inv diff = [2,-1]@[5,-4] = 14
    la_run_scalar("mahalanobis_sq(dense)", "mahalanobis_squared",
                  [2, 3.0, 1.0, 1.0, 2.0, 2.0, -1.0, -1.0, 2.0], 14.0, 1e-4, 1e-4)
    la_run_scalar("mahalanobis(dense)", "mahalanobis",
                  [2, 3.0, 1.0, 1.0, 2.0, 2.0, -1.0, -1.0, 2.0], 3.74165738677394, 1e-4, 1e-4)

    # --- Track 4: SDE with realistic noise ---
    print("== SDE: realistic noise ==")
    noise_realistic = [_m.sin(i * 1.7 + 0.3) for i in range(20)]
    # Expected: euler_maruyama on GBM dy=0.05*y*dt + 0.2*y*dW, y0=1, t=[0,1], 20 steps
    la_run_scalar("em_gbm_realistic", "test_em_gbm_realistic",
                  [1.0, 0.0, 1.0, 20] + noise_realistic,
                  1.08178023531837, 1e-4, 1e-4)

    # --- Track 5: LM with noisy data ---
    print("== CurveFit: noisy fit ==")
    noisy_xs = [0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0, 4.5, 5.0]
    noisy_ys = [1.05, 1.92, 3.12, 3.97, 5.07, 5.89, 7.04, 7.94, 9.09, 9.98]
    la_run_scalar("lm_linear(noisy)", "test_lm_linear",
                  [10, 0.5] + noisy_xs + noisy_ys, 2.0, 0.1, 0.05)

    # --- Track 1: distribution sample variants ---
    print("== Distributions: sample (deterministic seed) ==")
    zeros8 = [0.0] * 8
    # Expected values are deterministic (seed=0, chelis_uniform_sample_f32 hash)
    la_run_vec("uniform_sample(8)", "test_uniform_sample", [8] + zeros8,
               [2.0, 4.64993238449097, 3.29458403587341, 2.07930135726929,
                4.91264581680298, 2.31904006004333, 2.98197722434998, 2.52160358428955],
               1e-4, 1e-4)
    la_run_vec("normal_sample(8)", "test_normal_sample", [8] + zeros8,
               [5.67769241333008, 0.370152562856674, -1.17833054065704, 2.65849828720093,
                0.239049032330513, 1.6617956161499, -0.697885394096375, 0.861041247844696],
               1e-4, 1e-4)
    la_run_vec("exponential_sample(8)", "test_exponential_sample", [8] + zeros8,
               [8.05904769897461, 0.0620390810072422, 0.420211404561996, 1.8165545463562,
                0.0147751718759537, 1.12052500247955, 0.558399617671967, 0.874729573726654],
               1e-4, 1e-4)
    la_run_vec("lognormal_sample(8)", "test_lognormal_sample", [8] + zeros8,
               [17.0960292816162, 1.20331025123596, 0.554790198802948, 3.77820539474487,
                1.12696087360382, 2.29537868499756, 0.705433547496796, 1.53805804252625],
               1e-4, 1e-4)

    print(f"\n{total - fails} / {total} numerical assertions passed")
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
