///|
fn jpeg_u16(data : Bytes, offset : Int32) -> Int32 {
  (data[offset].to_int() << 8) | data[offset + 1].to_int()
}

///|
// Do not silently discard metadata while its full interpretation is being
// ported. Orientation-only EXIF can already be handled exactly.
fn exif_has_unported_metadata(fields : ExifFields) -> Bool {
  for
    tag in [
      0x010e, 0x0132, 0x013b, 0x8298, 0x9c9b, 0x9c9c, 0x9c9d, 0x9c9e, 0x9c9f,
    ] {
    if fields.primary.get(tag) is Some(_) {
      return true
    }
  }
  for tag in [0x9003, 0x9004, 0x9010, 0x9011, 0x9012, 0x9286] {
    if fields.exif.get(tag) is Some(_) {
      return true
    }
  }
  false
}

///|
fn read_jpeg(data : Bytes) -> Picture raise {
  let mut width = 0L
  let mut height = 0L
  let mut orientation = 0
  let mut offset = 2
  while offset <= data.length() - 4 {
    if data[offset] != 0xff {
      break
    }
    let marker = data[offset + 1].to_int()
    if marker == 0xff {
      offset += 1
      continue
    }
    if marker == 1 || (marker >= 0xd0 && marker <= 0xd8) {
      offset += 2
      continue
    }
    if marker == 0xd9 || marker == 0xda {
      break
    }
    let length = jpeg_u16(data, offset + 2)
    if length < 2 || length > data.length() - offset - 2 {
      break
    }
    let start = offset + 4
    let end = offset + 2 + length
    let segment = data[start:end].to_bytes()
    offset = end
    if marker == 0xe1 &&
      segment.length() >= 6 &&
      segment[:6] == b"Exif\x00\x00"[:] {
      match exif_fields(segment) {
        Some(fields) => {
          if exif_has_unported_metadata(fields) {
            raise ImageFailure("image: JPEG EXIF metadata is not yet supported")
          }
          if orientation == 0 {
            orientation = fields.orientation
          }
        }
        None => ()
      }
    } else if marker == 0xe1 &&
      segment.length() >= 29 &&
      segment[:29] == b"http://ns.adobe.com/xap/1.0/\x00"[:] {
      raise ImageFailure("image: JPEG XMP metadata is not yet supported")
    } else if marker == 0xed &&
      segment.length() >= 14 &&
      segment[:14] == b"Photoshop 3.0\x00"[:] {
      raise ImageFailure("image: JPEG IPTC metadata is not yet supported")
    } else if marker >= 0xc0 &&
      marker <= 0xcf &&
      marker != 0xc4 &&
      marker != 0xc8 &&
      marker != 0xcc &&
      width == 0 &&
      segment.length() >= 5 {
      height = jpeg_u16(segment, 1).to_int64()
      width = jpeg_u16(segment, 3).to_int64()
    }
  }
  if width == 0 || height == 0 {
    raise ImageFailure("image: JPEG: the JPEG image has no frame header")
  }
  if orientation >= 5 {
    { format: "jpeg", width: height, height: width, }
  } else {
    { format: "jpeg", width, height, }
  }
}
