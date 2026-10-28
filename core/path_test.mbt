///|
test "object retains inline and external paths" {
  let decoded = @core.decode_object_with_paths(
    b"\x42\x4f\x42\x4a\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\x02\x00\x01\x00\x00\x80\x3f\x00\x00\x00\x40\x00\x00\x40\x40\x00\x00\x80\x40\x01\x00\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0a\x0b\x0c\x0d\x0e\x0f\x03\x00\x00\x00\x00\x00",
  )
  assert_eq(decoded.paths.length(), 2)
  guard decoded.paths[0] is Inline(path) else { fail("inline path") }
  assert_eq(path.verbs, b"\x00\x01")
  assert_eq(path.coordinates, [1.0, 2.0, 3.0, 4.0])
  guard decoded.paths[1] is External(hash, index) else { fail("external path") }
  assert_eq(hash, "000102030405060708090a0b0c0d0e0f")
  assert_eq(index, 3)
}

///|
test "path collection validates verbs and lengths" {
  let paths = @core.decode_path_collection(
    b"\x01\x02\x00\x01\x00\x00\x80\x3f\x00\x00\x00\x40\x00\x00\x40\x40\x00\x00\x80\x40",
  )
  assert_eq(paths[0].coordinates, [1.0, 2.0, 3.0, 4.0])
  assert_eq(@core.decode_path_collection(b"\x00\x00").length(), 0)
  for input in [b"\x01\x01\x09", b"\x01\x01\x00"] {
    let rejected = try {
      ignore(@core.decode_path_collection(input))
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
  }
}

///|
test "object rejects unknown path entry kind" {
  let rejected = try {
    ignore(
      @core.decode_object_with_paths(
        b"\x42\x4f\x42\x4a\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x01\x02",
      ),
    )
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
}
