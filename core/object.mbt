///|
pub(all) struct ObjectPart {
  bbox : (Double, Double, Double, Double)
  strings : Array[String]
  images : Array[String]
  objects : Array[String]
  ops : Bytes
}

///|
/// Object data together with the path resources needed by drawing commands.
pub(all) struct ObjectWithPaths {
  object : ObjectPart
  paths : Array[PathEntry]
}

///|
/// The resources carried by a BDF object.
pub(all) struct ObjectResources {
  object : ObjectPart
  paths : Array[PathEntry]
  paints : Array[Paint]
  fonts : Array[Font]
}

///|
/// Decode an object and its resource tables.
pub fn decode_object_resources(data : Bytes) -> ObjectResources raise {
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
  let paths : Array[PathEntry] = []
  for _ in 0..<path_count {
    match r.u8() {
      0 => paths.push(Inline(read_path(r)))
      1 => paths.push(External(r.hash(), r.varuint()))
      _ => raise BadFormat("unknown path entry kind")
    }
  }
  let paint_count = r.varuint()
  if paint_count > r.remaining() {
    raise BadFormat("paint count out of range")
  }
  let paints : Array[Paint] = []
  for _ in 0..<paint_count {
    paints.push(read_paint(r))
  }
  let font_count = r.varuint()
  if font_count > r.remaining() {
    raise BadFormat("font count out of range")
  }
  let fonts : Array[Font] = []
  for _ in 0..<font_count {
    fonts.push(read_font(r))
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
  { object: { bbox, strings, images, objects, ops, }, paths, paints, fonts, }
}

///|
/// Decode an object and its path references.
pub fn decode_object_with_paths(data : Bytes) -> ObjectWithPaths raise {
  let decoded = decode_object_resources(data)
  { object: decoded.object, paths: decoded.paths, }
}

///|
/// Decode an object without returning its path resources.
pub fn decode_object(data : Bytes) -> ObjectPart raise {
  decode_object_with_paths(data).object
}
