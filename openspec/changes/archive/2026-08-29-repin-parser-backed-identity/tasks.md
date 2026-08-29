## 1. Pin and package

- [x] 1.1 Update `provenance/buoy-pin.toml`: revision `30b61f5e397bbf957b30ffd6eee47ee781d81bbe`, newly reviewed clean-tree source content hash, updated skew note naming the `chelis-surf-syntax/v2` reingestion, and `provenance_command_source` pointing at the upstream consumer package.
- [x] 1.2 Provide `chelis-provenance` from the upstream consumer package in `nix/buoy-consumer.nix`; delete `nix/chelis-provenance.nix`; update `devenv.nix` wiring and `scripts/check_buoy_pin.py` expectations.
- [x] 1.3 Verify `nautilus-buoy package-identity` reports the new revision and `chelis-provenance` answers with the usage exit class from the upstream package.

## 2. Reingestion

- [x] 2.1 Recompute every bound item digest from parsed declaration node bytes at the new pin; update the records in `src/`, `tests/`, and `tests_neg/` in place.
- [x] 2.2 Re-derive atom revisions from the revision-bearing v2 static report and rebind the surface rows, links, and carriers.
- [x] 2.3 Run `nautilus-provenance static` to verdict `accept` with 19 atoms, 1 surface, 1 oracle, 3 links, 3 carriers, and no diagnostics.

## 3. Fixtures, gate, and receipts

- [x] 3.1 Regenerate the fixture goldens under `chelis-static-report/v2`; adjust gate scripts that read report object rows to the `{id, digest, revision}` shape.
- [x] 3.2 Add a rejected-parse fixture asserting `CHELIS-PROV-PARSE-ERROR` on a non-canonical source.
- [x] 3.3 Re-execute the corpus and commit the regenerated receipts bound to the new static identity.

## 4. Documentation and final oracle

- [x] 4.1 Update `provenance/TRUST.md`: parser boundary, reingestion record, retired follow-ups, and the remaining open upstream note if any.
- [x] 4.2 Full `devenv test` exits 0 with the advisory provenance lane green; negative corpus stays green.
