///|
test "BDF strings discard one leading UTF-8 BOM" {
  let one = @core.Reader::new(b"\x04\xef\xbb\xbfA")
  assert_eq(one.string(), "A")
  let doubled = @core.Reader::new(b"\x0b\xef\xbb\xbf\xef\xbb\xbfA\xef\xbb\xbfB")
  assert_eq(doubled.string(), "\u{FEFF}A\u{FEFF}B")
  let interior = @core.Reader::new(b"\x05A\xef\xbb\xbfB")
  assert_eq(interior.string(), "A\u{FEFF}B")
}
