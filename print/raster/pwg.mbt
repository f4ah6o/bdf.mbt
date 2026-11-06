///|
// PWG Raster (PWG 5102.4): the page header and the compression of a row.
pub const HEADER_SIZE : Int = 1796
pub const SYNC : String = "RaS2"

pub const BLACK_1 : String = "black_1"
pub const SGRAY_1 : String = "sgray_1"
pub const SGRAY_8 : String = "sgray_8"
pub const SRGB_8 : String = "srgb_8"

///|
pub suberror RasterError {
  RasterError(String)
}

///|
pub(all) struct Page {
  width : Int
  height : Int
  xdpi : Int
  ydpi : Int
  typ : String
  page_width : Int
  page_height : Int
  page_size_name : String
  media_type : String
  media_color : String
  duplex : Bool
  tumble : Bool
  cross_feed : Int
  feed : Int
  copies : Int
  total_pages : Int
  quality : Int
  media_position : Int
}

///|
pub fn Page::new(width : Int, height : Int, xdpi : Int, ydpi : Int, typ : String) -> Page {
  {
    width,
    height,
    xdpi,
    ydpi,
    typ,
    page_width: 0,
    page_height: 0,
    page_size_name: "",
    media_type: "",
    media_color: "",
    duplex: false,
    tumble: false,
    cross_feed: 0,
    feed: 0,
    copies: 0,
    total_pages: 0,
    quality: 0,
    media_position: 0,
  }
}

///|
fn raster_layout(typ : String) -> (Int, Int, Int, Int)? {
  if typ == BLACK_1 {
    Some((3, 1, 1, 1))
  } else if typ == SGRAY_1 {
    Some((18, 1, 1, 1))
  } else if typ == SGRAY_8 {
    Some((18, 8, 8, 1))
  } else if typ == SRGB_8 {
    Some((19, 8, 24, 3))
  } else {
    None
  }
}

///|
fn header_u32(out : Array[Byte], offset : Int, value : Int) -> Unit {
  out[offset] = ((value >> 24) & 0xff).to_byte()
  out[offset + 1] = ((value >> 16) & 0xff).to_byte()
  out[offset + 2] = ((value >> 8) & 0xff).to_byte()
  out[offset + 3] = (value & 0xff).to_byte()
}

///|
fn header_string(
  out : Array[Byte],
  offset : Int,
  value : String,
) -> Unit raise RasterError {
  let bytes = @utf8.encode(value)
  if bytes.length() > 63 {
    raise RasterError("raster: \"" + value + "\" is longer than 63 bytes")
  }
  for i, byte in bytes {
    out[offset + i] = byte
  }
}

///|
/// The 1796-byte header of a PWG Raster page.
pub fn Page::header(self : Page) -> Bytes raise RasterError {
  let layout = raster_layout(self.typ)
  let (color_space, bits_per_color, bits_per_pixel, num_colors) = match layout {
    Some(value) => value
    None => raise RasterError("raster: no PWG Raster type \"" + self.typ + "\"")
  }
  if self.width <= 0 || self.height <= 0 || self.xdpi <= 0 || self.ydpi <= 0 {
    raise RasterError("raster: an empty page")
  }
  let out = Array::make(HEADER_SIZE, b'\x00')
  header_string(out, 0, "PwgRaster")
  header_string(out, 64, self.media_color)
  header_string(out, 128, self.media_type)
  header_string(out, 1732, self.page_size_name)
  let copies = if self.copies <= 0 { 1 } else { self.copies }
  let sign = fn(value : Int) -> Int { if value < 0 { -1 } else { 1 } }
  header_u32(out, 272, if self.duplex { 1 } else { 0 })
  header_u32(out, 276, self.xdpi)
  header_u32(out, 280, self.ydpi)
  header_u32(out, 324, self.media_position)
  header_u32(out, 340, copies)
  header_u32(out, 352, self.page_width)
  header_u32(out, 356, self.page_height)
  header_u32(out, 368, if self.tumble { 1 } else { 0 })
  header_u32(out, 372, self.width)
  header_u32(out, 376, self.height)
  header_u32(out, 384, bits_per_color)
  header_u32(out, 388, bits_per_pixel)
  header_u32(out, 392, (self.width * bits_per_pixel + 7) / 8)
  header_u32(out, 396, 0)
  header_u32(out, 400, color_space)
  header_u32(out, 420, num_colors)
  header_u32(out, 452, self.total_pages)
  header_u32(out, 456, sign(self.cross_feed))
  header_u32(out, 460, sign(self.feed))
  header_u32(out, 464, 0)
  header_u32(out, 468, 0)
  header_u32(out, 472, self.width)
  header_u32(out, 476, self.height)
  header_u32(out, 484, self.quality)
  Bytes::from_array(out)
}

///|
fn same_unit(line : Bytes, a : Int, b : Int, bpp : Int) -> Bool {
  let mut i = 0
  while i < bpp {
    if line[a * bpp + i] != line[b * bpp + i] {
      return false
    }
    i += 1
  }
  true
}

///|
/// Compress the pixels of one row as PWG 5102.4 §4.4 says: runs of a pixel
/// repeated, and literal pixels otherwise. bpp is the bytes of a pixel.
pub fn encode_line(line : Bytes, bpp : Int) -> Bytes raise RasterError {
  encode_line_repeat(line, bpp, b'\x00')
}

///|
/// Compress a row with the count of times the line before it repeats.
pub fn encode_line_repeat(
  line : Bytes,
  bpp : Int,
  repeat : Byte,
) -> Bytes raise RasterError {
  if bpp <= 0 || line.length() % bpp != 0 {
    raise RasterError("raster: the row does not hold whole pixels")
  }
  let units = line.length() / bpp
  let out : Array[Byte] = [repeat]
  let mut i = 0
  while i < units {
    let mut run = 1
    while i + run < units && run < 128 && same_unit(line, i, i + run, bpp) {
      run += 1
    }
    if run > 1 || i + run == units {
      out.push((run - 1).to_byte())
      for k in 0..<bpp {
        out.push(line[i * bpp + k])
      }
      i += run
      continue
    }
    let mut j = i + 1
    while j < units &&
      j - i < 128 &&
      !(j + 1 < units && same_unit(line, j, j + 1, bpp)) {
      j += 1
    }
    if j - i == 1 {
      out.push(b'\x00')
      for k in 0..<bpp {
        out.push(line[i * bpp + k])
      }
    } else {
      out.push((257 - (j - i)).to_byte())
      for k in (i * bpp)..<(j * bpp) {
        out.push(line[k])
      }
    }
    i = j
  }
  Bytes::from_array(out)
}
