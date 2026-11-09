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

// ------------------------------------------------------------- compressor

///|
priv struct BitWriter {
  out : Array[Byte]
  mut acc : Int
  mut n : Int
}

///|
fn BitWriter::put(self : BitWriter, v : Int, bits : Int) -> Unit {
  for i in 0..<bits {
    self.acc = (self.acc << 1) | ((v.lsr(bits - 1 - i)) & 1)
    self.n += 1
    if self.n == 8 {
      self.out.push(self.acc.to_byte())
      self.acc = 0
      self.n = 0
    }
  }
}

///|
fn BitWriter::finish(self : BitWriter) -> Bytes {
  if self.n > 0 {
    self.out.push((self.acc << (8 - self.n)).to_byte())
  }
  let pairs : FixedArray[Byte] = FixedArray::make(self.out.length(), b'\x00')
  for i, v in self.out {
    pairs[i] = v
  }
  Bytes::from_array(pairs)
}

///|
priv enum LzhNode {
  LzhLeaf(Int)
  LzhInner(Int, Int)
}

//|
/// Canonical codes for given lengths (same assignment as the decoder).
fn lzh_canonical(lens : Array[Int]) -> Array[(Int, Int)] {
  let count : FixedArray[Int] = FixedArray::make(17, 0)
  for l in lens {
    if l > 0 {
      count[l] += 1
    }
  }
  let next : FixedArray[Int] = FixedArray::make(17, 0)
  let mut code = 0
  for l in 1..<17 {
    code = (code + count[l - 1]) << 1
    if l == 1 {
      code = 0
    }
    next[l] = code
  }
  let out : Array[(Int, Int)] = []
  for l in lens {
    if l == 0 {
      out.push((0, 0))
    } else {
      let c = next[l]
      next[l] += 1
      out.push((c, l))
    }
  }
  out
}

///|
/// Huffman code lengths (limited to `max` bits) for symbol frequencies.
fn lzh_code_lengths(freq : Array[Int], max : Int) -> Array[Int] {
  let used : Array[Int] = []
  for i in 0..<freq.length() {
    if freq[i] > 0 {
      used.push(i)
    }
  }
  let lens : Array[Int] = Array::make(freq.length(), 0)
  if used.length() <= 1 {
    return lens // caller writes a single-symbol table
  }
  // Huffman tree, flattened to lengths; repeated with halved frequencies
  // as long as some depth grows past `max`.
  return lzh_code_rounds(freq.map((x : Int) => x.to_int64()), used, lens, max)
}

//|
/// One Huffman round; repeated with halved frequencies as long as some
/// depth grows past `max`.
fn lzh_code_rounds(
  f : Array[Int64],
  used : Array[Int],
  lens : Array[Int],
  max : Int,
) -> Array[Int] {
    // heap of (weight, node)
    let nodes : Array[Int64] = used.map((i : Int) => f[i])
    let kinds : Array[LzhNode] = used.map((i : Int) => LzhLeaf(i))
    let alive : Array[Int] = []
    for i in 0..<used.length() {
      alive.push(i)
    }
    while alive.length() > 1 {
      let mut best = 0
      for k in 0..<alive.length() {
        if nodes[alive[k]] > nodes[alive[best]] {
          best = k
        }
      }
      let a = alive.remove(best)
      let mut second = 0
      for k in 0..<alive.length() {
        if nodes[alive[k]] > nodes[alive[second]] {
          second = k
        }
      }
      let b = alive.remove(second)
      nodes.push(nodes[a] + nodes[b])
      kinds.push(LzhInner(a, b))
      alive.push(nodes.length() - 1)
    }
    let root = alive[0]
    let stack : Array[(Int, Int)] = [(root, 0)]
    let mut too_long = false
    while stack.length() > 0 {
      let pop = match stack.pop() {
        Some(pair) => pair
        None => break
      }
      let (i, d) = pop
      match kinds[i] {
        LzhLeaf(s) => {
          lens[s] = if d < 1 { 1 } else { d }
          if d > max {
            too_long = true
          }
        }
        LzhInner(a, b) => {
          stack.push((a, d + 1))
          stack.push((b, d + 1))
        }
      }
    }
    if !too_long {
      return lens
    }
    for i in 0..<f.length() {
      if f[i] > 0L {
        f[i] = (f[i] + 1L) >> 1
      }
    }
    lzh_code_rounds(f, used, lens, max)
}

///|
fn lzh_pos_code(d : Int) -> (Int, Int, Int) {
  // distance → (position symbol, extra bits value, extra bit count)
  if d == 0 {
    (0, 0, 0)
  } else {
    let nb = 32 - d.clz()
    let sym = nb
    if sym == 1 {
      (1, 0, 0)
    } else {
      (sym, d - (1 << (nb - 1)), nb - 1)
    }
  }
}

///|
fn lzh_compress(src : Bytes) -> Bytes raise {
  // tokens: literal byte or (c symbol, distance)
  let toks : Array[(Int, Int)] = []
  let head : Map[Int, Array[Int]] = Map::new()
  let mut i = 0
  while i < src.length() {
    let mut best = (0, 0)
    if i + 3 <= src.length() {
      let key = (src[i].to_int() << 16) | (src[i + 1].to_int() << 8) | src[i + 2].to_int()
      let list = head.get(key)
      if list is Some(list) {
        let mut k = list.length()
        let mut seen = 0
        while k > 0 && seen < 64 {
          k -= 1
          let j = list[k]
          if i - j > WINDOW - 1 {
            break
          }
          let mut l = 0
          while l < 256 && i + l < src.length() && src[j + l] == src[i + l] {
            l += 1
          }
          if l > best.0 {
            best = (l, i - j)
            if l == 256 {
              break
            }
          }
          seen += 1
        }
      }
    }
    let step = if best.0 >= 3 {
      // the token keeps distance - 1
      toks.push((best.0 - 3 + 256, best.1 - 1))
      best.0
    } else {
      toks.push((src[i].to_int(), 0))
      1
    }
    let upto = (i + step).min(src.length().max(2) - 2)
    for k in i..<upto {
      let key = (src[k].to_int() << 16) | (src[k + 1].to_int() << 8) | src[k + 2].to_int()
      let list = head.get(key)
      let target = match list {
        Some(v) => v
        None => {
          let fresh : Array[Int] = []
          head[key] = fresh
          fresh
        }
      }
      target.push(k)
    }
    i += step
  }
  let w : BitWriter = { out: [], acc: 0, n: 0 }
  let mut at = 0
  while at < toks.length() {
    let stop = (at + 0xffff).min(toks.length())
    let block : Array[(Int, Int)] = []
    for k in at..<stop {
      block.push(toks[k])
    }
    lzh_write_block(w, block)
    at = stop
  }
  w.finish()
}

///|
fn lzh_write_pt(w : BitWriter, lens : Array[Int], nbit : Int, special : Int?) -> Unit {
  let mut n = 0
  for i in 0..<lens.length() {
    if lens[i] > 0 {
      n = i + 1
    }
  }
  match special {
    Some(sp) => if n < sp {
      n = sp
    }
    None => ()
  }
  w.put(n, nbit)
  let mut i = 0
  while i < n {
    let c = lens[i]
    if c < 7 {
      w.put(c, 3)
    } else {
      w.put(7, 3)
      for _ in 7..<c {
        w.put(1, 1)
      }
      w.put(0, 1)
    }
    i += 1
    match special {
      Some(sp) =>
        if i == sp {
          let mut z = 0
          while z < 3 && i + z < n && lens[i + z] == 0 {
            z += 1
          }
          w.put(z, 2)
          i += z
        }
      None => ()
    }
  }
}

///|
fn lzh_write_block(w : BitWriter, toks : Array[(Int, Int)]) -> Unit raise {
  let cf : Array[Int] = Array::make(NC, 0)
  let pf : Array[Int] = Array::make(NP, 0)
  for t in toks {
    let (c, d) = t
    cf[c] += 1
    if c >= 256 {
      let ps = lzh_pos_code(d).0
      pf[ps] += 1
    }
  }
  let clen = lzh_code_lengths(cf, 16)
  let plen = lzh_code_lengths(pf, 16)
  let mut csingle_count = 0
  for x in cf {
    if x > 0 {
      csingle_count += 1
    }
  }
  let csingle = csingle_count == 1
  let mut psingle_count = 0
  for x in pf {
    if x > 0 {
      psingle_count += 1
    }
  }
  let psingle = psingle_count <= 1
  // run-length coding of the c lengths with the pt alphabet
  let tsyms : Array[(Int, Int, Int)] = [] // (symbol, extra, extra bits)
  let mut n = 0
  for k in 0..<NC {
    if clen[k] > 0 {
      n = k + 1
    }
  }
  let n = if csingle { 0 } else { n }
  let mut i = 0
  while i < n {
    if clen[i] == 0 {
      let mut run = 0
      while i + run < n && clen[i + run] == 0 {
        run += 1
      }
      let mut left = run
      while left > 0 {
        if left <= 2 {
          tsyms.push((0, 0, 0))
          left -= 1
        } else if left <= 18 {
          tsyms.push((1, left - 3, 4))
          left = 0
        } else if left == 19 {
          tsyms.push((0, 0, 0))
          left -= 1
        } else {
          let k = left.min(20 + 511)
          tsyms.push((2, k - 20, CBIT))
          left -= k
        }
      }
      i += run
    } else {
      tsyms.push((clen[i] + 2, 0, 0))
      i += 1
    }
  }
  let tf : Array[Int] = Array::make(NT, 0)
  for t in tsyms {
    let (s, _, _) = t
    tf[s] += 1
  }
  let tlen = lzh_code_lengths(tf, 16)
  let mut tsingle_count = 0
  for x in tf {
    if x > 0 {
      tsingle_count += 1
    }
  }
  let tsingle = tsingle_count <= 1

  w.put(toks.length(), 16)
  // pt table for c lengths
  if csingle || tsingle {
    w.put(0, TBIT)
    let s = match tsyms.get(0) {
      Some(t) => t.0
      None => 0
    }
    w.put(s, TBIT)
  } else {
    lzh_write_pt(w, tlen, TBIT, Some(3))
  }
  // c lengths
  if csingle {
    w.put(0, CBIT)
    let mut s = 0
    for k in 0..<NC {
      if cf[k] > 0 {
        s = k
        break
      }
    }
    w.put(s, CBIT)
  } else {
    w.put(n, CBIT)
    let tc = lzh_canonical(tlen)
    for t in tsyms {
      let (s, extra, nb) = t
      if !tsingle {
        let pair = tc[s]
        w.put(pair.0, pair.1)
      }
      if nb > 0 {
        w.put(extra, nb)
      }
    }
  }
  // p lengths
  if psingle {
    w.put(0, PBITS)
    let mut s = 0
    for k in 0..<NP {
      if pf[k] > 0 {
        s = k
        break
      }
    }
    w.put(s, PBITS)
  } else {
    lzh_write_pt(w, plen, PBITS, None)
  }
  let cc = lzh_canonical(clen)
  let pc = lzh_canonical(plen)
  for t in toks {
    let (c, d) = t
    if !csingle {
      let pair = cc[c]
      w.put(pair.0, pair.1)
    }
    if c >= 256 {
      let ps = lzh_pos_code(d)
      if !psingle {
        let pair = pc[ps.0]
        w.put(pair.0, pair.1)
      }
      if ps.2 > 0 {
        w.put(ps.1, ps.2)
      }
    }
  }
}
