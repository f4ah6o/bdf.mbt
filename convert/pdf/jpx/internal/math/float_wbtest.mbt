///|
// Upstream `store` (converter/internal/jpx/tile.go) rounds a float32 sample
// with `int32(v + 0.5)` for non-negative values and `-int32(0.5 - v)`
// otherwise. The operand and the sum are both float32, so the float32
// immediately below 0.5 sums to exactly 1.0 and rounds up to 1.
fn f32_from_bits(bits : Int32) -> Double {
  Float::reinterpret_from_int(bits).to_double()
}

///|
test "round_half_away_f32 rounds the float32 just below 0.5 up to 1" {
  // 0x3effffff is the float32 immediately below 0.5.
  let v = f32_from_bits(0x3effffff)
  assert_eq(v, 0.49999997019767761)
  // float32(v + 0.5) is exactly 1.0; double(v) + 0.5 is 0.99999997019767761.
  assert_eq(round_half_away_f32(v), 1)
}

///|
test "round_half_away_f32 rounds the float32 just above -0.5 down to -1" {
  // 0xbeffffff is the float32 immediately above -0.5.
  let v = f32_from_bits(0xbeffffff)
  assert_eq(v, -0.49999997019767761)
  // float32(0.5 - v) is exactly 1.0, so upstream yields -1.
  assert_eq(round_half_away_f32(v), -1)
}

///|
test "round_half_away_f32 rounds exact halves away from zero" {
  assert_eq(round_half_away_f32(0.5), 1)
  assert_eq(round_half_away_f32(-0.5), -1)
  assert_eq(round_half_away_f32(1.5), 2)
  assert_eq(round_half_away_f32(-1.5), -2)
  assert_eq(round_half_away_f32(2.5), 3)
  assert_eq(round_half_away_f32(-2.5), -3)
}

///|
test "round_half_away_f32 matches upstream around the 0.5 boundary" {
  // Neighbours of the float32 immediately below 0.5, both signs.
  let cases : Array[(Int32, Int)] = [
    (0x3efffffd, 0),
    (0x3efffffe, 0),
    (0x3effffff, 1),
    (0x3f000000, 1),
    (0x3f000001, 1),
    (0xbefffffd, 0),
    (0xbefffffe, 0),
    (0xbeffffff, -1),
    (0xbf000000, -1),
    (0xbf000001, -1),
  ]
  for pair in cases {
    let (bits, expected) = pair
    assert_eq(round_half_away_f32(f32_from_bits(bits)), expected)
  }
}

///|
test "round_half_away_f32 matches upstream on ordinary samples" {
  let cases : Array[(Int32, Int)] = [
    (0x00000000, 0), // 0
    (0x80000000, 0), // -0
    (0x3ecccccd, 0), // 0.4
    (0x3f19999a, 1), // 0.6
    (0xbecccccd, 0), // -0.4
    (0xbf19999a, -1), // -0.6
    (0x3f7fffff, 1), // 0.99999994
    (0xbf7fffff, -1), // -0.99999994
    (0x4019999a, 2), // 2.4
    (0x40333333, 3), // 2.8
    (0xc019999a, -2), // -2.4
    (0xc0333333, -3), // -2.8
  ]
  for pair in cases {
    let (bits, expected) = pair
    assert_eq(round_half_away_f32(f32_from_bits(bits)), expected)
  }
}

///|
test "round_half_away_f32 snaps to float32 before rounding" {
  // 0.49999999 is not a float32; it snaps to 0.5 and rounds up.
  assert_eq(round_half_away_f32(0.49999999), 1)
  assert_eq(round_half_away_f32(-0.49999999), -1)
  // 0.4999999 snaps to 0x3efffffd, which stays below the boundary.
  assert_eq(round_half_away_f32(0.4999999), 0)
  assert_eq(round_half_away_f32(-0.4999999), 0)
}

///|
test "round_half_away_f32 saturates instead of wrapping on huge samples" {
  // Upstream clamps before rounding, so these never reach the conversion;
  // the helper must still saturate rather than wrap.
  assert_eq(round_half_away_f32(1.0e30), 2147483647)
  assert_eq(round_half_away_f32(-1.0e30), -2147483647)
}
