# `chelis eval --file` aborts the process after ~135 frames of a let-heavy recursion

`chelis eval --file` evaluates on the `main` thread and overflows its stack at a
recursion depth that depends on how many bindings the recursive body holds. A
body with sixteen `let` bindings aborts the process at depth 136; a body with
one survives past 1000. The abort is a `SIGABRT` with no Chelis diagnostic, so
neither the evaluated program nor a script wrapping the CLI can distinguish it
from a crash in the compiler.

`chelis test` does not have the problem at the same depths: it runs each file on
a `chelis-test-worker` thread with a much larger stack, and it reports an
overflow there as a test failure rather than killing the harness. The two lanes
therefore disagree about whether the same program runs at all.

## Measured on Chelis 0.19.0 and 0.19.1, macOS 25.5.0 (arm64)

Both versions behave identically. Every boundary below is deterministic over
three repeats.

| Lane | Recursive body | Last depth that returns | First depth that aborts |
|---|---|---|---|
| `chelis eval --file` | 1 binding | 1020 | 1040 |
| `chelis eval --file` | 12 bindings | 150 | 160 |
| `chelis eval --file` | 16 bindings (the real case below) | 135 | 136 |
| `chelis test` | 16 bindings | 500 | between 500 and 1000 |

Values are irrelevant to the boundary. Driving the 16-binding body to depth 135
with finite, well-conditioned arguments returns `-0.016961427`; the same
arguments at depth 136 abort. Non-finite arguments abort at exactly the same
depth, not sooner.

## Reproducer

`fat` has twelve bindings in its recursive body, `slim` has one. Neither
allocates, and both are in tail position.

```text
module MinRepro
def fat(acc: f32, i: i64) -> f32 = {
  zero_i = cast(0, i64)
  one_i = cast(1, i64)
  if lte(i, zero_i) then acc else {
    a1 = add(acc, cast(1.0, f32))
    a2 = mul(a1, cast(1.000001, f32))
    a3 = sub(a2, cast(0.5, f32))
    a4 = div(a3, cast(1.000002, f32))
    a5 = add(a4, cast(0.25, f32))
    a6 = mul(a5, cast(0.999999, f32))
    a7 = sub(a6, cast(0.125, f32))
    a8 = if lt(a7, cast(0.0, f32)) then neg(a7) else a7
    a9 = add(a8, cast(0.0625, f32))
    a10 = mul(a9, cast(1.0000005, f32))
    a11 = sub(a10, cast(0.03125, f32))
    a12 = div(a11, cast(1.0000001, f32))
    fat(a12, sub(i, one_i))
  }
}
def slim(acc: f32, i: i64) -> f32 = if lte(i, 0i64) then acc else slim(add(acc, 1.0f32), sub(i, 1i64))
r = fat(0.0f32, 160i64)
```

```text
$ chelis eval --file minrepro.ch
thread 'main' (48586199) has overflowed its stack
fatal runtime error: stack overflow, aborting
$ echo $?
134
```

Replacing `160i64` with `150i64` prints `r = 98.42479`. Replacing the call with
`slim(0.0f32, 1020i64)` prints `r = 1020.0`, and `1040i64` aborts.

## Why this matters to a library

A numerical library sizes an iteration budget by the mathematics, not by the
host's stack. `Nautilus.Distributions` implements the regularised incomplete
gamma function with the standard Numerical-Recipes pair: a power series for
`x < a + 1` and a Lentz continued fraction above it, each given 200 iterations.
Written as the obvious recursion, each body holds about sixteen bindings, so the
budget could not be spent: 200 iterations needed 200 frames and the lane holds
135.

That turned every input needing more than ~135 iterations into a process abort,
including `gamma_cdf(2000.0, 2000.0, 1.0)` (187 series terms) and
`chi_squared_cdf(4000.0, 4000.0)`. Neither is degenerate; a chi-squared test on
4000 degrees of freedom is ordinary. Nautilus now runs both recursions in chunks
of sixteen through an outer driver, so a 200-iteration budget costs about 30
frames instead of 200. That is a workaround for the frame cost, not for the
mathematics, and it is what this draft is cited by (nautilus#140).

Two properties would each remove the need for it:

- tail calls in the eval lane that do not consume a native frame, or
- the eval lane running on a stack sized like the test worker's, with an
  overflow surfaced as a Chelis diagnostic rather than a `SIGABRT`.

The second alone would be enough to make the failure diagnosable, which is the
part a library cannot work around: a caller can guard a `NaN`, and can act on a
diagnostic, but cannot catch a dead process.

## Filing condition

File once a maintainer confirms the eval lane's stack sizing is intended to be
smaller than the test worker's, and that no existing issue already covers the
lane asymmetry. Search the upstream tracker for the eval-lane stack depth and
for `chelis-types` recursion depth guards before filing: a related finding
exists that the `infer_recursion_depth_guard` and
`infer_library_context_depth_guard` tests size a worker thread so a
`stacker::remaining_stack` budget fires deterministically, and that sizing does
not hold on every machine. That is the same class of problem one level up, and
the issues may belong together.
