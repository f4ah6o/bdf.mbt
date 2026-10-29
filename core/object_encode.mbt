///|
fn object_write_string(out : @buffer.Buffer, value : String) -> Unit {
  let bytes = @utf8.encode(value)
  let mut start = 0
  while start + 3 <= bytes.length() &&
        bytes[start] == 0xef &&
        bytes[start + 1] == 0xbb &&
        bytes[start + 2] == 0xbf {
    start += 3
  }
  out.write_leb128((bytes.length() - start).reinterpret_as_uint())
  out.write_bytes(bytes[start:])
}

///|
fn object_write_hash(out : @buffer.Buffer, hash : String) -> Unit raise {
  if !valid_hash(hash) {
    raise BadFormat("invalid object resource hash")
  }
  let bytes = @utf8.encode(hash)
  for i in 0..<16 {
    let a = bytes[2 * i].to_int()
    let b = bytes[2 * i + 1].to_int()
    let high = if a <= 57 { a - 48 } else { a - 87 }
    let low = if b <= 57 { b - 48 } else { b - 87 }
    out.write_byte((high * 16 + low).to_byte())
  }
}

///|
fn object_check_path(path : Path) -> Unit raise {
  let sizes = [2, 2, 4, 6, 0, 4, 8, 5, 5]
  let mut total = 0
  for verb in path.verbs {
    let n = verb.to_int()
    if n >= sizes.length() {
      raise BadFormat("unknown path verb")
    }
    total += sizes[n]
  }
  if total != path.coordinates.length() {
    raise BadFormat("wrong number of path coordinates")
  }
}

///|
fn object_write_path(out : @buffer.Buffer, path : Path) -> Unit raise {
  object_check_path(path)
  out.write_leb128(path.verbs.length().reinterpret_as_uint())
  out.write_bytes(path.verbs)
  for coordinate in path.coordinates {
    out.write_float_le(Float::from_double(coordinate))
  }
}

///|
fn object_write_paint(out : @buffer.Buffer, paint : Paint) -> Unit raise {
  match paint {
    Gradient(kind, coordinates, stops) => {
      let count = match kind {
        0 => 4
        1 => 6
        2 => 3
        _ => -1
      }
      if count < 0 || coordinates.length() != count {
        raise BadFormat("invalid gradient")
      }
      out.write_byte(kind.to_byte())
      for coordinate in coordinates {
        out.write_float_le(Float::from_double(coordinate))
      }
      out.write_leb128(stops.length().reinterpret_as_uint())
      for stop in stops {
        out.write_float_le(Float::from_double(stop.offset))
        out.write_uint_le(stop.color.reinterpret_as_uint())
      }
    }
    Pattern(image, repeat, matrix) => {
      if image < 0 || repeat < 0 || repeat > 255 || matrix.length() != 6 {
        raise BadFormat("invalid pattern")
      }
      out.write_byte(3)
      out.write_leb128(image.reinterpret_as_uint())
      out.write_byte(repeat.to_byte())
      for coordinate in matrix {
        out.write_float_le(Float::from_double(coordinate))
      }
    }
  }
}

///|
fn object_write_font(out : @buffer.Buffer, font : Font) -> Unit raise {
  if font.weight < 0 ||
    font.weight > 65535 ||
    font.style < 0 ||
    font.style > 255 {
    raise BadFormat("invalid font attributes")
  }
  match font.hash {
    Some(hash) => {
      out.write_byte(0)
      object_write_hash(out, hash)
    }
    None => out.write_byte(1)
  }
  object_write_string(out, font.family)
  out.write_uint16_le(font.weight.to_uint16())
  out.write_byte(font.style.to_byte())
}

///|
/// Encode all resource tables and the raw instruction stream of a BDF object.
/// String byte-order marks are removed as in the upstream writer.
pub fn encode_object_resources(resources : ObjectResources) -> Bytes raise {
  let object = resources.object
  let out = @buffer.Buffer()
  out.write_bytes(b"BOBJ\x01\x00\x00\x00")
  let (x, y, w, h) = object.bbox
  out.write_float_le(Float::from_double(x))
  out.write_float_le(Float::from_double(y))
  out.write_float_le(Float::from_double(w))
  out.write_float_le(Float::from_double(h))
  out.write_leb128(object.strings.length().reinterpret_as_uint())
  for value in object.strings {
    object_write_string(out, value)
  }
  out.write_leb128(resources.paths.length().reinterpret_as_uint())
  for path in resources.paths {
    match path {
      Inline(path) => {
        out.write_byte(0)
        object_write_path(out, path)
      }
      External(hash, index) => {
        if index < 0 {
          raise BadFormat("invalid external path index")
        }
        out.write_byte(1)
        object_write_hash(out, hash)
        out.write_leb128(index.reinterpret_as_uint())
      }
    }
  }
  out.write_leb128(resources.paints.length().reinterpret_as_uint())
  for paint in resources.paints {
    object_write_paint(out, paint)
  }
  out.write_leb128(resources.fonts.length().reinterpret_as_uint())
  for font in resources.fonts {
    object_write_font(out, font)
  }
  out.write_leb128(object.images.length().reinterpret_as_uint())
  for image in object.images {
    object_write_hash(out, image)
  }
  out.write_leb128(object.objects.length().reinterpret_as_uint())
  for child in object.objects {
    object_write_hash(out, child)
  }
  out.write_leb128(object.ops.length().reinterpret_as_uint())
  out.write_bytes(object.ops)
  out.to_bytes()
}

///|
/// Encode a collection of inline paths as a BDF path part.
pub fn encode_path_collection(paths : Array[Path]) -> Bytes raise {
  let out = @buffer.Buffer()
  out.write_leb128(paths.length().reinterpret_as_uint())
  for path in paths {
    object_write_path(out, path)
  }
  out.to_bytes()
}
