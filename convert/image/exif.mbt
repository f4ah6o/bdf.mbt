///|
// Raw TIFF directory values used by the image metadata readers. Entries
// retain their encoded byte order so SHORT, LONG and text tags can be decoded
// according to the TIFF header.
struct ExifFields {
  little : Bool
  primary : Map[Int32, Bytes]
  exif : Map[Int32, Bytes]
  orientation : Int32
}

///|
fn exif_u16(data : Bytes, offset : Int32, little : Bool) -> Int32 {
  let first = data[offset].to_int()
  let second = data[offset + 1].to_int()
  if little {
    first | (second << 8)
  } else {
    (first << 8) | second
  }
}

///|
fn exif_u32(data : Bytes, offset : Int32, little : Bool) -> Int64 {
  let first = exif_u16(data, offset, little).to_int64()
  let second = exif_u16(data, offset + 2, little).to_int64()
  if little {
    first | (second << 16)
  } else {
    (first << 16) | second
  }
}

///|
fn exif_ifd(data : Bytes, offset : Int64, little : Bool) -> Map[Int32, Bytes]? {
  if offset < 0 || offset + 2 > data.length().to_int64() {
    return None
  }
  let start = offset.to_int()
  let count = exif_u16(data, start, little)
  let entries : Map[Int32, Bytes] = Map([])
  for i in 0..<count {
    let entry64 = offset + 2 + 12 * i.to_int64()
    if entry64 + 12 > data.length().to_int64() {
      break
    }
    let entry = entry64.to_int()
    let tag = exif_u16(data, entry, little)
    let kind = exif_u16(data, entry + 2, little)
    let item_size = match kind {
      1 | 2 | 6 | 7 => 1L
      3 | 8 => 2L
      4 | 9 | 11 => 4L
      5 | 10 | 12 => 8L
      _ => 0L
    }
    if item_size == 0 {
      continue
    }
    let length = item_size * exif_u32(data, entry + 4, little)
    let at = if length <= 4 {
      entry64 + 8
    } else {
      exif_u32(data, entry + 8, little)
    }
    if at + length <= data.length().to_int64() {
      entries[tag] = data[at.to_int():(at + length).to_int()].to_bytes()
    }
  }
  Some(entries)
}

///|
fn exif_fields(input : Bytes) -> ExifFields? {
  let data = if input.length() >= 6 && input[:6] == b"Exif\x00\x00"[:] {
    input[6:].to_bytes()
  } else {
    input
  }
  if data.length() < 8 {
    return None
  }
  let little = if data[:4] == b"II\x2a\x00"[:] {
    true
  } else if data[:4] == b"MM\x00\x2a"[:] {
    false
  } else {
    return None
  }
  guard exif_ifd(data, exif_u32(data, 4, little), little) is Some(primary) else {
    return None
  }
  let mut orientation = 0
  match primary.get(0x0112) {
    Some(value) if value.length() >= 2 => {
      let candidate = exif_u16(value, 0, little)
      if candidate >= 1 && candidate <= 8 {
        orientation = candidate
      }
    }
    _ => ()
  }
  let mut extra : Map[Int32, Bytes] = Map([])
  match primary.get(0x8769) {
    Some(value) => {
      let offset = if value.length() >= 4 {
        exif_u32(value, 0, little)
      } else {
        0L
      }
      match exif_ifd(data, offset, little) {
        Some(found) => extra = found
        None => ()
      }
    }
    None => ()
  }
  Some({ little, primary, exif: extra, orientation, })
}
