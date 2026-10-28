///|
test "fill rectangle opset decoding" {
  let object : @core.ObjectPart = {
    bbox: (0.0, 0.0, 20.0, 20.0),
    strings: [],
    images: [],
    objects: [],
    ops: b"\x01\x20\x00\x00\x80\x3f\x00\x00\x00\x40\x00\x00\x40\x40\x00\x00\x80\x40\x02",
  }
  let result = compile_object(object)
  assert_eq(result.length(), 3)
  match result[1] {
    FillRect(x, y, w, h) => {
      assert_eq(x, 1.0)
      assert_eq(y, 2.0)
      assert_eq(w, 3.0)
      assert_eq(h, 4.0)
    }
    _ => fail("expected FillRect")
  }
}

///|
test "unknown render instruction is not ignored" {
  let object : @core.ObjectPart = {
    bbox: (0.0, 0.0, 0.0, 0.0),
    strings: [],
    images: [],
    objects: [],
    ops: b"\x99",
  }
  let mut rejected = false
  try {
    ignore(compile_object(object))
  } catch {
    _ => rejected = true
  }
  assert_eq(rejected, true)
}

///|
test "untrusted text indices are checked" {
  let object : @core.ObjectPart = {
    bbox: (0.0, 0.0, 0.0, 0.0),
    strings: [],
    images: [],
    objects: [],
    ops: b"\x30\x00",
  }
  let mut rejected = false
  try {
    ignore(compile_object(object))
  } catch {
    _ => rejected = true
  }
  assert_eq(rejected, true)
}
