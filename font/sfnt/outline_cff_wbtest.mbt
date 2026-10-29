///|
test "CFF charstrings draw through global subroutines and close contours" {
  let first = b"\x8b\x8b\x15\x20\x1d\x0e"
  let invalid = b"\x20\x0a\x0e"
  let subroutine = b"\x95\x8b\x05\x0b"
  let font : CffOutlines = {
    charstrings: [first[:], invalid[:]],
    global: [subroutine[:]],
    local: [[]],
    fd_select: None,
  }
  let (ok, path) = font.outline(0)
  assert_true(ok)
  assert_eq(path, [Move(0.0, 0.0), Line(10.0, 0.0), Close])
  let (bad_subroutine, partial) = font.outline(1)
  assert_true(bad_subroutine)
  assert_eq(partial.length(), 0)
  assert_false(font.outline(2).0)
}

///|
test "CFF cubic bounds include the curve extrema" {
  let curve = b"\x8b\x8b\x15\x8b\xef\xef\x8b\x8b\x27\x08\x0e"
  let font : CffOutlines = {
    charstrings: [curve[:]],
    global: [],
    local: [[]],
    fd_select: None,
  }
  assert_eq(font.bounds(0), Some((0.0, 0.0, 100.0, 75.0)))
  assert_eq(font.bounds(1), None)
}
