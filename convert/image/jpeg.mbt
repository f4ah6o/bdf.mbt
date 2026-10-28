///|
fn jpeg_u16(data : Bytes, offset : Int32) -> Int32 {
  (data[offset].to_int() << 8) | data[offset + 1].to_int()
}

///|
fn metadata_merge(
  target : Map[String, Array[String]],
  source : Map[String, Array[String]],
) -> Unit {
  for key, values in source {
    if target.get(key) is None {
      target[key] = values
    }
  }
}

///|
fn read_jpeg(data : Bytes) -> Picture raise {
  let mut width = 0L
  let mut height = 0L
  let mut orientation = 0
  let mut offset = 2
  let packets : Array[Bytes] = []
  let exif_blocks : Array[ExifFields] = []
  let mut iptc : Bytes? = None
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
          exif_blocks.push(fields)
          if orientation == 0 {
            orientation = fields.orientation
          }
        }
        None => ()
      }
    } else if marker == 0xe1 &&
      segment.length() >= 29 &&
      segment[:29] == b"http://ns.adobe.com/xap/1.0/\x00"[:] {
      packets.push(segment[29:].to_bytes())
    } else if marker == 0xed &&
      segment.length() >= 14 &&
      segment[:14] == b"Photoshop 3.0\x00"[:] &&
      iptc is None {
      iptc = photoshop_iptc(segment[14:].to_bytes())
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
  let dc : Map[String, Array[String]] = Map([])
  for packet in packets {
    let utf16 = packet.length() >= 2 &&
      (
        (packet[0] == 0xff && packet[1] == 0xfe) ||
        (packet[0] == 0xfe && packet[1] == 0xff)
      )
    let text = if utf16 {
      "\u{feff}" +
      metadata_utf16_raw(packet[2:].to_bytes(), packet[0] == 0xff, false)
    } else {
      @utf8.decode(packet, ignore_bom=true) catch {
        _ => raise ImageFailure("image: JPEG XMP encoding is not yet supported")
      }
    }
    let (root, complete) = xmp_tree_checked(text, utf16~)
    if !complete {
      raise ImageFailure("image: malformed JPEG XMP is not yet supported")
    }
    if root is Some(node) {
      metadata_merge(dc, xmp_metadata(node))
    }
  }
  for fields in exif_blocks {
    metadata_merge(dc, exif_metadata(fields))
  }
  if iptc is Some(block) {
    metadata_merge(dc, iptc_metadata(block))
  }
  if orientation >= 5 {
    { format: "jpeg", width: height, height: width, dc, }
  } else {
    { format: "jpeg", width, height, dc, }
  }
}
