# Nautilus parity

This directory contains the SOLE Python script in post-cutover Nautilus.
`run_parity.py` invokes the Chelis runtime via `chelis eval --file` on
batched probe expressions and compares the output against
`scipy.special`, `scipy.stats`, etc. as the external oracle. Internal
mathematical correctness is asserted in `tests/*.ch` via `chelis test`;
this script exists *solely* to catch drift between Nautilus
implementations and scipy semantics. Run with
`python3 parity/run_parity.py --strict` for CI (non-zero exit on any
sample exceeding tol).

## Why batched probes

Each `chelis eval --file` invocation pays the full module-graph compile
cost — roughly 30–40 seconds with `Nautilus.Special` or
`Nautilus.Distributions` imported. Running one eval per sample would
take an hour for ~200 samples. Instead, all samples for a domain are
emitted into a single probe with `result_0 = ...`, `result_1 = ...`,
... bindings; one chelis eval per domain returns every result; the
script parses `result_N = value` lines from stdout. Total wall-clock
for the current ~80 special + ~125 distribution samples is ~70 s.

## Adding a new parity check

1. In the relevant `*_cases(scipy)` table in `run_parity.py`, append a
   `(label, snippet_builder, scipy_ref_callable, samples, tol)` tuple.
2. `snippet_builder(sample) -> str` must return a Chelis expression
   (the script wraps it with `result_N = ...`).
3. The `import` in the corresponding `*_IMPORTS` constant must already
   re-export the function being called; add the symbol if it's missing.
4. Run locally to confirm it passes: `python3 -u parity/run_parity.py`.
