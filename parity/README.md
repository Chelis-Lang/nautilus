# Nautilus parity

This directory owns every external Python oracle used by Nautilus. Production
Chelis code and non-parity tooling must not import or call NumPy, SciPy, or any
other oracle library; CI enforces that boundary with
`scripts/check_oracle_isolation.py`.

`run_parity.py` invokes `chelis eval --file` on batched probe expressions and
compares the results with the reviewed files under `goldens/`. Normal validation
never imports SciPy and never rewrites expected values.

## Validate

The parity environment is an isolated uv project with a checked-in lockfile:

```sh
uv sync --project parity --frozen
uv run --project parity --frozen python parity/run_parity.py --strict
```

Set `CHELIS_BIN=/path/to/chelis` to validate an explicit candidate binary;
otherwise the runner resolves `chelis` from `PATH`.

Inside the Devenv shell, the equivalent convenience command is:

```sh
nautilus-parity --strict
```

Strict mode fails on tolerance misses, missing or malformed goldens, recipe /
golden metadata drift, and any case lacking at least two distinct configurations.

## Regenerate goldens

Regeneration is explicit and must be reviewed; CI never runs it:

```sh
uv run --project parity --frozen python parity/run_parity.py --regen-goldens
git diff -- parity/goldens/
uv run --project parity --frozen python parity/run_parity.py --strict
```

The golden files record the locked NumPy and SciPy versions used to produce
them. Regenerate only for an intentional oracle, case, or dependency change.

## Why batched probes

Each `chelis eval --file` invocation pays the full module-graph compile cost —
roughly 30–40 seconds with `Nautilus.Special` or `Nautilus.Distributions`
imported. All samples for a domain are therefore emitted in one probe with
`result_0 = ...`, `result_1 = ...`, and so on. One evaluation per domain keeps
the full 216-sample run near 70 seconds.

## Adding a parity case

1. Add the case to the relevant `*_cases(scipy)` table in `run_parity.py`.
2. Provide at least two distinct sample configurations.
3. Ensure the corresponding import constant exports the called Nautilus verb.
4. Regenerate the goldens explicitly and review the JSON diff.
5. Run strict validation.
