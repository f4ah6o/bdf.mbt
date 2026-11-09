///|
/// The properties block: the document's object tree.
///
/// Once expanded, the block is a flat list of records written in tree order
/// (each record says how deep it sits):
///
/// ```text
/// 62 len {
///   80 01 depth            0 root, 1 document, 2 page, 3 placement, 4 object
///   62 len { type }        what the record is (a number, e.g. 0x8010 page body)
///   attributes …           one element each
/// }
/// ```
///
/// Attribute tags use the usual one-byte form (`83` = tag 3) or the long
/// form (`9f 8f 51` = tag 2001). Tags from 2001 up are named per record by
/// attribute 51, a list of definitions (number, type, …, name).
///
/// Numbers inside values are stored as a length byte and that many
/// big-endian two's-complement bytes; a value can hold several (a size is
/// `02 52 08 02 74 04` = 21000, 29700). Text values are stored as they are.

///|
/// Attribute 51: names for this record's attributes 2001…
pub const A_DEFS : Int = 51

///|
priv struct PropAttr {
  /// The class bits of the tag byte (0x80 context, 0xc0 private), and the
  /// "constructed" bit 0x20 as stored.
  class : Int
  tag : Int
  value : Bytes
}

///|
priv struct PropRecord {
  depth : Int
  /// The record's type as stored (big-endian bytes, sign-preserving).
  kind : Bytes
  attrs : Array[PropAttr]
}

///|
/// One attribute definition from attribute 51.
priv struct PropAttrDef {
  tag : Int
  ty : Int64
  /// -1, or a position in a list ("#pd" 101 = the 101st picture).
  index : Int64
  name : String
}

///|
/// Read definitions: groups of five items (number, type, index, name
/// length, name). Large lists are kept in an entry of their own and the
/// attribute then holds a reference to it.
fn xdw_parse_defs(v : Bytes) -> Array[PropAttrDef] {
  let items = xdw_value_items(v)
  let out : Array[PropAttrDef] = []
  let mut i = 0
  while i + 5 <= items.length() {
    out.push({
      tag: xdw_num(items[i]).to_int(),
      ty: xdw_num(items[i + 1]),
      index: xdw_num(items[i + 2]),
      name: xdw_trim_nul(xdw_lossy(items[i + 4])),
    })
    i += 5
  }
  out
}

///|
fn PropRecord::kind_num(self : PropRecord) -> Int64 {
  xdw_num(self.kind)
}

///|
fn PropRecord::get(self : PropRecord, tag : Int) -> PropAttr? {
  for a in self.attrs {
    if a.tag == tag {
      return Some(a)
    }
  }
  None
}

///|
/// The definitions from attribute 51 (when stored in the record).
fn PropRecord::defs(self : PropRecord) -> Array[PropAttrDef] {
  match self.get(A_DEFS) {
    Some(a) => if (a.class & 0xc0) != 0xc0 {
      xdw_parse_defs(a.value)
    } else {
      []
    }
    None => []
  }
}

///|
/// The attribute named `name` (through the definitions).
fn PropRecord::named(self : PropRecord, name : String) -> PropAttr? {
  for d in self.defs() {
    if d.name == name {
      let a = self.get(d.tag)
      if a is Some(_) {
        return a
      }
    }
  }
  None
}

///|
///|
/// The numbers stored in attribute `tag`.
fn PropRecord::ints(self : PropRecord, tag : Int) -> Array[Int64] {
  match self.get(tag) {
    Some(a) => xdw_value_ints(a.value)
    None => []
  }
}

///|
fn PropRecord::int(self : PropRecord, tag : Int) -> Int64? {
  match self.get(tag) {
    Some(a) =>
      match xdw_value_ints(a.value).get(0) {
        Some(v) => Some(v)
        None => None
      }
    None => None
  }
}

///|
/// The numbers stored in the attribute named `name`.
fn PropRecord::named_ints(self : PropRecord, name : String) -> Array[Int64] {
  match self.named(name) {
    Some(a) => xdw_value_ints(a.value)
    None => []
  }
}

///|
/// A big-endian two's-complement number.
fn xdw_num(b : Bytes) -> Int64 {
  if b.is_empty() || b.length() > 8 {
    return 0L
  }
  let neg = (b[0].to_int() & 0x80) != 0
  let mut acc : Int64 = if neg { -1L } else { 0L }
  for x in b {
    acc = (acc << 8) | x.to_int().to_int64()
  }
  acc
}

/// The lossy UTF-8 text of `b` (text values are stored as they are).
fn xdw_lossy(b : Bytes) -> String {
  @utf8.decode_lossy(b)
}

///|
fn xdw_depth(b : Bytes, at : Int, end : Int) -> (Int, Int, Int, Int) raise XdwError {
  let (_, tag, v, len, e) = xdw_element5(b, at, end)
  (tag, v, len, e)
}

///|
/// Drop the trailing NUL characters.
fn xdw_trim_nul(s : String) -> String {
  let n = s.length()
  let mut end = n
  while end > 0 && s[end - 1] == '\x00' {
    end -= 1
  }
  if end == n {
    s
  } else {
    s.substring(start=0, end=end)
  }
}

///|
/// Split a value into its length-prefixed items.
fn xdw_value_items(v : Bytes) -> Array[Bytes] {
  let out : Array[Bytes] = []
  let mut i = 0
  while i < v.length() {
    let n = v[i].to_int()
    if i + 1 + n > v.length() {
      break
    }
    out.push(v[i + 1 : i + 1 + n].to_owned())
    i += 1 + n
  }
  out
}

///|
/// The numbers of a value made of length-prefixed items.
fn xdw_value_ints(v : Bytes) -> Array[Int64] {
  xdw_value_items(v).map(xdw_num)
}

///|
/// Encode numbers as length-prefixed items.
/// One element as stored: (class byte, tag number, value offset,
/// length, end).
fn xdw_element5(b : Bytes, at : Int, end : Int) -> (Int, Int, Int, Int, Int) raise XdwError {
  let mut i = at
  let first = match b.get(i) {
    Some(v) => v.to_int()
    None => raise xdw_bad(at)
  }
  i += 1
  let mut tag = first & 0x1f
  if tag == 0x1f {
    tag = 0
    while true {
      let x = match b.get(i) {
        Some(v) => v.to_int()
        None => raise xdw_bad(at)
      }
      i += 1
      tag = (tag << 7) | (x & 0x7f)
      if (x & 0x80) == 0 {
        break
      }
    }
  }
  let (len, after) = xdw_read_len(b, i)
  if after + len > end {
    raise xdw_bad(at)
  }
  (first & 0xe0, tag, after, len, after + len)
}

///|
fn xdw_bad(at : Int) -> XdwError {
  XdwCorrupt("properties: bad element at \{at}")
}

fn xdw_read_len(b : Bytes, i : Int) -> (Int, Int) raise XdwError {
  let n = match b.get(i) {
    Some(v) => v.to_int()
    None => raise xdw_bad(i)
  }
  let k = i + 1
  if n < 0x80 {
    return (n, k)
  }
  let width = n & 0x7f
  if width == 0 || width > 4 || k + width > b.length() {
    raise xdw_bad(i)
  }
  let mut v = 0
  for x in b[k : k + width] {
    v = (v << 8) | x.to_int()
  }
  (v, k + width)
}

///|
fn xdw_props_parse(b : Bytes) -> Array[PropRecord] raise XdwError {
  let out : Array[PropRecord] = []
  let mut i = 0
  while i < b.length() {
    let (class, tag, v, len, end) = xdw_element5(b, i, b.length())
    if tag != 2 || class != 0x60 {
      raise xdw_bad(i)
    }
    // depth
    let (t0, v0, l0, e0) = xdw_depth(b, v, end)
    if t0 != 0 || l0 != 1 {
      raise xdw_bad(v)
    }
    let depth = b[v0].to_int()
    // type
    let (c1, t1, v1, l1, e1) = xdw_element5(b, e0, end)
    if t1 != 2 || c1 != 0x60 {
      raise xdw_bad(e0)
    }
    let kind = b[v1 : v1 + l1].to_owned()
    let attrs : Array[PropAttr] = []
    let mut j = e1
    while j < end {
      let (c, t, va, la, ea) = xdw_element5(b, j, end)
      attrs.push({ class: c, tag: t, value: b[va : va + la].to_owned() })
      j = ea
    }
    out.push({ depth, kind, attrs })
    i = end
  }
  out
}
