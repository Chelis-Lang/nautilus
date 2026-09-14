module Nautilus.Tests_Blocked.Masked_Select.Untaken_Arm_Overflow
import Std.Test (assert_true)
-- BLOCKED on chelis#1464. `spec/06` §2.10.1 says an untaken branch is not
-- evaluated; under `vmap` a scalar `if` is lowered to a masked select that
-- evaluates BOTH arms, so an untaken arm that overflows poisons the result.
--
-- Deliberately self-contained: it reproduces the UNCLAMPED shape that
-- `Nautilus.Special.erf` had to work around, without depending on `erf`, so
-- the probe keeps reporting on the compiler rather than on our workaround.
-- While this fails, `erf`'s series-input clamp must stay. When it passes,
-- that clamp is removable -- that is the signal this probe exists to give.
def uao_abs(x: f32) -> f32 = if lt(x, cast(0.0, f32)) then neg(x) else x
def uao_series(x: f32) -> f32 = {
  x2 = mul(x, x)
  poly = sub(cast(1.0, f32), mul(x2, sub(cast(0.3333333333333333, f32), mul(x2, sub(cast(0.1, f32), mul(x2, cast(0.023809523809523808, f32)))))))
  mul(mul(x, poly), cast(1.1283791670955126, f32))
}
def uao_erf(x: f32) -> f32 = if lt(uao_abs(x), cast(0.25, f32)) then uao_series(x) else cast(1.0, f32)
def uao_row(t: tensor[3, f32]) -> tensor[3, f32] = {
  s = tensor_to_scalar(sum(t, cast(0, int32)))
  ev = insert(scalar_to_tensor(uao_erf(s)), cast(0, int32), cast(3, int64))
  mul(t, ev)
}
def uao_batched(b: tensor[2, 3, f32]) -> tensor[2, 3, f32] = vmap(uao_row)(b)
def test_blocked_untaken_arm_does_not_poison_a_vmapped_select() -> unit ! { Test } = {
  batch = to_tensor([[cast(1000000.0, f32), cast(0.0, f32), cast(0.0, f32)], [cast(0.1, f32), cast(0.0, f32), cast(0.0, f32)]])
  rows = to_list(sum(uao_batched(batch), cast(1, int32)))
  big = index(rows, cast(0, int64))
  assert_true(eq(big, big), "the untaken overflowing arm does not poison the selected value")
}
