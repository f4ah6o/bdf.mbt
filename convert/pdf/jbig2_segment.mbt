///|
// Segment headers, the region segment information field and the byte reader of
// T.88 7.2 to 7.4, ported from upstream converter/internal/jbig2/segment.go.
let pdf_jbig2_type_symbol_dict : Int = 0
let pdf_jbig2_type_intermediate_text : Int = 4
let pdf_jbig2_type_immediate_text : Int = 6
let pdf_jbig2_type_immediate_lossless_text : Int = 7
let pdf_jbig2_type_pattern_dict : Int = 16
let pdf_jbig2_type_intermediate_halftone : Int = 20
let pdf_jbig2_type_immediate_halftone : Int = 22
let pdf_jbig2_type_immediate_lossless_halftone : Int = 23
let pdf_jbig2_type_intermediate_generic : Int = 36
let pdf_jbig2_type_immediate_generic : Int = 38
let pdf_jbig2_type_immediate_lossless_generic : Int = 39
let pdf_jbig2_type_intermediate_refinement : Int = 40
let pdf_jbig2_type_immediate_refinement : Int = 42
let pdf_jbig2_type_immediate_lossless_refinement : Int = 43
let pdf_jbig2_type_page_info : Int = 48
let pdf_jbig2_type_end_of_page : Int = 49
let pdf_jbig2_type_end_of_stripe : Int = 50
let pdf_jbig2_type_end_of_file : Int = 51
let pdf_jbig2_type_tables : Int = 53

///|
// Limits on sizes taken from the data.
let pdf_jbig2_max_dimension : Int = 1 << 24
let pdf_jbig2_max_pixels : Int = 1 << 28
let pdf_jbig2_max_work : Int64 = 1073741824L
let pdf_jbig2_max_symbols : Int = 1 << 20

///|
// The data length of a segment whose end is found by scanning (7.2.7).
let pdf_jbig2_unknown_length : Int = 0xffffffff

///|
// The size of the region segment information field.
let pdf_jbig2_region_info_size : Int = 17

///|
fn pdf_jbig2_is_intermediate(typ : Int) -> Bool {
  typ == pdf_jbig2_type_intermediate_text ||
  typ == pdf_jbig2_type_intermediate_halftone ||
  typ == pdf_jbig2_type_intermediate_generic ||
  typ == pdf_jbig2_type_intermediate_refinement
}

///|
fn pdf_jbig2_is_generic(typ : Int) -> Bool {
  typ == pdf_jbig2_type_intermediate_generic ||
  typ == pdf_jbig2_type_immediate_generic ||
  typ == pdf_jbig2_type_immediate_lossless_generic
}

///|
// A pixel offset, such as an adaptive template pixel.
priv struct PdfJbig2Point {
  x : Int
  y : Int
}

///|
// A segment header (7.2).
priv struct PdfJbig2SegmentHeader {
  number : Int
  typ : Int
  page : Int // page association
  refs : Array[Int] // referred-to segments
  mut length : Int // data length, or pdf_jbig2_unknown_length
  size : Int // header size in bytes
}

///|
priv enum PdfJbig2HeaderResult {
  PdfJbig2HeaderTruncated
  PdfJbig2HeaderOk(PdfJbig2SegmentHeader)
}

///|
// Parse the segment header at the start of b and return it with its size.
fn pdf_jbig2_parse_segment_header(
  b : Bytes,
) -> PdfJbig2HeaderResult raise PdfStreamError {
  let r = pdf_jbig2_reader_new(b)
  let number = r.u32()
  let flags = r.u8()
  let typ = flags & 0x3f
  let mut count = r.u8() >> 5
  if count == 7 {
    r.pos -= 1
    let c = r.u32() & 0x1fffffff
    if c > b.length() {
      return PdfJbig2HeaderTruncated
    }
    count = c
    r.skip((count + 8) / 8) // retention flags
  } else if count > 4 {
    raise InvalidStream(
      "invalid JBIG2 referred-to segment count in segment \{number}",
    )
  }
  let size = if number < 0 || number > 65536 {
    4
  } else if number > 256 {
    2
  } else {
    1
  }
  if !r.err && count * size > b.length() - r.pos {
    return PdfJbig2HeaderTruncated
  }
  let refs : Array[Int] = []
  for _ in 0..<count {
    let value = match size {
      1 => r.u8()
      2 => r.u16()
      _ => r.u32()
    }
    refs.push(value)
  }
  let page = if (flags & 0x40) != 0 {
    r.u32()
  } else {
    r.u8()
  }
  let length = r.u32()
  if r.err {
    return PdfJbig2HeaderTruncated
  }
  PdfJbig2HeaderOk({ number, typ, page, refs, length, size: r.pos })
}

///|
// Find the end of an immediate generic region segment of unknown length
// (7.2.7): its coded data ends with 0xFF 0xAC (arithmetic) or 0x00 0x00 (MMR)
// followed by a 4-byte row count.
fn pdf_jbig2_generic_region_length(data : Bytes) -> (Int, Bool) {
  if data.length() < pdf_jbig2_region_info_size + 1 {
    return (0, false)
  }
  let flags = data[pdf_jbig2_region_info_size].to_int()
  let mut start = pdf_jbig2_region_info_size + 1
  let mut m0 = 0xff
  let mut m1 = 0xac
  if (flags & 1) != 0 {
    m0 = 0
    m1 = 0
  } else if ((flags >> 1) & 3) == 0 {
    start += 8
  } else {
    start += 2
  }
  let mut i = start
  while i + 6 <= data.length() {
    if data[i].to_int() == m0 && data[i + 1].to_int() == m1 {
      return (i + 6, true)
    }
    i += 1
  }
  (0, false)
}

///|
// The region segment information field (7.4.1).
priv struct PdfJbig2RegionInfo {
  w : Int
  h : Int
  x : Int
  y : Int
  op : Int // external combination operator
}

///|
fn pdf_jbig2_read_region_info(
  r : PdfJbig2Reader,
) -> PdfJbig2RegionInfo raise PdfStreamError {
  let w = r.u32()
  let h = r.u32()
  let x = r.u32()
  let y = r.u32()
  let op = r.u8() & 7
  if r.err {
    raise InvalidStream("truncated JBIG2 region segment information")
  }
  if op > pdf_jbig2_op_replace {
    raise InvalidStream("invalid JBIG2 combination operator \{op}")
  }
  { w, h, x, y, op }
}

///|
fn PdfJbig2RegionInfo::size(
  self : PdfJbig2RegionInfo,
) -> (Int, Int) raise PdfStreamError {
  (pdf_jbig2_dim(self.w), pdf_jbig2_dim(self.h))
}

///|
// Convert a width or height read from the data.
fn pdf_jbig2_dim(v : Int) -> Int raise PdfStreamError {
  if v > pdf_jbig2_max_dimension {
    raise InvalidStream("JBIG2 size \{v} out of range")
  }
  v
}

///|
// Read big-endian fields. Reading past the end sets err and yields zeros.
priv struct PdfJbig2Reader {
  data : Bytes
  mut pos : Int
  mut err : Bool
}

///|
fn pdf_jbig2_reader_new(data : Bytes) -> PdfJbig2Reader {
  { data, pos: 0, err: false }
}

///|
fn PdfJbig2Reader::need(self : PdfJbig2Reader, n : Int) -> Bool {
  if self.err || n > self.data.length() - self.pos {
    self.err = true
    false
  } else {
    true
  }
}

///|
fn PdfJbig2Reader::skip(self : PdfJbig2Reader, n : Int) -> Unit {
  if self.need(n) {
    self.pos += n
  }
}

///|
fn PdfJbig2Reader::u8(self : PdfJbig2Reader) -> Int {
  if !self.need(1) {
    return 0
  }
  self.pos += 1
  self.data[self.pos - 1].to_int()
}

///|
fn PdfJbig2Reader::i8(self : PdfJbig2Reader) -> Int {
  let v = self.u8()
  if v >= 0x80 {
    v - 0x100
  } else {
    v
  }
}

///|
fn PdfJbig2Reader::u16(self : PdfJbig2Reader) -> Int {
  if !self.need(2) {
    return 0
  }
  self.pos += 2
  (self.data[self.pos - 2].to_int() << 8) | self.data[self.pos - 1].to_int()
}

///|
fn PdfJbig2Reader::u32(self : PdfJbig2Reader) -> Int {
  if !self.need(4) {
    return 0
  }
  self.pos += 4
  (self.data[self.pos - 4].to_int() << 24) |
  (self.data[self.pos - 3].to_int() << 16) |
  (self.data[self.pos - 2].to_int() << 8) |
  self.data[self.pos - 1].to_int()
}

///|
fn PdfJbig2Reader::i32(self : PdfJbig2Reader) -> Int {
  let v = self.u32()
  if v >= 0x80000000 {
    (v.to_int64() - 4294967296L).to_int()
  } else {
    v
  }
}

///|
// Read n adaptive template pixels.
fn PdfJbig2Reader::at(
  self : PdfJbig2Reader,
  n : Int,
) -> Array[PdfJbig2Point] {
  let points : Array[PdfJbig2Point] = []
  for _ in 0..<n {
    let x = self.i8()
    let y = self.i8()
    points.push({ x, y })
  }
  points
}

///|
// The unread bytes.
fn PdfJbig2Reader::rest(self : PdfJbig2Reader) -> Bytes {
  if self.err {
    b""
  } else {
    self.data[self.pos:].to_owned()
  }
}
