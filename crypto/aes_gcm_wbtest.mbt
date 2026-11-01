///|
fn gcm_hex(value : String) -> Bytes {
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
fn gcm_hex_string(value : Bytes) -> String {
  let out = StringBuilder()
  for byte in value {
    out.write_char("0123456789abcdef".get_char(byte.to_int() >> 4).unwrap())
    out.write_char("0123456789abcdef".get_char(byte.to_int() & 15).unwrap())
  }
  out.to_string()
}

///|
test "AES-GCM matches the empty NIST vector" {
  let key = gcm_hex("00000000000000000000000000000000")
  let nonce = gcm_hex("000000000000000000000000")
  let (ciphertext, tag) = aes_gcm_encrypt(key, nonce, b"", b"")
  assert_eq(ciphertext.length(), 0)
  assert_eq(gcm_hex_string(tag), "58e2fccefa7e3061367f1d57a4e7455a")
}

///|
test "AES-GCM matches the one-block NIST vector" {
  let key = gcm_hex("00000000000000000000000000000000")
  let nonce = gcm_hex("000000000000000000000000")
  let plain = gcm_hex("00000000000000000000000000000000")
  let (ciphertext, tag) = aes_gcm_encrypt(key, nonce, plain, b"")
  assert_eq(gcm_hex_string(ciphertext), "0388dace60b6a392f328c2b971b2fe78")
  assert_eq(gcm_hex_string(tag), "ab6e47d42cec13bdf53a67b21257bddf")
  let roundtrip = aes_gcm_decrypt(key, nonce, ciphertext, tag, b"").unwrap()
  assert_eq(roundtrip, plain)
}
