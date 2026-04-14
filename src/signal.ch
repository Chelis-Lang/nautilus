module Nautilus.Signal
export (
  fft_magnitude_stub,
  ifft_magnitude_stub,
  stft_magnitude_stub,
  lowpass_stub,
  highpass_stub,
  bandpass_stub,
  fftfreq
)

def signal_stub_nan() -> f32 = div(cast(0.0, f32), cast(0.0, f32))

def fft_magnitude_stub[n](x: tensor[n, f32]) -> tensor[n, f32] =
  to_tensor(map(fn (v: f32) -> signal_stub_nan(), to_list(x)))

def ifft_magnitude_stub[n](x: tensor[n, f32]) -> tensor[n, f32] =
  to_tensor(map(fn (v: f32) -> signal_stub_nan(), to_list(x)))

def stft_magnitude_stub[n](x: tensor[n, f32], window_size: int64, hop_size: int64) -> tensor[n, f32] = {
  ignore_ws = window_size
  ignore_hs = hop_size
  to_tensor(map(fn (v: f32) -> signal_stub_nan(), to_list(x)))
}

def lowpass_stub[n](x: tensor[n, f32], cutoff_hz: f32, sample_rate: f32) -> tensor[n, f32] = {
  ignore_c = cutoff_hz
  ignore_s = sample_rate
  to_tensor(map(fn (v: f32) -> signal_stub_nan(), to_list(x)))
}

def highpass_stub[n](x: tensor[n, f32], cutoff_hz: f32, sample_rate: f32) -> tensor[n, f32] = {
  ignore_c = cutoff_hz
  ignore_s = sample_rate
  to_tensor(map(fn (v: f32) -> signal_stub_nan(), to_list(x)))
}

def bandpass_stub[n](x: tensor[n, f32], low_hz: f32, high_hz: f32, sample_rate: f32) -> tensor[n, f32] = {
  ignore_l = low_hz
  ignore_h = high_hz
  ignore_s = sample_rate
  to_tensor(map(fn (v: f32) -> signal_stub_nan(), to_list(x)))
}

def fftfreq[n](x: tensor[n, f32], sample_rate: f32) -> tensor[n, f32] = {
  n_i = numel(copy(x))
  n_f = cast(n_i, f32)
  half = mul(cast(0.5, f32), n_f)
  indexed = enumerate(to_list(x))
  to_tensor(map(fn (pair: (int64, f32)) -> {
    i_f = cast(pair.0, f32)
    shifted = if lt(i_f, half) then i_f else sub(i_f, n_f)
    mul(div(shifted, n_f), sample_rate)
  }, indexed))
}
