///|
fn pdf_jbig2_u32(data : Bytes, offset : Int32) -> Int32 {
  (data[offset].to_int() << 24) |
  (data[offset + 1].to_int() << 16) |
  (data[offset + 2].to_int() << 8) |
  data[offset + 3].to_int()
}

///|
fn pdf_jbig2_set_bit(
  page : Array[Byte],
  row_bytes : Int32,
  width : Int32,
  height : Int32,
  x : Int32,
  y : Int32,
) -> Unit {
  if x < 0 || y < 0 || x >= width || y >= height {
    return
  }
  let index = y * row_bytes + x / 8
  page[index] = (page[index].to_int() | (1 << (7 - x % 8))).to_byte()
}

///|
fn pdf_jbig2_decode(data : Bytes) -> (Int32, Int32, Bytes) raise PdfStreamError {
  let mut pos = 0
  if data.length() >= 9 &&
    data[0] == b'\x97' &&
    data[1] == b'J' &&
    data[2] == b'B' &&
    data[3] == b'2' {
    pos = 9
  }
  let mut page_width = 0
  let mut page_height = 0
  let mut page : Array[Byte] = []
  let mut regions = 0
  while pos + 11 <= data.length() {
    let number = pdf_jbig2_u32(data, pos)
    pos += 4
    let flags = data[pos].to_int()
    pos += 1
    let segment_type = flags & 0x3f
    let page_bytes = if (flags & 0x40) != 0 { 4 } else { 1 }
    let referred_byte = data[pos].to_int()
    pos += 1
    let mut referred = referred_byte >> 5
    if referred == 7 {
      if pos + 4 > data.length() {
        raise InvalidStream("invalid JBIG2 segment header")
      }
      referred = pdf_jbig2_u32(data, pos)
      pos += 4
    } else if referred == 0 && (referred_byte & 0x1f) != 0 {
      if pos + 4 > data.length() {
        raise InvalidStream("invalid JBIG2 segment header")
      }
      pos += 4
    }
    let reference_size = if number < 256 { 1 } else { 4 }
    if referred < 0 ||
      pos + referred * reference_size + page_bytes + 4 > data.length() {
      raise InvalidStream("invalid JBIG2 segment header")
    }
    pos += referred * reference_size
    pos += page_bytes
    let length = pdf_jbig2_u32(data, pos)
    pos += 4
    if length < 0 || pos + length > data.length() {
      raise InvalidStream("invalid JBIG2 segment length")
    }
    let end = pos + length
    if segment_type == 48 {
      if length < 19 {
        raise InvalidStream("invalid JBIG2 page information")
      }
      page_width = pdf_jbig2_u32(data, pos)
      page_height = pdf_jbig2_u32(data, pos + 4)
      if page_width <= 0 || page_height <= 0 {
        raise InvalidStream("invalid JBIG2 page size")
      }
      let row_bytes = (page_width + 7) / 8
      let needed = row_bytes.to_int64() * page_height.to_int64()
      if needed > 1073741824L {
        raise InvalidStream("JBIG2 page exceeds the decode limit")
      }
      let default_pixel : Byte = if (data[pos + 16].to_int() & 1) != 0 {
        0xff
      } else {
        0
      }
      page = Array::make(needed.to_int(), default_pixel)
    } else if segment_type == 36 {
      if length < 17 {
        raise InvalidStream("invalid JBIG2 generic region")
      }
      let region_width = pdf_jbig2_u32(data, pos)
      let region_height = pdf_jbig2_u32(data, pos + 4)
      let x = pdf_jbig2_u32(data, pos + 8)
      let y = pdf_jbig2_u32(data, pos + 12)
      let region_flags = data[pos + 16].to_int()
      if region_width <= 0 || region_height <= 0 {
        raise InvalidStream("invalid JBIG2 generic region size")
      }
      if page_width == 0 || page_height == 0 {
        page_width = x + region_width
        page_height = y + region_height
        let row_bytes = (page_width + 7) / 8
        page = Array::make(row_bytes * page_height, 0)
      }
      let mmr = (region_flags & 1) != 0
      if !mmr {
        raise InvalidStream(
          "arithmetic-coded JBIG2 generic regions are not supported yet",
        )
      }
      let params = pdf_ccitt_default_params()
      params.k = -1
      params.columns = region_width
      params.rows = region_height
      params.black_is1 = true
      params.encoded_byte_align = true
      let bits = pdf_decode_ccitt(
        params,
        region_width,
        region_height,
        data[pos + 17:end].to_owned(),
      )
      let region_row_bytes = (region_width + 7) / 8
      let page_row_bytes = (page_width + 7) / 8
      for dy in 0..<region_height {
        for dx in 0..<region_width {
          let bit = (bits[dy * region_row_bytes + dx / 8].to_int() >>
            (7 - dx % 8)) & 1
          if bit != 0 {
            pdf_jbig2_set_bit(
              page,
              page_row_bytes,
              page_width,
              page_height,
              x + dx,
              y + dy,
            )
          }
        }
      }
      regions += 1
    }
    pos = end
  }
  if page_width <= 0 || page_height <= 0 || regions == 0 {
    raise InvalidStream("unsupported or empty JBIG2 image data")
  }
  (page_width, page_height, Bytes::from_array(page))
}

///|
fn pdf_jbig2_rgb(data : Bytes, invert : Bool) -> (Int32, Int32, Bytes) raise PdfStreamError {
  let (width, height, bits) = pdf_jbig2_decode(data)
  let rgb = pdf_ccitt_rgb(width, height, bits, true, invert)
  (width, height, rgb)
}
