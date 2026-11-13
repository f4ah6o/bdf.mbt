///|
test "public rectangle results cannot mutate the encoded symbol" {
  let symbol = @barcode.encode("code39", "A")
  let before = symbol.width()
  let first_bar = symbol.at(10, 0)
  let rectangles = symbol.rects()
  rectangles.clear()
  assert_true(first_bar)
  assert_eq(symbol.width(), before)
  assert_true(symbol.at(10, 0))
  assert_true(!symbol.rects().is_empty())
}
