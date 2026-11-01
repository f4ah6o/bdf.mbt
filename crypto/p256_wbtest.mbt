///|
fn p256_hex(value : String) -> Bytes {
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
fn p256_hex_string(value : Bytes) -> String {
  let out = StringBuilder()
  for byte in value {
    out.write_char("0123456789abcdef".get_char(byte.to_int() >> 4).unwrap())
    out.write_char("0123456789abcdef".get_char(byte.to_int() & 15).unwrap())
  }
  out.to_string()
}

///|
test "P-256 public key and ECDH match known vectors" {
  let one = p256_hex(
    "0000000000000000000000000000000000000000000000000000000000000001",
  )
  let two = p256_hex(
    "0000000000000000000000000000000000000000000000000000000000000002",
  )
  let generator = p256_hex(
    "046b17d1f2e12c4247f8bce6e563a440f277037d812deb33a0f4a13945d898c2964fe342e2fe1a7f9b8ee7eb4a7c0f9e162bce33576b315ececbb6406837bf51f5",
  )
  assert_eq(p256_hex_string(p256_public_key(one)), p256_hex_string(generator))
  assert_eq(
    p256_hex_string(p256_ecdh(one, generator)),
    "6b17d1f2e12c4247f8bce6e563a440f277037d812deb33a0f4a13945d898c296",
  )
  assert_eq(
    p256_hex_string(p256_ecdh(two, generator)),
    "7cf27b188d034f7e8a52380304b51ac3c08969e277f21b35a60b48fc47669978",
  )
}

///|
test "P-256 scalar 12345 matches the known public key" {
  let private_key = p256_hex(
    "0000000000000000000000000000000000000000000000000000000000003039",
  )
  assert_eq(
    p256_hex_string(p256_public_key(private_key)),
    "0426efcebd0ee9e34a669187e18b3a9122b2f733945b649cc9f9f921e9f9dad81290238bde9cc7bb330d150c67704dd25ae7055205744b6f31bf4070745872d0e6",
  )
}
