# eval of an unused Reef import demands an unrelated symbolic input

**Target:** `Chelis-Lang/chelis`

**Status:** ready to file

**Filing condition:** File before treating
`scripts/bench_eval_startup.py` as current import-startup evidence, unless an
upstream tracker search finds an issue for the exact unused-import/symbolic-
input residue. Replace draft citations with the issue number after filing or
deduplication.

## Summary

Chelis 0.16.1 no longer hangs on package-aware `eval --file`, and real imported
calls used by Nautilus parity succeed. However, the import-only shape used to
measure module startup fails after about 23 seconds with a symbolic input from
an unrelated generic definition:

```text
error: missing required input `a` for symbolic dimension `k`
```

The baseline file without an import succeeds. Calling the imported symbol also
succeeds. Merely importing it while evaluating an independent scalar binding
triggers the failure.

## Minimal reproducer

Run from the Nautilus Reef package root:

```chelis
import Nautilus.Special (erf)
bench = cast(0.0, f32)
```

```text
$ chelis eval --file /tmp/import_case bench
error: missing required input `a` for symbolic dimension `k`
```

Controls on the same pin:

```text
bench = add(cast(1, f32), cast(2, f32))
# chelis eval --file ... bench => 3

import Nautilus.Special (erf)
bench = erf(cast(1.0, f32))
# => 0.842700719833374
```

The same import-only diagnostic reproduces for every module in
`scripts/bench_eval_startup.py`, including the aggregate case. The real parity
surfaces `Nautilus.Special.erf` and `Nautilus.Distributions.normal_cdf` both
succeed through `src/probe.ch`.

## Downstream impact

- Strict numerical parity is unblocked.
- The import-startup benchmark cannot measure its intended import-only surface.
- The historical 5-second hang timeout became misleading because successful
  file evaluation itself takes about 23 seconds; Nautilus raises that timeout
  while retaining the failed scenario as visible tracking evidence.

This command surface cannot be represented by `chelis test
 tests_blocked/ --expect blocked`; it remains a documented manual re-probe.

## Expected behavior

Unused imports do not introduce runtime roots or symbolic-input requirements.
The command prints `0` and exits successfully, while still paying the package
import/compile startup cost the benchmark is designed to measure.
