///|
pub fn ObjectBuilder::transform(
  self : ObjectBuilder,
  a : Float,
  b : Float,
  c : Float,
  d : Float,
  e : Float,
  f : Float,
) -> Unit {
  self.ops.write_byte(0x03)
  for value in [a, b, c, d, e, f] {
    self.ops.write_float_le(value)
  }
}

///|
pub fn ObjectBuilder::scale(self : ObjectBuilder, x : Float, y : Float) -> Unit {
  self.ops.write_byte(0x05)
  self.ops.write_float_le(x)
  self.ops.write_float_le(y)
}

///|
fn ObjectBuilder::path_reference(
  self : ObjectBuilder,
  index : Int32,
) -> Unit raise {
  if index < 0 || index >= self.paths.length() {
    raise BadFormat("invalid path reference")
  }
}

///|
fn ObjectBuilder::paint_reference(
  self : ObjectBuilder,
  index : Int32,
) -> Unit raise {
  if index < 0 || index >= self.paints.length() {
    raise BadFormat("invalid paint reference")
  }
}

///|
pub fn ObjectBuilder::clip_path(
  self : ObjectBuilder,
  index : Int32,
  rule : Byte,
) -> Unit raise {
  self.path_reference(index)
  self.ops.write_byte(0x06)
  self.ops.write_leb128(index.reinterpret_as_uint())
  self.ops.write_byte(rule)
}

///|
pub fn ObjectBuilder::fill_paint(
  self : ObjectBuilder,
  index : Int32,
) -> Unit raise {
  self.paint_reference(index)
  self.ops.write_byte(0x11)
  self.ops.write_leb128(index.reinterpret_as_uint())
}

///|
pub fn ObjectBuilder::stroke_color(
  self : ObjectBuilder,
  color : UInt32,
) -> Unit {
  self.ops.write_byte(0x12)
  self.ops.write_uint_le(color)
}

///|
pub fn ObjectBuilder::stroke_paint(
  self : ObjectBuilder,
  index : Int32,
) -> Unit raise {
  self.paint_reference(index)
  self.ops.write_byte(0x13)
  self.ops.write_leb128(index.reinterpret_as_uint())
}

///|
pub fn ObjectBuilder::line(
  self : ObjectBuilder,
  width : Float,
  cap : Byte,
  join : Byte,
  miter : Float,
) -> Unit {
  self.ops.write_byte(0x14)
  self.ops.write_float_le(width)
  self.ops.write_byte(cap)
  self.ops.write_byte(join)
  self.ops.write_float_le(miter)
}

///|
pub fn ObjectBuilder::dash(
  self : ObjectBuilder,
  segments : Array[Float],
  offset : Float,
) -> Unit {
  self.ops.write_byte(0x15)
  self.ops.write_leb128(segments.length().reinterpret_as_uint())
  for segment in segments {
    self.ops.write_float_le(segment)
  }
  self.ops.write_float_le(offset)
}

///|
pub fn ObjectBuilder::alpha(self : ObjectBuilder, value : Float) -> Unit {
  self.ops.write_byte(0x16)
  self.ops.write_float_le(value)
}

///|
pub fn ObjectBuilder::blend(self : ObjectBuilder, value : Byte) -> Unit {
  self.ops.write_byte(0x17)
  self.ops.write_byte(value)
}

///|
pub fn ObjectBuilder::shadow(
  self : ObjectBuilder,
  color : UInt32,
  blur : Float,
  x : Float,
  y : Float,
) -> Unit {
  self.ops.write_byte(0x18)
  self.ops.write_uint_le(color)
  self.ops.write_float_le(blur)
  self.ops.write_float_le(x)
  self.ops.write_float_le(y)
}

///|
pub fn ObjectBuilder::filter(self : ObjectBuilder, css : String) -> Unit {
  self.ops.write_byte(0x19)
  self.ops.write_leb128(self.string_ref(css).reinterpret_as_uint())
}
