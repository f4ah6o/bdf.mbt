///|
fn kw_hex(value : String) -> Bytes {
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
fn kw_hex_string(value : Bytes) -> String {
  let out = StringBuilder()
  for byte in value {
    out.write_char("0123456789abcdef".get_char(byte.to_int() >> 4).unwrap())
    out.write_char("0123456789abcdef".get_char(byte.to_int() & 15).unwrap())
  }
  out.to_string()
}

///|
test "AES key wrap matches RFC 3394" {
  let kek = kw_hex("000102030405060708090a0b0c0d0e0f")
  let plain = kw_hex("00112233445566778899aabbccddeeff")
  let wrapped = aes_key_wrap(kek, plain)
  assert_eq(
    kw_hex_string(wrapped),
    "1fa68b0a8112b447aef34bd8fb5a7b829d3e862371d2cfe5",
  )
  let unwrapped = aes_key_unwrap(kek, wrapped).unwrap()
  assert_eq(unwrapped, plain)
}
