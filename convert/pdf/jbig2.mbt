///|
// JBIG2 decoding for PDF image streams, ported from upstream
// converter/internal/jbig2. The stream is the sequential organisation without
// the file header, page 1, with the optional JBIG2Globals data whose segments
// must be processed first.
//
// It decodes generic regions (arithmetic templates 0 to 3 with typical
// prediction, and MMR), generic refinement regions, text regions with their
// symbol dictionaries (arithmetic or Huffman coded, with refinement and
// aggregation), halftone regions with their pattern dictionaries, custom
// Huffman tables and striped pages of initially unknown height.
//
// Extended templates and colour extensions (T.88 Amendments 2 and 3) are not
// supported: an extended generic template is rejected explicitly, and the
// colour extension segments PDF never uses are ignored.
priv struct PdfJbig2Page {
  mut bm : PdfJbig2Bitmap
  def_pixel : Int
  mut grow : Bool // height unknown: grown by stripes
}

///|
priv enum PdfJbig2Result {
  PdfJbig2ResultNone
  PdfJbig2ResultSymbolDict(PdfJbig2SymbolDict)
  PdfJbig2ResultPatternDict(PdfJbig2PatternDict)
  PdfJbig2ResultHuffTable(PdfJbig2HuffTable)
  PdfJbig2ResultBitmap(PdfJbig2Bitmap)
}

///|
// A processed segment and its result.
priv struct PdfJbig2Segment {
  header : PdfJbig2SegmentHeader
  mut result : PdfJbig2Result
}

///|
// The state of one decode call.
priv struct PdfJbig2Decoder {
  segments : Map[Int, PdfJbig2Segment]
  mut page : PdfJbig2Page?
  mut page_num : Int // page association of the page being decoded
  mut ended : Bool // end of page or end of file seen
  mut work : Int64
}

///|
fn PdfJbig2Decoder::new() -> PdfJbig2Decoder {
  { segments: {}, page: None, page_num: 0, ended: false, work: 0L }
}

///|
// Account for n units of work (roughly pixels) against the limit.
fn PdfJbig2Decoder::spend(
  self : PdfJbig2Decoder,
  n : Int64,
) -> Unit raise PdfStreamError {
  self.work += n
  if self.work > pdf_jbig2_max_work {
    raise InvalidStream("JBIG2 image too large or too complex")
  }
}

///|
// Allocate a white bitmap after checking its size against the limits.
fn PdfJbig2Decoder::new_bitmap(
  self : PdfJbig2Decoder,
  w : Int,
  h : Int,
) -> PdfJbig2Bitmap raise PdfStreamError {
  if w < 0 ||
    h < 0 ||
    w > pdf_jbig2_max_dimension ||
    h > pdf_jbig2_max_dimension ||
    w.to_int64() * h.to_int64() > pdf_jbig2_max_pixels.to_int64() {
    raise InvalidStream("JBIG2 bitmap size \{w}x\{h} out of range")
  }
  self.spend(w.to_int64() * h.to_int64() + 64L)
  pdf_jbig2_bitmap_new(w, h)
}

///|
// Process the segments of a stream.
fn PdfJbig2Decoder::run(
  self : PdfJbig2Decoder,
  data : Bytes,
  global : Bool,
) -> Unit raise PdfStreamError {
  let mut rest = data
  while rest.length() > 0 && !self.ended {
    let header = match pdf_jbig2_parse_segment_header(rest) {
      PdfJbig2HeaderTruncated => return // a cut-off header or trailing padding
      PdfJbig2HeaderOk(header) => header
    }
    rest = rest[header.size:].to_owned()
    let mut length = header.length
    if header.length == pdf_jbig2_unknown_length {
      // Only immediate generic regions may have an unknown length. Some
      // encoders mark the last segment this way, so take the rest.
      length = rest.length()
      let mut found = false
      if pdf_jbig2_is_generic(header.typ) {
        let (found_length, is_found) = pdf_jbig2_generic_region_length(rest)
        if is_found {
          length = found_length
        }
        found = is_found
      }
      if !found {
        header.length = length
      }
    }
    if length < 0 {
      raise InvalidStream("invalid JBIG2 segment length")
    }
    if length > rest.length() {
      length = rest.length() // truncated stream: decode what there is
    }
    let body = rest[:length].to_owned()
    rest = rest[length:].to_owned()
    self.segment({ header, result: PdfJbig2ResultNone }, body, global)
  }
}

///|
// Process one segment.
fn PdfJbig2Decoder::segment(
  self : PdfJbig2Decoder,
  s : PdfJbig2Segment,
  data : Bytes,
  global : Bool,
) -> Unit raise PdfStreamError {
  if !global &&
    s.header.page != 0 &&
    self.page_num != 0 &&
    s.header.page != self.page_num {
    if s.header.typ == pdf_jbig2_type_page_info {
      self.ended = true // the next page begins
    }
    return
  }
  let typ = s.header.typ
  if typ == pdf_jbig2_type_symbol_dict {
    self.symbol_dict_segment(s, data)
  } else if typ == pdf_jbig2_type_intermediate_text ||
    typ == pdf_jbig2_type_immediate_text ||
    typ == pdf_jbig2_type_immediate_lossless_text {
    self.text_region_segment(s, data)
  } else if typ == pdf_jbig2_type_pattern_dict {
    self.pattern_dict_segment(s, data)
  } else if typ == pdf_jbig2_type_intermediate_halftone ||
    typ == pdf_jbig2_type_immediate_halftone ||
    typ == pdf_jbig2_type_immediate_lossless_halftone {
    self.halftone_region_segment(s, data)
  } else if typ == pdf_jbig2_type_intermediate_generic ||
    typ == pdf_jbig2_type_immediate_generic ||
    typ == pdf_jbig2_type_immediate_lossless_generic {
    pdf_jbig2_generic_region_segment(self, s, data)
  } else if typ == pdf_jbig2_type_intermediate_refinement ||
    typ == pdf_jbig2_type_immediate_refinement ||
    typ == pdf_jbig2_type_immediate_lossless_refinement {
    self.refinement_region_segment(s, data)
  } else if typ == pdf_jbig2_type_page_info {
    self.page_info_segment(s, data)
  } else if typ == pdf_jbig2_type_end_of_page ||
    typ == pdf_jbig2_type_end_of_file {
    self.ended = true
  } else if typ == pdf_jbig2_type_end_of_stripe {
    self.end_of_stripe_segment(data)
  } else if typ == pdf_jbig2_type_tables {
    s.result = PdfJbig2ResultHuffTable(pdf_jbig2_parse_table_segment(data))
  } // profiles, extensions and unused segment types carry no image data
  self.segments[s.header.number] = s
}

///|
// The results of the segments s refers to.
fn PdfJbig2Decoder::referred(
  self : PdfJbig2Decoder,
  s : PdfJbig2Segment,
) -> Array[PdfJbig2Result] {
  let out : Array[PdfJbig2Result] = []
  for n in s.header.refs {
    match self.segments.get(n) {
      Some(segment) =>
        match segment.result {
          PdfJbig2ResultNone => ()
          _ => out.push(segment.result)
        }
      None => ()
    }
  }
  out
}

///|
// Start the page (7.4.8).
fn PdfJbig2Decoder::page_info_segment(
  self : PdfJbig2Decoder,
  s : PdfJbig2Segment,
  data : Bytes,
) -> Unit raise PdfStreamError {
  if self.page is Some(_) {
    self.ended = true
    return
  }
  let r = pdf_jbig2_reader_new(data)
  let w = r.u32()
  let h = r.u32()
  r.skip(8) // resolution
  let flags = r.u8()
  r.skip(2) // striping
  if r.err {
    raise InvalidStream("truncated JBIG2 page information segment")
  }
  let width = pdf_jbig2_dim(w)
  let def_pixel = (flags >> 2) & 1
  let page : PdfJbig2Page = {
    bm: pdf_jbig2_bitmap_new(0, 0),
    def_pixel,
    grow: false,
  }
  let mut height = 0
  if h == 0xffffffff {
    page.grow = true
  } else {
    height = pdf_jbig2_dim(h)
  }
  page.bm = self.new_bitmap(width, height)
  page.bm.fill(def_pixel)
  self.page = Some(page)
  self.page_num = s.header.page
}

///|
// Extend a page of unknown height to the stripe's end row (7.4.10).
fn PdfJbig2Decoder::end_of_stripe_segment(
  self : PdfJbig2Decoder,
  data : Bytes,
) -> Unit raise PdfStreamError {
  let r = pdf_jbig2_reader_new(data)
  let end = r.u32()
  if r.err {
    raise InvalidStream("truncated JBIG2 end of stripe segment")
  }
  match self.page {
    Some(page) =>
      if page.grow {
        self.grow_page(end.to_int64() + 1L)
      }
    None => ()
  }
}

///|
// Extend a page of unknown height to h rows.
fn PdfJbig2Decoder::grow_page(
  self : PdfJbig2Decoder,
  h : Int64,
) -> Unit raise PdfStreamError {
  let page = match self.page {
    Some(page) => page
    None => return
  }
  let bm = page.bm
  if h <= bm.height.to_int64() {
    return
  }
  if h > pdf_jbig2_max_dimension.to_int64() ||
    bm.width.to_int64() * h > pdf_jbig2_max_pixels.to_int64() {
    raise InvalidStream("JBIG2 page height \{h} out of range")
  }
  self.spend((h - bm.height.to_int64()) * bm.width.to_int64())
  let old = bm.data.length()
  let needed = h.to_int() * bm.stride
  while bm.data.length() < needed {
    bm.data.push(0)
  }
  if page.def_pixel != 0 {
    for i in old..<bm.data.length() {
      bm.data[i] = 0xff
    }
  }
  bm.height = h.to_int()
  bm.clear_padding()
}

///|
// Keep the bitmap of an intermediate region segment for later refinement, or
// draw the bitmap of an immediate one onto the page.
fn PdfJbig2Decoder::place_region(
  self : PdfJbig2Decoder,
  s : PdfJbig2Segment,
  bm : PdfJbig2Bitmap,
  ri : PdfJbig2RegionInfo,
) -> Unit raise PdfStreamError {
  if pdf_jbig2_is_intermediate(s.header.typ) {
    s.result = PdfJbig2ResultBitmap(bm)
    return
  }
  let page = match self.page {
    Some(page) => page
    None =>
      raise InvalidStream(
        "JBIG2 region segment \{s.header.number} before the page information",
      )
  }
  if page.grow {
    self.grow_page(ri.y.to_int64() + bm.height.to_int64())
  }
  self.draw(page.bm, bm, ri.x.to_int64(), ri.y.to_int64(), ri.op)
}

///|
// Combine src into dst at (x, y), accounting for the work.
fn PdfJbig2Decoder::draw(
  self : PdfJbig2Decoder,
  dst : PdfJbig2Bitmap,
  src : PdfJbig2Bitmap,
  x : Int64,
  y : Int64,
  op : Int,
) -> Unit raise PdfStreamError {
  self.spend(src.width.to_int64() * src.height.to_int64() / 4L + 64L)
  dst.compose(src, pdf_jbig2_clamp_coord(x), pdf_jbig2_clamp_coord(y), op)
}

///|
// Limit a coordinate to a range in which any bitmap placed there either lies
// partly on the page or lies clear off it, without overflow.
fn pdf_jbig2_clamp_coord(v : Int64) -> Int {
  let lim = 1073741824L
  if v < -lim {
    -1073741824
  } else if v > lim {
    1073741824
  } else {
    v.to_int()
  }
}

///|
// The number of bits needed to number n values.
fn pdf_jbig2_ceil_log2(n : Int) -> Int {
  let mut b = 0
  while b < 31 && (1 << b) < n {
    b += 1
  }
  b
}

///|
fn pdf_jbig2_decode_with_globals(
  data : Bytes,
  globals : Bytes,
) -> (Int32, Int32, Bytes) raise PdfStreamError {
  let d = PdfJbig2Decoder::new()
  if globals.length() > 0 {
    d.run(globals, true)
  }
  d.ended = false
  // A few encoders write the 9-byte file header in the PDF stream even though
  // the embedded organisation omits it.
  let body = if data.length() >= 9 &&
    data[0] == b'\x97' &&
    data[1] == b'J' &&
    data[2] == b'B' &&
    data[3] == b'2' {
    data[9:].to_owned()
  } else {
    data
  }
  d.run(body, false)
  match d.page {
    None => raise InvalidStream("JBIG2 stream has no page information segment")
    Some(page) => {
      if page.bm.width == 0 || page.bm.height == 0 {
        raise InvalidStream("empty JBIG2 page")
      }
      (page.bm.width, page.bm.height, Bytes::from_array(page.bm.data))
    }
  }
}

///|
fn pdf_jbig2_decode(data : Bytes) -> (Int32, Int32, Bytes) raise PdfStreamError {
  pdf_jbig2_decode_with_globals(data, b"")
}

///|
fn pdf_jbig2_rgb(
  data : Bytes,
  invert : Bool,
) -> (Int32, Int32, Bytes) raise PdfStreamError {
  pdf_jbig2_rgb_with_globals(data, invert, b"")
}

///|
fn pdf_jbig2_rgb_with_globals(
  data : Bytes,
  invert : Bool,
  globals : Bytes,
) -> (Int32, Int32, Bytes) raise PdfStreamError {
  let (width, height, bits) = pdf_jbig2_decode_with_globals(data, globals)
  let rgb = pdf_ccitt_rgb(width, height, bits, true, invert)
  (width, height, rgb)
}

///|
fn pdf_jbig2_filter_index(filters : Array[PdfStreamFilter]) -> Int {
  for i, filter in filters {
    if filter.name == b"JBIG2Decode" {
      return i
    }
  }
  -1
}

///|
// The JBIG2Globals data of an image stream, empty when the stream has none.
fn pdf_jbig2_globals(
  file : PdfFile,
  dict : PdfObject,
) -> Bytes raise PdfStreamError {
  let filters = file.resolved_stream_filters(dict)
  let index = pdf_jbig2_filter_index(filters)
  if index < 0 {
    return b""
  }
  // Keep the JBIG2Globals reference unresolved: it names a stream object,
  // which only the reference can identify.
  let resolved = file.page_deref(pdf_dict_get(dict, b"DecodeParms"))
  let options = match resolved {
    PdfArray(values) =>
      if index < values.length() {
        file.page_deref(Some(values[index]))
      } else {
        PdfNull
      }
    PdfDict(_) => resolved
    _ => PdfNull
  }
  let globals = match pdf_dict_get(options, b"JBIG2Globals") {
    Some(PdfRef(number, _)) => {
      let loaded = file.load(number, 0)
      match loaded.stream {
        Some(raw) => {
          let (data, codec) = pdf_decode_stream(
            raw,
            file.resolved_stream_filters(loaded.value),
            1073741824L,
            false,
            1073741824L,
          )
          match codec {
            Some(_) =>
              raise InvalidStream("JBIG2 globals stream has an image filter")
            None => data
          }
        }
        None => raise InvalidStream("JBIG2 globals is not a stream")
      }
    }
    Some(PdfNull) | None => b""
    _ => raise InvalidStream("invalid JBIG2Globals entry")
  }
  globals
}
