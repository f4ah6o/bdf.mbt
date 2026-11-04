///|
// Huffman coding of T.88 Annex B, ported from upstream
// converter/internal/jbig2/huffman.go. Data is packed most significant bit
// first.
priv struct PdfJbig2BitReader {
  data : Bytes
  mut pos : Int // in bits
}

///|
fn PdfJbig2BitReader::read_bit(self : PdfJbig2BitReader) -> Int raise PdfStreamError {
  let i = self.pos >> 3
  if i >= self.data.length() {
    raise InvalidStream("unexpected end of JBIG2 Huffman data")
  }
  let b = (self.data[i].to_int() >> (7 - (self.pos & 7))) & 1
  self.pos += 1
  b
}

///|
fn PdfJbig2BitReader::read_bits(
  self : PdfJbig2BitReader,
  n : Int,
) -> Int raise PdfStreamError {
  let mut v = 0
  for _ in 0..<n {
    v = (v << 1) | self.read_bit()
  }
  v
}

///|
fn PdfJbig2BitReader::align(self : PdfJbig2BitReader) -> Unit {
  self.pos = ((self.pos + 7) / 8) * 8
}

///|
fn PdfJbig2BitReader::bytes(
  self : PdfJbig2BitReader,
  n : Int,
) -> Bytes raise PdfStreamError {
  let i = self.pos >> 3
  if n < 0 || n > self.data.length() - i {
    raise InvalidStream("unexpected end of JBIG2 Huffman data")
  }
  self.pos += n << 3
  self.data[i:i + n].to_owned()
}

///|
// Kinds of Huffman table lines (B.2).
let pdf_jbig2_line_normal : Int = 0
let pdf_jbig2_line_lower : Int = 1
let pdf_jbig2_line_upper : Int = 2
let pdf_jbig2_line_oob : Int = 3

///|
// A line of a Huffman table: values low to low+2^range_len−1 are coded as a
// prefix of pref_len bits followed by range_len bits of offset.
priv struct PdfJbig2HuffLine {
  pref_len : Int
  range_len : Int
  low : Int
  kind : Int
}

///|
// A Huffman table with prefix codes assigned as in B.3.
priv struct PdfJbig2HuffTable {
  lines : Array[PdfJbig2HuffLine]
  count : Array[Int] // codes of each length
  sorted : Array[Int] // line indices by code length, in table order
  max_len : Int
}

///|
fn pdf_jbig2_new_huff_table(
  lines : Array[PdfJbig2HuffLine],
) -> PdfJbig2HuffTable {
  let count : Array[Int] = Array::make(33, 0)
  let mut max_len = 0
  for line in lines {
    if line.pref_len > 0 {
      count[line.pref_len] += 1
      if line.pref_len > max_len {
        max_len = line.pref_len
      }
    }
  }
  let start : Array[Int] = Array::make(34, 0)
  for n in 1..=32 {
    start[n + 1] = start[n] + count[n]
  }
  let sorted : Array[Int] = Array::make(start[33], 0)
  for i, line in lines {
    if line.pref_len > 0 {
      sorted[start[line.pref_len]] = i
      start[line.pref_len] += 1
    }
  }
  { lines, count, sorted, max_len }
}

///|
fn pdf_jbig2_huff_value(
  r : PdfJbig2BitReader,
  line : PdfJbig2HuffLine,
) -> (Int, Bool) raise PdfStreamError {
  if line.kind == pdf_jbig2_line_oob {
    return (0, false)
  }
  let off = r.read_bits(line.range_len)
  if off < 0 {
    raise InvalidStream("JBIG2 Huffman coded value out of range")
  }
  let mut v = line.low + off
  if line.kind == pdf_jbig2_line_lower {
    v = line.low - off
  }
  if v < -2147483647 || v > 2147483647 {
    raise InvalidStream("JBIG2 Huffman coded value out of range")
  }
  (v, true)
}

///|
// Decode a value; ok is false for the out-of-band value.
fn pdf_jbig2_huff_decode(
  table : PdfJbig2HuffTable,
  r : PdfJbig2BitReader,
) -> (Int, Bool) raise PdfStreamError {
  let mut code = 0
  let mut first = 0
  let mut index = 0
  for n in 1..=table.max_len {
    let b = r.read_bit()
    code = (code << 1) | b
    let c = table.count[n]
    if code >= first && code - first < c {
      return pdf_jbig2_huff_value(r, table.lines[table.sorted[index + code - first]])
    }
    index += c
    first = (first + c) << 1
  }
  raise InvalidStream("invalid JBIG2 Huffman code")
}

///|
// Standard Huffman tables B.1 to B.15 (index 1 to 15) as their lines of
// {prefix length, range length, range low}, with the lower range, upper range
// and out-of-band lines last.
fn pdf_jbig2_standard_sources() -> Array[Array[(Int, Int, Int)]] {
  [
    [],
    [(1, 4, 0), (2, 8, 16), (3, 16, 272), (3, 32, 65808)],
    [(1, 0, 0), (2, 0, 1), (3, 0, 2), (4, 3, 3), (5, 6, 11), (6, 32, 75), (6, 0, 0)],
    [
      (8, 8, -256), (1, 0, 0), (2, 0, 1), (3, 0, 2), (4, 3, 3), (5, 6, 11),
      (8, 32, -257), (7, 32, 75), (6, 0, 0),
    ],
    [(1, 0, 1), (2, 0, 2), (3, 0, 3), (4, 3, 4), (5, 6, 12), (5, 32, 76)],
    [
      (7, 8, -255), (1, 0, 1), (2, 0, 2), (3, 0, 3), (4, 3, 4), (5, 6, 12),
      (7, 32, -256), (6, 32, 76),
    ],
    [
      (5, 10, -2048), (4, 9, -1024), (4, 8, -512), (4, 7, -256), (5, 6, -128),
      (5, 5, -64), (4, 5, -32), (2, 7, 0), (3, 7, 128), (3, 8, 256),
      (4, 9, 512), (4, 10, 1024), (6, 32, -2049), (6, 32, 2048),
    ],
    [
      (4, 9, -1024), (3, 8, -512), (4, 7, -256), (5, 6, -128), (5, 5, -64),
      (4, 5, -32), (4, 5, 0), (5, 5, 32), (5, 6, 64), (4, 7, 128),
      (3, 8, 256), (3, 9, 512), (3, 10, 1024), (5, 32, -1025), (5, 32, 2048),
    ],
    [
      (8, 3, -15), (9, 1, -7), (8, 1, -5), (9, 0, -3), (7, 0, -2), (4, 0, -1),
      (2, 1, 0), (5, 0, 2), (6, 0, 3), (3, 4, 4), (6, 1, 20), (4, 4, 22),
      (4, 5, 38), (5, 6, 70), (5, 7, 134), (6, 7, 262), (7, 8, 390),
      (6, 10, 646), (9, 32, -16), (9, 32, 1670), (2, 0, 0),
    ],
    [
      (8, 4, -31), (9, 2, -15), (8, 2, -11), (9, 1, -7), (7, 1, -5),
      (4, 1, -3), (3, 1, -1), (3, 1, 1), (5, 1, 3), (6, 1, 5), (3, 5, 7),
      (6, 2, 39), (4, 5, 43), (4, 6, 75), (5, 7, 139), (5, 8, 267),
      (6, 8, 523), (7, 9, 779), (6, 11, 1291), (9, 32, -32), (9, 32, 3339),
      (2, 0, 0),
    ],
    [
      (7, 4, -21), (8, 0, -5), (7, 0, -4), (5, 0, -3), (2, 2, -2), (5, 0, 2),
      (6, 0, 3), (7, 0, 4), (8, 0, 5), (2, 6, 6), (5, 5, 70), (6, 5, 102),
      (6, 6, 134), (6, 7, 198), (6, 8, 326), (6, 9, 582), (6, 10, 1094),
      (7, 11, 2118), (8, 32, -22), (8, 32, 4166), (2, 0, 0),
    ],
    [
      (1, 0, 1), (2, 1, 2), (4, 0, 4), (4, 1, 5), (5, 1, 7), (5, 2, 9),
      (6, 2, 13), (7, 2, 17), (7, 3, 21), (7, 4, 29), (7, 5, 45),
      (7, 6, 77), (7, 32, 141),
    ],
    [
      (1, 0, 1), (2, 0, 2), (3, 1, 3), (5, 0, 5), (5, 1, 6), (6, 1, 8),
      (7, 0, 10), (7, 1, 11), (7, 2, 13), (7, 3, 17), (7, 4, 25),
      (8, 5, 41), (8, 32, 73),
    ],
    [
      (1, 0, 1), (3, 0, 2), (4, 0, 3), (5, 0, 4), (4, 1, 5), (3, 3, 7),
      (6, 1, 15), (6, 2, 17), (6, 3, 21), (6, 4, 29), (6, 5, 45),
      (7, 6, 77), (7, 32, 141),
    ],
    [(3, 0, -2), (3, 0, -1), (1, 0, 0), (3, 0, 1), (3, 0, 2)],
    [
      (7, 4, -24), (6, 2, -8), (5, 1, -4), (4, 0, -2), (3, 0, -1), (1, 0, 0),
      (3, 0, 1), (4, 0, 2), (5, 1, 3), (6, 2, 5), (7, 4, 9), (7, 32, -25),
      (7, 32, 25),
    ],
  ]
}

///|
fn pdf_jbig2_build_standard_tables() -> Array[PdfJbig2HuffTable] {
  let sources = pdf_jbig2_standard_sources()
  let has_lower : Array[Bool] = [
    false, false, false, true, false, true, true, true, true, true, true,
    false, false, false, false, true,
  ]
  let has_oob : Array[Bool] = [
    false, false, true, true, false, false, false, false, true, true, true,
    false, false, false, false, false,
  ]
  let out : Array[PdfJbig2HuffTable] = []
  for i in 0..<16 {
    let src = sources[i]
    let n = src.length()
    let kinds : Array[Int] = Array::make(n, pdf_jbig2_line_normal)
    let mut m = n
    if i > 0 {
      if has_oob[i] {
        m -= 1
        kinds[m] = pdf_jbig2_line_oob
      }
      if i != 14 {
        kinds[m - 1] = pdf_jbig2_line_upper
        if has_lower[i] {
          kinds[m - 2] = pdf_jbig2_line_lower
        }
      }
    }
    let lines : Array[PdfJbig2HuffLine] = []
    for j, value in src {
      lines.push({
        pref_len: value.0,
        range_len: value.1,
        low: value.2,
        kind: kinds[j],
      })
    }
    out.push(pdf_jbig2_new_huff_table(lines))
  }
  out
}

///|
let pdf_jbig2_standard_tables : Array[PdfJbig2HuffTable] = pdf_jbig2_build_standard_tables()

///|
fn pdf_jbig2_standard_table(n : Int) -> PdfJbig2HuffTable {
  pdf_jbig2_standard_tables[n]
}

///|
// Pick standard or custom Huffman tables for a segment; custom tables come
// from the referred-to table segments in order.
priv struct PdfJbig2TableSelector {
  custom : Array[PdfJbig2HuffTable]
  mut next : Int
}

///|
// Return standard table std[sel], or the next custom table if sel is custom;
// std has 0 for invalid selections.
fn pdf_jbig2_table_pick(
  selector : PdfJbig2TableSelector,
  sel : Int,
  custom : Int,
  std : Array[Int],
) -> PdfJbig2HuffTable raise PdfStreamError {
  if sel == custom {
    if selector.next >= selector.custom.length() {
      raise InvalidStream("missing custom Huffman table in JBIG2 segment")
    }
    let table = selector.custom[selector.next]
    selector.next += 1
    return table
  }
  if sel < 0 || sel >= std.length() || std[sel] == 0 {
    raise InvalidStream("invalid Huffman table selection in JBIG2 segment")
  }
  pdf_jbig2_standard_table(std[sel])
}

///|
// Parse a code table segment (7.4.13, B.2).
fn pdf_jbig2_parse_table_segment(
  data : Bytes,
) -> PdfJbig2HuffTable raise PdfStreamError {
  let r = pdf_jbig2_reader_new(data)
  let flags = r.u8()
  let low = r.i32()
  let high = r.i32()
  if r.err {
    raise InvalidStream("truncated JBIG2 code table segment")
  }
  let ps = ((flags >> 1) & 7) + 1
  let rs = ((flags >> 4) & 7) + 1
  let br : PdfJbig2BitReader = { data: r.rest(), pos: 0 }
  let lines : Array[PdfJbig2HuffLine] = []
  let mut cur = low
  let mut failed = false
  while cur < high && !failed {
    let pref = br.read_bits(ps) catch {
      _ => {
        failed = true
        0
      }
    }
    let range = br.read_bits(rs) catch {
      _ => {
        failed = true
        0
      }
    }
    if failed {
      break
    }
    if range > 32 {
      raise InvalidStream("invalid JBIG2 code table range")
    }
    lines.push({
      pref_len: pref,
      range_len: range,
      low: cur,
      kind: pdf_jbig2_line_normal,
    })
    cur += 1 << range
  }
  let pref_lower = br.read_bits(ps) catch {
    _ => {
      failed = true
      0
    }
  }
  lines.push({
    pref_len: pref_lower,
    range_len: 32,
    low: low - 1,
    kind: pdf_jbig2_line_lower,
  })
  let pref_upper = br.read_bits(ps) catch {
    _ => {
      failed = true
      0
    }
  }
  lines.push({
    pref_len: pref_upper,
    range_len: 32,
    low: high,
    kind: pdf_jbig2_line_upper,
  })
  if (flags & 1) != 0 {
    let pref_oob = br.read_bits(ps) catch {
      _ => {
        failed = true
        0
      }
    }
    lines.push({ pref_len: pref_oob, range_len: 0, low: 0, kind: pdf_jbig2_line_oob })
  }
  if failed {
    raise InvalidStream("truncated JBIG2 code table segment")
  }
  pdf_jbig2_new_huff_table(lines)
}
