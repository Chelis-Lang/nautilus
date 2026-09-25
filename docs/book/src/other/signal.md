# Signal Processing

`Nautilus.Signal` exports seven functions. `fftfreq` works; the other six
are placeholders that return NaN tensors, reserved until Chelis supports
complex numbers (see the
[deferrals in `spec/scope.md`](https://github.com/Chelis-Lang/nautilus/blob/main/spec/scope.md#deferrals)).

## Status

| Function | Status | Notes |
|---|---|---|
| `fft_magnitude_stub` | Stub (NaN) | Needs complex FFT |
| `ifft_magnitude_stub` | Stub (NaN) | Needs complex IFFT |
| `stft_magnitude_stub` | Stub (NaN) | Needs complex FFT + windowing |
| `lowpass_stub` | Stub (NaN) | Needs FFT for frequency-domain filtering |
| `highpass_stub` | Stub (NaN) | Needs FFT for frequency-domain filtering |
| `bandpass_stub` | Stub (NaN) | Needs FFT for frequency-domain filtering |
| `fftfreq` | **Functional** | Computes FFT frequency bins (real arithmetic only) |

## fftfreq

The one functional export. Computes the frequency bin centers for a
discrete Fourier transform, matching numpy's `fft.fftfreq` convention.

```chelis-fragment
import Nautilus.Signal (fftfreq)

// For an 8-sample signal at 100 Hz sample rate:
freqs = fftfreq(signal, cast(100.0, f32))
// Returns: [0, 12.5, 25, 37.5, -50, -37.5, -25, -12.5]
```

**Signature:** `[n](x: &tensor[n, f32], sample_rate: f32) -> tensor[n, f32]`

The input tensor's values are ignored; only its length `n` is used.

## Naming

The `_stub` suffix is deliberate. Real implementations, once Chelis has
complex numbers, are expected to take the plain names (`fft`, `ifft`,
`stft`, `lowpass`, `highpass`, `bandpass`), so code written against the
placeholders will not silently change behavior.
