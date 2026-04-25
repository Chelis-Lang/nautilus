module Nautilus.Tests.Signal

-- Smoke / structural tests for Nautilus.Signal.
--
-- Most of this module is intentionally a placeholder: the FFT/filter
-- entry points are stubs that emit NaN-filled tensors of the input
-- shape so that downstream callers can still wire pipelines while the
-- real numerical kernels are deferred. The only substantive function
-- is `fftfreq`, which we exercise with a closed-form check.

import Nautilus.Signal (fft_magnitude_stub, ifft_magnitude_stub,
                        stft_magnitude_stub, lowpass_stub,
                        highpass_stub, bandpass_stub, fftfreq)
import Nautilus.LinAlg (inner_product)
import Std.Test (assert_close, assert_true)

-- ===== Helpers =====

-- Standard basis vector e_k in R^4 (used to project tensor[4, f32] outputs).
def basis4(k: int64) -> tensor[4, f32] =
  to_tensor(map(fn (i: int64) -> if eq(i, k) then cast(1.0, f32) else cast(0.0, f32),
                  range(cast(0, int64), cast(4, int64))))

-- A NaN value detector: NaN != NaN.
def is_nan(x: f32) -> bool = neq(x, x)

-- A length-4 input signal.
def sample4() -> tensor[4, f32] =
  to_tensor([cast(1.0, f32), cast(2.0, f32), cast(3.0, f32), cast(4.0, f32)])

-- ===== Module load smoke =====

def test_signal_module_loads() -> unit ! { Test } =
  assert_true(true, "Nautilus.Signal module loads under chelis test")

-- ===== Stub shape preservation =====

def test_fft_magnitude_stub_preserves_length() -> unit ! { Test } = {
  y = fft_magnitude_stub(sample4())
  assert_true(eq(numel(y), cast(4, int64)),
              "fft_magnitude_stub: numel preserved")
}

def test_ifft_magnitude_stub_preserves_length() -> unit ! { Test } = {
  y = ifft_magnitude_stub(sample4())
  assert_true(eq(numel(y), cast(4, int64)),
              "ifft_magnitude_stub: numel preserved")
}

def test_stft_magnitude_stub_preserves_length() -> unit ! { Test } = {
  y = stft_magnitude_stub(sample4(), cast(2, int64), cast(1, int64))
  assert_true(eq(numel(y), cast(4, int64)),
              "stft_magnitude_stub: numel preserved")
}

def test_lowpass_stub_preserves_length() -> unit ! { Test } = {
  y = lowpass_stub(sample4(), cast(0.25, f32), cast(1.0, f32))
  assert_true(eq(numel(y), cast(4, int64)),
              "lowpass_stub: numel preserved")
}

def test_highpass_stub_preserves_length() -> unit ! { Test } = {
  y = highpass_stub(sample4(), cast(0.25, f32), cast(1.0, f32))
  assert_true(eq(numel(y), cast(4, int64)),
              "highpass_stub: numel preserved")
}

def test_bandpass_stub_preserves_length() -> unit ! { Test } = {
  y = bandpass_stub(sample4(), cast(0.1, f32), cast(0.4, f32), cast(1.0, f32))
  assert_true(eq(numel(y), cast(4, int64)),
              "bandpass_stub: numel preserved")
}

-- ===== Stubs emit NaN (documented placeholder behavior) =====

def test_fft_magnitude_stub_emits_nan() -> unit ! { Test } = {
  y = fft_magnitude_stub(sample4())
  v0 = inner_product(y, basis4(cast(0, int64)))
  assert_true(is_nan(v0), "fft_magnitude_stub element is NaN (placeholder)")
}

def test_lowpass_stub_emits_nan() -> unit ! { Test } = {
  y = lowpass_stub(sample4(), cast(0.25, f32), cast(1.0, f32))
  v0 = inner_product(y, basis4(cast(0, int64)))
  assert_true(is_nan(v0), "lowpass_stub element is NaN (placeholder)")
}

-- ===== fftfreq: real (non-stub) logic =====
--
-- Convention (NumPy-style, two-sided): for a length-N input and
-- sample rate fs, fftfreq returns N bins. For even N=4 with fs=1.0
-- the expected bins are [0, 1/4, -1/2, -1/4]. The current
-- implementation uses the simple `i < N/2` rule, which for N=4 puts
-- bin 2 (i=2) on the negative side: 2/4 - 1 = -1/2. We test bins
-- 0, 1, 3 which are unambiguous across the common conventions, plus
-- the length-preservation check.

def test_fftfreq_preserves_length() -> unit ! { Test } = {
  freqs = fftfreq(sample4(), cast(1.0, f32))
  assert_true(eq(numel(freqs), cast(4, int64)),
              "fftfreq: length matches input")
}

def test_fftfreq_dc_bin_zero() -> unit ! { Test } = {
  -- DC bin (index 0) is always 0 for any sample rate.
  freqs = fftfreq(sample4(), cast(8.0, f32))
  f0 = inner_product(freqs, basis4(cast(0, int64)))
  assert_close(f0, cast(0.0, f32), cast(1.0e-7, f32),
               "fftfreq[0] = 0 (DC bin)")
}

def test_fftfreq_first_positive_bin() -> unit ! { Test } = {
  -- Bin 1 should be fs/N. fs=8, N=4 -> 2.0
  freqs = fftfreq(sample4(), cast(8.0, f32))
  f1 = inner_product(freqs, basis4(cast(1, int64)))
  assert_close(f1, cast(2.0, f32), cast(1.0e-6, f32),
               "fftfreq[1] = fs/N = 2.0")
}

def test_fftfreq_last_bin_negative() -> unit ! { Test } = {
  -- Bin N-1 = 3 wraps to negative side: (3 - 4)/4 * fs = -fs/4 = -2.0
  freqs = fftfreq(sample4(), cast(8.0, f32))
  f3 = inner_product(freqs, basis4(cast(3, int64)))
  assert_close(f3, cast(-2.0, f32), cast(1.0e-6, f32),
               "fftfreq[N-1] = -fs/N = -2.0 (negative wrap)")
}

def test_fftfreq_scales_with_sample_rate() -> unit ! { Test } = {
  -- Doubling fs doubles every non-DC bin.
  f_a = fftfreq(sample4(), cast(2.0, f32))
  f_b = fftfreq(sample4(), cast(4.0, f32))
  v_a = inner_product(f_a, basis4(cast(1, int64)))
  v_b = inner_product(f_b, basis4(cast(1, int64)))
  assert_close(mul(cast(2.0, f32), v_a), v_b, cast(1.0e-6, f32),
               "fftfreq scales linearly with sample_rate")
}
