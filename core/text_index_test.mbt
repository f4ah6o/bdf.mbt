///|
test "BTXT index preserves references, Unicode and separators" {
  let index = @core.decode_text_index(
    b"BTXT\x01\x00\x03\x00\x01\x00\x02\x05Hello\x00\x01\x01\x01\x06\xe4\xb8\x96\xe7\x95\x8c\x02\x00\x03\x02\x04next",
  )
  assert_eq(index.length(), 3)
  assert_eq((index[1].a, index[1].b, index[1].ordinal), (0, 1, 1))
  assert_eq(@core.index_plain_text(index), "Hello 世界\nnext")
  assert_eq(@core.decode_text_index(b"BTXT\x00\x00\x00").length(), 0)
}

///|
test "BTXT rejects invalid headers, versions, counts and strings" {
  for
    input in [
      b"wrong", b"BTXT\x02\x00\x00", b"BTXT\x01\x00\xff\xff\xff\xff\x07", b"BTXT\x01\x00\x01\x00\x00\x00\x00\x04x",
      b"BTXT\x01\x00\x01\x00\x00\x00\x00\x01\xff",
    ] {
    let mut rejected = false
    ignore(@core.decode_text_index(input)) catch {
      _ => rejected = true
    }
    assert_true(rejected)
  }
}

///|
test "manifest retains text index reference" {
  let hash = "0123456789abcdef0123456789abcdef"
  let m = @core.parse_manifest(
    "{\"bdf\":1,\"parts\":[],\"views\":[{\"id\":\"v\",\"kind\":\"fixed\",\"textIndex\":\"0123456789abcdef0123456789abcdef\"}]}",
  )
  assert_eq(m.views[0].text_index, Some(hash))
}
