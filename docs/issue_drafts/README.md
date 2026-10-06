# Parked upstream issue drafts

This directory holds ready-to-file bodies for upstream Chelis issues that are
waiting on a stated filing condition. While a draft is parked, Nautilus cites
it by path (`docs/issue_drafts/<file>.md`) at the narrowing site and in the
Parked section of [`docs/UPSTREAM_BUGS.md`](../UPSTREAM_BUGS.md).

Parked drafts:

- [`chelis_eval_fat_frame_stack_abort.md`](chelis_eval_fat_frame_stack_abort.md)
  — `chelis eval --file` aborts the process after about 135 frames of a
  let-heavy recursion, while `chelis test` runs the same depth. Cited by the
  chunked incomplete-gamma recursions in `src/distributions.ch`.

Before filing a draft, search the upstream tracker for duplicates. After
filing, delete the draft and replace every citation of its path with the new
`chelis#NNN` in the same change.
