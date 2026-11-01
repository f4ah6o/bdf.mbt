///|
fn crypto_be32(value : Int32) -> Array[Byte] {
  [
    ((value >> 24) & 0xff).to_byte(),
    ((value >> 16) & 0xff).to_byte(),
    ((value >> 8) & 0xff).to_byte(),
    (value & 0xff).to_byte(),
  ]
}

///|
fn crypto_bytes_from_fixed(data : FixedArray[Byte]) -> Bytes {
  let out : Array[Byte] = []
  for byte in data {
    out.push(byte)
  }
  Bytes::from_array(out)
}

///|
/// PBKDF2-HMAC-SHA-256. This is the password key derivation used by BDF
/// password key slots; it has no JavaScript dependency.
pub fn pbkdf2_sha256(
  password : Bytes,
  salt : Bytes,
  iterations : Int32,
  length : Int32,
) -> Bytes {
  if iterations < 1 || length <= 0 {
    return b""
  }
  let output : Array[Byte] = []
  let mut block = 1
  while output.length() < length {
    let input : Array[Byte] = []
    for byte in salt {
      input.push(byte)
    }
    for byte in crypto_be32(block) {
      input.push(byte)
    }
    let mut u = @xcrypto.hmac(
      @xcrypto.SHA256::new(),
      password,
      Bytes::from_array(input),
    )
    let t = u.copy()
    for _ in 1..<iterations {
      u = @xcrypto.hmac(
        @xcrypto.SHA256::new(),
        password,
        crypto_bytes_from_fixed(u),
      )
      for i in 0..<t.length() {
        t[i] = (t[i].to_int() ^ u[i].to_int()).to_byte()
      }
    }
    for byte in t {
      output.push(byte)
    }
    block += 1
  }
  Bytes::from_array(output[:length].to_array())
}
