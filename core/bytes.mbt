///|
pub suberror BdfError {
  BadFormat(String)
  Unsupported(String)
}

///|
/// A checked little-endian reader shared by JS and wasm-gc.
/// All lengths and allocations are checked against the underlying input.
pub(all) struct Reader {
  data : Bytes
  mut pos : Int
}

///|
pub fn Reader::new(data : Bytes) -> Reader {
  { data, pos: 0 }
}

///|
pub fn Reader::remaining(self : Reader) -> Int {
  self.data.length() - self.pos
}

///|
pub fn Reader::u8(self : Reader) -> Int raise {
  if self.remaining() < 1 {
    raise BadFormat("unexpected end of data")
  }
  let value = self.data[self.pos].to_int()
  self.pos += 1
  value
}

///|
pub fn Reader::u16(self : Reader) -> Int raise {
  let a = self.u8()
  let b = self.u8()
  a | (b << 8)
}

///|
pub fn Reader::u32(self : Reader) -> Int raise {
  let a = self.u16()
  let b = self.u16()
  a | (b << 16)
}

///|
/// BDF input counts are bounded to a signed 32-bit address space in this
/// in-memory implementation.
pub fn Reader::u64_size(self : Reader) -> Int raise {
  let lo = self.u32()
  let hi = self.u32()
  if lo < 0 || hi != 0 {
    raise BadFormat("64-bit offset out of range")
  }
  lo
}

///|
pub fn Reader::f32(self : Reader) -> Double raise {
  Float::reinterpret_from_int(self.u32()).to_double()
}

///|
pub fn Reader::varuint(self : Reader) -> Int raise {
  let mut value = 0
  let mut shift = 0
  for _ in 0..<5 {
    let b = self.u8()
    if shift == 28 && (b & 0xf8) != 0 {
      raise BadFormat("varuint out of range")
    }
    value = value | ((b & 0x7f) << shift)
    if (b & 0x80) == 0 {
      if value < 0 {
        raise BadFormat("varuint out of range")
      }
      return value
    }
    shift += 7
  }
  raise BadFormat("varuint too long")
}

///|
pub fn Reader::skip(self : Reader, size : Int) -> Unit raise {
  if size < 0 || size > self.remaining() {
    raise BadFormat("unexpected end of data")
  }
  self.pos += size
}

///|
pub fn Reader::take(self : Reader, size : Int) -> Bytes raise {
  if size < 0 || size > self.remaining() {
    raise BadFormat("unexpected end of data")
  }
  let start = self.pos
  self.pos += size
  Bytes::from_array([for i in start..<self.pos => self.data[i]])
}

///|
pub fn Reader::string(self : Reader) -> String raise {
  let size = self.varuint()
  @utf8.decode(self.take(size), ignore_bom=true) catch {
    _ => raise BadFormat("invalid UTF-8 string")
  }
}

///|
pub fn Reader::hash(self : Reader) -> String raise {
  let bytes = self.take(16)
  let out = StringBuilder()
  for b in bytes {
    let n = b.to_int()
    let high = (n >> 4) & 15
    let low = n & 15
    out.write_char((if high < 10 { high + 48 } else { high + 87 }).unsafe_to_char())
    out.write_char((if low < 10 { low + 48 } else { low + 87 }).unsafe_to_char())
  }
  out.to_string()
}

///|
pub fn valid_hash(hash : String) -> Bool {
  let bytes = @utf8.encode(hash)
  if bytes.length() != 32 {
    return false
  }
  for b in bytes {
    let c = b.to_int()
    if !((c >= 48 && c <= 57) || (c >= 97 && c <= 102)) {
      return false
    }
  }
  true
}
