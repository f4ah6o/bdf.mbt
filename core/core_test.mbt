///|
test "v1 header decodes 32-byte input" {
  let h = parse_header(
    b"bdf\x00\x01\x00\x00\x00\x20\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00",
  )
  assert_eq(h.version, 1)
  assert_eq(h.manifest_offset, 32)
  assert_eq(h.manifest_length, 0)
}

///|
test "bad BDF magic rejected" {
  let mut rejected = false
  try {
    ignore(parse_header(b"nope"))
  } catch {
    _ => rejected = true
  }
  assert_eq(rejected, true)
}

///|
test "manifest accepts a valid empty document" {
  let m = parse_manifest("{\"bdf\":1,\"opset\":1,\"parts\":[],\"views\":[{\"id\":\"a\",\"kind\":\"fixed\",\"pages\":[]}]}")
  assert_eq(m.parts.length(), 0)
  assert_eq(m.views[0].id, "a")
}

///|
test "manifest refuses path traversal part hash" {
  let mut rejected = false
  try {
    ignore(parse_manifest("{\"bdf\":1,\"parts\":[{\"h\":\"../secret\",\"t\":\"obj\",\"len\":0,\"size\":0}],\"views\":[]}"))
  } catch {
    _ => rejected = true
  }
  assert_eq(rejected, true)
}

///|
test "BOBJ empty display list" {
  let obj = decode_object(
    b"BOBJ\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00",
  )
  assert_eq(obj.ops.length(), 0)
}
