///|
/// LHA `-lh5-` decompression (and a minimal compressor for testing).
///
/// DocuWorks stores its properties block and its vector page bodies as raw
/// `-lh5-` bit streams (no LHA archive header): blocks of static Huffman
/// codes over an 8 KiB sliding window. Bits are read most significant first.
///
/// Block layout:
///
/// ```text
/// u16 count of codes in the block
/// code lengths of the "pt" helper alphabet (19 symbols, 5-bit count)
/// code lengths of the literal/length alphabet (510 symbols, 9-bit count),
///     run-length coded with the pt alphabet
/// code lengths of the position alphabet (14 symbols, 4-bit count)
/// `count` codes: a literal byte (< 256) or a match of length c - 253
///     followed by a position code
/// ```

///|
const NC : Int = 510 // 256 literals + lengths 3..=256

///|
const NT : Int = 19

///|
const NP : Int = 14 // 8 KiB window: positions up to 2^13

///|
const CBIT : Int = 9

///|
const TBIT : Int = 5

///|
const PBITS : Int = 4

///|
const WINDOW : Int = 0x2000

///|
priv struct Bits {
  b : Bytes
  // Bit position.
  mut pos : Int
}

///|
fn Bits::bit(self : Bits) -> Int {
  let byte = match self.b.get(self.pos / 8) {
    Some(v) => v.to_int()
    None => 0
  }
  let v = (byte.lsr(7 - self.pos % 8)) & 1
  self.pos += 1
  v
}

///|
fn Bits::get(self : Bits, n : Int) -> Int {
  let mut v = 0
  for _ in 0..<n {
    v = (v << 1) | self.bit()
  }
  v
}

///|
/// The next `n` bits without consuming them.
fn Bits::peek(self : Bits, n : Int) -> Int {
  let t : Bits = { b: self.b, pos: self.pos }
  t.get(n)
}

///|
fn Bits::exhausted(self : Bits) -> Bool {
  self.pos > self.b.length() * 8 + 16
}

///|
/// A canonical Huffman code (codes assigned by length, then symbol order).
priv struct Huff {
  /// Only symbol when every length is zero.
  single : Int?
  first : FixedArray[Int]
  count : FixedArray[Int]
  offset : FixedArray[Int]
  symbols : Array[Int]
}

///|
fn Huff::single(s : Int) -> Huff {
  {
    single: Some(s),
    first: FixedArray::make(17, 0),
    count: FixedArray::make(17, 0),
    offset: FixedArray::make(17, 0),
    symbols: [],
  }
}

///|
fn huff_new(lens : Array[Int]) -> Huff raise XdwError {
  let count : FixedArray[Int] = FixedArray::make(17, 0)
  for l in lens {
    if l > 16 {
      raise XdwCorrupt("Huffman code longer than 16 bits")
    }
    if l > 0 {
      count[l] += 1
    }
  }
  let first : FixedArray[Int] = FixedArray::make(17, 0)
  let offset : FixedArray[Int] = FixedArray::make(17, 0)
  let mut code = 0
  let mut idx = 0
  for l in 1..<17 {
    code = (code + count[l - 1]) << 1
    if l == 1 {
      code = 0
    }
    first[l] = code
    offset[l] = idx
    idx += count[l]
  }
  let symbols : Array[Int] = Array::make(idx, 0)
  let next : FixedArray[Int] = FixedArray::make(17, 0)
  for k in 0..<offset.length() {
    next[k] = offset[k]
  }
  for s, l in lens {
    if l > 0 {
      symbols[next[l]] = s
      next[l] += 1
    }
  }
  {
    single: None,
    first,
    count,
    offset,
    symbols,
  }
}

///|
fn Huff::decode(self : Huff, r : Bits) -> Int raise XdwError {
  match self.single {
    Some(s) => return s
    None => ()
  }
  let mut code = 0
  for l in 1..<17 {
    code = (code << 1) | r.bit()
    let c = self.count[l]
    if c > 0 && code >= self.first[l] && code - self.first[l] < c {
      return self.symbols[self.offset[l] + code - self.first[l]]
    }
  }
  raise XdwCorrupt("invalid Huffman code")
}

///|
fn read_pt_len(
  r : Bits,
  nn : Int,
  nbit : Int,
  special : Int?,
) -> Huff raise XdwError {
  let n = r.get(nbit)
  if n == 0 {
    return Huff::single(r.get(nbit))
  }
  if n > nn {
    raise XdwCorrupt("pt table too long")
  }
  let lens : Array[Int] = Array::make(nn, 0)
  let mut i = 0
  while i < n {
    let mut c = r.get(3)
    if c == 7 {
      while r.bit() == 1 {
        c += 1
        if c > 16 {
          raise XdwCorrupt("pt length overflow")
        }
      }
    }
    lens[i] = c
    i += 1
    match special {
      Some(sp) =>
        if i == sp {
          let z = r.get(2)
          for _ in 0..<z {
            if i < nn {
              lens[i] = 0
              i += 1
            }
          }
        }
      None => ()
    }
  }
  huff_new(lens)
}

///|
fn read_c_len(r : Bits, pt : Huff) -> Huff raise XdwError {
  let n = r.get(CBIT)
  if n == 0 {
    return Huff::single(r.get(CBIT))
  }
  if n > NC {
    raise XdwCorrupt("c table too long")
  }
  let lens : Array[Int] = Array::make(NC, 0)
  let mut i = 0
  while i < n {
    let c = pt.decode(r)
    if c <= 2 {
      let run = match c {
        0 => 1
        1 => r.get(4) + 3
        _ => r.get(CBIT) + 20
      }
      for _ in 0..<run {
        if i < NC {
          lens[i] = 0
          i += 1
        }
      }
    } else {
      lens[i] = c - 2
      i += 1
    }
  }
  huff_new(lens)
}

///|
/// A growable byte output, kept to dynamic capacity so a hostile file
/// cannot make the reader reserve gigabytes up front.
priv struct OutBuf {
  mut data : FixedArray[Byte]
  mut len : Int
}

///|
fn OutBuf::push(self : OutBuf, v : Byte) -> Unit {
  if self.len == self.data.length() {
    let grown : FixedArray[Byte] = FixedArray::make(self.len * 2 + 4096, v)
    for i in 0..<self.len {
      grown[i] = self.data[i]
    }
    self.data = grown
  }
  self.data[self.len] = v
  self.len += 1
}

///|
fn OutBuf::at(self : OutBuf, i : Int) -> Byte {
  self.data[i]
}

///|
fn OutBuf::to_bytes(self : OutBuf) -> Bytes {
  Bytes::from_array(self.data[:self.len])
}

///|
/// Decompress a raw `-lh5-` stream into exactly `out_len` bytes.
///
/// `out_len` comes from the file, so it is checked first against the limits
/// in effect (at most `max_expand`, and at most `max_ratio` times the
/// stored size), and memory grows with what is really decoded instead of
/// being reserved up front.
pub fn lzh_decompress(
  src : Bytes,
  out_len : Int,
  limits : Limits,
) -> Bytes raise XdwError {
  // the size comes from the file, so it is checked first
  if !limits_expand_ok(
      limits,
      src.length().to_int64(),
      out_len.to_int64(),
    ) {
    raise XdwTooLarge("expanded size outside the limits")
  }
  let out : OutBuf = {
    data: FixedArray::make((out_len.min(src.length() * 4 + 4096)).max(1), b'\x00'),
    len: 0,
  }
  let r : Bits = { b: src, pos: 0 }
  while out.len < out_len {
    if r.exhausted() {
      raise XdwCorrupt("compressed data ends early")
    }
    let mut blocksize = r.get(16)
    if blocksize == 0 {
      raise XdwCorrupt("empty LZH block")
    }
    let pt = read_pt_len(r, NT, TBIT, Some(3))
    let c = read_c_len(r, pt)
    let p = read_pt_len(r, NP, PBITS, None)
    while blocksize > 0 && out.len < out_len {
      blocksize -= 1
      let sym = c.decode(r)
      if sym < 256 {
        out.push(sym.to_byte())
      } else {
        let len = sym - 256 + 3
        let mut d = p.decode(r)
        if d > 1 {
          d = (1 << (d - 1)) + r.get(d - 1)
        }
        let dist = d + 1
        if dist > out.len || dist > WINDOW {
          raise XdwCorrupt("LZH match points before the start")
        }
        let from = out.len - dist
        for k in 0..<len {
          if out.len >= out_len {
            break
          }
          out.push(out.at(from + k))
        }
      }
      if r.exhausted() {
        raise XdwCorrupt("compressed data ends early")
      }
    }
  }
  let _ = r.peek(0)
  out.to_bytes()
}
