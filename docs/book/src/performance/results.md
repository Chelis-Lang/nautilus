# Performance

Nautilus has no release-wide performance threshold. Measure the function,
input size, dtype, and Chelis target used by your application before making
speed claims.

## Keep tensor arithmetic on tensors

For elementwise vector calculations, use Chelis tensor operations where they
express the computation. A `to_list` / `map` / `to_tensor` round trip moves
values through host lists and can cost much more than a native tensor
operation in generated C. Some Nautilus functions use lists internally, so
measure the complete function as well as the surrounding expression.

## Compare like with like

- Check numerical error against a suitable reference before comparing time.
  A faster result with a different tolerance is a different calculation.
- Keep dtype, input shape, number of threads, and compiler flags visible in
  the measurement. Most Nautilus modules compute in f32; a direct comparison
  with an f64 library also compares precision.
- Time the generated C path for a compiled workload. CLI startup and calls
  from a host-language test harness can dominate short calculations.
- Measure both small and representative large inputs. The fastest choice
  can change when dispatch overhead stops dominating the work.

The [archived benchmark record](https://github.com/Chelis-Lang/nautilus/blob/main/docs/archive/benchmark_findings.md)
contains measured configurations and results. Those measurements are not a
performance promise for this release or for other hardware.
