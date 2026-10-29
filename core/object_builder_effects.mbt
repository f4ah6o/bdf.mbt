///|
pub fn ObjectBuilder::image_sub(
  self : ObjectBuilder,
  index : Int32,
  sx : Float,
  sy : Float,
  sw : Float,
  sh : Float,
  dx : Float,
  dy : Float,
  dw : Float,
  dh : Float,
) -> Unit raise {
  if index < 0 || index >= self.images.length() {
    raise BadFormat("invalid image reference")
  }
  self.grow(dx, dy, dw, dh)
  self.ops.write_byte(0x41)
  self.ops.write_leb128(index.reinterpret_as_uint())
  for value in [sx, sy, sw, sh, dx, dy, dw, dh] {
    self.ops.write_float_le(value)
  }
}

///|
pub fn ObjectBuilder::use_object(
  self : ObjectBuilder,
  index : Int32,
) -> Unit raise {
  if index < 0 || index >= self.children.length() {
    raise BadFormat("invalid object reference")
  }
  let (x, y, w, h) = self.child_boxes[index]
  self.grow(x, y, w, h)
  self.ops.write_byte(0x50)
  self.ops.write_leb128(index.reinterpret_as_uint())
}

///|
pub fn ObjectBuilder::use_object_at(
  self : ObjectBuilder,
  index : Int32,
  x : Float,
  y : Float,
) -> Unit raise {
  if index < 0 || index >= self.children.length() {
    raise BadFormat("invalid object reference")
  }
  let (bx, by, w, h) = self.child_boxes[index]
  self.grow(bx + x, by + y, w, h)
  self.ops.write_byte(0x51)
  self.ops.write_leb128(index.reinterpret_as_uint())
  self.ops.write_float_le(x)
  self.ops.write_float_le(y)
}

///|
pub fn ObjectBuilder::group_begin(
  self : ObjectBuilder,
  alpha : Float,
  blend : Byte,
  x : Float,
  y : Float,
  w : Float,
  h : Float,
) -> Unit {
  self.ops.write_byte(0x52)
  self.ops.write_float_le(alpha)
  self.ops.write_byte(blend)
  for value in [x, y, w, h] {
    self.ops.write_float_le(value)
  }
}

///|
pub fn ObjectBuilder::group_end(self : ObjectBuilder) -> Unit {
  self.ops.write_byte(0x53)
}

///|
pub fn ObjectBuilder::mask_begin(
  self : ObjectBuilder,
  kind : Byte,
  backdrop : UInt32,
  transfer : Bytes,
) -> Unit {
  self.ops.write_byte(0x54)
  self.ops.write_byte(kind)
  self.ops.write_uint_le(backdrop)
  self.ops.write_leb128(transfer.length().reinterpret_as_uint())
  self.ops.write_bytes(transfer)
}

///|
pub fn ObjectBuilder::mask_end(self : ObjectBuilder) -> Unit {
  self.ops.write_byte(0x55)
}

///|
pub fn ObjectBuilder::link(
  self : ObjectBuilder,
  x : Float,
  y : Float,
  w : Float,
  h : Float,
  url : String,
) -> Unit {
  self.rect_op(0x70, x, y, w, h)
  self.ops.write_leb128(self.string_ref(url).reinterpret_as_uint())
}

///|
pub fn ObjectBuilder::ext(self : ObjectBuilder, payload : Bytes) -> Unit {
  self.ops.write_byte(0xff)
  self.ops.write_uint_le(payload.length().reinterpret_as_uint())
  self.ops.write_bytes(payload)
}
