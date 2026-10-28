///|
pub(all) struct ObjectPart {
  bbox : (Double, Double, Double, Double)
  strings : Array[String]
  images : Array[String]
  objects : Array[String]
  ops : Bytes
}

///|
fn skip_path(reader : Reader) -> Unit raise {
  let count = reader.varuint()
  if count > reader.remaining() {
    raise BadFormat("path verb count out of range")
  }
  let verbs = reader.take(count)
  let mut coords = 0
  let sizes = [2, 2, 4, 6, 0, 4, 8, 5, 5]
  for b in verbs {
    let verb = b.to_int()
    if verb >= sizes.length() {
      raise BadFormat("unknown path verb")
    }
    coords += sizes[verb]
  }
  if coords > reader.remaining() / 4 {
    raise BadFormat("path coordinates out of range")
  }
  reader.skip(coords * 4)
}

///|
pub fn decode_object(data : Bytes) -> ObjectPart raise {
  let r = Reader::new(data)
  if r.take(4) != b"BOBJ" || r.u16() != 1 || r.u16() != 0 {
    raise BadFormat("unsupported object header")
  }
  let bbox = (r.f32(), r.f32(), r.f32(), r.f32())
  let strings : Array[String] = []
  let string_count = r.varuint()
  if string_count > r.remaining() {
    raise BadFormat("string count out of range")
  }
  for _ in 0..<string_count {
    strings.push(r.string())
  }
  let path_count = r.varuint()
  if path_count > r.remaining() {
    raise BadFormat("path count out of range")
  }
  for _ in 0..<path_count {
    if r.u8() == 0 {
      skip_path(r)
    } else {
      r.skip(16)
      ignore(r.varuint())
    }
  }
  let paint_count = r.varuint()
  if paint_count > r.remaining() {
    raise BadFormat("paint count out of range")
  }
  for _ in 0..<paint_count {
    let kind = r.u8()
    if kind == 3 {
      ignore(r.varuint())
      r.skip(1 + 6 * 4)
    } else {
      if kind > 2 {
        raise BadFormat("unknown paint kind")
      }
      let coord_count = if kind == 0 { 4 } else if kind == 1 { 6 } else { 3 }
      r.skip(coord_count * 4)
      let stops = r.varuint()
      if stops > r.remaining() / 8 {
        raise BadFormat("paint stops out of range")
      }
      r.skip(stops * 8)
    }
  }
  let font_count = r.varuint()
  if font_count > r.remaining() {
    raise BadFormat("font count out of range")
  }
  for _ in 0..<font_count {
    let kind = r.u8()
    if kind == 0 {
      r.skip(16)
    } else if kind != 1 {
      raise BadFormat("unknown font kind")
    }
    ignore(r.string())
    r.skip(3)
  }
  let images : Array[String] = []
  let image_count = r.varuint()
  if image_count > r.remaining() / 16 {
    raise BadFormat("image count out of range")
  }
  for _ in 0..<image_count {
    images.push(r.hash())
  }
  let objects : Array[String] = []
  let object_count = r.varuint()
  if object_count > r.remaining() / 16 {
    raise BadFormat("object count out of range")
  }
  for _ in 0..<object_count {
    objects.push(r.hash())
  }
  let ops = r.take(r.varuint())
  if r.remaining() != 0 {
    raise BadFormat("trailing object bytes")
  }
  { bbox, strings, images, objects, ops }
}
