///|
// Generic region decoding (T.88 6.2.5), ported from upstream
// converter/internal/jbig2/generic.go.
// A window describes the pixels a row above the current one contributes to a
// context: pixels x+hi down to x+lo land at context bits shift upwards. A
// window with lo > hi is empty.
priv struct PdfJbig2Window {
  hi : Int
  lo : Int
  shift : Int
}

///|
fn PdfJbig2Window::mask(self : PdfJbig2Window) -> Int {
  (1 << (self.hi - self.lo + 1)) - 1
}

///|
fn PdfJbig2Window::start(
  self : PdfJbig2Window,
  data : Array[Byte],
  base : Int,
  width : Int,
) -> Int {
  let mut v = 0
  let mut k = self.lo
  while k <= self.hi {
    v = (v << 1) | pdf_jbig2_bit(data, base, width, k)
    k += 1
  }
  v
}

///|
// A generic region template (6.2.5.3) in the context bit order of the
// standard: the current row supplies bits 0 to cur−1 (x−1, x−2, ...), rows y−1
// and y−2 the windows rows, and the adaptive template (AT) pixels the bits at
// at_bits. When the AT pixels are at their nominal positions, the wider
// windows fast take them in instead.
priv struct PdfJbig2GenericTemplate {
  bits : Int
  cur : Int
  rows : Array[PdfJbig2Window]
  at_bits : Array[Int]
  nominal : Array[PdfJbig2Point]
  fast : Array[PdfJbig2Window]
  sltp : Int // the context of the typical prediction bit (6.2.5.7)
}

///|
let pdf_jbig2_generic_templates : Array[PdfJbig2GenericTemplate] = [
  {
    bits: 16,
    cur: 4,
    rows: [{ hi: 2, lo: -2, shift: 5 }, { hi: 1, lo: -1, shift: 12 }],
    at_bits: [4, 10, 11, 15],
    nominal: [{ x: 3, y: -1 }, { x: -3, y: -1 }, { x: 2, y: -2 }, { x: -2, y: -2 }],
    fast: [{ hi: 3, lo: -3, shift: 4 }, { hi: 2, lo: -2, shift: 11 }],
    sltp: 0x9b25,
  },
  {
    bits: 13,
    cur: 3,
    rows: [{ hi: 2, lo: -2, shift: 4 }, { hi: 2, lo: -1, shift: 9 }],
    at_bits: [3],
    nominal: [{ x: 3, y: -1 }],
    fast: [{ hi: 3, lo: -2, shift: 3 }, { hi: 2, lo: -1, shift: 9 }],
    sltp: 0x0795,
  },
  {
    bits: 10,
    cur: 2,
    rows: [{ hi: 1, lo: -2, shift: 3 }, { hi: 1, lo: -1, shift: 7 }],
    at_bits: [2],
    nominal: [{ x: 2, y: -1 }],
    fast: [{ hi: 2, lo: -2, shift: 2 }, { hi: 1, lo: -1, shift: 7 }],
    sltp: 0x00e5,
  },
  {
    bits: 10,
    cur: 4,
    rows: [{ hi: 1, lo: -3, shift: 5 }, { hi: 0, lo: 1, shift: 0 }],
    at_bits: [4],
    nominal: [{ x: 2, y: -1 }],
    fast: [{ hi: 2, lo: -3, shift: 4 }, { hi: 0, lo: 1, shift: 0 }],
    sltp: 0x0195,
  },
]

///|
// The parameters of the generic region decoding procedure.
priv struct PdfJbig2GenericParams {
  template : Int
  tpgdon : Bool
  at : Array[PdfJbig2Point] // as many AT pixels as the template has
  skip : PdfJbig2Bitmap? // pixels not to decode (USESKIP), or none
}

///|
fn pdf_jbig2_new_generic_stats(template : Int) -> Array[Int] {
  Array::make(1 << pdf_jbig2_generic_templates[template].bits, 0)
}

///|
// Decode a w×h bitmap with the arithmetic generic region decoding procedure
// (6.2.5). If the coded data runs out, the rows not yet decoded stay white.
fn pdf_jbig2_decode_generic(
  d : PdfJbig2Decoder,
  ad : PdfJbig2Arith,
  stats : Array[Int],
  w : Int,
  h : Int,
  p : PdfJbig2GenericParams,
) -> PdfJbig2Bitmap raise PdfStreamError {
  let bm = d.new_bitmap(w, h)
  let t = pdf_jbig2_generic_templates[p.template]
  let mut rows = t.rows
  let mut at_bits = t.at_bits
  let mut at = p.at
  let mut nominal = p.at.length() == t.nominal.length()
  if nominal {
    for i in 0..<t.nominal.length() {
      if p.at[i].x != t.nominal[i].x || p.at[i].y != t.nominal[i].y {
        nominal = false
      }
    }
  }
  if nominal {
    rows = t.fast
    at_bits = []
    at = []
  }
  let m0 = rows[0].mask()
  let m1 = rows[1].mask()
  let s0 = rows[0].shift
  let s1 = rows[1].shift
  let h0 = rows[0].hi + 1
  let h1 = rows[1].hi + 1
  let cm = (1 << t.cur) - 1
  let mut ltp = 0
  for y in 0..<h {
    if ad.exhausted() {
      break
    }
    if p.tpgdon {
      ltp = ltp ^ pdf_jbig2_arith_decode(ad, stats, t.sltp)
      if ltp != 0 {
        if y > 0 {
          bm.copy_row_from(y, y - 1)
        }
        continue
      }
    }
    let r1 = bm.row_base(y - 1)
    let r2 = bm.row_base(y - 2)
    let mut w1 = rows[0].start(bm.data, r1, w)
    let mut w2 = rows[1].start(bm.data, r2, w)
    let mut c = 0
    for x in 0..<w {
      let mut b = 0
      let skip = match p.skip {
        Some(skip) => skip.pixel(x, y) != 0
        None => false
      }
      if !skip {
        let mut cx = c | (w1 << s0) | (w2 << s1)
        for i in 0..<at.length() {
          cx = cx | (bm.pixel(x + at[i].x, y + at[i].y) << at_bits[i])
        }
        b = pdf_jbig2_arith_decode(ad, stats, cx)
        if b != 0 {
          bm.set(x, y)
        }
      }
      c = ((c << 1) | b) & cm
      w1 = ((w1 << 1) | pdf_jbig2_bit(bm.data, r1, w, x + h0)) & m0
      w2 = ((w2 << 1) | pdf_jbig2_bit(bm.data, r2, w, x + h1)) & m1
    }
  }
  bm
}

///|
// Decode a generic region segment (7.4.6).
fn pdf_jbig2_generic_region_segment(
  d : PdfJbig2Decoder,
  s : PdfJbig2Segment,
  data : Bytes,
) -> Unit raise PdfStreamError {
  let r = pdf_jbig2_reader_new(data)
  let mut ri = pdf_jbig2_read_region_info(r)
  let flags = r.u8()
  let mmr = (flags & 1) != 0
  let template = (flags >> 1) & 3
  let tpgdon = (flags & 8) != 0
  if (flags & 0x10) != 0 {
    raise InvalidStream(
      "extended generic region templates are not supported in JBIG2",
    )
  }
  let mut at : Array[PdfJbig2Point] = []
  if !mmr {
    at = r.at(pdf_jbig2_generic_templates[template].nominal.length())
  }
  let body = r.rest()
  if r.err {
    raise InvalidStream("jbig2: unexpected end of data")
  }
  if s.header.length == pdf_jbig2_unknown_length && data.length() >= 4 {
    // The data ends with the row count (7.2.7).
    let n = data.length()
    let rows = (data[n - 4].to_int() << 24) |
      (data[n - 3].to_int() << 16) |
      (data[n - 2].to_int() << 8) |
      data[n - 1].to_int()
    if rows > ri.h {
      raise InvalidStream(
        "JBIG2 generic region row count \{rows} exceeds its height",
      )
    }
    ri = { w: ri.w, h: rows, x: ri.x, y: ri.y, op: ri.op }
  }
  let (w, h) = ri.size()
  let bm = if mmr {
    let (bm, _) = d.decode_mmr(body, w, h)
    bm
  } else {
    pdf_jbig2_decode_generic(
      d,
      pdf_jbig2_arith_new(body),
      pdf_jbig2_new_generic_stats(template),
      w,
      h,
      { template, tpgdon, at, skip: None },
    )
  }
  d.place_region(s, bm, ri)
}
