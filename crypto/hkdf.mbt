///|
/// SHA-256 digest of a byte string.
pub fn sha256_bytes(data : Bytes) -> Bytes {
  let digest = @xcrypto.sha256(data)
  let out : Array[Byte] = []
  for byte in digest {
    out.push(byte)
  }
  Bytes::from_array(out)
}

///|
/// HKDF-SHA-256 (RFC 5869).
pub fn hkdf_sha256(
  ikm : Bytes,
  salt : Bytes,
  info : Bytes,
  length : Int32,
) -> Bytes raise {
  if length < 0 || length > 255 * 32 {
    raise InvalidKeyWrap
  }
  let actual_salt = if salt.length() == 0 { Bytes::make(32, 0) } else { salt }
  let prk = @xcrypto.hmac(@xcrypto.SHA256::new(), actual_salt, ikm)
  let prk_bytes : Array[Byte] = []
  for byte in prk {
    prk_bytes.push(byte)
  }
  let output : Array[Byte] = []
  let mut previous : Array[Byte] = []
  let mut counter = 1
  while output.length() < length {
    let input : Array[Byte] = []
    for byte in previous {
      input.push(byte)
    }
    for byte in info {
      input.push(byte)
    }
    input.push(counter.to_byte())
    let block = @xcrypto.hmac(
      @xcrypto.SHA256::new(),
      Bytes::from_array(prk_bytes),
      Bytes::from_array(input),
    )
    previous = []
    for byte in block {
      previous.push(byte)
      output.push(byte)
    }
    counter += 1
  }
  Bytes::from_array(output[:length].to_array())
}
