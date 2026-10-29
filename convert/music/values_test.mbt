///|
test "compound beat rest uses a dotted quarter" {
  let values = @music.divide_values(0L, 1440L, 1440L, 2880L, true, true)
  assert_eq(values.length(), 1)
  assert_eq(values[0].kind, 3)
  assert_eq(values[0].dots, 1)
  assert_eq(values[0].ticks, 1440L)
}

///|
test "off-beat rest is aligned and malformed zero beat terminates" {
  let values = @music.divide_values(240L, 960L, 960L, 3840L, false, true)
  assert_eq(values.length(), 2)
  assert_eq(values[0].ticks, 240L)
  assert_eq(values[1].ticks, 480L)
  assert_eq(@music.divide_values(0L, 20L, 0L, 100L, false, true).length(), 0)
}
