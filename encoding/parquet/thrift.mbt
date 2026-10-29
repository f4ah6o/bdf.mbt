///|
struct Compact {
  out : @buffer.Buffer
  last : Array[Int32]
}

///|
fn Compact::new() -> Compact {
  { out: @buffer.new(), last: [0], }
}

///|
fn uvarint(out : @buffer.Buffer, n : UInt64) -> Unit {
  let mut value = n
  while value >= 128UL {
    out.write_byte(((value & 127UL) | 128UL).to_byte())
    value = value >> 7
  }
  out.write_byte(value.to_byte())
}

///|
fn svarint(out : @buffer.Buffer, n : Int64) -> Unit {
  let bits = n.reinterpret_as_uint64()
  uvarint(out, (bits << 1) ^ (n >> 63).reinterpret_as_uint64())
}

///|
fn Compact::field(self : Compact, id : Int32, typ : Int32) -> Unit {
  let idx = self.last.length() - 1
  let delta = id - self.last[idx]
  if delta > 0 && delta <= 15 {
    self.out.write_byte((delta * 16 + typ).to_byte())
  } else {
    self.out.write_byte(typ.to_byte())
    svarint(self.out, id.to_int64())
  }
  self.last[idx] = id
}

///|
fn Compact::integer(
  self : Compact,
  id : Int32,
  value : Int64,
  typ : Int32,
) -> Unit {
  self.field(id, typ)
  svarint(self.out, value)
}

///|
fn Compact::i32(self : Compact, id : Int32, value : Int32) -> Unit {
  self.integer(id, value.to_int64(), 5)
}

///|
fn Compact::i64(self : Compact, id : Int32, value : Int64) -> Unit {
  self.integer(id, value, 6)
}

///|
fn Compact::binary(self : Compact, id : Int32, text : String) -> Unit {
  self.field(id, 8)
  let bytes = @utf8.encode(text)
  uvarint(self.out, bytes.length().to_uint64())
  self.out.write_bytes(bytes)
}

///|
fn Compact::begin(self : Compact, id : Int32) -> Unit {
  self.field(id, 12)
  self.last.push(0)
}

///|
fn Compact::elem(self : Compact) -> Unit {
  self.last.push(0)
}

///|
fn Compact::end(self : Compact) -> Unit {
  self.out.write_byte(0)
  ignore(self.last.pop())
}

///|
fn Compact::list(
  self : Compact,
  id : Int32,
  typ : Int32,
  count : Int32,
) -> Unit {
  self.field(id, 9)
  if count < 15 {
    self.out.write_byte((count * 16 + typ).to_byte())
  } else {
    self.out.write_byte((240 + typ).to_byte())
    uvarint(self.out, count.to_uint64())
  }
}

///|
fn Compact::bytes(self : Compact) -> Bytes {
  self.out.write_byte(0)
  self.out.to_bytes()
}
