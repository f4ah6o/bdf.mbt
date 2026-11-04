///|
// Text region decoding (T.88 6.4), ported from upstream
// converter/internal/jbig2/text.go.
// Reference corners of symbol instances (7.4.3.1.1).
let pdf_jbig2_corner_bottom_left : Int = 0
let pdf_jbig2_corner_top_left : Int = 1
let pdf_jbig2_corner_bottom_right : Int = 2
let pdf_jbig2_corner_top_right : Int = 3

///|
// The arithmetic integer contexts of the text region decoding procedure, which
// symbol dictionaries share for aggregation.
priv struct PdfJbig2TextContexts {
  iadt : Array[Int]
  iafs : Array[Int]
  iads : Array[Int]
  iait : Array[Int]
  iari : Array[Int]
  iardw : Array[Int]
  iardh : Array[Int]
  iardx : Array[Int]
  iardy : Array[Int]
  iaid : Array[Int]
}

///|
fn pdf_jbig2_new_text_contexts(code_len : Int) -> PdfJbig2TextContexts {
  {
    iadt: Array::make(512, 0),
    iafs: Array::make(512, 0),
    iads: Array::make(512, 0),
    iait: Array::make(512, 0),
    iari: Array::make(512, 0),
    iardw: Array::make(512, 0),
    iardh: Array::make(512, 0),
    iardx: Array::make(512, 0),
    iardy: Array::make(512, 0),
    iaid: Array::make(1 << code_len, 0),
  }
}

///|
// The parameters of the text region decoding procedure (6.4.2).
priv struct PdfJbig2TextParams {
  huff : Bool
  refine : Bool
  mut w : Int
  mut h : Int
  mut instances : Int
  log_strips : Int
  syms : Array[PdfJbig2Bitmap]
  mut code_len : Int // symbol ID code length
  mut codes : PdfJbig2HuffTable? // Huffman symbol ID codes; none for fixed-length codes
  def_pixel : Int
  op : Int
  transposed : Bool
  corner : Int
  mut ds_offset : Int
  // Huffman tables
  mut fs : PdfJbig2HuffTable?
  mut ds : PdfJbig2HuffTable?
  mut dt : PdfJbig2HuffTable?
  mut rdw : PdfJbig2HuffTable?
  mut rdh : PdfJbig2HuffTable?
  mut rdx : PdfJbig2HuffTable?
  mut rdy : PdfJbig2HuffTable?
  mut rsize : PdfJbig2HuffTable?
  // refinement
  rtemplate : Int
  mut rat : Array[PdfJbig2Point]
}

///|
// Reads the values of a text region from either coder.
priv struct PdfJbig2TextDecoder {
  mut ad : PdfJbig2Arith?
  mut br : PdfJbig2BitReader?
  cx : PdfJbig2TextContexts
  mut gr : Array[Int]? // refinement contexts
}

///|
fn pdf_jbig2_text_int(
  t : PdfJbig2TextDecoder,
  huff : PdfJbig2HuffTable?,
  cx : Array[Int]?,
) -> (Int, Bool) raise PdfStreamError {
  match t.br {
    Some(br) => {
      let table = match huff {
        Some(table) => table
        None => raise InvalidStream("missing JBIG2 Huffman table")
      }
      pdf_jbig2_huff_decode(table, br)
    }
    None => {
      let ad = match t.ad {
        Some(ad) => ad
        None => raise InvalidStream("missing JBIG2 arithmetic decoder")
      }
      let index = match cx {
        Some(cx) => cx
        None => raise InvalidStream("missing JBIG2 arithmetic context")
      }
      pdf_jbig2_arith_decode_int(ad, index)
    }
  }
}

///|
// Read an integer that may not be out of band.
fn pdf_jbig2_text_value(
  t : PdfJbig2TextDecoder,
  huff : PdfJbig2HuffTable?,
  cx : Array[Int]?,
) -> Int raise PdfStreamError {
  let (v, ok) = pdf_jbig2_text_int(t, huff, cx)
  if !ok {
    raise InvalidStream("unexpected out-of-band value in JBIG2 segment")
  }
  v
}

///|
fn pdf_jbig2_clamp_40(v : Int64) -> Int64 {
  let lim = 1099511627776L // 1 << 40
  if v < -lim {
    -lim
  } else if v > lim {
    lim
  } else {
    v
  }
}

///|
// Decode a text region (6.4.5). If the arithmetic coded data runs out, the
// instances decoded so far make up the region.
fn pdf_jbig2_decode_text(
  d : PdfJbig2Decoder,
  p : PdfJbig2TextParams,
  t : PdfJbig2TextDecoder,
) -> PdfJbig2Bitmap raise PdfStreamError {
  let bm = d.new_bitmap(p.w, p.h)
  if p.def_pixel != 0 {
    bm.fill(1)
  }
  let strips = 1 << p.log_strips
  let mut dt = pdf_jbig2_text_value(t, p.dt, Some(t.cx.iadt))
  let mut stript = -(dt.to_int64() * strips.to_int64())
  let mut firsts : Int64 = 0L
  let mut n = 0
  while n < p.instances {
    let exhausted = match t.ad {
      Some(ad) => ad.exhausted()
      None => false
    }
    if exhausted {
      return bm // the coded data ran out: keep what was drawn
    }
    dt = pdf_jbig2_text_value(t, p.dt, Some(t.cx.iadt))
    stript += dt.to_int64() * strips.to_int64()
    let mut first = true
    let mut curs : Int64 = 0L
    while true {
      if first {
        let dfs = pdf_jbig2_text_value(t, p.fs, Some(t.cx.iafs))
        firsts += dfs.to_int64()
        curs = firsts
        first = false
      } else {
        let (ids, ok) = pdf_jbig2_text_int(t, p.ds, Some(t.cx.iads))
        if !ok {
          break // the end of the strip
        }
        if n >= p.instances {
          return bm // more instances than announced
        }
        curs += ids.to_int64() + p.ds_offset.to_int64()
      }
      let mut curt : Int64 = 0L
      if strips > 1 {
        match t.br {
          Some(br) => curt = br.read_bits(p.log_strips).to_int64()
          None => curt = pdf_jbig2_text_value(t, None, Some(t.cx.iait)).to_int64()
        }
      }
      let ti = stript + curt
      let exhausted = match t.ad {
        Some(ad) => ad.exhausted()
        None => false
      }
      if exhausted {
        return bm
      }
      let ib = pdf_jbig2_text_symbol(d, p, t)
      let w = ib.width.to_int64()
      let h = ib.height.to_int64()
      if !p.transposed &&
        (p.corner == pdf_jbig2_corner_top_right ||
          p.corner == pdf_jbig2_corner_bottom_right) {
        curs += w - 1L
      } else if p.transposed &&
        (p.corner == pdf_jbig2_corner_bottom_left ||
          p.corner == pdf_jbig2_corner_bottom_right) {
        curs += h - 1L
      }
      let mut x = curs
      let mut y = ti
      if p.transposed {
        x = ti
        y = curs
      }
      if p.corner == pdf_jbig2_corner_top_right ||
        p.corner == pdf_jbig2_corner_bottom_right {
        x -= w - 1L
      }
      if p.corner == pdf_jbig2_corner_bottom_left ||
        p.corner == pdf_jbig2_corner_bottom_right {
        y -= h - 1L
      }
      d.draw(bm, ib, x, y, p.op)
      if !p.transposed &&
        (p.corner == pdf_jbig2_corner_top_left ||
          p.corner == pdf_jbig2_corner_bottom_left) {
        curs += w - 1L
      } else if p.transposed &&
        (p.corner == pdf_jbig2_corner_top_left ||
          p.corner == pdf_jbig2_corner_top_right) {
        curs += h - 1L
      }
      curs = pdf_jbig2_clamp_40(curs)
      n += 1
    }
    firsts = pdf_jbig2_clamp_40(firsts)
    stript = pdf_jbig2_clamp_40(stript)
  }
  bm
}

///|
// Decode the symbol ID of an instance and, if it is refined, the refinement,
// returning the instance's bitmap (6.4.10, 6.4.11).
fn pdf_jbig2_text_symbol(
  d : PdfJbig2Decoder,
  p : PdfJbig2TextParams,
  t : PdfJbig2TextDecoder,
) -> PdfJbig2Bitmap raise PdfStreamError {
  let mut id = 0
  let mut ad = match t.ad {
    Some(ad) => ad
    None => pdf_jbig2_arith_new(b"")
  }
  match t.br {
    None => {
      let a = match t.ad {
        Some(ad) => ad
        None => raise InvalidStream("missing JBIG2 arithmetic decoder")
      }
      id = pdf_jbig2_arith_decode_iaid(a, t.cx.iaid, p.code_len)
    }
    Some(br) =>
      match p.codes {
        Some(codes) => id = pdf_jbig2_text_value(t, Some(codes), None)
        None => id = br.read_bits(p.code_len)
      }
  }
  if id < 0 || id >= p.syms.length() {
    raise InvalidStream("invalid JBIG2 symbol ID \{id}")
  }
  let sym = p.syms[id]
  if !p.refine {
    return sym
  }
  let mut ri = 0
  match t.br {
    Some(br) => ri = br.read_bit()
    None => ri = pdf_jbig2_text_value(t, None, Some(t.cx.iari))
  }
  if ri == 0 {
    return sym
  }
  d.spend(64L)
  let rdw = pdf_jbig2_text_value(t, p.rdw, Some(t.cx.iardw))
  let rdh = pdf_jbig2_text_value(t, p.rdh, Some(t.cx.iardh))
  let rdx = pdf_jbig2_text_value(t, p.rdx, Some(t.cx.iardx))
  let rdy = pdf_jbig2_text_value(t, p.rdy, Some(t.cx.iardy))
  match t.br {
    Some(br) => {
      let size = pdf_jbig2_text_value(t, p.rsize, None)
      br.align()
      let data = br.bytes(size)
      ad = pdf_jbig2_arith_new(data)
    }
    None => ()
  }
  let w = sym.width + rdw
  let h = sym.height + rdh
  if w < 0 || h < 0 || w > pdf_jbig2_max_dimension || h > pdf_jbig2_max_dimension {
    raise InvalidStream("JBIG2 refined symbol size out of range")
  }
  let gr = match t.gr {
    Some(gr) => gr
    None => raise InvalidStream("missing JBIG2 refinement contexts")
  }
  pdf_jbig2_decode_refinement(ad, gr, w, h, {
    template: p.rtemplate,
    at: p.rat,
    reference: sym,
    dx: pdf_jbig2_clamp_coord((rdw >> 1).to_int64() + rdx.to_int64()),
    dy: pdf_jbig2_clamp_coord((rdh >> 1).to_int64() + rdy.to_int64()),
    tpgron: false,
  })
}

///|
// Read the Huffman table of symbol IDs of a text region (7.4.3.1.7): 35 run
// code lengths, then the code lengths of the n symbols coded with the run codes.
fn pdf_jbig2_read_symbol_id_table(
  br : PdfJbig2BitReader,
  n : Int,
) -> PdfJbig2HuffTable raise PdfStreamError {
  let run_lines : Array[PdfJbig2HuffLine] = []
  for i in 0..<35 {
    let v = br.read_bits(4)
    run_lines.push({
      pref_len: v,
      range_len: 0,
      low: i,
      kind: pdf_jbig2_line_normal,
    })
  }
  let run_codes = pdf_jbig2_new_huff_table(run_lines)
  let lengths : Array[Int] = Array::make(n, 0)
  let mut i = 0
  while i < n {
    let (c, _) = pdf_jbig2_huff_decode(run_codes, br)
    let mut length = c
    let mut repeat = 1
    if c == 32 {
      if i == 0 {
        raise InvalidStream("invalid JBIG2 symbol ID table")
      }
      let extra = br.read_bits(2)
      length = lengths[i - 1]
      repeat = 3 + extra
    } else if c == 33 {
      let extra = br.read_bits(3)
      length = 0
      repeat = 3 + extra
    } else if c == 34 {
      let extra = br.read_bits(7)
      length = 0
      repeat = 11 + extra
    }
    if repeat > n - i {
      raise InvalidStream("invalid JBIG2 symbol ID table")
    }
    while repeat > 0 {
      lengths[i] = length
      i += 1
      repeat -= 1
    }
  }
  br.align()
  let lines : Array[PdfJbig2HuffLine] = []
  for j in 0..<n {
    lines.push({
      pref_len: lengths[j],
      range_len: 0,
      low: j,
      kind: pdf_jbig2_line_normal,
    })
  }
  pdf_jbig2_new_huff_table(lines)
}

///|
// Decode a text region segment (7.4.3).
fn PdfJbig2Decoder::text_region_segment(
  self : PdfJbig2Decoder,
  s : PdfJbig2Segment,
  data : Bytes,
) -> Unit raise PdfStreamError {
  let r = pdf_jbig2_reader_new(data)
  let ri = pdf_jbig2_read_region_info(r)
  let flags = r.u16()
  let p : PdfJbig2TextParams = {
    huff: (flags & 1) != 0,
    refine: (flags & 2) != 0,
    log_strips: (flags >> 2) & 3,
    corner: (flags >> 4) & 3,
    transposed: (flags & 0x40) != 0,
    op: (flags >> 7) & 3,
    def_pixel: (flags >> 9) & 1,
    ds_offset: (flags >> 10) & 0x1f,
    rtemplate: (flags >> 15) & 1,
    w: 0,
    h: 0,
    instances: 0,
    syms: [],
    code_len: 0,
    codes: None,
    fs: None,
    ds: None,
    dt: None,
    rdw: None,
    rdh: None,
    rdx: None,
    rdy: None,
    rsize: None,
    rat: [],
  }
  if p.ds_offset >= 16 {
    p.ds_offset = p.ds_offset - 32
  }
  let mut huff_flags = 0
  if p.huff {
    huff_flags = r.u16()
  }
  if p.refine && p.rtemplate == 0 {
    p.rat = r.at(2)
  }
  p.instances = r.u32()
  if r.err {
    raise InvalidStream("truncated JBIG2 text region segment")
  }
  if p.instances < 0 {
    raise InvalidStream("invalid JBIG2 text instance count")
  }
  let (w, h) = ri.size()
  p.w = w
  p.h = h
  let selector : PdfJbig2TableSelector = { custom: [], next: 0 }
  for value in self.referred(s) {
    match value {
      PdfJbig2ResultSymbolDict(dict) => {
        for symbol in dict.exported {
          p.syms.push(symbol)
        }
        if p.syms.length() > pdf_jbig2_max_symbols {
          raise InvalidStream("too many JBIG2 symbols")
        }
      }
      PdfJbig2ResultHuffTable(table) => selector.custom.push(table)
      _ => ()
    }
  }
  if p.instances == 0 {
    let bm = self.new_bitmap(p.w, p.h)
    bm.fill(p.def_pixel)
    self.place_region(s, bm, ri)
    return
  }
  p.code_len = pdf_jbig2_ceil_log2(p.syms.length())
  let t : PdfJbig2TextDecoder = {
    ad: None,
    br: None,
    cx: pdf_jbig2_new_text_contexts(p.code_len),
    gr: None,
  }
  if p.refine {
    t.gr = Some(pdf_jbig2_new_refinement_stats(p.rtemplate))
  }
  if p.huff {
    p.fs = Some(pdf_jbig2_table_pick(selector, huff_flags & 3, 3, [6, 7]))
    p.ds = Some(
      pdf_jbig2_table_pick(selector, (huff_flags >> 2) & 3, 3, [8, 9, 10]),
    )
    p.dt = Some(
      pdf_jbig2_table_pick(selector, (huff_flags >> 4) & 3, 3, [11, 12, 13]),
    )
    p.rdw = Some(
      pdf_jbig2_table_pick(selector, (huff_flags >> 6) & 3, 3, [14, 15]),
    )
    p.rdh = Some(
      pdf_jbig2_table_pick(selector, (huff_flags >> 8) & 3, 3, [14, 15]),
    )
    p.rdx = Some(
      pdf_jbig2_table_pick(selector, (huff_flags >> 10) & 3, 3, [14, 15]),
    )
    p.rdy = Some(
      pdf_jbig2_table_pick(selector, (huff_flags >> 12) & 3, 3, [14, 15]),
    )
    p.rsize = Some(
      pdf_jbig2_table_pick(selector, (huff_flags >> 14) & 1, 1, [1]),
    )
    let br : PdfJbig2BitReader = { data: r.rest(), pos: 0 }
    t.br = Some(br)
    p.codes = Some(pdf_jbig2_read_symbol_id_table(br, p.syms.length()))
  } else {
    t.ad = Some(pdf_jbig2_arith_new(r.rest()))
  }
  let bm = pdf_jbig2_decode_text(self, p, t)
  self.place_region(s, bm, ri)
}
