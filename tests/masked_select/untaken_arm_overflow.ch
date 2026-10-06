module Nautilus.Tests_Blocked.Masked_Select.Untaken_Arm_Overflow
import Std.Test (assert_true)
-- The untaken overflowing arm must not poison the selected value under vmap.
-- The probe keeps this masked-select behavior independent of a library helper.
def uao_abs(x: f32) -> f32 = if lt(x, cast(0.0, f32)) then neg(x) else x
def uao_series(x: f32) -> f32 = {
  x2 = mul(x, x)
  poly = sub(cast(1.0, f32), mul(x2, sub(cast(0.3333333333333333, f32), mul(x2, sub(cast(0.1, f32), mul(x2, cast(0.023809523809523808, f32)))))))
  mul(mul(x, poly), cast(1.1283791670955126, f32))
}
def uao_erf(x: f32) -> f32 = if lt(uao_abs(x), cast(0.25, f32)) then uao_series(x) else cast(1.0, f32)
def uao_row(t: tensor[3, f32]) -> tensor[3, f32] = {
  s = tensor_to_scalar(sum(t, cast(0, i32)))
  ev = insert(scalar_to_tensor(uao_erf(s)), cast(0, i32), cast(3, i64))
  mul(t, ev)
}
def uao_batched(b: tensor[2, 3, f32]) -> tensor[2, 3, f32] = vmap(uao_row)(b)
def test_blocked_untaken_arm_does_not_poison_a_vmapped_select() -> unit ! { Test } = {
  batch = to_tensor([[cast(1000000.0, f32), cast(0.0, f32), cast(0.0, f32)], [cast(0.1, f32), cast(0.0, f32), cast(0.0, f32)]])
  rows = to_list(sum(uao_batched(batch), cast(1, i32)))
  big = index(rows, cast(0, i64))
  assert_true(eq(big, big), "the untaken overflowing arm does not poison the selected value")
}
