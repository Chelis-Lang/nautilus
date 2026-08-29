## Context

Nautilus is a pure-Chelis numerical library (release 0.7.38 on Chelis 0.18.1). Its support claims live in the `README.md` module table and in `spec/phase3j.md` phase deferrals, with no machine link to `src/*.ch` or to the test corpus. The Buoy repository at revision `f41fd501` ships the `chelis-provenance` crate: total Surf adapters for saved `.ch` bytes, a frozen `chelis:provenance/v1` comment-record grammar, deterministic static/change/execute commands with core exit classes, and an advisory report. No repository yet carries a live record; this change makes Nautilus the first.

## Goals / Non-Goals

**Goals:**

- Close the live chain: governed support claim → real Chelis declaration → executed test verdict, checked by one deterministic command.
- Keep every claim honest: complete surface dispositions, visible deferrals, real five-state verdicts, and an advisory-only lane.
- Pin all provenance tooling to one exact Buoy revision through the published consumer-package path.

**Non-Goals:**

- Blocking policy, Chelis compiler-repo changes, Deep (`.dp`) adapters, proof claims, or README-table generation.

## Decisions

### Consume Buoy through the pinned consumer package

`devenv.nix` gains one input for the Buoy consumer package pinned to revision `f41fd501`, following the `nix/consumer-package-v1` contract in the Buoy repository. One early task verifies that the package exposes the `chelis-provenance` command; if it does not, the fallback is a pinned source build of the `chelis-provenance` crate from the same revision, and a follow-up Buoy change adds the command to the package contract. Alternative: vendoring Buoy sources. Rejected because it forks the assurance boundary.

### Self-contained records in `.ch` sources

The pilot keeps authorities, the surface, links, carriers, and the oracle declaration as `chelis:provenance/v1` comment records attached to real declarations, checked by `chelis-provenance static` alone. Alternative: authorities as Markdown fences in `spec/*.md` through the `buoy` CLI. Deferred, not rejected: a two-command pipeline adds coordination cost the pilot does not need, and moving authorities into the spec documents remains a clean follow-up because atom identities are revision-bound either way.

### The module support matrix is the first surface

The surface dispositions every `Nautilus.*` module: `normative` for implemented modules under their authority atoms, `deferred` for `Nautilus.Signal`'s Phase 5f stubs, and `not-applicable` where a row names no shippable capability. The `README.md` table stays hand-maintained for now; the advisory report keeps it visible as a possible untracked copy until a later change derives or retires it.

### Carriers bind the real gate

Carrier records in `tests/*.ch` bind the exact test declaration, role `positive` (negative corpus rows bind `tests_neg/` with role `negative`), the atom revisions they exercise, and one oracle record for the real Nautilus gate command. Verdicts move only through `chelis-provenance execute` receipts, so registration is never execution evidence.

### Advisory lane in the gate

One devenv script runs `chelis-provenance static` plus the advisory report in the gate. Advisory findings (uncovered atoms, `not-run` carriers, untracked copies) print without blocking; malformed records, unsupported schema versions, and unattached metadata fail the lane through the static exit class.

### Version-skew boundary

The record grammar is comment-based (`--` lines) and attaches to top-level `def`/`type` declarations; both are stable from Chelis 0.16 through 0.18.1, so the frozen adapter parser identity from the Buoy pin applies unchanged. The pin record states this explicitly.

## Risks / Trade-offs

- **Consumer package may not expose the command** → verified in the first task; pinned source build is the recorded fallback.
- **Record noise in library sources** → records are comments only, attached to module-level declarations, and reviewed like documentation.
- **README table drifts from the surface** → the advisory report keeps the duplicate visible every run until it is derived or retired.
- **Advisory lane rot** → extraction failures block; only coverage gaps stay advisory, and each appears in every gate run.

## Migration Plan

1. Pin the Buoy revision and wire the consumer package into `devenv.nix`; verify the command.
2. Freeze the adapter configuration and selectors for `src/`, `tests/`, and `tests_neg/`.
3. Atomize the support surface: authority records, the surface record, and dispositions for every module.
4. Attach implementation links and carriers; declare the gate oracle.
5. Add the advisory gate lane and a cross-root determinism check.
6. Execute the corpus once so real verdicts replace `not-run`; document trust boundaries.

Rollback removes the records, the configuration, the devenv input, and the gate lane; no runtime code changes.

## Open Questions

- Which modules carry links and carriers in the first tranche: all 18, or `signal`, `linalg`, and `stats` first?
- Does the Buoy consumer package expose `chelis-provenance` today, or does the fallback source build carry the pilot?
- When does the README table become derived output instead of a visible duplicate?
