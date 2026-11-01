///|
test "PBKDF2-HMAC-SHA-256 matches the known vector" {
  let derived = pbkdf2_sha256(b"password", b"salt", 1, 32)
  let expected = "120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b"
  let hex = StringBuilder()
  for byte in derived {
    let value = byte.to_int()
    hex.write_char("0123456789abcdef".get_char(value >> 4).unwrap())
    hex.write_char("0123456789abcdef".get_char(value & 15).unwrap())
  }
  assert_eq(hex.to_string(), expected)
}
