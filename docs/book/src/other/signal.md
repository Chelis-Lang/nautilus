# Signal processing

`Nautilus.Signal` provides `fftfreq`, the frequency of each bin of a
discrete Fourier transform, in NumPy's `numpy.fft.fftfreq` order. Nautilus
does not compute Fourier transforms, short-time transforms, or filters,
because Chelis has no complex numbers; use `fftfreq` to label bins computed
elsewhere.

## fftfreq

```chelis-fragment
import Nautilus.Signal (fftfreq)

def signal() -> tensor[8, f32] = to_tensor([0.0f32, 0.0f32, 0.0f32, 0.0f32, 0.0f32, 0.0f32, 0.0f32, 0.0f32])
freqs = fftfreq(signal(), 100.0f32)
```

```text
signal = tensor(shape=[8], data=[0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0])
freqs = tensor(shape=[8], data=[0.0, 12.5, 25.0, 37.5, -50.0, -37.5, -25.0, -12.5])
```

**Signature:** `[n](x: &tensor[n, f32], sample_rate: f32) -> tensor[n, f32]`

The input's values are ignored; only its length `n` is used. Bin `i` is
`i * sample_rate / n` when `i < n / 2`, compared in floating point, and
`(i - n) * sample_rate / n` otherwise. For even `n` the Nyquist bin `n/2` is
negative; for odd `n` bins `0` through `(n - 1) / 2` are non-negative. Both
match NumPy. `fftfreq` of a five-element tensor at `sample_rate = 5.0`
returns `[0.0, 1.0, 2.0, -2.0, -1.0]`. The result is in hertz when
`sample_rate` is in samples per second. NumPy's second argument is the
sample spacing `d`; pass `sample_rate = 1 / d`.

`sample_rate` should be positive. It is not checked: 0 gives all zeros
(the upper half as `-0.0`), and a negative rate negates every bin.
