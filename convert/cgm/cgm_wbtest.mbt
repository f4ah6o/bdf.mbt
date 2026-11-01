///|
test "cgm detection" {
  assert_true(detect(b"\x1f\x8b\x08\x00"))
  assert_true(detect(b"\x00\x20\x00\x04BEGMF"))
  assert_false(detect(b"not a metafile"))
}
