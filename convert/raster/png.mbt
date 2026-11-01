///|
/// A raster conversion failure.
pub suberror RasterError {
  InvalidRaster(String)
}

///|
/// PNG signature, as every PNG file starts.
let raster_png_signature : Bytes = b"\x89PNG\r\n\x1a\n"

///|
fn raster_crc_table() -> FixedArray[UInt32] {
  let table : FixedArray[UInt32] = FixedArray::make(256, 0U)
  for i in 0..<256 {
    let mut c = i.to_uint()
    for _ in 0..<8 {
      c = if (c & 1U) != 0U { (c >> 1) ^ 0xedb88320U } else { c >> 1 }
    }
    table[i] = c
  }
  table
}

///|
let raster_crc : FixedArray[UInt32] = raster_crc_table()

///|
fn raster_crc_update(crc : UInt32, data : BytesView) -> UInt32 {
  let mut value = crc
  for byte in data {
    value = raster_crc[(value ^ byte.to_uint()).to_int() & 0xff] ^ (value >> 8)
  }
  value
}

///|
fn raster_write_chunk(out : @buffer.Buffer, kind : Bytes, data : Bytes) -> Unit {
  out.write_uint_be(data.length().to_uint())
  out.write_bytes(kind)
  out.write_bytes(data)
  let mut crc = 0xffffffffU
  crc = raster_crc_update(crc, kind)
  crc = raster_crc_update(crc, data)
  out.write_uint_be(crc ^ 0xffffffffU)
}

///|
/// Encode 8-bit RGBA pixels as a PNG with filter 0 scanlines.
///
/// The output is a valid PNG, but its bytes are not identical to the Go
/// standard library encoder upstream uses: only the decoded pixels are
/// compatible.
pub fn encode_png(
  width : Int32,
  height : Int32,
  rgba : Bytes,
) -> Bytes raise RasterError {
  if width <= 0 || height <= 0 {
    raise InvalidRaster("raster: the image has no size")
  }
  let pixels = width.to_int64() * height.to_int64()
  if pixels > 67108864L {
    raise InvalidRaster("raster: the image is larger than 67108864 pixels")
  }
  if rgba.length().to_int64() != pixels * 4L {
    raise InvalidRaster("raster: the RGBA buffer does not match the image size")
  }
  let raw = @buffer.Buffer()
  let mut offset = 0
  for _ in 0..<height {
    raw.write_byte(0)
    raw.write_bytes(rgba[offset:offset + width * 4])
    offset += width * 4
  }
  let compressed = @zlib.compress(raw.to_bytes(), level=6)
  let header = @buffer.Buffer()
  header.write_uint_be(width.to_uint())
  header.write_uint_be(height.to_uint())
  header.write_byte(8) // bit depth
  header.write_byte(6) // RGBA
  header.write_byte(0) // compression
  header.write_byte(0) // filter
  header.write_byte(0) // interlace
  let out = @buffer.Buffer()
  out.write_bytes(raster_png_signature)
  raster_write_chunk(out, b"IHDR", header.to_bytes())
  raster_write_chunk(out, b"IDAT", compressed)
  raster_write_chunk(out, b"IEND", b"")
  out.to_bytes()
}

///|
/// The decoded dimensions of a PNG, JPEG, GIF, BMP or ICO header.
///
/// Formats whose size is not needed by the converters (WebP, AVIF, SVG)
/// return `None`.
pub fn image_size(data : Bytes) -> (Int32, Int32)? {
  if data.length() >= 24 && data[:8] == raster_png_signature {
    return Some((raster_be32(data, 16), raster_be32(data, 20)))
  }
  if data.length() >= 10 &&
    (data[:6] == b"GIF87a"[:] || data[:6] == b"GIF89a"[:]) {
    return Some((raster_le16(data, 6), raster_le16(data, 8)))
  }
  if data.length() >= 26 && data[:2] == b"BM"[:] {
    let width = raster_le32_signed(data, 18)
    let height = raster_le32_signed(data, 22)
    if width > 0 && height != 0 {
      return Some((width, if height < 0 { -height } else { height }))
    }
  }
  if data.length() >= 4 && data[0] == 0xff && data[1] == 0xd8 {
    let mut offset = 2
    while offset + 9 < data.length() {
      if data[offset] != 0xff {
        offset += 1
        continue
      }
      let marker = data[offset + 1].to_int()
      if marker == 0xd8 || marker == 0x01 || (marker >= 0xd0 && marker <= 0xd7) {
        offset += 2
        continue
      }
      if marker == 0xd9 || marker == 0xda {
        return None
      }
      let length = (data[offset + 2].to_int() << 8) | data[offset + 3].to_int()
      if length < 2 {
        return None
      }
      if marker >= 0xc0 &&
        marker <= 0xcf &&
        marker != 0xc4 &&
        marker != 0xc8 &&
        marker != 0xcc {
        let height = (data[offset + 5].to_int() << 8) |
          data[offset + 6].to_int()
        let width = (data[offset + 7].to_int() << 8) | data[offset + 8].to_int()
        if width > 0 && height > 0 {
          return Some((width, height))
        }
        return None
      }
      offset += 2 + length
    }
  }
  if data.length() >= 22 && data[0] == 0 && data[1] == 0 && data[2] == 1 {
    let count = raster_le16(data, 4)
    let mut width = 0
    let mut height = 0
    for i in 0..<count {
      let entry = 6 + i * 16
      if entry + 2 >= data.length() {
        break
      }
      let w = if data[entry] == 0 { 256 } else { data[entry].to_int() }
      let h = if data[entry + 1] == 0 { 256 } else { data[entry + 1].to_int() }
      if w * h > width * height {
        width = w
        height = h
      }
    }
    if width > 0 && height > 0 {
      return Some((width, height))
    }
  }
  None
}

///|
fn raster_be32(data : Bytes, offset : Int32) -> Int32 {
  (data[offset].to_int() << 24) |
  (data[offset + 1].to_int() << 16) |
  (data[offset + 2].to_int() << 8) |
  data[offset + 3].to_int()
}

///|
fn raster_le16(data : Bytes, offset : Int32) -> Int32 {
  data[offset].to_int() | (data[offset + 1].to_int() << 8)
}

///|
fn raster_le32_signed(data : Bytes, offset : Int32) -> Int32 {
  let value = data[offset].to_int() |
    (data[offset + 1].to_int() << 8) |
    (data[offset + 2].to_int() << 16) |
    (data[offset + 3].to_int() << 24)
  value
}
