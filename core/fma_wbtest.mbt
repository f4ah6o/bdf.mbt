///|
test "fused multiply add preserves cancellation" {
  let step = 1.0 / 134217728.0
  assert_eq(
    fused_multiply_add(1.0 + step, 1.0 - step, -1.0),
    -1.0 / 18014398509481984.0,
  )
}
