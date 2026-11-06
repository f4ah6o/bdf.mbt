///|
// Apple Raster (image/urf): a 12-byte sync and a 32-byte page header.
pub const URF_SYNC : String = "UNIRAST\x00"
pub const URF_HEADER_SIZE : Int = 32

const URF_SGRAY : Int = 0
const URF_SRGB : Int = 1
const URF_ONE_SIDED : Int = 1
const URF_SHORT_EDGE : Int = 2
const URF_LONG_EDGE : Int = 3

///|
pub fn urf_header(page : Page) -> Bytes raise RasterError {
  if page.width <= 0 || page.height <= 0 || page.xdpi <= 0 {
    raise RasterError("raster: an empty page")
  }
  let out = Array::make(URF_HEADER_SIZE, b'\x00')
  if page.typ == SGRAY_8 {
    out[0] = 8
    out[1] = URF_SGRAY.to_byte()
  } else if page.typ == SRGB_8 {
    out[0] = 24
    out[1] = URF_SRGB.to_byte()
  } else {
    raise RasterError(
      "raster: Apple Raster has no type \"" + page.typ + "\" (sgray_8 or srgb_8)",
    )
  }
  out[2] = (if !page.duplex {
    URF_ONE_SIDED
  } else if page.tumble {
    URF_SHORT_EDGE
  } else {
    URF_LONG_EDGE
  }).to_byte()
  out[3] = Int::min(Int::max(page.quality, 0), 255).to_byte()
  out[5] = Int::min(Int::max(page.media_position, 0), 255).to_byte()
  header_u32(out, 12, page.width)
  header_u32(out, 16, page.height)
  header_u32(out, 20, page.xdpi)
  Bytes::from_array(out)
}

///|
/// Write an Apple Raster stream of pages pages.
pub fn Writer::new_urf(pages : Int) -> Writer {
  {
    ..Writer::new(),
    urf: true,
    urf_pages: pages,
  }
}

///|
/// Read an Apple Raster stream.
pub fn read_urf(data : Bytes) -> Array[RasterPage] raise RasterError {
  if data.length() < 12 || data[0] != b'U' || data[1] != b'N' || data[2] != b'I' ||
    data[3] != b'R' || data[4] != b'A' || data[5] != b'S' || data[6] != b'T' ||
    data[7] != b'\x00' {
    raise RasterError("raster: not an Apple Raster stream")
  }
  let count = raster_read_u32(data, 8)
  let pages : Array[RasterPage] = []
  let mut pos = 12
  while pages.length() < count {
    if pos + URF_HEADER_SIZE > data.length() {
      raise RasterError("raster: the Apple Raster page is cut")
    }
    let header = data[pos:pos + URF_HEADER_SIZE].to_bytes()
    pos += URF_HEADER_SIZE
    let bits = header[0].to_int()
    let color_space = header[1].to_int()
    let typ = if bits == 8 && color_space == URF_SGRAY {
      SGRAY_8
    } else if bits == 24 && color_space == URF_SRGB {
      SRGB_8
    } else {
      raise RasterError("raster: unknown Apple Raster colour")
    }
    let sides = header[2].to_int()
    let page : Page = {
      ..Page::new(
        raster_read_u32(header, 12),
        raster_read_u32(header, 16),
        raster_read_u32(header, 20),
        raster_read_u32(header, 20),
        typ,
      ),
      quality: header[3].to_int(),
      media_position: header[5].to_int(),
      duplex: sides == URF_SHORT_EDGE || sides == URF_LONG_EDGE,
      tumble: sides == URF_SHORT_EDGE,
      cross_feed: 1,
      feed: 1,
      copies: 1,
      total_pages: count,
    }
    if page.width <= 0 || page.height <= 0 {
      raise RasterError("raster: an empty Apple Raster page")
    }
    let line_size = (page.width * bits + 7) / 8
    let bpp = Int::max(bits / 8, 1)
    let rows : Array[Bytes] = []
    while rows.length() < page.height {
      if pos >= data.length() {
        raise RasterError("raster: the Apple Raster page is cut")
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
