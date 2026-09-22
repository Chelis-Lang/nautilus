module Nautilus.Tests.Signal
import Nautilus.Signal (fft_magnitude_stub, ifft_magnitude_stub, stft_magnitude_stub, lowpass_stub, highpass_stub, bandpass_stub, fftfreq)
import Nautilus.LinAlg (inner_product)
import Std.Test (assert_close, assert_true)
def basis4(k: i64) -> tensor[4, f32] = to_tensor(map(fn (i: i64) -> if eq(i, k) then cast(1.0, f32) else cast(0.0, f32), range(cast(0, i64), cast(4, i64))))
def is_nan(x: f32) -> bool = neq(x, x)
def sample4() -> tensor[4, f32] = to_tensor([cast(1.0, f32), cast(2.0, f32), cast(3.0, f32), cast(4.0, f32)])
def test_fft_magnitude_stub_preserves_length() -> unit ! { Test } = {
  y = fft_magnitude_stub(sample4())
  assert_true(eq(numel(y), cast(4, i64)), "fft_magnitude_stub: numel preserved")
}
def test_ifft_magnitude_stub_preserves_length() -> unit ! { Test } = {
  y = ifft_magnitude_stub(sample4())
  assert_true(eq(numel(y), cast(4, i64)), "ifft_magnitude_stub: numel preserved")
}
def test_stft_magnitude_stub_preserves_length() -> unit ! { Test } = {
  y = stft_magnitude_stub(sample4(), cast(2, i64), cast(1, i64))
  assert_true(eq(numel(y), cast(4, i64)), "stft_magnitude_stub: numel preserved")
}
def test_lowpass_stub_preserves_length() -> unit ! { Test } = {
  y = lowpass_stub(sample4(), cast(0.25, f32), cast(1.0, f32))
  assert_true(eq(numel(y), cast(4, i64)), "lowpass_stub: numel preserved")
}
def test_highpass_stub_preserves_length() -> unit ! { Test } = {
  y = highpass_stub(sample4(), cast(0.25, f32), cast(1.0, f32))
  assert_true(eq(numel(y), cast(4, i64)), "highpass_stub: numel preserved")
}
def test_bandpass_stub_preserves_length() -> unit ! { Test } = {
  y = bandpass_stub(sample4(), cast(0.1, f32), cast(0.4, f32), cast(1.0, f32))
  assert_true(eq(numel(y), cast(4, i64)), "bandpass_stub: numel preserved")
}
def test_fft_magnitude_stub_emits_nan() -> unit ! { Test } = {
  y = fft_magnitude_stub(sample4())
  v0 = inner_product(y, basis4(cast(0, i64)))
  assert_true(is_nan(v0), "fft_magnitude_stub element is NaN (placeholder)")
}
def test_lowpass_stub_emits_nan() -> unit ! { Test } = {
  y = lowpass_stub(sample4(), cast(0.25, f32), cast(1.0, f32))
  v0 = inner_product(y, basis4(cast(0, i64)))
  assert_true(is_nan(v0), "lowpass_stub element is NaN (placeholder)")
}
def test_fftfreq_preserves_length() -> unit ! { Test } = {
  freqs = fftfreq(sample4(), cast(1.0, f32))
  assert_true(eq(numel(freqs), cast(4, i64)), "fftfreq: length matches input")
}
def test_fftfreq_dc_bin_zero() -> unit ! { Test } = {
  freqs = fftfreq(sample4(), cast(8.0, f32))
  f0 = inner_product(freqs, basis4(cast(0, i64)))
  assert_close(f0, cast(0.0, f32), cast(1e-7, f32), "fftfreq[0] = 0 (DC bin)")
}
def test_fftfreq_first_positive_bin() -> unit ! { Test } = {
  freqs = fftfreq(sample4(), cast(8.0, f32))
  f1 = inner_product(freqs, basis4(cast(1, i64)))
  assert_close(f1, cast(2.0, f32), cast(1e-6, f32), "fftfreq[1] = fs/N = 2.0")
}
def test_fftfreq_last_bin_negative() -> unit ! { Test } = {
  freqs = fftfreq(sample4(), cast(8.0, f32))
  f3 = inner_product(freqs, basis4(cast(3, i64)))
  assert_close(f3, cast(-2.0, f32), cast(1e-6, f32), "fftfreq[N-1] = -fs/N = -2.0 (negative wrap)")
}
def test_fftfreq_scales_with_sample_rate() -> unit ! { Test } = {
  f_a = fftfreq(sample4(), cast(2.0, f32))
  f_b = fftfreq(sample4(), cast(4.0, f32))
  v_a = inner_product(f_a, basis4(cast(1, i64)))
  v_b = inner_product(f_b, basis4(cast(1, i64)))
  assert_close(mul(cast(2.0, f32), v_a), v_b, cast(1e-6, f32), "fftfreq scales linearly with sample_rate")
}
