---
name: phase-gate
description: Use when deciding whether a Chelis phase is actually complete. Applies the repo’s completion standard, checks manual gates, examples, docs, and phase-specific acceptance criteria before any completion claim.
---

# Phase Gate

Use this skill when a phase is claimed complete or nearly complete.

## Acceptance Oracle

Before judging a phase, identify its single authoritative oracle:

- one command
- one named suite
- or one documented manual validation runner

Treat all other evidence as supporting material, not the completion decision itself.

## Completion Rule

Do not call the phase complete if any of these remain:

- broken default gate
- missing or ambiguous phase oracle
- hidden manual-only acceptance criteria not documented as such
- false-perfect machine-facing reports
- examples/docs whose meaning contradicts the actual implementation
<!-- shell-local:begin -->
<!-- shell-local:exclude:begin -->
<!-- ## Default Gate -->
<!-- ## Additional Required Checks -->
<!-- shell-local:exclude:end -->

## Nautilus Default Gate

Run the Nautilus gate in `docs/maintainer_guide.md` §Local gate at the exact candidate
head. It includes the pinned compiler's build and native tests:

```sh
chelis reef build
chelis test tests/ --timeout 600 --jobs auto
chelis test tests_neg/ --expect neg
chelis reef conform audit
```

The same documented gate also runs blocked probes when present, strict
SciPy parity, and the Python tooling checks. For documentation claims,
run the `SKILL.md` and book example validators and `mdbook build docs/book`
as listed there. Check applicable CI and the acceptance oracle in
`spec/scope.md` before declaring a phase complete.
<!-- shell-local:end -->
