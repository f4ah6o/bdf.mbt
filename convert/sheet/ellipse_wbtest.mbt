///|
// Expected path coordinates are decoded from the upstream Go fixture.
test "ellipse coordinates match upstream Go" {
  {
    let path = sheet_ellipse_path(96, 42.75)
    let expected : Array[UInt32] = [
      0x00000000U, 0x41ab0000U, 0x42400000U, 0x41ab0000U, 0x42400000U, 0x41ab0000U,
      0x00000000U, 0xc0490fdbU, 0xbfc90fdbU, 0x00000000U, 0x42400000U, 0x41ab0000U,
      0x42400000U, 0x41ab0000U, 0x00000000U, 0xbfc90fdbU, 0x26d02c3eU, 0x00000000U,
      0x42400000U, 0x41ab0000U, 0x42400000U, 0x41ab0000U, 0x00000000U, 0x00000000U,
      0x3fc90fdbU, 0x00000000U, 0x42400000U, 0x41ab0000U, 0x42400000U, 0x41ab0000U,
      0x00000000U, 0x3fc90fdbU, 0x40490fdbU, 0x00000000U,
    ]
    assert_eq(path.verbs, b"\x00\x06\x06\x06\x06\x04")
    for j in 0..<expected.length() {
      assert_eq(
        Float::from_double(path.coordinates[j]).reinterpret_as_uint(),
        expected[j],
      )
    }
  }
  {
    let path = sheet_ellipse_path(96, 28.5)
    let expected : Array[UInt32] = [
      0x00000000U, 0x41640000U, 0x42400000U, 0x41640000U, 0x42400000U, 0x41640000U,
      0x00000000U, 0xc0490fdbU, 0xbfc90fdbU, 0x00000000U, 0x42400000U, 0x41640000U,
      0x42400000U, 0x41640000U, 0x00000000U, 0xbfc90fdbU, 0x271c212eU, 0x00000000U,
      0x42400000U, 0x41640000U, 0x42400000U, 0x41640000U, 0x00000000U, 0x00000000U,
      0x3fc90fdbU, 0x00000000U, 0x42400000U, 0x41640000U, 0x42400000U, 0x41640000U,
      0x00000000U, 0x3fc90fdbU, 0x40490fdbU, 0x00000000U,
    ]
    assert_eq(path.verbs, b"\x00\x06\x06\x06\x06\x04")
    for j in 0..<expected.length() {
      assert_eq(
        Float::from_double(path.coordinates[j]).reinterpret_as_uint(),
        expected[j],
      )
    }
  }
  let path = sheet_ellipse_path(72, 36)
  let expected : Array[UInt32] = [
    0x00000000U, 0x41900000U, 0x42100000U, 0x41900000U, 0x42100000U, 0x41900000U,
    0x00000000U, 0xc0490fdbU, 0xbfc90fdbU, 0x00000000U, 0x42100000U, 0x41900000U,
    0x42100000U, 0x41900000U, 0x00000000U, 0xbfc90fdbU, 0x26b96767U, 0x00000000U,
    0x42100000U, 0x41900000U, 0x42100000U, 0x41900000U, 0x00000000U, 0x00000000U,
    0x3fc90fdbU, 0x00000000U, 0x42100000U, 0x41900000U, 0x42100000U, 0x41900000U,
    0x00000000U, 0x3fc90fdbU, 0x40490fdbU, 0x00000000U,
  ]
  assert_eq(path.verbs, b"\x00\x06\x06\x06\x06\x04")
  for j in 0..<expected.length() {
    assert_eq(
      Float::from_double(path.coordinates[j]).reinterpret_as_uint(),
      expected[j],
    )
  }
}
