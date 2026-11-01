///|
pub suberror KeyWrapError {
  InvalidKeyWrap
}

///|
fn kw_bytes(values : Array[Byte]) -> Bytes {
  Bytes::from_array(values)
}

///|
fn kw_xor_t(a : Array[Byte], t : Int32) -> Unit {
  let value = [(t >> 24) & 0xff, (t >> 16) & 0xff, (t >> 8) & 0xff, t & 0xff]
  for i in 0..<4 {
    a[4 + i] = (a[4 + i].to_int() ^ value[i]).to_byte()
  }
}

///|
/// AES key wrap (RFC 3394) with a 128/192/256-bit key-encryption key.
pub fn aes_key_wrap(kek : Bytes, plaintext : Bytes) -> Bytes raise {
  let length = plaintext.length()
  if length % 8 != 0 || length < 16 {
    raise InvalidKeyWrap
  }
  let n = length / 8
  let a : Array[Byte] = [0xa6, 0xa6, 0xa6, 0xa6, 0xa6, 0xa6, 0xa6, 0xa6]
  let r : Array[Array[Byte]] = []
  for i in 0..<n {
    let block : Array[Byte] = []
    for j in 0..<8 {
      block.push(plaintext[i * 8 + j])
    }
    r.push(block)
  }
  for j in 0..<6 {
    for i in 0..<n {
      let input : Array[Byte] = []
      for byte in a {
        input.push(byte)
      }
      for byte in r[i] {
        input.push(byte)
      }
      let b = @xcrypto.aes_ecb_encrypt(kek, kw_bytes(input))
      let next : Array[Byte] = []
      for k in 0..<8 {
        next.push(b[k])
      }
      kw_xor_t(next, n * j + i + 1)
      a.clear()
      for byte in next {
        a.push(byte)
      }
      r[i].clear()
      for k in 8..<16 {
        r[i].push(b[k])
      }
    }
  }
  let output : Array[Byte] = []
  for byte in a {
    output.push(byte)
  }
  for block in r {
    for byte in block {
      output.push(byte)
    }
  }
  kw_bytes(output)
}

///|
/// AES key unwrap (RFC 3394). Returns None when the integrity check fails.
pub fn aes_key_unwrap(kek : Bytes, wrapped : Bytes) -> Bytes? raise {
  let length = wrapped.length()
  if length % 8 != 0 || length < 24 {
    return None
  }
  let n = length / 8 - 1
  let a : Array[Byte] = []
  for i in 0..<8 {
    a.push(wrapped[i])
  }
  let r : Array[Array[Byte]] = []
  for i in 0..<n {
    let block : Array[Byte] = []
    for j in 0..<8 {
      block.push(wrapped[8 + i * 8 + j])
    }
    r.push(block)
  }
  for j in 0..<6 {
    let round = 5 - j
    for index in 0..<n {
      let i = n - 1 - index
      let input : Array[Byte] = []
      for byte in a {
        input.push(byte)
      }
      kw_xor_t(input, n * round + i + 1)
      for byte in r[i] {
        input.push(byte)
      }
      let b = @xcrypto.aes_ecb_decrypt(kek, kw_bytes(input))
      for k in 0..<8 {
        a[k] = b[k]
      }
      r[i].clear()
      for k in 8..<16 {
        r[i].push(b[k])
      }
    }
  }
  for byte in a {
    if byte != b'\xa6' {
      return None
    }
  }
  let output : Array[Byte] = []
  for block in r {
    for byte in block {
      output.push(byte)
    }
  }
  Some(kw_bytes(output))
}
