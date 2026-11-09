///|
/// The file as a whole: a header and one or more segments.
///
/// ```text
/// 0x60  header      { 0x82 generation, 0x80 …, 0x83 … }
/// 0x61  segment     { 0x64 entry …, 0x63 properties, 0x68 trailer }
/// 0x61  segment     (each later save appends one)
/// ```
///
/// A save does not rewrite the file: it appends a segment with the entries
/// that are new, a complete new properties block, and a trailer whose offset
/// table lists every entry in effect (old ones included). The last trailer
/// is the current state of the document, and it is found from the end of
/// the file: the last 4 bytes give the length of the trailer's value.

///|
pub const T_HEADER : Int = 0x60

///|

///|
const T_PROPERTIES : Int = 0x63

///|
pub const T_ENTRY : Int = 0x64

///|
const T_TRAILER : Int = 0x68

///|
const T_TRAILER_OLD : Int = 0x65

///|
/// A protected document (password or certificate) stores its properties and
/// entries encrypted, under these tags instead of 0x63 / 0x64.
const T_PROPERTIES_PROTECTED : Int = 0x66

///|
const T_ENTRY_PROTECTED : Int = 0x67

///|
priv struct Trailer {
  /// Offset of the trailer's tag byte.
  at : Int
  tag : Int
  /// Number of entries in effect (0x80).
  count : Int64
  /// Absolute offsets of the entries in effect (0x81, u32 LE each).
  offsets : Array[Int]
  /// 0x8d: (entry index, check value) pairs kept by some writers.
  checks : Array[(Int, Int)]
  /// 0x82, meaning unknown; kept as stored.
  unknown82 : Bytes
  /// Size of the properties block once expanded (0x83).
  props_expanded : Int64
  /// Stored size of the properties block (0x84).
  props_stored : Int64
  /// 0x85: check value of the stored properties block.
  check : Int64
  /// Every field as stored: (tag, value bytes).
  fields : Array[(Int, Bytes)]
}

/// How an entry stores its data.
priv enum Body {
  /// `0x82 { 0x80 kind, …, 0x86 data }`: kind, every field as
  /// (tag, number if it reads as one, value range), the data field 0x86
  /// as (offset, length).
  FieldsBody(Int64?, Array[(Int, Int64?, (Int, Int))], (Int, Int)?)
  /// The value of 0x82 is the data itself: (offset, length).
  Raw(Int, Int)
}

///|
/// One entry (0x64): `0x81` check value and the `0x82` body.
priv struct Entry {
  at : Int
  len : Int
  check : Int64?
  /// The `0x82` value: (offset, length). The check value is computed
  /// over these bytes.
  body_range : (Int, Int)
  body : Body
}

///|
fn Entry::kind(self : Entry) -> Int64? {
  match self.body {
    FieldsBody(kind, _, _) => kind
    Raw(_, _) => None
  }
}

///|
fn Entry::field(self : Entry, tag : Int) -> Int64? {
  match self.body {
    FieldsBody(_, fields, _) => {
      for f in fields {
        if f.0 == tag {
          return f.1
        }
      }
      None
    }
    Raw(_, _) => None
  }
}

///|
/// The stored data (0x86, or the whole raw body).
fn Entry::data(self : Entry, b : Bytes) -> Bytes {
  match self.body {
    FieldsBody(_, _, Some((at, len))) => b[at : at + len].to_owned()
    FieldsBody(_, _, None) => b[0 : 0].to_owned()
    Raw(at, len) => b[at : at + len].to_owned()
  }
}

///|
/// The data as the program uses it: expanded when compressed.
fn Entry::expanded(self : Entry, b : Bytes, limits : Limits) -> Bytes raise XdwError {
  let d = self.data(b)
  match xdw_expanded_size(self.kind(), self.field(0x8a), self.field(0x81), d.length()) {
    Some(n) => lzh_decompress(d, n, limits)
    None => d

  }
}
///|
priv struct XdwContainer {
  size : Int
  generation : Int64?
  /// The header's raw value.
  header : (Int, Int)
  trailer : Trailer
}

///|
fn xdw_container_parse(b : Bytes, limits : Limits) -> XdwContainer raise XdwError {
  if b.length() < 24 || b[0].to_int() != T_HEADER {
    raise XdwNotFile("does not start with the DocuWorks header")
  }
  let header = tlv_read(b, 0, b.length())
  let hf = tlv_list(b, header.value, header.end())
  let generation = tlv_find_uint(hf, b, 0x82)
  let trailer = xdw_find_trailer(b)
  if xdw_is_protected(b, trailer) {
    raise XdwProtected
  }
  {
    size: b.length(),
    generation,
    header: (header.value, header.len),
    trailer,
  }
}

///|
/// Where the current properties block is stored: (value offset, length).
fn XdwContainer::properties_range(
  self : XdwContainer,
  b : Bytes,
) -> (Int, Int) raise XdwError {
  let stored = self.trailer.props_stored.to_int()
  // the block sits right before the trailer: 0x63, its length, value
  for hdr in [2, 3, 4, 5, 6] {
    let start = self.trailer.at - stored - hdr
    if start < 0 {
      continue
    }
    if b[start].to_int() != T_PROPERTIES {
      continue
    }
    match tlv_try_read(b, start, b.length()) {
      Some(t) =>
        if t.len == stored && t.end() == self.trailer.at {
          return (t.value, t.len)
        }
      None => continue
    }
  }
  raise XdwCorrupt("properties block not found before the trailer")
}

///|
/// The current properties block as stored (compressed).
fn XdwContainer::properties_stored(self : XdwContainer, b : Bytes) -> Bytes raise XdwError {
  let (at, len) = self.properties_range(b)
  b[at : at + len].to_owned()
}

///|
/// The current properties block, expanded.
fn XdwContainer::properties(
  self : XdwContainer,
  b : Bytes,
  limits : Limits,
) -> Bytes raise XdwError {
  lzh_decompress(self.properties_stored(b), self.trailer.props_expanded.to_int(), limits)
}

///|
/// Entries in effect, in table order.
fn XdwContainer::entries(
  self : XdwContainer,
  b : Bytes,
  limits : Limits,
) -> Array[Entry] raise XdwError {
  let out : Array[Entry] = []
  for o in self.trailer.offsets {
    out.push(xdw_parse_entry(b, o, limits))
  }
  out
}

///|
/// Whether stored data is compressed, and to what size. Entries say so
/// with 0x8a = 1; drawings stored inside the properties leave 0x8a out, so
/// an expanded size (0x81) larger than the data also means compressed.
/// Thumbnails (kind 7) use 0x81 for something else.
fn xdw_expanded_size(
  kind : Int64?,
  flag : Int64?,
  size : Int64?,
  stored : Int,
) -> Int? {
  match size {
    Some(n) => {
      let n = n.to_int()
      if flag is Some(1L) ||
        (kind != Some(7L) && flag is None && n > stored) {
        Some(n)
      } else {
        None
      }
    }
    None => None
  }
}

///|
/// Is the document protected? Its first entry, or the block before the
/// trailer, carries the encrypted tags.
fn xdw_is_protected(b : Bytes, t : Trailer) -> Bool {
  if t.offsets.length() > 0 {
    let o = t.offsets[0]
    match b.get(o) {
      Some(tag) => if tag.to_int() == T_ENTRY_PROTECTED {
        return true
      }
      None => ()
    }
  }
  let n = t.props_stored.to_int()
  for hdr in 2..<7 {
    let s = t.at - n - hdr
    if s < 0 {
      continue
    }
    match tlv_try_read(b, s, b.length()) {
      Some(t2) =>
        if t2.tag == T_PROPERTIES_PROTECTED && t2.end() == t.at {
          return true
        }
      None => continue
    }
  }
  false
}

///|
/// The trailer, found from the end of the file.
fn xdw_find_trailer(b : Bytes) -> Trailer raise XdwError {
  let n = b.length()
  let self_len = le_u32(b, n - 4)
  let value = n - self_len
  if value < 0 {
    raise XdwCorrupt("trailer length past the start of the file")
  }
  for hdr in 2..<7 {
    let at = value - hdr
    if at < 0 {
      // the loop stops once it would go past the start
      break
    }
    let tag = b[at].to_int()
    if tag != T_TRAILER && tag != T_TRAILER_OLD {
      continue
    }
    match tlv_try_read(b, at, n) {
      Some(t) =>
        if t.value == value && t.end() == n {
          return xdw_parse_trailer(b, t)
        }
      None => continue
    }
  }
  raise XdwNotFile("no trailer at the end of the file")
}

///|
fn le_u32(b : Bytes, at : Int) -> Int {
  b[at].to_int() |
  (b[at + 1].to_int() << 8) |
  (b[at + 2].to_int() << 16) |
  (b[at + 3].to_int() << 24)
}

///|
fn xdw_parse_trailer(b : Bytes, t : Tlv) -> Trailer raise XdwError {
  let f = tlv_list(b, t.value, t.end())
  fn le32s(x : Tlv) -> Array[Int] {
    let out : Array[Int] = []
    let v = x.bytes(b)
    let mut i = 0
    while i + 4 <= v.length() {
      out.push(le_u32(v, i))
      i += 4
    }
    out
  }
  let checks : Array[(Int, Int)] = match tlv_find(f, 0x8d) {
    Some(x) => {
      let seq = le32s(x)
      let out : Array[(Int, Int)] = []
      let mut i = 0
      while i + 2 <= seq.length() {
        out.push((seq[i], seq[i + 1]))
        i += 2
      }
      out
    }
    None => []
  }
  let fields : Array[(Int, Bytes)] = []
  for x in f {
    fields.push((x.tag, x.bytes(b)))
  }
  {
    at: t.start,
    tag: t.tag,
    count: match tlv_find_uint(f, b, 0x80) {
      Some(v) => v
      None => 0L
    },
    offsets: match tlv_find(f, 0x81) {
      Some(x) => le32s(x)
      None => []
    },
    checks,
    unknown82: match tlv_find(f, 0x82) {
      Some(x) => x.bytes(b)
      None => b[0 : 0].to_owned()
    },
    props_expanded: match tlv_find_uint(f, b, 0x83) {
      Some(v) => v
      None => 0L
    },
    props_stored: match tlv_find_uint(f, b, 0x84) {
      Some(v) => v
      None => 0L
    },
    check: match tlv_find_uint(f, b, 0x85) {
      Some(v) => v
      None => 0L
    },
    fields,
  }
}


///|
fn xdw_parse_entry(b : Bytes, at : Int, limits : Limits) -> Entry raise XdwError {
  let t : Tlv = match tlv_try_read(b, at, b.length()) {
    Some(t) => t
    None => raise XdwCorrupt("no entry at \{at}")
  }
  if t.tag != T_ENTRY {
    raise XdwCorrupt("no entry at \{at}")
  }
  let f = tlv_list(b, t.value, t.end())
  let check : Int64? = tlv_find_uint(f, b, 0x81)
  let body = match tlv_find(f, 0x82) {
    Some(v) => v
    None => raise XdwCorrupt("entry without body")
  }
  let body_flag : Bool = match b.get(body.value) {
    Some(v) => v.to_int() == 0x80
    None => false
  }
  let as_fields : Array[Tlv]? = if body_flag {
    tlv_try_list(b, body.value, body.end())
  } else {
    None
  }
  let parsed = match as_fields {
    Some(bf) =>
      FieldsBody(
        tlv_find_uint(bf, b, 0x80),
        bf.map((x : Tlv) => {
          let num : Int64? = if x.tag == 0x86 {
            None
          } else {
            x.uint(b)
          }
          (x.tag, num, (x.value, x.len))
        }),
        match tlv_find(bf, 0x86) {
          Some(v) => Some((v.value, v.len))
          None => None
        },
      )
    None => Raw(body.value, body.len)
  }
  {
    at,
    len: t.end() - at,
    check,
    body_range: (body.value, body.len),
    body: parsed,
  }
}
