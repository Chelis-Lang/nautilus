# Signal processing

`Nautilus.Signal` exports seven functions. `fftfreq` computes frequency
bins using real arithmetic. The other six names end in `_stub` and
return NaN tensors; Nautilus does not provide FFT, STFT, or these filters.

## Functions

| Function | Result | Notes |
|---|---|---|
| `fft_magnitude_stub` | Stub (NaN) | No Fourier transform |
| `ifft_magnitude_stub` | Stub (NaN) | No inverse Fourier transform |
| `stft_magnitude_stub` | Stub (NaN) | No short-time Fourier transform |
| `lowpass_stub` | Stub (NaN) | No low-pass filter |
| `highpass_stub` | Stub (NaN) | No high-pass filter |
| `bandpass_stub` | Stub (NaN) | No band-pass filter |
| `fftfreq` | Frequency bins | Computes FFT frequency bins (real arithmetic only) |

## fftfreq

`fftfreq` computes the frequency bin centers for a discrete Fourier transform,
matching NumPy's `fft.fftfreq` convention.

```chelis-fragment
import Nautilus.Signal (fftfreq)

-- For an 8-sample signal at 100 Hz sample rate:
freqs = fftfreq(signal, cast(100.0, f32))
-- Returns: [0, 12.5, 25, 37.5, -50, -37.5, -25, -12.5]
```

**Signature:** `[n](x: &tensor[n, f32], sample_rate: f32) -> tensor[n, f32]`

The input tensor's values are ignored; only its length `n` is used.
