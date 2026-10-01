---
name: redteam-exec
description: Run a compliant Chelis red-team round, or send a local repair back to the standing reviewer for verification before push. A round starts with a fresh local subagent working an inline brief against the pushed head, then keeps that reviewer alive through the local repair loop. Anything else is not a red team.
---

# Red Team Exec

Use this skill when the user asks for a red team, an adversarial review, a fresh-context
validation pass, or verification of a fix that a red team reported.

## Repository Contract

1. A **round** starts with a fresh local subagent reviewing from the inline brief below
   and continues through the repair loop. **Verification** is the reviewer that reported
   a finding checking the exact local repair commit before it is pushed. Neither is a
   main-thread pass, and a phase or pull request is red-teamed only when the subagent
   actually ran the validation work.
2. Keep the reviewer alive while the author and reviewer serially hand off the supplied
   worktree. A confirmed in-scope P0 or P1 earns a fresh round after the current round
   closes and its exact verified repair head is pushed, subject to the cap below.
   Unmigrated assertions, old comments, minor documentation drift, and P2-or-lower
   findings do not alone earn another round. A rebase with substantial conflicts or
   semantic overlap gets a targeted red team focused on the overlap; it needs no
   separate permission and does not count toward the fresh-round cap.
3. A pull request gets at most three fresh rounds by default; a fourth needs the user's
   explicit approval. A prose-only pull request, design documents included, gets one,
   and a second needs the same approval. Rounds run from any platform count, and the
   pull request's round record is the counter. Verification does not count against the
   cap; the end-of-pull-request round does.
4. Context budgets and time limits are optional, with no default. When set, include
   them in the brief. The reviewer reports what it has when an explicit limit is
   reached; an unfinished check is "unvalidated", not a finding.
5. The initial head is pushed before the round starts, so CI runs while the first review
   runs. Repair commits remain local until the standing reviewer is satisfied. Push the
   exact verified repair head once after the round closes; CI then validates that head.
   CI is watched by at most one background waiter, never a foreground sleep or poll loop.
6. If every local subagent path is unavailable, state that red-team validation is
   blocked. Do not substitute an external agent CLI or main-thread validation.

## Finding Discipline

- Every pull request, documentation-only work included, needs at least one compliant
  round before it merges. Only a confirmed in-scope P0/P1 blocks, and the standing
  reviewer's local verification closes the finding inside the current round. A
  confirmed in-scope P0/P1 then earns a fresh round on the pushed repair head, subject
  to the cap.
- Absent an in-scope P0 or P1 finding, scale rounds to the change. Minor updates, bug
  fixes, and textual changes do not inherently merit another round. If another change
  already requires a push or CI rerun, include every known P2-or-lower repair in that
  local candidate before the standing reviewer closes the round.
- A rebase with substantial conflicts or semantic overlap gets a targeted red team
  focused on that overlap and does not count toward the cap. A rebase with no such
  overlap does not automatically require review.
- Classify every finding against the pull request's stated scope. Mere discovery,
  including an unrelated pre-existing spec/implementation mismatch, does not bring it
  into scope. Do not repair an out-of-scope finding in the pull request; link its
  existing issue or file one when it is not already tracked.
- A gate repair may correct, remove, or narrow existing pull-request content. It must
  not add design scope, implementation responsibilities, inventories, mechanisms, or
  promises merely to absorb a finding. State every claim at the granularity its oracle
  proves; an unbounded universal claim invites sampling in every round.
- Record the class of every finding in the round record. When two consecutive rounds
  report the same class, or replace a repaired finding with a different class, stop
  patching witnesses: change the representation, the oracle, the claim, or the brief
  before another round. Do not keep expanding the pull request to satisfy a moving
  brief.
- Separability sizes a pull request. Slices that must ship together are commits
  inside one pull request, and slices that can ship apart are separate pull requests.
  About 1,000 hand-written changed lines, regenerated artifacts excluded, is the point
  at which the author owes a sentence justifying one shippable slice, not a threshold.
  Size is in scope for the round: the ratio of cases a claim covers to cases its tests
  prove is the reportable signal, and a low one is a finding whatever the line count.

## Minimum Deliverable

- findings ordered by severity, each with its class and its in-scope or out-of-scope
  classification, with linked issue status for every out-of-scope defect
- exact commands run for every P0, P1, and P2; a P3 is one line with no reproduction
- coverage against the in-scope claims and the active acceptance oracle
- exact reviewed commit and final worktree status; deadline met or missed when one was set
- explicit note of anything unvalidated

## Validation Discipline

- run code and commands, not just source inspection
- add adversarial probes where coverage is thin
- verify positive and negative cases
- check examples, docs, and CLI behavior against shipped behavior
<!-- shell-local:begin -->
<!-- shell-local:exclude:begin -->
<!-- ## Execution Order: New Round -->
<!-- ## Execution Order: Verify My Fix -->
<!-- ## Worktree And Build Reuse -->
<!-- ## Round Brief Template -->
<!-- ## Verification Brief Template -->
<!-- shell-local:exclude:end -->

## Nautilus New Round

1. Confirm the candidate is committed and pushed; count this PR's rounds
   against the cap. Retire only your own stale or failed handles.
2. Choose a clean worktree at the exact review head with no active owner.
   Use an isolated worktree if the handoff evidence is uncertain.
3. Give a fresh local reviewer a self-contained brief naming the pushed
   head, changed paths, bounded claims, worktree, validation probes, report
   budget, and delivery channel. Keep that reviewer through repairs.

## Nautilus Worktree Handoff And Verification

- Capture `git rev-parse HEAD`, `git status --porcelain --untracked-files=all`,
  and `git worktree list --porcelain`. Inventory all processes whose cwd is
  under the worktree with `lsof -nP -a -d cwd +D "$PWD"`; check a shared
  target separately with `lsof -nP +D "$target"`. Do not filter by process
  name before the ownership scan. Use `ps -p PID -o pid,ppid,command` to
  identify each returned PID, disregarding only scan processes after they
  exit. Inspect `lsof` output even when it exits nonzero. Paste the output
  with a timestamp into each round or verification brief. A dirty tree,
  active owner, unavailable scan, or uncertain scope forbids reuse. Never
  write or build concurrently with a reviewer.
- Consolidate repairs into an unpushed local commit. Send its exact head,
  changed paths, handoff evidence, and the original reproduction to the
  same reporting reviewer. Repeat until that reviewer confirms the repair;
  then push. Restore temporary probes before each handoff.
- For a new round, the brief states the PR and round, exact pushed head,
  changed paths, in-scope claims, clean worktree and process evidence,
  report budget, delivery channel, required executed probes, and final
  restoration check. For verification, state the standing reviewer,
  unpushed head, repairs, original reproduction, and closed/not-closed
  response expected.
<!-- shell-local:end -->
