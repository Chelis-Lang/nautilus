# Signal Processing

The `Nautilus.Signal` module is **stub-only**. All functions except
`fftfreq` return NaN tensors. The module exists to reserve the API
surface for when upstream Chelis adds complex-number support (Phase 5f).

## Current status

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

**Signature:** `[n](x: tensor[n, f32], sample_rate: f32) -> tensor[n, f32]`

The input tensor's values are ignored; only its length `n` is used.

## What will ship with complex numbers

Once Chelis supports a complex type (or a `(f32, f32)` pair convention):

- **FFT/IFFT:** Cooley-Tukey radix-2 for power-of-2 lengths, Bluestein
  for arbitrary lengths. Magnitude and phase extraction.
- **STFT:** Windowed FFT with configurable window size and hop.
- **Filters:** Frequency-domain lowpass, highpass, and bandpass via
  FFT, mask, IFFT.

The `_stub` suffix on current names is intentional: when real
implementations ship, they will use the clean names (`fft`, `ifft`,
`stft`, `lowpass`, `highpass`, `bandpass`).
