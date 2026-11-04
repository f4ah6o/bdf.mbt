///|
// Halftone region and pattern dictionary decoding (T.88 6.6, 6.7), ported from
// upstream converter/internal/jbig2/halftone.go.
priv struct PdfJbig2PatternDict {
  patterns : Array[PdfJbig2Bitmap]
}

///|
// Decode a pattern dictionary segment (7.4.4, 6.7): a collective bitmap of
// GRAYMAX+1 patterns side by side.
fn PdfJbig2Decoder::pattern_dict_segment(
  self : PdfJbig2Decoder,
  s : PdfJbig2Segment,
  data : Bytes,
) -> Unit raise PdfStreamError {
  let r = pdf_jbig2_reader_new(data)
  let flags = r.u8()
  let pw = r.u8()
  let ph = r.u8()
  let gray_max = r.u32()
  let body = r.rest()
  if r.err {
    raise InvalidStream("truncated JBIG2 pattern dictionary segment")
  }
  if pw == 0 || ph == 0 || gray_max < 0 {
    raise InvalidStream("invalid JBIG2 patterns")
  }
  let gray_max = gray_max.to_int64()
  let n = gray_max + 1L
  if n * pw.to_int64() > pdf_jbig2_max_dimension.to_int64() {
    raise InvalidStream("too many JBIG2 patterns")
  }
  let w = n.to_int() * pw
  let bm = if (flags & 1) != 0 {
    let (bm, _) = self.decode_mmr(body, w, ph)
    bm
  } else {
    let template = (flags >> 1) & 3
    let all : Array[PdfJbig2Point] = [
      { x: -pw, y: 0 },
      { x: -3, y: -1 },
      { x: 2, y: -2 },
      { x: -2, y: -2 },
    ]
    let at : Array[PdfJbig2Point] = []
    for i in 0..<pdf_jbig2_generic_templates[template].nominal.length() {
      at.push(all[i])
    }
    pdf_jbig2_decode_generic(
      self,
      pdf_jbig2_arith_new(body),
      pdf_jbig2_new_generic_stats(template),
      w,
      ph,
      { template, tpgdon: false, at, skip: None },
    )
  }
  let patterns : Array[PdfJbig2Bitmap] = []
  for i in 0..<n.to_int() {
    patterns.push(bm.sub(i * pw, 0, pw, ph))
  }
  s.result = PdfJbig2ResultPatternDict({ patterns, })
}

///|
// A grid position (6.6.5.2) in 1/256 pixel.
fn pdf_jbig2_halftone_pos(
  mg : Int,
  ng : Int,
  gx : Int,
  gy : Int,
  rx : Int,
  ry : Int,
) -> (Int, Int) {
  ((gx + mg * ry + ng * rx) >> 8, (gy + mg * rx - ng * ry) >> 8)
}

///|
// Decode a halftone region segment (7.4.5, 6.6).
fn PdfJbig2Decoder::halftone_region_segment(
  self : PdfJbig2Decoder,
  s : PdfJbig2Segment,
  data : Bytes,
) -> Unit raise PdfStreamError {
  let r = pdf_jbig2_reader_new(data)
  let ri = pdf_jbig2_read_region_info(r)
  let flags = r.u8()
  let mmr = (flags & 1) != 0
  let template = (flags >> 1) & 3
  let enable_skip = (flags & 8) != 0
  let op = (flags >> 4) & 7
  let def_pixel = (flags >> 7) & 1
  let gw = r.u32()
  let gh = r.u32()
  let gx = r.i32()
  let gy = r.i32()
  let rx = r.u16()
  let ry = r.u16()
  let body = r.rest()
  if r.err {
    raise InvalidStream("truncated JBIG2 halftone region segment")
  }
  if op > pdf_jbig2_op_replace {
    raise InvalidStream("invalid JBIG2 combination operator \{op}")
  }
  let (w, h) = ri.size()
  let mut patterns : Array[PdfJbig2Bitmap] = []
  for value in self.referred(s) {
    match value {
      PdfJbig2ResultPatternDict(dict) => patterns = dict.patterns
      _ => ()
    }
  }
  if patterns.length() == 0 {
    raise InvalidStream(
      "JBIG2 halftone region \{s.header.number} without patterns",
    )
  }
  let grid_w = pdf_jbig2_dim(gw)
  let grid_h = pdf_jbig2_dim(gh)
  // Grid cells are normally as large as the patterns; more cells than twice
  // the region's pixels only draw over each other.
  let cells = grid_w.to_int64() * grid_h.to_int64()
  if cells > 2L * w.to_int64() * h.to_int64() + 65536L {
    raise InvalidStream("JBIG2 halftone grid too large")
  }
  let bm = self.new_bitmap(w, h)
  bm.fill(def_pixel)
  let pw = patterns[0].width
  let ph = patterns[0].height
  let skip = if enable_skip && !mmr {
    let sk = self.new_bitmap(grid_w, grid_h)
    for mg in 0..<grid_h {
      for ng in 0..<grid_w {
        let (x, y) = pdf_jbig2_halftone_pos(mg, ng, gx, gy, rx, ry)
        if x + pw <= 0 || x >= w || y + ph <= 0 || y >= h {
          sk.set(ng, mg)
        }
      }
    }
    Some(sk)
  } else {
    None
  }
  let planes = self.decode_gray_scale(
    body,
    grid_w,
    grid_h,
    pdf_jbig2_ceil_log2(patterns.length()),
    mmr,
    template,
    skip,
  )
  for mg in 0..<grid_h {
    self.spend(grid_w.to_int64() * (planes.length().to_int64() + 1L))
    for ng in 0..<grid_w {
      let (x, y) = pdf_jbig2_halftone_pos(mg, ng, gx, gy, rx, ry)
      if x + pw <= 0 || x >= w || y + ph <= 0 || y >= h {
        continue // off the region
      }
      let mut v = 0
      for j, plane in planes {
        v = v | (plane.pixel(ng, mg) << j)
      }
      let pattern = patterns[Int::min(v, patterns.length() - 1)]
      self.draw(bm, pattern, x.to_int64(), y.to_int64(), op)
    }
  }
  self.place_region(s, bm, ri)
}

///|
// Decode a gray-scale image as bits-per-pixel bitplanes, most significant
// first, each Gray coded against the one above (Annex C.5). It returns the
// planes with plane j holding bit j of the values.
fn PdfJbig2Decoder::decode_gray_scale(
  self : PdfJbig2Decoder,
  body : Bytes,
  w : Int,
  h : Int,
  bpp : Int,
  mmr : Bool,
  template : Int,
  skip : PdfJbig2Bitmap?,
) -> Array[PdfJbig2Bitmap] raise PdfStreamError {
  let planes : Array[PdfJbig2Bitmap] = Array::make(
    bpp,
    pdf_jbig2_bitmap_new(0, 0),
  )
  let mut ad : PdfJbig2Arith? = None
  let mut stats : Array[Int] = []
  let params_at : Array[PdfJbig2Point] = []
  if !mmr {
    ad = Some(pdf_jbig2_arith_new(body))
    stats = pdf_jbig2_new_generic_stats(template)
    let ax = if template >= 2 { 2 } else { 3 }
    let all : Array[PdfJbig2Point] = [
      { x: ax, y: -1 },
      { x: -3, y: -1 },
      { x: 2, y: -2 },
      { x: -2, y: -2 },
    ]
    for i in 0..<pdf_jbig2_generic_templates[template].nominal.length() {
      params_at.push(all[i])
    }
  }
  let mut rest = body
  for j0 in 0..<bpp {
    let j = bpp - 1 - j0
    if mmr {
      let (plane, used) = self.decode_mmr(rest, w, h)
      planes[j] = plane
      rest = rest[used:].to_owned()
    } else {
      let arith = match ad {
        Some(arith) => arith
        None => raise InvalidStream("missing JBIG2 arithmetic decoder")
      }
      planes[j] = pdf_jbig2_decode_generic(
        self,
        arith,
        stats,
        w,
        h,
        { template, tpgdon: false, at: params_at, skip },
      )
    }
    if j + 1 < bpp {
      let lower = planes[j].data
      let upper = planes[j + 1].data
      for i in 0..<lower.length() {
        lower[i] = (lower[i].to_int() ^ upper[i].to_int()).to_byte()
      }
    }
  }
  planes
}
