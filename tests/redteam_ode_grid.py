#!/usr/bin/env python3
"""Adversarial tests for rk45_adaptive_solve_grid."""
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
CHELIS = "/tmp/chelis-toolchain-v21maj/chelis-v0.2.1-linux-x86_64/bin/chelis"


def strip_module(src: str) -> str:
    src = re.sub(r"^module .*\n", "", src, flags=re.M)
    src = re.sub(r"^import .*\n", "", src, flags=re.M)
    src = re.sub(r"^export \([^)]*\)\s*\n", "", src, flags=re.M | re.S)
    return src


def _dedup_defs(bare: str) -> str:
    seen: dict[str, int] = {}
    out: list[str] = []
    for lineno, line in enumerate(bare.split("\n"), 1):
        m = re.match(r"^def\s+(\w+)\b", line)
        if m:
            name = m.group(1)
            if name in seen:
                continue
            seen[name] = lineno
        out.append(line)
    return "\n".join(out)


def chelis_build(bare_ch: Path, outdir: Path) -> Path:
    if outdir.exists():
        shutil.rmtree(outdir)
    proc = subprocess.run(
        [CHELIS, "build", str(bare_ch), "-o", str(outdir)],
        capture_output=True, text=True,
    )
    msg = (proc.stdout + proc.stderr).strip()
    if "cannot find libchelis_runtime.a" not in msg and proc.returncode != 0:
        raise SystemExit(f"chelis build failed:\n{msg}")
    c_file = outdir / f"{bare_ch.stem}.c"
    if not c_file.exists():
        raise SystemExit(f"no C output: {c_file}")
    txt = c_file.read_text()
    txt = txt.replace("double main", "double chelis_entry")
    c_file.write_text(txt)
    return c_file


DRIVER_C = r"""
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <math.h>
#include "chelis_runtime.h"

/* ---- Chelis function declarations ---- */
/* scalar decay: n=1, p=4 */
chelis_tensor* test_ode_grid_n1_p4(chelis_tensor* y0, chelis_tensor* t_out);
/* 2-state decay: n=2, p=3 */
chelis_tensor* test_ode_grid_n2_p3(chelis_tensor* y0, chelis_tensor* t_out);

/* adversarial wrappers (dynamic size versions) */
/* We'll add extra test functions below */
chelis_tensor* test_ode_grid_n1_p2_late(chelis_tensor* y0, chelis_tensor* t_out);
chelis_tensor* test_ode_grid_n1_p1_tend(chelis_tensor* y0, chelis_tensor* t_out);
chelis_tensor* test_ode_grid_n1_p4_dense(chelis_tensor* y0, chelis_tensor* t_out);

static chelis_tensor* make_vec(int n, double* vals) {
    chelis_tensor* t = chelis_alloc(1, (int[]){n}, 0);
    for (int i = 0; i < n; i++) t->data[i] = (float)vals[i];
    return t;
}

static void print_mat(chelis_tensor* t) {
    int total = t->size;
    for (int i = 0; i < total; i++) {
        if (i > 0) printf(" ");
        printf("%.15g", (double)t->data[i]);
    }
    printf("\n");
}

static void print_scalar(double v) { printf("%.15g\n", v); }

int main(int argc, char** argv) {
    if (argc < 2) { fprintf(stderr, "usage: rt FN ARGS...\n"); return 1; }
    const char* fn = argv[1];
    double a[256] = {0};
    int nargs = argc - 2;
    for (int i = 0; i < nargs && i < 256; i++) a[i] = atof(argv[2+i]);

    if (!strcmp(fn, "test_ode_grid_n1_p4")) {
        chelis_tensor* y0 = make_vec(1, a);
        chelis_tensor* t_out = make_vec(4, a+1);
        chelis_tensor* r = test_ode_grid_n1_p4(y0, t_out);
        print_mat(r);
        return 0;
    }
    if (!strcmp(fn, "test_ode_grid_n2_p3")) {
        chelis_tensor* y0 = make_vec(2, a);
        chelis_tensor* t_out = make_vec(3, a+2);
        chelis_tensor* r = test_ode_grid_n2_p3(y0, t_out);
        print_mat(r);
        return 0;
    }
    if (!strcmp(fn, "test_ode_grid_n1_p2_late")) {
        chelis_tensor* y0 = make_vec(1, a);
        chelis_tensor* t_out = make_vec(2, a+1);
        chelis_tensor* r = test_ode_grid_n1_p2_late(y0, t_out);
        print_mat(r);
        return 0;
    }
    if (!strcmp(fn, "test_ode_grid_n1_p1_tend")) {
        chelis_tensor* y0 = make_vec(1, a);
        chelis_tensor* t_out = make_vec(1, a+1);
        chelis_tensor* r = test_ode_grid_n1_p1_tend(y0, t_out);
        print_mat(r);
        return 0;
    }
    if (!strcmp(fn, "test_ode_grid_n1_p4_dense")) {
        chelis_tensor* y0 = make_vec(1, a);
        chelis_tensor* t_out = make_vec(4, a+1);
        chelis_tensor* r = test_ode_grid_n1_p4_dense(y0, t_out);
        print_mat(r);
        return 0;
    }
    fprintf(stderr, "unknown fn: %s\n", fn);
    return 2;
}
"""

# Chelis test helpers (adversarial wrappers)
TEST_HELPERS_CH = r"""
def ode_grid_decay1(y: tensor[1, f32], t: f32) -> tensor[1, f32] =
  scale_vec(y, neg(cast(1.0, f32)))

def ode_grid_sys2(y: tensor[2, f32], t: f32) -> tensor[2, f32] = {
  tpl = to_tensor(map(fn (v: f32) -> cast(0.0, f32), to_list(copy(y))))
  y1 = inner_product(copy(y), la_basis_n_f32(cast(0, int64), cast(1.0, f32), copy(tpl)))
  y2 = inner_product(y, la_basis_n_f32(cast(1, int64), cast(1.0, f32), tpl))
  e1 = la_basis_n_f32(cast(0, int64), neg(y1), to_tensor(map(fn (v: int64) -> cast(0.0, f32), range(cast(0, int64), cast(2, int64)))))
  e2 = la_basis_n_f32(cast(1, int64), mul(neg(cast(2.0, f32)), y2), to_tensor(map(fn (v: int64) -> cast(0.0, f32), range(cast(0, int64), cast(2, int64)))))
  la_vec_add(e1, e2)
}

def test_ode_grid_n1_p4(y0: tensor[1, f32], t_out: tensor[4, f32]) -> tensor[1, 4, f32] =
  rk45_adaptive_solve_grid(ode_grid_decay1, cast(0.0, f32), y0, cast(2.0, f32),
    cast(1.0e-6, f32), cast(1.0e-8, f32), t_out)

def test_ode_grid_n2_p3(y0: tensor[2, f32], t_out: tensor[3, f32]) -> tensor[2, 3, f32] =
  rk45_adaptive_solve_grid(ode_grid_sys2, cast(0.0, f32), y0, cast(1.5, f32),
    cast(1.0e-6, f32), cast(1.0e-8, f32), t_out)

def test_ode_grid_n1_p4_dense(y0: tensor[1, f32], t_out: tensor[4, f32]) -> tensor[1, 4, f32] =
  rk45_adaptive_solve_grid(ode_grid_decay1, cast(0.0, f32), y0, cast(1.0, f32),
    cast(1.0e-6, f32), cast(1.0e-8, f32), t_out)

def test_ode_grid_n1_p2_late(y0: tensor[1, f32], t_out: tensor[2, f32]) -> tensor[1, 2, f32] =
  rk45_adaptive_solve_grid(ode_grid_decay1, cast(0.0, f32), y0, cast(2.0, f32),
    cast(1.0e-6, f32), cast(1.0e-8, f32), t_out)

def test_ode_grid_n1_p1_tend(y0: tensor[1, f32], t_out: tensor[1, f32]) -> tensor[1, 1, f32] =
  rk45_adaptive_solve_grid(ode_grid_decay1, cast(0.0, f32), y0, cast(2.0, f32),
    cast(1.0e-6, f32), cast(1.0e-8, f32), t_out)
"""


def build_binary() -> Path:
    bare = "\n".join(
        strip_module((SRC / f).read_text())
        for f in ("special.ch", "distributions.ch", "linalg.ch", "stats.ch",
                  "distance.ch", "sde.ch", "interpolation.ch", "curvefit.ch", "ode.ch")
    ) + TEST_HELPERS_CH + "\ndef main() -> f32 = cast(0.0, f32)\n"
    bare = _dedup_defs(bare)
    workdir = Path(tempfile.mkdtemp(prefix="nautilus-rt-ode-"))
    bare_ch = workdir / "rt_bare.ch"
    bare_ch.write_text(bare)
    c_file = chelis_build(bare_ch, workdir / "out")

    # Copy runtime lib
    out_dir = workdir / "out"
    drv_c = workdir / "rt_driver.c"
    drv_c.write_text(DRIVER_C)
    binary = workdir / "rt_test_bin"

    # Find runtime lib
    rt_dirs = list(Path("/tmp").glob("chelis-toolchain*/*/bin"))
    include_dir = out_dir

    cc = subprocess.run(
        ["gcc", "-O2", "-fopenmp",
         "-o", str(binary),
         str(c_file), str(drv_c),
         "-I", str(include_dir),
         "-L", str(out_dir),
         "-lchelis_runtime", "-lm", "-lpthread"],
        capture_output=True, text=True,
    )
    if cc.returncode != 0:
        raise SystemExit(f"gcc failed:\n{cc.stderr}")
    print(f"[build] binary: {binary}", file=sys.stderr)
    return binary


def call(binary: Path, fn: str, *args: float) -> str:
    res = subprocess.run(
        [str(binary), fn, *(str(a) for a in args)],
        capture_output=True, text=True,
    )
    if res.returncode != 0:
        return f"ERROR: {res.stderr.strip()}"
    return res.stdout.strip()


def close(have: float, want: float, atol: float = 1e-4, rtol: float = 1e-4) -> bool:
    if math.isnan(have) or math.isnan(want):
        return False
    return abs(have - want) <= max(atol, rtol * abs(want))


def report(test_id: str, desc: str, expected: float, got: float,
           atol: float = 1e-4, rtol: float = 1e-4, severity: str = "CRITICAL"):
    ok = close(got, expected, atol, rtol)
    status = "PASS" if ok else f"FAIL [{severity}]"
    err = abs(got - expected) if not (math.isnan(got) or math.isnan(expected)) else float("nan")
    print(f"  [{status}] {test_id}: {desc}")
    print(f"           expected={expected:.8g}, got={got:.8g}, |err|={err:.3e}")
    return ok


def main():
    print("=== Building adversarial ODE grid test binary ===")
    binary = build_binary()
    print(f"Binary built: {binary}\n")

    findings = []
    total = 0
    passes = 0

    def check(test_id, desc, expected, got, atol=1e-4, rtol=1e-4, severity="CRITICAL"):
        nonlocal total, passes
        total += 1
        ok = report(test_id, desc, expected, got, atol, rtol, severity)
        if ok:
            passes += 1
        else:
            findings.append((severity, test_id, desc, expected, got))

    # ============================================================
    # TEST 1: All output points filled (n=1, 4 points, t_out=[0.25,0.5,0.75,1.0])
    # ============================================================
    print("--- Test 1: All output points filled ---")
    raw = call(binary, "test_ode_grid_n1_p4_dense", 1.0, 0.25, 0.5, 0.75, 1.0)
    print(f"  raw output: {raw!r}")
    if raw.startswith("ERROR"):
        print(f"  FAIL [HIGH] Test1: binary error: {raw}")
        findings.append(("HIGH", "Test1", "binary crashed", 0.0, float("nan")))
        total += 4
    else:
        vals = [float(x) for x in raw.split()]
        # tensor[1,4,f32] row-major: vals[0..3] = columns j=0..3 for row i=0
        t_outs = [0.25, 0.5, 0.75, 1.0]
        for j, t in enumerate(t_outs):
            expected = math.exp(-t)
            got = vals[j] if j < len(vals) else float("nan")
            check(f"T1.j{j}", f"t_out[{j}]={t:.2f}: exp(-{t})={expected:.6f}", expected, got)

    # ============================================================
    # TEST 2: Hermite interpolant accuracy at midpoints
    # ============================================================
    print("\n--- Test 2: Hermite interpolant accuracy (t=0.5 from golden case) ---")
    # Using the standard case: t_out=[0.5,1.0,1.5,2.0], t_end=2.0
    raw = call(binary, "test_ode_grid_n1_p4", 1.0, 0.5, 1.0, 1.5, 2.0)
    print(f"  raw output: {raw!r}")
    if raw.startswith("ERROR"):
        print(f"  FAIL [HIGH] Test2: binary error: {raw}")
        findings.append(("HIGH", "Test2", "binary crashed", 0.0, float("nan")))
        total += 1
    else:
        vals = [float(x) for x in raw.split()]
        # j=0 => t=0.5
        got = vals[0] if vals else float("nan")
        expected = math.exp(-0.5)
        check("T2", f"Hermite interp at t=0.5: exp(-0.5)={expected:.6f}", expected, got, atol=1e-4)

    # ============================================================
    # TEST 3: t_out not starting at t0 — t_out=[1.5, 2.0], t0=0, t_end=2
    # ============================================================
    print("\n--- Test 3: t_out=[1.5, 2.0] starting well after t0 ---")
    raw = call(binary, "test_ode_grid_n1_p2_late", 1.0, 1.5, 2.0)
    print(f"  raw output: {raw!r}")
    if raw.startswith("ERROR"):
        print(f"  FAIL [HIGH] Test3: binary error: {raw}")
        findings.append(("HIGH", "Test3", "binary crashed", 0.0, float("nan")))
        total += 2
    else:
        vals = [float(x) for x in raw.split()]
        for j, t in enumerate([1.5, 2.0]):
            expected = math.exp(-t)
            got = vals[j] if j < len(vals) else float("nan")
            check(f"T3.j{j}", f"t_out={t:.1f}: exp(-{t})={expected:.6f}", expected, got)

    # ============================================================
    # TEST 4: n=2 vector interpolation — 2-state system
    # ============================================================
    print("\n--- Test 4: n=2 vector interpolation ---")
    raw = call(binary, "test_ode_grid_n2_p3", 1.0, 1.0, 0.5, 1.0, 1.5)
    print(f"  raw output: {raw!r}")
    # tensor[2,3,f32] row-major: vals[i*3 + j] for row i (state), col j (t_out)
    # y1'=-y1 => y1(t)=exp(-t); y2'=-2*y2 => y2(t)=exp(-2*t)
    if raw.startswith("ERROR"):
        print(f"  FAIL [HIGH] Test4: binary error: {raw}")
        findings.append(("HIGH", "Test4", "binary crashed", 0.0, float("nan")))
        total += 6
    else:
        vals = [float(x) for x in raw.split()]
        t_outs = [0.5, 1.0, 1.5]
        for j, t in enumerate(t_outs):
            exp_y1 = math.exp(-t)
            exp_y2 = math.exp(-2 * t)
            got_y1 = vals[0 * 3 + j] if (0 * 3 + j) < len(vals) else float("nan")
            got_y2 = vals[1 * 3 + j] if (1 * 3 + j) < len(vals) else float("nan")
            check(f"T4.y1.j{j}", f"y1 at t={t}: exp(-t)={exp_y1:.6f}", exp_y1, got_y1)
            check(f"T4.y2.j{j}", f"y2 at t={t}: exp(-2t)={exp_y2:.6f}", exp_y2, got_y2)

    # ============================================================
    # TEST 5: Consistency with scalar solver — grid at t_end should match point solver
    # ============================================================
    print("\n--- Test 5: Consistency with scalar-path (grid at t_end vs standard golden) ---")
    # Use the standard n=1 case with t_out=[2.0] only (the last point), compare with exp(-2)
    raw_grid = call(binary, "test_ode_grid_n1_p1_tend", 1.0, 2.0)
    print(f"  grid@t=2.0 raw: {raw_grid!r}")
    expected_tend = math.exp(-2.0)
    if raw_grid.startswith("ERROR"):
        print(f"  FAIL [HIGH] Test5: binary error: {raw_grid}")
        findings.append(("HIGH", "Test5", "binary crashed", 0.0, float("nan")))
        total += 1
    else:
        got_grid = float(raw_grid.split()[0])
        check("T5.grid_vs_exact", f"grid t_out=[2.0] vs exp(-2)={expected_tend:.8f}", expected_tend, got_grid)
        # Also check the standard 4-point case last point
        raw_4pt = call(binary, "test_ode_grid_n1_p4", 1.0, 0.5, 1.0, 1.5, 2.0)
        vals_4pt = [float(x) for x in raw_4pt.split()]
        got_4pt = vals_4pt[3] if len(vals_4pt) >= 4 else float("nan")
        check("T5.4pt_vs_1pt", f"4-pt grid last vs 1-pt grid: both should be exp(-2)", got_grid, got_4pt, atol=1e-5)

    # ============================================================
    # TEST 6: Dense output accuracy vs step endpoints
    # ============================================================
    print("\n--- Test 6: Dense output (Hermite) vs linear interp accuracy ---")
    # We query at t=0.5 and t=0.25 to see if Hermite is meaningfully better than linear.
    # Use the n=1 solver with dense output [0.25, 0.5, 0.75, 1.0]
    raw_dense = call(binary, "test_ode_grid_n1_p4_dense", 1.0, 0.25, 0.5, 0.75, 1.0)
    print(f"  dense output [0.25,0.5,0.75,1.0]: {raw_dense!r}")
    if raw_dense.startswith("ERROR"):
        print(f"  FAIL [HIGH] Test6: binary error: {raw_dense}")
        findings.append(("HIGH", "Test6", "binary crashed", 0.0, float("nan")))
        total += 1
    else:
        vals_d = [float(x) for x in raw_dense.split()]
        # Focus on t=0.5: Hermite value vs exact vs linear interpolation between t=0 and t=1
        got_hermite_05 = vals_d[1] if len(vals_d) > 1 else float("nan")
        exact_05 = math.exp(-0.5)
        y0_exact = 1.0
        y1_exact = math.exp(-1.0)
        linear_interp_05 = 0.5 * y0_exact + 0.5 * y1_exact  # midpoint between t=0 and t=1
        err_hermite = abs(got_hermite_05 - exact_05)
        err_linear = abs(linear_interp_05 - exact_05)
        print(f"  t=0.5: Hermite={got_hermite_05:.8f}, linear_interp={linear_interp_05:.8f}, exact={exact_05:.8f}")
        print(f"  err_hermite={err_hermite:.3e}, err_linear={err_linear:.3e}")
        if err_hermite < err_linear:
            print(f"  [PASS] T6: Hermite more accurate than linear (ratio={err_hermite/max(err_linear,1e-15):.3f})")
            total += 1
            passes += 1
        else:
            print(f"  [FAIL] T6 [MEDIUM]: Hermite NOT more accurate than linear")
            total += 1
            findings.append(("MEDIUM", "T6", "Hermite should beat linear interp", err_linear, err_hermite))

    # ============================================================
    # TEST 7: t_out at exact t_end — boundary condition
    # ============================================================
    print("\n--- Test 7: t_out=[2.0] exactly at t_end=2.0 ---")
    raw_tend = call(binary, "test_ode_grid_n1_p1_tend", 1.0, 2.0)
    print(f"  raw: {raw_tend!r}")
    if raw_tend.startswith("ERROR"):
        print(f"  FAIL [HIGH] Test7: binary error: {raw_tend}")
        findings.append(("HIGH", "Test7", "binary crashed", 0.0, float("nan")))
        total += 1
    else:
        got = float(raw_tend.split()[0])
        expected = math.exp(-2.0)
        # Check it's non-zero first (off-by-one would leave it as 0.0)
        if abs(got) < 1e-10:
            print(f"  FAIL [CRITICAL] T7: got ~0 (zero fill bug at t_end boundary!), expected {expected:.8f}")
            findings.append(("CRITICAL", "T7", "t_out=[t_end] left as zero", expected, got))
            total += 1
        else:
            check("T7", f"t_out=[t_end=2.0]: exp(-2)={expected:.8f}", expected, got)

    # ============================================================
    # SUMMARY
    # ============================================================
    print(f"\n{'='*60}")
    print(f"RESULTS: {passes}/{total} passed, {len(findings)} finding(s)")
    if findings:
        print("\nFINDINGS:")
        for sev, tid, desc, exp, got in findings:
            print(f"  [{sev}] {tid}: {desc} | expected~{exp:.6g}, got~{got:.6g}")
    else:
        print("No findings.")
    return 0 if not findings else 1


if __name__ == "__main__":
    sys.exit(main())
