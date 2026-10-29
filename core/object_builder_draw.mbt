///|
pub fn ObjectBuilder::save(self : ObjectBuilder) -> Unit {
  self.ops.write_byte(0x01)
}

///|
pub fn ObjectBuilder::restore(self : ObjectBuilder) -> Unit {
  self.ops.write_byte(0x02)
}

///|
pub fn ObjectBuilder::translate(
  self : ObjectBuilder,
  x : Float,
  y : Float,
) -> Unit {
  self.ops.write_byte(0x04)
  self.ops.write_float_le(x)
  self.ops.write_float_le(y)
}

///|
fn ObjectBuilder::rect_op(
  self : ObjectBuilder,
  op : Byte,
  x : Float,
  y : Float,
  w : Float,
  h : Float,
) -> Unit {
  self.ops.write_byte(op)
  self.ops.write_float_le(x)
  self.ops.write_float_le(y)
  self.ops.write_float_le(w)
  self.ops.write_float_le(h)
}

///|
pub fn ObjectBuilder::clip_rect(
  self : ObjectBuilder,
  x : Float,
  y : Float,
  w : Float,
  h : Float,
) -> Unit {
  self.rect_op(0x07, x, y, w, h)
}

///|
pub fn ObjectBuilder::fill_color(self : ObjectBuilder, color : UInt32) -> Unit {
  self.ops.write_byte(0x10)
  self.ops.write_uint_le(color)
}

///|
pub fn ObjectBuilder::font(
  self : ObjectBuilder,
  index : Int32,
  size : Float,
) -> Unit raise {
  if index < 0 || index >= self.fonts.length() {
    raise BadFormat("invalid font reference")
  }
  self.ops.write_byte(0x1a)
  self.ops.write_leb128(index.reinterpret_as_uint())
  self.ops.write_float_le(size)
}

///|
pub fn ObjectBuilder::text_style(
  self : ObjectBuilder,
  align : Byte,
  baseline : Byte,
  direction : Byte,
  spacing : Float,
) -> Unit {
  self.ops.write_byte(0x1b)
  self.ops.write_byte(align)
  self.ops.write_byte(baseline)
  self.ops.write_byte(direction)
  self.ops.write_float_le(spacing)
}

///|
pub fn ObjectBuilder::fill_rect(
  self : ObjectBuilder,
  x : Float,
  y : Float,
  w : Float,
  h : Float,
) -> Unit {
  self.grow(x, y, w, h)
  self.rect_op(0x20, x, y, w, h)
}

///|
pub fn ObjectBuilder::stroke_rect(
  self : ObjectBuilder,
  x : Float,
  y : Float,
  w : Float,
  h : Float,
) -> Unit {
  self.grow(x, y, w, h)
  self.rect_op(0x21, x, y, w, h)
}

///|
pub fn ObjectBuilder::clear_rect(
  self : ObjectBuilder,
  x : Float,
  y : Float,
  w : Float,
  h : Float,
) -> Unit {
  self.rect_op(0x26, x, y, w, h)
}

///|
fn ObjectBuilder::text_op(
  self : ObjectBuilder,
  op : Byte,
  text : String,
  x : Float,
  y : Float,
  advance : Float,
) -> Unit {
  self.grow(x, y, advance, 0.0F)
  self.ops.write_byte(op)
  self.ops.write_leb128(self.string_ref(text).reinterpret_as_uint())
  self.ops.write_float_le(x)
  self.ops.write_float_le(y)
  self.ops.write_float_le(advance)
}

///|
pub fn ObjectBuilder::fill_text(
  self : ObjectBuilder,
  text : String,
  x : Float,
  y : Float,
  advance : Float,
) -> Unit {
  self.text_op(0x30, text, x, y, advance)
}

///|
pub fn ObjectBuilder::stroke_text(
  self : ObjectBuilder,
  text : String,
  x : Float,
  y : Float,
  advance : Float,
) -> Unit {
  self.text_op(0x31, text, x, y, advance)
}

///|
pub fn ObjectBuilder::image(
  self : ObjectBuilder,
  index : Int32,
  x : Float,
  y : Float,
  w : Float,
  h : Float,
) -> Unit raise {
  if index < 0 || index >= self.images.length() {
    raise BadFormat("invalid image reference")
  }
  self.grow(x, y, w, h)
  self.ops.write_byte(0x40)
  self.ops.write_leb128(index.reinterpret_as_uint())
  self.ops.write_float_le(x)
  self.ops.write_float_le(y)
  self.ops.write_float_le(w)
  self.ops.write_float_le(h)
}

///|
pub fn ObjectBuilder::smoothing(
  self : ObjectBuilder,
  enabled : Bool,
  quality : Byte,
) -> Unit {
  self.ops.write_byte(0x42)
  self.ops.write_byte(if enabled { 1 } else { 0 })
  self.ops.write_byte(quality)
}

///|
pub fn ObjectBuilder::mark(
  self : ObjectBuilder,
  kind : Byte,
  payload : String,
) -> Unit {
  self.ops.write_byte(0x71)
  self.ops.write_byte(kind)
  self.ops.write_leb128(self.string_ref(payload).reinterpret_as_uint())
}
