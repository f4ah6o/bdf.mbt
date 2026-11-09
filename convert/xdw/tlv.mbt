///|
/// tag-length-value elements, every part of a `.xdw` is made of.
///
/// One tag byte, then a length in the short form (`< 0x80`: the length
/// itself) or the long form (`0x80 | k`, then `k` big-endian bytes), then
/// the value. Values of the context tags (`0x80`…) are often lists of
/// elements again.

///|
priv struct Tlv {
  tag : Int
  /// Offset of the tag byte.
  start : Int
  /// Offset of the first value byte.
  value : Int
  len : Int
}

///|
fn Tlv::end(self : Tlv) -> Int {
  self.value + self.len
}

///|
fn Tlv::bytes(self : Tlv, b : Bytes) -> Bytes {
  b[self.value : self.end()].to_owned()
}

///|
/// The value as a number. Numbers are stored like ASN.1 INTEGERs: the
/// fewest big-endian bytes in two's complement, so `00 c0 13` is 49171
/// and `a1 b1 ae` is negative. Returns the value sign-extended to 64
/// bits, reinterpreted as signed; use the low 32 bits for check values.
fn Tlv::uint(self : Tlv, b : Bytes) -> Int64? {
  if self.len == 0 || self.len > 9 {
    return None
  }
  if self.len == 9 && b[self.value].to_int() != 0 {
    return None
  }
  let neg = (b[self.value].to_int() & 0x80) != 0
  let mut acc : Int64 = if neg { -1L } else { 0L }
  for x in b[self.value : self.end()] {
    acc = (acc << 8) | x.to_int().to_int64()
  }
  Some(acc)
}

///|
/// One element at `at`, which must end at or before `limit`.
fn tlv_read(b : Bytes, at : Int, limit : Int) -> Tlv raise XdwError {
  let bad = (what : String) => XdwCorrupt("\{what} at offset \{at}")
  let tag : Int = match b.get(at) {
    Some(v) => v.to_int()
    None => raise bad("missing tag")
  }
  let n : Int = match b.get(at + 1) {
    Some(v) => v.to_int()
    None => raise bad("missing length")
  }
  let (len, value) = if n < 0x80 {
    (n, at + 2)
  } else {
    let k = n & 0x7f
    if k == 0 || k > 4 {
      raise bad("bad length form")
    }
    let bytes = b[at + 2 : at + 2 + k]
    let mut v = 0
    for x in bytes {
      v = (v << 8) | x.to_int()
    }
    (v, at + 2 + k)
  }
  if value + len > limit.min(b.length()) {
    raise bad("element runs past its parent")
  }
  { tag, start: at, value, len }
}

///|
/// All elements packed in `b[start..end]`.
fn tlv_list(b : Bytes, start : Int, end : Int) -> Array[Tlv] raise XdwError {
  let out : Array[Tlv] = []
  let mut i = start
  while i < end {
    let t = tlv_read(b, i, end)
    i = t.end()
    out.push(t)
  }
  out
}

///|
fn tlv_find(items : Array[Tlv], tag : Int) -> Tlv? {
  for t in items {
    if t.tag == tag {
      return Some(t)
    }
  }
  None
}

///|
fn tlv_find_uint(items : Array[Tlv], b : Bytes, tag : Int) -> Int64? {
  match tlv_find(items, tag) {
    Some(t) => t.uint(b)
    None => None
  }
}

///|
fn tlv_try_read(b : Bytes, at : Int, limit : Int) -> Tlv? {
  try Some(tlv_read(b, at, limit)) catch {
    e => {
      ignore(e)
      None
    }
  }
}

///|
fn tlv_try_list(b : Bytes, start : Int, end : Int) -> Array[Tlv]? {
  try Some(tlv_list(b, start, end)) catch {
    e => {
      ignore(e)
      None
    }
  }
}
