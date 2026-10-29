///|
fn webp_u24(data : Bytes, offset : Int32) -> Int64 {
  u16(data, offset).to_int64() | (data[offset + 2].to_int64() << 16)
}

///|
fn read_webp(data : Bytes) -> Picture raise {
  if data.length() < 20 {
    raise ImageFailure("image: WebP: the image is truncated")
  }
  let declared_end = 8L + u32(data, 4)
  let end = if declared_end < data.length().to_int64() {
    declared_end.to_int()
  } else {
    data.length()
  }
  let mut offset = 12
  let mut width = 0L
  let mut height = 0L
  let mut extended = false
  let mut frames = 0
  let exif : Array[Bytes] = []
  let xmp : Array[Bytes] = []
  while offset <= end - 8 {
    let kind = data[offset:offset + 4]
    let size = u32(data, offset + 4)
    if size > (end - offset - 8).to_int64() {
      break
    }
    let start = offset + 8
    let length = size.to_int()
    offset = start + length + (length & 1)
    if kind == b"VP8X"[:] && length >= 10 {
      extended = true
      width = 1 + webp_u24(data, start + 4)
      height = 1 + webp_u24(data, start + 7)
    } else if kind == b"VP8 "[:] &&
      !extended &&
      length >= 10 &&
      data[start + 3] == 0x9d &&
      data[start + 4] == 1 &&
      data[start + 5] == 0x2a {
      width = (u16(data, start + 6) & 0x3fff).to_int64()
      height = (u16(data, start + 8) & 0x3fff).to_int64()
    } else if kind == b"VP8L"[:] &&
      !extended &&
      length >= 5 &&
      data[start] == 0x2f {
      let bits = u32(data, start + 1)
      width = 1 + (bits & 0x3fff)
      height = 1 + ((bits >> 14) & 0x3fff)
    } else if kind == b"ANMF"[:] {
      frames += 1
    } else if kind == b"EXIF"[:] {
      exif.push(data[start:start + length].to_bytes())
    } else if kind == b"XMP "[:] {
      xmp.push(data[start:start + length].to_bytes())
    }
  }
  if width == 0 || height == 0 {
    raise ImageFailure("image: WebP: the WebP image has no size")
  }
  let dc : Map[String, Array[String]] = Map([])
  for packet in xmp {
    metadata_merge(dc, metadata_xmp(packet))
  }
  let mut orientation = 0
  for block in exif {
    if exif_fields(block) is Some(fields) {
      metadata_merge(dc, exif_metadata(fields))
      if orientation == 0 {
        orientation = fields.orientation
      }
    }
  }
  let warnings : Array[String] = []
  if orientation > 1 {
    warnings.push(
      "the EXIF orientation of the WebP image is not applied: browsers draw WebP images as they are stored",
    )
  }
  { format: "webp", width, height, dc, animated: frames > 1, warnings, }
}
