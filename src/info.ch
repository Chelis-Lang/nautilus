module Nautilus.Info
export (entropy, distribution_cross_entropy, kl_divergence)
def info_zero() -> f32 = cast(0.0, f32)
def entropy[n](p: &tensor[n, f32]) -> f32 = {
  total = fold(fn (acc: f32, x: f32) -> {
    term = if lte(x, info_zero()) then info_zero() else (x |> mul(log(x)) |> neg)
    add(acc, term)
  }, info_zero(), to_list(p))
  total
}
def distribution_cross_entropy[n](p: &tensor[n, f32], q: &tensor[n, f32]) -> f32 = {
  pairs = p |> to_list |> zip(to_list(q))
  fold(fn (acc: f32, pair: (f32, f32)) -> {
    px = pair.0
    qx = pair.1
    term = if lte(px, info_zero()) then info_zero() else (px |> mul(log(qx)) |> neg)
    add(acc, term)
  }, info_zero(), pairs)
}
def kl_divergence[n](p: &tensor[n, f32], q: &tensor[n, f32]) -> f32 = {
  pairs = p |> to_list |> zip(to_list(q))
  fold(fn (acc: f32, pair: (f32, f32)) -> {
    px = pair.0
    qx = pair.1
    term = if lte(px, info_zero()) then info_zero() else mul(px, px |> div(qx) |> log)
    add(acc, term)
  }, info_zero(), pairs)
}
