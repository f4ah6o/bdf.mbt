///|
/// Incremental SHA-256 state. `digest` leaves the stream unchanged.
pub struct Sha256Stream {
  state : FixedArray[UInt32]
  pending : FixedArray[Byte]
  mut used : Int32
  mut size : Int64
}

///|
pub fn Sha256Stream::new() -> Sha256Stream {
  {
    state: [
      0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab,
      0x5be0cd19,
    ],
    pending: FixedArray::make(64, b'\x00'),
    used: 0,
    size: 0L,
  }
}

///|
fn Sha256Stream::block(self : Sha256Stream) -> Unit {
  let words = FixedArray::make(64, 0U)
  for i in 0..<16 {
    words[i] = (self.pending[4 * i].to_uint() << 24) |
      (self.pending[4 * i + 1].to_uint() << 16) |
      (self.pending[4 * i + 2].to_uint() << 8) |
      self.pending[4 * i + 3].to_uint()
  }
  for i in 16..<64 {
    let s0 = rotr(words[i - 15], 7) ^
      rotr(words[i - 15], 18) ^
      (words[i - 15] >> 3)
    let s1 = rotr(words[i - 2], 17) ^
      rotr(words[i - 2], 19) ^
      (words[i - 2] >> 10)
    words[i] = words[i - 16] + s0 + words[i - 7] + s1
  }
  let mut a = self.state[0]
  let mut b = self.state[1]
  let mut c = self.state[2]
  let mut d = self.state[3]
  let mut e = self.state[4]
  let mut f = self.state[5]
  let mut g = self.state[6]
  let mut h = self.state[7]
  for i in 0..<64 {
    let s1 = rotr(e, 6) ^ rotr(e, 11) ^ rotr(e, 25)
    let ch = (e & f) ^ (e.lnot() & g)
    let t1 = h + s1 + ch + sha256_k[i] + words[i]
    let s0 = rotr(a, 2) ^ rotr(a, 13) ^ rotr(a, 22)
    let t2 = s0 + ((a & b) ^ (a & c) ^ (b & c))
    h = g
    g = f
    f = e
    e = d + t1
    d = c
    c = b
    b = a
    a = t1 + t2
  }
  self.state[0] += a
  self.state[1] += b
  self.state[2] += c
  self.state[3] += d
  self.state[4] += e
  self.state[5] += f
  self.state[6] += g
  self.state[7] += h
}

///|
fn Sha256Stream::byte(self : Sha256Stream, value : Byte) -> Unit {
  self.pending[self.used] = value
  self.used += 1
  if self.used == 64 {
    self.block()
    self.used = 0
  }
}

///|
/// Append bytes to this hash stream.
pub fn Sha256Stream::write(self : Sha256Stream, data : BytesView) -> Unit {
  self.size += data.length().to_int64()
  for value in data {
    self.byte(value)
  }
}

///|
/// Return the current hash as lowercase hexadecimal without consuming it.
pub fn Sha256Stream::digest(self : Sha256Stream) -> String {
  let copy = Sha256Stream::new()
  for i in 0..<8 {
    copy.state[i] = self.state[i]
  }
  for i in 0..<64 {
    copy.pending[i] = self.pending[i]
  }
  copy.used = self.used
  let bits = self.size * 8L
  copy.byte(b'\x80')
  while copy.used != 56 {
    copy.byte(b'\x00')
  }
  for i in 0..<8 {
    copy.byte((bits >> (8 * (7 - i))).to_byte())
  }
  let hex = "0123456789abcdef"
  let out = StringBuilder()
  for word in copy.state {
    for shift = 28; shift >= 0; shift = shift - 4 {
      out.write_char(
        hex.get_char(((word >> shift) & 15).reinterpret_as_int()).unwrap(),
      )
    }
  }
  out.to_string()
}
