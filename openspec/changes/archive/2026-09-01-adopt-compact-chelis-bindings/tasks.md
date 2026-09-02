## 1. Pin and digest migration

- [x] 1.1 Pin Buoy to `a88fd2efce0f2aef20538abdc7f265696600e408`, record the reviewed clean-tree hash, and select `blake3-256` in the pin and consumer package.
- [x] 1.2 Add the `provenance/bindings` artifact selector and configure that path as the binding store; verify the selector boundary.
- [x] 1.3 Review the BLAKE3 `rebind` dry-run plan, apply it with `--write`, and verify that all declarations stay byte-identical.

## 2. Compact relation conversion

- [x] 2.1 Review and apply `bind` for `NAUT-LINK-LINALG-MATMUL`; verify the source replacement and object write.
- [x] 2.2 Review and apply `bind` for `NAUT-LINK-SIGNAL-STUBS`; verify the source replacement and object write.
- [x] 2.3 Review and apply `bind` for `NAUT-LINK-STATS-HELPERS`; verify the source replacement and object write.
- [x] 2.4 Verify that no inline implementation link remains, all declaration bytes match the baseline, and a second `rebind` plan is empty.

## 3. Gate, fixtures, and receipts

- [x] 3.1 Extend the fixture pack with valid resolution, object tamper, stale subject, and digest-feature drift cases.
- [x] 3.2 Update gate checks for BLAKE3 identities, compact trace expansion, and the empty rebind plan.
- [x] 3.3 Re-execute the corpus and save receipts with the exact final compact static report.
- [x] 3.4 Update `provenance/TRUST.md` with the collision-resistant member, immutable object-store workflow, declaration preservation, and Git rollback.

## 4. Validation

- [x] 4.1 Run the pin, fixture, gate, and development-environment contract tests.
- [x] 4.2 Run static checks and traces for all three compact relations.
- [x] 4.3 Run `openspec validate --all --strict --no-interactive`.
- [x] 4.4 Run the full `devenv test` acceptance oracle.
