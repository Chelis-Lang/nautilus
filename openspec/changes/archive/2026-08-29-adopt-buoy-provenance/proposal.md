## Why

Nautilus governs itself with a hand-maintained module table in `README.md` and explicit phase deferrals in `spec/phase3j.md`, but no machine check links those claims to the Chelis sources in `src/` or to the test corpus. The Buoy Chelis integration shipped at `Chelis-Lang/buoy` revision `f41fd501` with total adapters for saved `.ch` sources, yet no repository carries a live `chelis:provenance/v1` record. Nautilus is pure Chelis, so it is the first host that can close the chain from a governed support claim to a real Chelis declaration to an executed test verdict.

## What Changes

- Pin Buoy consumption to one exact revision through the published consumer-package path; no vendored or floating copy.
- Declare the Nautilus module support matrix as one governed finite surface with an explicit disposition for every module, including the `Nautilus.Signal` Phase 5f deferral.
- Attach `chelis:provenance/v1` authority, surface, implementation-link, carrier, and oracle records to real declarations in saved `src/*.ch` and `tests/*.ch` sources.
- Register the Chelis-native test corpus as carriers bound to the real Nautilus gate command; retain honest `not-run`, `fail`, `error`, and `timeout` verdicts.
- Run the deterministic static check and the advisory report inside the Nautilus gate as an advisory lane; extraction failures stay loud.
- Keep the `README.md` module table visible as a possible untracked copy in the advisory report until a later change derives or retires it.
- **Non-goals:** blocking policy, changes to the Chelis compiler repository, Deep (`.dp`) sources, formal proof claims, and generation of the README table.

## Capabilities

### New Capabilities
- `nautilus-provenance`: repository-owned provenance governance for the Nautilus support surface over the pinned Buoy interfaces.

### Modified Capabilities

None.

## Impact

- Adds a pinned Buoy consumer-package input to `devenv.nix` and one gate script.
- Adds provenance comment records to governed `src/*.ch` modules and to `tests/*.ch` carriers; no runtime code changes.
- Adds one explicit adapter configuration and registration records under a repository-owned directory.
- Adds one advisory lane to the Nautilus gate; the existing blocking gate stays unchanged.
