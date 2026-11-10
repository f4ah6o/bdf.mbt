///|
// Upstream `store` (converter/internal/jpx/tile.go) clamps the float32 sample
// to [lo - shift, hi - shift] before rounding, which is
// [-2^(prec-1), 2^(prec-1) - 1] for both signednesses, and `!(v >= lo)` maps
// NaN to the lower bound. `clamp_float_component_output` reproduces that, so
// the integer add never sees an out-of-range sample.
test "clamp_float_component_output matches upstream store() rounding" {
  let values : Array[Double] = [
    0.49999997019767761, -0.49999997019767761, 0.5, -0.5, 0.4, -0.4, 0.6, -0.6, 1.5, -1.5, 2.5,
    -2.5,
  ]
  assert_eq(
    clamp_float_component_output(values, 8, false),
    [129, 127, 129, 127, 128, 128, 129, 127, 130, 126, 131, 125],
  )
  assert_eq(
    clamp_float_component_output(values, 8, true),
    [1, -1, 1, -1, 0, 0, 1, -1, 2, -2, 3, -3],
  )
}

///|
test "clamp_float_component_output clamps out-of-range samples like upstream" {
  let values : Array[Double] = [127.5, -128.5, 255.5, -256.5]
  assert_eq(clamp_float_component_output(values, 8, false), [255, 0, 255, 0])
  assert_eq(
    clamp_float_component_output(values, 8, true),
    [127, -128, 127, -128],
  )
}

///|
test "clamp_float_component_output clamps huge samples before the integer add" {
  // Rounding first would saturate to the Int range and then wrap on the DC
  // offset; upstream clamps the float32 first, so these stay at the bounds.
  let values : Array[Double] = [
    1.0e30, -1.0e30, 3.4028234663852886e38, -3.4028234663852886e38,
  ]
  assert_eq(clamp_float_component_output(values, 8, false), [255, 0, 255, 0])
  assert_eq(
    clamp_float_component_output(values, 8, true),
    [127, -128, 127, -128],
  )
  assert_eq(
    clamp_float_component_output(values, 12, false),
    [4095, 0, 4095, 0],
  )
  assert_eq(
    clamp_float_component_output(values, 12, true),
    [2047, -2048, 2047, -2048],
  )
}

///|
test "clamp_float_component_output maps NaN and infinities like upstream" {
  let inf = 1.0 / 0.0
  let nan = inf - inf
  let values : Array[Double] = [inf, -inf, nan]
  // +inf clamps to the upper bound, -inf and NaN to the lower bound.
  assert_eq(clamp_float_component_output(values, 8, false), [255, 0, 0])
  assert_eq(clamp_float_component_output(values, 8, true), [127, -128, -128])
  assert_eq(clamp_float_component_output(values, 12, false), [4095, 0, 0])
  assert_eq(
    clamp_float_component_output(values, 12, true),
    [2047, -2048, -2048],
  )
}

///|
test "clamp_float_component_output rounds the 12-bit boundary like upstream" {
  let values : Array[Double] = [0.49999997019767761, -0.49999997019767761]
  assert_eq(clamp_float_component_output(values, 12, false), [2049, 2047])
  assert_eq(clamp_float_component_output(values, 12, true), [1, -1])
}

///|
test "clamp_float_component_output saturates the 16-bit range like upstream" {
  let values : Array[Double] = [32767.0, 32768.0, -32768.0, -32769.0]
  assert_eq(
    clamp_float_component_output(values, 16, false),
    [65535, 65535, 0, 0],
  )
  assert_eq(
    clamp_float_component_output(values, 16, true),
    [32767, 32767, -32768, -32768],
  )
}
