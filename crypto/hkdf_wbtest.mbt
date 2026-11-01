///|
fn hkdf_hex(value : String) -> Bytes {
  let out : Array[Byte] = []
  for i in 0..<(value.length() / 2) {
    let high = value.get_char(i * 2).unwrap()
    let low = value.get_char(i * 2 + 1).unwrap()
    let digit = fn(c : Char) {
      if c >= '0' && c <= '9' {
        c.to_int() - '0'.to_int()
      } else {
        c.to_int() - 'a'.to_int() + 10
      }
    }
    out.push(((digit(high) << 4) | digit(low)).to_byte())
  }
  Bytes::from_array(out)
}

///|
fn hkdf_hex_string(value : Bytes) -> String {
  let out = StringBuilder()
  for byte in value {
    out.write_char("0123456789abcdef".get_char(byte.to_int() >> 4).unwrap())
    out.write_char("0123456789abcdef".get_char(byte.to_int() & 15).unwrap())
  }
  out.to_string()
}

///|
test "HKDF-SHA-256 matches RFC 5869 case 1" {
  let ikm = hkdf_hex("0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b")
  let salt = hkdf_hex("000102030405060708090a0b0c")
  let info = hkdf_hex("f0f1f2f3f4f5f6f7f8f9")
  let output = hkdf_sha256(ikm, salt, info, 42)
  assert_eq(
    hkdf_hex_string(output),
    "3cb25f25faacd57a90434f64d0362f2a2d2d0a90cf1a5a4c5db02d56ecc4c5bf34007208d5b887185865",
  )
}

///|
test "HKDF-SHA-256 accepts 32-byte inputs" {
  let output = hkdf_sha256(Bytes::make(32, 1), Bytes::make(32, 2), b"x", 32)
  assert_eq(output.length(), 32)
}
