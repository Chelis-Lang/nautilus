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

This bypasses the broken `chelis eval --file` and the unavailable
libchelis_runtime.a — the bare scalar functions don't need either.

The harness covers Nautilus.Special and Nautilus.Distributions scalar
functions only. Nautilus.LinAlg ops that take tensor inputs are covered by
the API-smoke type check (src/apismoke.ch + chelis check), since their
runtime exercise requires the full chelis runtime. As of v0.1.4 the
runtime ships as `libchelis_runtime.a` — enabling tensor-path runtime
tests is tracked separately (see UPSTREAM_BUGS.md Bug 3 status).
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
CHELIS = os.environ.get("CHELIS_BIN", "/tmp/chelisbin")


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


RUNTIME_STUBS = """\
#include <stdint.h>
#include <stdlib.h>
typedef struct chelis_tensor chelis_tensor;
typedef struct chelis_list chelis_list;
typedef struct chelis_tuple chelis_tuple;
typedef struct chelis_value_s { int dummy; } chelis_value;
int64_t chelis_list_len(const chelis_list* x) { return 0; }
chelis_value chelis_list_index(const chelis_list* x, int64_t i) { chelis_value v={0}; return v; }
chelis_tuple* chelis_value_as_tuple(chelis_value v) { return NULL; }
chelis_value chelis_tuple_get(const chelis_tuple* t, int64_t i) { chelis_value v={0}; return v; }
double chelis_value_as_f64(chelis_value v) { return 0.0; }
chelis_value chelis_value_from_f64(double x) { chelis_value v={0}; return v; }
chelis_list* chelis_list_append(chelis_list* l, chelis_value v) { return l; }
chelis_list* chelis_list_empty(void) { return NULL; }
chelis_list* chelis_list_zip(const chelis_list* a, const chelis_list* b) { return NULL; }
chelis_list* chelis_list_from_tensor(const chelis_tensor* t) { return NULL; }
chelis_tensor* chelis_tensor_from_value_list(const chelis_list* l) { return NULL; }
chelis_tensor* chelis_alloc(int ndim, int* shape, int dtype) { return NULL; }
chelis_tensor* chelis_uniform_like_f32(chelis_tensor* t, float lo, float hi) { return NULL; }
void chelis_contiguous(chelis_tensor* t) {}
void chelis_free(chelis_tensor* t) {}
int64_t chelis_tensor_numel(const chelis_tensor* t) { return 0; }
chelis_list* chelis_list_enumerate(const chelis_list* l) { return NULL; }
chelis_tuple* chelis_tuple_from_values(const chelis_value* vs, int64_t n) { return NULL; }
int64_t chelis_value_as_int64(chelis_value v) { return 0; }
int chelis_value_as_bool(chelis_value v) { return 0; }
chelis_value chelis_value_from_bool(int b) { chelis_value v={0}; return v; }
chelis_value chelis_value_from_int64(int64_t n) { chelis_value v={0}; return v; }
chelis_list* chelis_range_i64(int64_t start, int64_t end) { return NULL; }
"""


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
    rt_c = workdir / "runtime_stubs.c"
    rt_c.write_text(RUNTIME_STUBS)
    binary = workdir / "nautilus_test_bin"
    cc = subprocess.run(
        ["gcc", "-O2", "-o", str(binary),
         str(c_file), str(drv_c), str(rt_c),
         "-I", str(workdir / "out"), "-lm"],
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
    rt_c = workdir / "p1_runtime_stubs.c"
    rt_c.write_text(RUNTIME_STUBS)
    binary = workdir / "p1_test_bin"
    cc = subprocess.run(
        ["gcc", "-O2", "-o", str(binary),
         str(c_file), str(drv_c), str(rt_c),
         "-I", str(workdir / "out"), "-lm"],
        capture_output=True, text=True,
    )
    if cc.returncode != 0:
        raise SystemExit(f"p1 gcc failed: {cc.stderr}")
    return binary


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

    print(f"\n{total - fails} / {total} numerical assertions passed")
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
