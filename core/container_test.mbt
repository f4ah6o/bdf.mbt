///|
/// Builds a single-file BDF whose manifest declares one part of `declared`
/// bytes, followed by `payload` bytes of part data.
fn single_file_with_part(declared : Int, payload : Int) -> Bytes {
  let manifest = "{\"bdf\":1,\"opset\":1,\"parts\":[{\"h\":\"000102030405060708090a0b0c0d0e0f\",\"t\":\"obj\",\"len\":" +
    declared.to_string() +
    ",\"size\":" +
    declared.to_string() +
    ",\"off\":0}],\"views\":[{\"id\":\"a\",\"kind\":\"fixed\",\"pages\":[]}]}"
  let body = @utf8.encode(manifest)
  let n = body.length()
  let out : Array[Byte] = [
    b'b', b'd', b'f', b'\x00', // magic
    b'\x01', b'\x00', // version 1
    b'\x00', b'\x00', // flags 0
    b'\x20', b'\x00', b'\x00', b'\x00', // manifest_offset low word = 32
    b'\x00', b'\x00', b'\x00', b'\x00', // manifest_offset high word = 0
    (n & 0xff).to_byte(), ((n >> 8) & 0xff).to_byte(),
    ((n >> 16) & 0xff).to_byte(), ((n >> 24) & 0xff).to_byte(), // manifest_length low
    b'\x00', b'\x00', b'\x00', b'\x00', // manifest_length high = 0
    b'\x00', // manifest_encoding = identity
    b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', // reserved
  ]
  for b in body {
    out.push(b)
  }
  for _ in 0..<payload {
    out.push(b'\x00')
  }
  Bytes::from_array(out)
}

///|
test "open_single accepts a part that fits exactly" {
  let doc = @core.open_single(single_file_with_part(4, 4))
  assert_eq(doc.manifest.parts.length(), 1)
  assert_eq(doc.part("000102030405060708090a0b0c0d0e0f"), b"\x00\x00\x00\x00")
}

///|
test "open_single rejects a part one byte past the file" {
  let rejected = try {
    ignore(@core.open_single(single_file_with_part(5, 4)))
    false
  } catch {
    @core.BadFormat("part outside BDF file") => true
    _ => false
  }
  assert_true(rejected)
}

///|
test "open_single rejects a part far past the file" {
  let rejected = try {
    ignore(@core.open_single(single_file_with_part(1000, 4)))
    false
  } catch {
    @core.BadFormat("part outside BDF file") => true
    _ => false
  }
  assert_true(rejected)
}

///|
test "property: open_single accepts exactly the parts that fit" {
  @quickcheck.check((sample : Byte) => {
    let declared = sample.to_int() % 65
    let payload = 8
    let accepted = try {
      ignore(@core.open_single(single_file_with_part(declared, payload)))
      true
    } catch {
      @core.BadFormat("part outside BDF file") => false
      other => raise other
    }
    accepted == (declared <= payload)
  })
}
