///|
/// Errors in a TrueType or OpenType font program.
pub suberror FontError {
  InvalidFont(String)
}

///|
fn u16(data : BytesView, offset : Int32) -> Int32 {
  if offset < 0 || offset >= data.length() - 1 {
    return 0
  }
  (data[offset].to_int() << 8) | data[offset + 1].to_int()
}

///|
fn s16(data : BytesView, offset : Int32) -> Int32 {
  let value = u16(data, offset)
  if value >= 32768 {
    value - 65536
  } else {
    value
  }
}

///|
fn u32(data : BytesView, offset : Int32) -> UInt32 {
  if offset < 0 || offset >= data.length() - 3 {
    return 0U
  }
  (data[offset].to_uint() << 24) |
  (data[offset + 1].to_uint() << 16) |
  (data[offset + 2].to_uint() << 8) |
  data[offset + 3].to_uint()
}

///|
fn sfnt_table(
  data : Bytes,
  tables : Map[String, (Int32, Int32)],
  name : String,
) -> BytesView {
  match tables.get(name) {
    Some((offset, length)) => data[offset:offset + length]
    None => data[0:0]
  }
}

///|
/// Return the number of faces in an SFNT collection, or one for a single
/// font. Short inputs have no faces.
pub fn face_count(data : Bytes) -> Int32 {
  if data.length() < 12 {
    return 0
  }
  if u32(data[:], 0) == 0x74746366U {
    let count = u32(data[:], 8)
    if count > 2147483647U {
      0
    } else {
      count.reinterpret_as_int()
    }
  } else {
    1
  }
}
