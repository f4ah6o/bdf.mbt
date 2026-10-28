///|
test "header prefix can be parsed before the manifest is fetched" {
  let header = b"bdf\x00\x01\x00\x00\x00\x20\x00\x00\x00\x00\x00\x00\x00\x08\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
  let parsed = parse_header_prefix(header)
  assert_eq(parsed.manifest_offset, 32)
  assert_eq(parsed.manifest_length, 8)
  let mut rejected = false
  ignore(parse_header(header)) catch {
    _ => rejected = true
  }
  assert_true(rejected)
}

///|
test "header prefix rejects truncated or invalid headers" {
  for
    bytes in [
      b"bdf\x00", b"bad\x00\x01\x00\x00\x00\x20\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00",
    ] {
    let mut rejected = false
    ignore(parse_header_prefix(bytes)) catch {
      _ => rejected = true
    }
    assert_true(rejected)
  }
}
