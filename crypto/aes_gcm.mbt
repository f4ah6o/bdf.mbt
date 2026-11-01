///|
fn gcm_block(values : Array[Byte]) -> Bytes {
  Bytes::from_array(values)
}

///|
fn gcm_shift_right(block : Array[Byte]) -> Unit {
  let mut carry = 0
  for i in 0..<16 {
    let value = block[i].to_int()
    block[i] = ((value >> 1) | carry).to_byte()
    carry = (value & 1) << 7
  }
}

///|
fn gcm_multiply(x : Array[Byte], y : Array[Byte]) -> Array[Byte] {
  let z : Array[Byte] = Array::make(16, b'\x00')
  let v = y.copy()
  for i in 0..<128 {
    let bit = (x[i / 8].to_int() >> (7 - i % 8)) & 1
    if bit == 1 {
      for j in 0..<16 {
        z[j] = (z[j].to_int() ^ v[j].to_int()).to_byte()
      }
    }
    let low = v[15].to_int() & 1
    gcm_shift_right(v)
    if low == 1 {
      v[0] = (v[0].to_int() ^ 0xe1).to_byte()
    }
  }
  z
}

///|
fn gcm_ghash(h : Array[Byte], aad : Bytes, ciphertext : Bytes) -> Array[Byte] {
  let y : Array[Byte] = Array::make(16, b'\x00')
  let absorb = fn(data : Bytes, offset : Int32, length : Int32) {
    let block : Array[Byte] = Array::make(16, b'\x00')
    for i in 0..<length {
      block[i] = data[offset + i]
    }
    for j in 0..<16 {
      y[j] = (y[j].to_int() ^ block[j].to_int()).to_byte()
    }
    let product = gcm_multiply(y, h)
    for j in 0..<16 {
      y[j] = product[j]
    }
  }
  let mut offset = 0
  while offset < aad.length() {
    let length = Int32::min(16, aad.length() - offset)
    absorb(aad, offset, length)
    offset += length
  }
  offset = 0
  while offset < ciphertext.length() {
    let length = Int32::min(16, ciphertext.length() - offset)
    absorb(ciphertext, offset, length)
    offset += length
  }
  let lengths : Array[Byte] = Array::make(16, b'\x00')
  let aad_bits = aad.length().to_int64() * 8L
  let cipher_bits = ciphertext.length().to_int64() * 8L
  for i in 0..<8 {
    lengths[7 - i] = ((aad_bits >> (i * 8)) & 0xffL).to_int().to_byte()
    lengths[15 - i] = ((cipher_bits >> (i * 8)) & 0xffL).to_int().to_byte()
  }
  for j in 0..<16 {
    y[j] = (y[j].to_int() ^ lengths[j].to_int()).to_byte()
  }
  gcm_multiply(y, h)
}

///|
fn gcm_counter_inc(counter : Array[Byte]) -> Unit {
  for i in 0..<4 {
    let index = 15 - i
    let value = (counter[index].to_int() + 1) & 0xff
    counter[index] = value.to_byte()
    if value != 0 {
      break
    }
  }
}

///|
fn gcm_ctr(key : Bytes, nonce : Bytes, input : Bytes) -> Bytes raise {
  let counter : Array[Byte] = []
  for byte in nonce {
    counter.push(byte)
  }
  for _ in 0..<4 {
    counter.push(b'\x00')
  }
  counter[15] = b'\x01'
  gcm_counter_inc(counter)
  let output : Array[Byte] = []
  let mut offset = 0
  while offset < input.length() {
    let block = @xcrypto.aes_ecb_encrypt(key, gcm_block(counter))
    let length = Int32::min(16, input.length() - offset)
    for i in 0..<length {
      output.push((input[offset + i].to_int() ^ block[i].to_int()).to_byte())
    }
    gcm_counter_inc(counter)
    offset += length
  }
  gcm_block(output)
}

///|
fn gcm_tag(
  key : Bytes,
  h : Array[Byte],
  nonce : Bytes,
  aad : Bytes,
  ciphertext : Bytes,
) -> Bytes raise {
  let j0 : Array[Byte] = []
  for byte in nonce {
    j0.push(byte)
  }
  for _ in 0..<4 {
    j0.push(b'\x00')
  }
  j0[15] = b'\x01'
  let mask = @xcrypto.aes_ecb_encrypt(key, gcm_block(j0))
  let ghash = gcm_ghash(h, aad, ciphertext)
  let tag : Array[Byte] = []
  for i in 0..<16 {
    tag.push((mask[i].to_int() ^ ghash[i].to_int()).to_byte())
  }
  gcm_block(tag)
}

///|
/// AES-256-GCM encryption with a 12-byte nonce. Returns the ciphertext and
/// the 16-byte authentication tag.
pub fn aes_gcm_encrypt(
  key : Bytes,
  nonce : Bytes,
  plaintext : Bytes,
  aad : Bytes,
) -> (Bytes, Bytes) raise {
  if nonce.length() != 12 {
    raise InvalidKeyWrap
  }
  let h = @xcrypto.aes_ecb_encrypt(
    key, b"\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00",
  )
  let h_array : Array[Byte] = []
  for byte in h {
    h_array.push(byte)
  }
  let ciphertext = gcm_ctr(key, nonce, plaintext)
  let tag = gcm_tag(key, h_array, nonce, aad, ciphertext)
  (ciphertext, tag)
}

///|
/// AES-256-GCM decryption. Returns None when the tag does not match.
pub fn aes_gcm_decrypt(
  key : Bytes,
  nonce : Bytes,
  ciphertext : Bytes,
  tag : Bytes,
  aad : Bytes,
) -> Bytes? raise {
  if nonce.length() != 12 || tag.length() != 16 {
    return None
  }
  let h = @xcrypto.aes_ecb_encrypt(
    key, b"\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00",
  )
  let h_array : Array[Byte] = []
  for byte in h {
    h_array.push(byte)
  }
  let expected = gcm_tag(key, h_array, nonce, aad, ciphertext)
  for i in 0..<16 {
    if expected[i] != tag[i] {
      return None
    }
  }
  Some(gcm_ctr(key, nonce, ciphertext))
}
