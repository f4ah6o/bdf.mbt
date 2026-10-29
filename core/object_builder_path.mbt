///|
/// One path reference and its position in a path run.
pub(all) struct ObjectGlyph {
  path : Int32
  x : Float
  y : Float
}

///|
fn ObjectBuilder::grow_path(
  self : ObjectBuilder,
  index : Int32,
  dx : Float,
  dy : Float,
  translated : Bool,
) -> Unit raise {
  self.path_reference(index)
  if !self.auto_bbox {
    return
  }
  let path = match self.paths[index] {
    External(_, _) => return
    Inline(path) => path
  }
  // Validate before indexing the coordinates, including unused arc operands.
  object_check_path(path)
  let tmp = if translated { ObjectBuilder::new() } else { self }
  let mut pos = 0
  for verb in path.verbs {
    let n = verb.to_int()
    let sizes = [2, 2, 4, 6, 0, 4, 8, 5, 5]
    let count = sizes[n]
    if n == 0 || n == 1 || n == 2 || n == 3 || n == 7 {
      let points = if n == 7 { 2 } else { count / 2 }
      for i in 0..<points {
        let x = Float::from_double(path.coordinates[pos + i * 2])
        let y = Float::from_double(path.coordinates[pos + i * 2 + 1])
        tmp.grow(x, y, 0.0F, 0.0F)
      }
    } else if n == 5 || n == 8 {
      let x = Float::from_double(path.coordinates[pos])
      let y = Float::from_double(path.coordinates[pos + 1])
      let w = Float::from_double(path.coordinates[pos + 2])
      let h = Float::from_double(path.coordinates[pos + 3])
      tmp.grow(x, y, w, h)
    } else if n == 6 {
      let x = Float::from_double(path.coordinates[pos])
      let y = Float::from_double(path.coordinates[pos + 1])
      let rx = Float::from_double(path.coordinates[pos + 2])
      let ry = Float::from_double(path.coordinates[pos + 3])
      tmp.grow(x - rx, y - ry, 2.0F * rx, 2.0F * ry)
    }
    pos += count
  }
  if translated {
    let (x, y, w, h) = tmp.bbox
    self.grow(x + dx, y + dy, w, h)
  }
}

///|
pub fn ObjectBuilder::fill_path(
  self : ObjectBuilder,
  index : Int32,
  rule : Byte,
) -> Unit raise {
  self.grow_path(index, 0.0F, 0.0F, false)
  self.ops.write_byte(0x22)
  self.ops.write_leb128(index.reinterpret_as_uint())
  self.ops.write_byte(rule)
}

///|
pub fn ObjectBuilder::stroke_path(
  self : ObjectBuilder,
  index : Int32,
) -> Unit raise {
  self.grow_path(index, 0.0F, 0.0F, false)
  self.ops.write_byte(0x23)
  self.ops.write_leb128(index.reinterpret_as_uint())
}

///|
pub fn ObjectBuilder::fill_path_at(
  self : ObjectBuilder,
  index : Int32,
  rule : Byte,
  x : Float,
  y : Float,
) -> Unit raise {
  self.grow_path(index, x, y, true)
  self.ops.write_byte(0x24)
  self.ops.write_leb128(index.reinterpret_as_uint())
  self.ops.write_byte(rule)
  self.ops.write_float_le(x)
  self.ops.write_float_le(y)
}

///|
pub fn ObjectBuilder::fill_path_run(
  self : ObjectBuilder,
  rule : Byte,
  glyphs : Array[ObjectGlyph],
) -> Unit raise {
  for glyph in glyphs {
    self.grow_path(glyph.path, glyph.x, glyph.y, true)
  }
  self.ops.write_byte(0x25)
  self.ops.write_byte(rule)
  self.ops.write_leb128(glyphs.length().reinterpret_as_uint())
  for glyph in glyphs {
    self.ops.write_leb128(glyph.path.reinterpret_as_uint())
    self.ops.write_float_le(glyph.x)
    self.ops.write_float_le(glyph.y)
  }
}
