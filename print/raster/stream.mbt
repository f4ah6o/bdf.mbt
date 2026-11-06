///|
/// The raster pages read from a stream.
pub(all) struct RasterPage {
  page : Page
  rows : Array[Bytes]
}

///|
fn raster_read_u32(data : Bytes, offset : Int) -> Int {
  ((data[offset].to_int() << 24) |
    (data[offset + 1].to_int() << 16) |
    (data[offset + 2].to_int() << 8) |
    data[offset + 3].to_int())
}

///|
fn raster_header_string(data : Bytes, offset : Int) -> String {
  let out = StringBuilder()
  let mut i = 0
  while i < 64 && data[offset + i] != b'\x00' {
    out.write_string(
      String::from_array([
        data[offset + i].to_int().to_char().unwrap_or('\u{fffd}'),
      ]),
    )
    i += 1
  }
  out.to_string()
}

///|
fn raster_type(color_space : Int, bits_per_pixel : Int) -> String? {
  if color_space == 3 && bits_per_pixel == 1 {
    Some(BLACK_1)
  } else if color_space == 18 && bits_per_pixel == 1 {
    Some(SGRAY_1)
  } else if color_space == 18 && bits_per_pixel == 8 {
    Some(SGRAY_8)
  } else if color_space == 19 && bits_per_pixel == 24 {
    Some(SRGB_8)
  } else {
    None
  }
}

///|
fn raster_parse_page(header : Bytes) -> Page raise RasterError {
  if header.length() < HEADER_SIZE {
    raise RasterError("raster: the page header is short")
  }
  let bits = raster_read_u32(header, 388)
  let typ = match raster_type(raster_read_u32(header, 400), bits) {
    Some(value) => value
    None => raise RasterError("raster: unknown page colour space")
  }
  {
    ..Page::new(
      raster_read_u32(header, 372),
      raster_read_u32(header, 376),
      raster_read_u32(header, 276),
      raster_read_u32(header, 280),
      typ,
    ),
    page_width: raster_read_u32(header, 352),
    page_height: raster_read_u32(header, 356),
    page_size_name: raster_header_string(header, 1732),
    media_type: raster_header_string(header, 128),
    media_color: raster_header_string(header, 64),
    duplex: raster_read_u32(header, 272) != 0,
    tumble: raster_read_u32(header, 368) != 0,
    cross_feed: if raster_read_u32(header, 456) == -1 { -1 } else { 1 },
    feed: if raster_read_u32(header, 460) == -1 { -1 } else { 1 },
    copies: raster_read_u32(header, 340),
    total_pages: raster_read_u32(header, 452),
    quality: raster_read_u32(header, 484),
    media_position: raster_read_u32(header, 324),
  }
}

///|
/// Write a PWG Raster stream from whole rows.
pub(all) struct Writer {
  out : Array[Byte]
  mut started : Bool
  mut page : Page?
  mut bpp : Int
  mut line_size : Int
  mut rows : Int
  mut held : Bool
  mut repeat : Int
  mut prev : Bytes
  mut urf : Bool
  mut urf_pages : Int
}

///|
pub fn Writer::new() -> Writer {
  {
    out: [],
    started: false,
    page: None,
    bpp: 1,
    line_size: 0,
    rows: 0,
    held: false,
    repeat: 0,
    prev: Bytes::new(0),
    urf: false,
    urf_pages: 0,
  }
}

///|
fn Writer::flush_line(self : Writer) -> Unit raise RasterError {
  if self.held {
    self.held = false
    let encoded = encode_line_repeat(self.prev, self.bpp, self.repeat.to_byte())
    for byte in encoded {
      self.out.push(byte)
    }
  }
}

///|
/// Start a page: write the stream sync (once) and the page header.
pub fn Writer::start_page(self : Writer, page : Page) -> Unit raise RasterError {
  match self.page {
    Some(current) =>
      if self.rows != current.height {
        raise RasterError(
          "raster: the rows do not fill the page: " +
          self.rows.to_string() +
          " of " +
          current.height.to_string(),
        )
      }
    None => ()
  }
  self.flush_line()
  if !self.started {
    self.started = true
    if self.urf {
      for byte in [b'U', b'N', b'I', b'R', b'A', b'S', b'T', b'\x00'] {
        self.out.push(byte)
      }
      let count = Array::make(4, b'\x00')
      header_u32(count, 0, self.urf_pages)
      for byte in count {
        self.out.push(byte)
      }
    } else {
      for byte in [b'R', b'a', b'S', b'2'] {
        self.out.push(byte)
      }
    }
  }
  let header = if self.urf { urf_header(page) } else { page.header() }
  for i in 0..<header.length() {
    self.out.push(header[i])
  }
  let layout = raster_layout(page.typ)
  let bits = match layout {
    Some((_, _, bpp, _)) => bpp
    None => raise RasterError("raster: unknown page type")
  }
  self.page = Some(page)
  self.bpp = Int::max(bits / 8, 1)
  self.line_size = (page.width * bits + 7) / 8
  self.rows = 0
  self.held = false
  self.repeat = 0
  self.prev = Bytes::new(0)
}

///|
/// Add a row of the page, as the page type lays it out.
pub fn Writer::write_row(self : Writer, row : Bytes) -> Unit raise RasterError {
  let page = match self.page {
    Some(value) => value
    None => raise RasterError("raster: a row before a page")
  }
  if row.length() != self.line_size {
    raise RasterError(
      "raster: a row of " +
      row.length().to_string() +
      " bytes for a page of " +
      self.line_size.to_string(),
    )
  }
  if self.rows >= page.height {
    raise RasterError("raster: the rows run past the page")
  }
  self.rows += 1
  if self.held && self.repeat < 255 && row.to_array() == self.prev.to_array() {
    self.repeat += 1
    return
  }
  self.flush_line()
  self.prev = row
  self.held = true
  self.repeat = 0
}

///|
/// End the stream and return its bytes.
pub fn Writer::close(self : Writer) -> Bytes raise RasterError {
  match self.page {
    Some(page) =>
      if self.rows != page.height {
        raise RasterError(
          "raster: the rows do not fill the page: " +
          self.rows.to_string() +
          " of " +
          page.height.to_string(),
        )
      }
    None => ()
  }
  self.flush_line()
  Bytes::from_array(self.out)
}

///|
fn raster_decode_line(
  data : Bytes,
  start : Int,
  line_size : Int,
  bpp : Int,
) -> (Bytes, Int) raise RasterError {
  let out : Array[Byte] = []
  let mut pos = start
  while out.length() < line_size {
    if pos >= data.length() {
      raise RasterError("raster: the row is cut")
    }
    let control = data[pos].to_int()
    pos += 1
    if control < 128 {
      let count = control + 1
      if pos + bpp > data.length() {
        raise RasterError("raster: the row is cut")
      }
      for _ in 0..<count {
        for k in 0..<bpp {
          out.push(data[pos + k])
        }
      }
      pos += bpp
    } else {
      let count = 257 - control
      if pos + count * bpp > data.length() {
        raise RasterError("raster: the row is cut")
      }
      for k in 0..<(count * bpp) {
        out.push(data[pos + k])
      }
      pos += count * bpp
    }
  }
  (Bytes::from_array(out), pos)
}

///|
/// Read a PWG Raster stream.
pub fn read(data : Bytes) -> Array[RasterPage] raise RasterError {
  if data.length() < 4 || data[0] != b'R' || data[1] != b'a' || data[2] != b'S' ||
    data[3] != b'2' {
    raise RasterError("raster: not a PWG Raster stream")
  }
  let pages : Array[RasterPage] = []
  let mut pos = 4
  while pos < data.length() {
    if pos + HEADER_SIZE > data.length() {
      raise RasterError("raster: the page header is cut")
    }
    let page = raster_parse_page(data[pos:pos + HEADER_SIZE].to_bytes())
    pos += HEADER_SIZE
    let layout = raster_layout(page.typ)
    let (bits, bpp) = match layout {
      Some((_, _, bpp, _)) => (bpp, Int::max(bpp / 8, 1))
      None => raise RasterError("raster: unknown page type")
    }
    let line_size = (page.width * bits + 7) / 8
    let rows : Array[Bytes] = []
    while rows.length() < page.height {
      if pos >= data.length() {
        raise RasterError("raster: the page is cut")
      }
      let repeat = data[pos].to_int()
      pos += 1
      let (line, next) = raster_decode_line(data, pos, line_size, bpp)
      pos = next
      rows.push(line)
      for _ in 0..<repeat {
        rows.push(line)
      }
    }
    pages.push({ page, rows })
  }
  pages
}
///|
/// Read a PWG Raster stream with bounds on its pages and pixels.
pub fn read_limited(
  data : Bytes,
  max_pages : Int,
  max_pixels : Int,
) -> Array[RasterPage] raise RasterError {
  let pages = read(data)
  if max_pages > 0 && pages.length() > max_pages {
    raise RasterError("raster: more pages than allowed")
  }
  let mut pixels = 0
  for page in pages {
    let page_pixels = page.page.width * page.page.height
    if page_pixels < 0 || pixels + page_pixels > max_pixels && max_pixels > 0 {
      raise RasterError("raster: more pixels than allowed")
    }
    pixels += page_pixels
  }
  pages
}

