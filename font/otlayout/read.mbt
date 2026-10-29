///|
fn u16(data : BytesView, at : Int32) -> Int32 {
  if at < 0 || at >= data.length() - 1 {
    return 0
  }
  (data[at].to_int() << 8) | data[at + 1].to_int()
}

///|
fn u32(data : BytesView, at : Int32) -> UInt32 {
  if at < 0 || at >= data.length() - 3 {
    return 0U
  }
  (data[at].to_uint() << 24) |
  (data[at + 1].to_uint() << 16) |
  (data[at + 2].to_uint() << 8) |
  data[at + 3].to_uint()
}

///|
fn at(data : BytesView, offset : Int32) -> BytesView? {
  if offset <= 0 || offset >= data.length() {
    None
  } else {
    Some(data[offset:])
  }
}

///|
fn at32(data : BytesView, offset : UInt32) -> BytesView? {
  if offset == 0U || offset >= data.length().reinterpret_as_uint() {
    None
  } else {
    Some(data[offset.reinterpret_as_int():])
  }
}

///|
fn count(
  data : BytesView,
  declared : Int32,
  offset : Int32,
  width : Int32,
) -> Int32 {
  if offset < 0 || offset > data.length() {
    return 0
  }
  Int32::min(declared, (data.length() - offset) / width)
}

///|
fn take(left : Ref[Int32], n : Int32) -> Bool {
  left.val -= n
  left.val >= 0
}
