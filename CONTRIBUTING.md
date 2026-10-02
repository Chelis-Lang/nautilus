# Contributing to Nautilus

## Setup

Nautilus builds with one exact Chelis compiler version, recorded as the
`compiler` pin in [`reef.toml`](reef.toml). Install `chelisup`, the Chelis
toolchain manager, and then from a fresh clone run:

```sh
chelis reef setup
```

This installs the pinned compiler if it is missing, installs the dependencies
recorded in `reef.lock`, and prints a health summary. `chelisup` resolves the
compiler per repository from `reef.toml`, so other Chelis projects on the same
machine are unaffected.

Python tooling is managed by [uv](https://docs.astral.sh/uv/). Scripts under
`scripts/` use only the standard library but need Python 3.11 or newer, so run
them through uv as shown below rather than with a system interpreter. The SciPy
parity harness is a separate uv project under `parity/`.

Install the commit-message hook once per clone:

```sh
cp hooks/commit-msg .git/hooks/commit-msg && chmod +x .git/hooks/commit-msg
```

## Tests

| Suite | Command | What it checks |
|---|---|---|
| Native tests | `chelis test tests/ --timeout 600 --suite-timeout 2400 --jobs auto` | Identities, invariants, solver recovery, tensor paths, edge cases, and callability, written in Chelis |
| Negative tests | `chelis test tests_neg/ --expect neg` | Each `tests_neg/<area>/<name>.ch` must fail to compile with the diagnostic on line 1 of its `.expect` file |
| Blocked probes | `chelis test tests_blocked/ --expect blocked` | Reproducers of open upstream compiler issues. Each must keep failing the way its `.expect` file says. See [`tests_blocked/README.md`](tests_blocked/README.md) |
| SciPy parity | `uv run --project parity --frozen python parity/run_parity.py --strict` | Selected Special and Distributions functions against reviewed SciPy/NumPy goldens. See [`parity/README.md`](parity/README.md) |
| Rolling pandas parity | `uv run --no-project --python 3.12 python scripts/check_rolling_parity.py` | `Nautilus.Rolling`'s warm-up and `min_periods` against reviewed pandas goldens. Needs the pinned compiler but not pandas; success is `ROLLING PARITY: PASS` |

`tests/` must never contain Python, and SciPy, NumPy, or other oracle libraries
may be imported only under `parity/`. CI enforces both rules.

## Local gate

Run the whole gate before opening a pull request that changes library code:

```sh
for f in $(git ls-files 'src/*.ch' 'tests/*.ch' 'tests_neg/*.ch' 'tests_blocked/*.ch'); do
  chelis fmt --check "$f" || echo "unformatted: $f"
done
chelis lint --check .
chelis reef build
chelis test tests/ --timeout 600 --suite-timeout 2400 --jobs auto
chelis test tests_neg/ --expect neg
chelis test tests_blocked/ --expect blocked      # when probes exist
uv sync --project parity --frozen
uv run --project parity --frozen python parity/run_parity.py --strict
uv run --no-project --python 3.12 python scripts/check_oracle_isolation.py
uv run --no-project --python 3.12 python scripts/validate_surface.py
uv run --no-project --python 3.12 python scripts/extract_stability.py --check
uv run --no-project --python 3.12 python -m unittest discover -s scripts -p 'test_*.py'
uv run --no-project --python 3.12 python scripts/check_rolling_tensor_parity.py
uv run --no-project --python 3.12 python scripts/check_rolling_parity.py
chelis reef conform audit
```

`scripts/check_rolling_parity.py` and `scripts/check_rolling_tensor_parity.py`
also run in CI, in the native-test and hard-rule jobs respectively.
Regenerating the pandas goldens is a separate, reviewed manual gate that does
need pandas, and CI never runs it:

```sh
uv run --with 'pandas==2.3.3' --no-project python parity/rolling_goldens.py --write
git diff -- parity/goldens/rolling.json
```

When you change documentation, also run the example validators, which compile
every complete ```` ```chelis ```` block against the pinned compiler:

```sh
uv run --no-project --python 3.12 python scripts/validate_skill_examples.py
uv run --no-project --python 3.12 python scripts/validate_book_examples.py
mdbook build docs/book
```

## Continuous integration

`ci.yml` runs on every pull request and every push to `main`:

1. **Pin and conformance guard.** Unit tests for the Python tooling, the check
   that every workflow's compiler version matches `reef.toml`,
   `chelis reef conform audit` (the Chelis shell-repository conformance
   check), and `chelis reef conform bump-check`, which rejects a compiler pin
   change that skipped the upgrade checklist.
2. **Hard rules.** No AI-authorship commit trailers, no Python under `tests/`,
   oracle imports confined to `parity/`, and a non-empty native suite.
3. **Build, tests, and parity**, run in parallel: the package build with a
   reproducibility check on the release artifacts, the native, negative, and
   blocked suites, and the strict SciPy parity check. On pushes to `main`, a
   macOS job also builds and validates the package.

`nightly.yml` runs the slower checks: a per-file `chelis check` over every
module and the `SKILL.md` and book example validators. A failed nightly opens a
tracking issue, which closes itself on the next green run. `release.yml` builds
and publishes the release artifacts when a `v*` tag is pushed; see
[`docs/releases.md`](docs/releases.md).

## Adding or changing public functions

- Export the function from its module and add a row to the matching table in
  [`SKILL.md`](SKILL.md) §6 with its signature and a `stable` or `alpha` label.
  `scripts/validate_surface.py` and `scripts/extract_stability.py --check` keep
  the table, the exports, and `dist/stability.json` in agreement.
- Test every new public function on at least two distinct shapes or
  configurations. If you add a parity case, give it at least two
  configurations and review the regenerated goldens.
- Claim differentiability only with a `grad` test against an exact or
  finite-difference reference.
- [`spec/scope.md`](spec/scope.md) has the full acceptance rules and the list of
  deliberate deferrals.

## Upstream compiler issues

When a Chelis limitation forces a workaround, file it in
[`Chelis-Lang/chelis`](https://github.com/Chelis-Lang/chelis/issues) and cite it
as `chelis#NNN` at the workaround site. Record it in
[`docs/UPSTREAM_BUGS.md`](docs/UPSTREAM_BUGS.md), and add an executable
reproducer under `tests_blocked/` when the test harness can express one.
`chelis reef conform audit` checks that every cited issue is covered.
[`docs/CHELIS_SURFACE.md`](docs/CHELIS_SURFACE.md) lists what the pinned
compiler and standard library provide. Read it before designing around a
suspected language gap.

## Upgrading the Chelis compiler

A compiler upgrade is a pull request that runs the checklist in
[`AGENTS.md`](AGENTS.md#pin-bump-checklist). It starts with
`chelis reef conform bump <version>`, which updates every pin in lockstep. It
then re-probes every open upstream issue, promotes any fixed reproducer from
`tests_blocked/` into `tests/`, removes the corresponding workaround, and runs
the full local gate.
