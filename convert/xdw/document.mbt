///|
/// The document: pages and what sits on them, read from the object tree.
///
/// ```text
/// [0] c013 root                     (a binder .xbd has c014 → 1401 → 1402 → c013 …)
///   [1] 1303 document               lastmid
///     [2] 1301 page                 5 = size (1/100 mm), 3 = number
///       [3] 1302 placement          52 = position, childdim = size
///         [4] 8010 page content     7 = drawing (entry or inline), 61 = rotation,
///                                   58 = thumbnail, 300… = pictures for DWb
///       [3] 1302 placement
///         [4] 8011 text annotation  (and other annotation kinds)
///   [1] 1304, 1306 (attached original files), 1305
/// ```

///|
pub const K_ROOT : Int64 = 0xc013

///|
pub const K_DOCUMENT : Int64 = 0x1303

///|
pub const K_PAGE : Int64 = 0x1301

///|
pub const K_PLACE : Int64 = 0x1302

///|
pub const K_CONTENT : Int64 = 0x8010

///|
pub const K_TEXT : Int64 = 0x8011

///|
pub const K_LINE : Int64 = 0x803c

///|
pub const K_RECT : Int64 = 0x803d

///|
pub const K_ELLIPSE : Int64 = 0x803e

///|
pub const K_PICTURE : Int64 = 0x803f

///|
pub const K_CUSTOM : Int64 = 0x8045

///|
pub const K_OLE : Int64 = 0x800f

///|
pub const K_PAGEFORM : Int64 = 0x802e

///|
pub const K_STAMP : Int64 = 0x8033

///|
pub const K_FUSEN : Int64 = 0x801a

///|
pub const K_MARKER : Int64 = 0x801b

///|
pub const K_POLYGON : Int64 = 0x8042

///|
pub const K_RECEIVED : Int64 = 0x8040

///|
pub const K_LINK : Int64 = 0xc02f

///|
/// A signature (DocuWorks 電子印鑑 / PKI), placed on the page like an
/// annotation.
pub const K_SIGNATURE : Int64 = 0x8043

///|
const K_BINDER : Int64 = 0xc014

///|
const K_BINDER_LIST : Int64 = 0x1401

///|
const K_BINDER_ITEM : Int64 = 0x1402

///|
/// The UTF-16 name of a binder document.
const A_NAME_W : Int = 70

///|
/// A UTF-16 NUL-terminated LE name.
fn xdw_name_w(v : Bytes) -> String {
  let out = StringBuilder::new()
  let mut i = 0
  while i + 2 <= v.length() {
    let u = (v[i].to_int() | v[i + 1].to_int() << 8)
    if u == 0 {
      break
    }
    out.write_string(Char::from_int(u).to_string())
    i += 2
  }
  out.to_string()
}

///|
/// The name stored in a document or binder record (attribute 4). Seen:
/// document names in a binder as Shift_JIS + NUL, the binder's own name
/// as UTF-16 + one zero byte.
fn xdw_decode_name(v : Bytes) -> String {
  // UTF-16 starting with an ASCII character
  if v.length() >= 2 && v[0].to_int() != 0 && v[1].to_int() == 0 {
    return xdw_name_w(v)
  }
  let text = xdw_sjis(xdw_upto_nul(v))
  // half-width katakana in a name almost always means UTF-16 bytes read as
  // Shift_JIS (kana and kanji have 0x30… high bytes)
  let mut halfwidth = false
  for c in text.iter() {
    let n = c.to_int()
    if n >= 0xff61 && n <= 0xff9f {
      halfwidth = true
      break
    }
  }
  if !halfwidth {
    return text
  }
  xdw_name_w(v)
}

///|
/// A binder document's name: 70 (UTF-16) when there, else 4.
fn xdw_doc_name(rec : PropRecord) -> String {
  match rec.get(A_NAME_W) {
    Some(a) => xdw_name_w(a.value)
    None =>
      match rec.get(4) {
        Some(a) => xdw_decode_name(a.value)
        None => ""
      }
  }
}

///|
/// What kind of thing an object is, in words.
pub fn xdw_kind_name(k : Int64) -> String {
  match k {
    K_CONTENT => "page"
    K_TEXT => "text"
    K_LINE => "line"
    K_RECT => "rectangle"
    K_ELLIPSE => "ellipse"
    K_PICTURE => "picture"
    K_CUSTOM => "shape"
    K_OLE => "object"
    K_PAGEFORM => "header/footer"
    K_STAMP => "date stamp"
    K_FUSEN => "sticky note"
    K_MARKER => "marker"
    K_POLYGON => "polygon"
    K_RECEIVED => "received stamp"
    K_LINK => "link"
    K_SIGNATURE => "signature"
    _ => "annotation"
  }
}

///|
priv struct XdwObject {
  /// Index of the placement record (1302).
  place : Int
  /// Index of the object record.
  record : Int
  kind : Int64
  /// Position and size on the page (1/100 mm).
  x : Int64
  y : Int64
  w : Int64
  h : Int64
  /// Content rotation in degrees (page content only).
  rotation : Int64
  /// Text of a text annotation.
  text : String?
}

///|
priv struct XdwPage {
  /// Index of the page record (1301).
  record : Int
  w : Int64
  h : Int64
  objects : Array[XdwObject]
}

///|
priv struct XdwDocument {
  size : Int
  b : Bytes
  container : XdwContainer
  records : Array[PropRecord]
  entries : Array[Entry]
  /// Pages in document order.
  mut pages : Array[XdwPage]
  /// Maximum index of text kept; attribute definitions kept in entries, by
  /// record index.
  ext_defs : Map[Int, Array[PropAttrDef]]
  /// Limits for reading this document and drawing its pages.
  limits : Limits
  /// Keep text that something drawn later covers completely (a black box,
  /// an opaque picture) in the text extraction. Off by default: covered
  /// text is left out.
  mut include_hidden : Bool
}

///|
/// Open a document with the default [`Limits`].
fn xdw_open(b : Bytes) -> XdwDocument raise XdwError {
  xdw_open_with(b, Limits::default())
}

///|
/// Open a document; reading it and drawing its pages stay within `limits`.
fn xdw_open_with(b : Bytes, limits : Limits) -> XdwDocument raise XdwError {
  let container = xdw_container_parse(b, limits)
  let records = xdw_props_parse(container.properties(b, limits))
  let entries = container.entries(b, limits)
  let doc : XdwDocument = {
    size: b.length(),
    b,
    container,
    records,
    entries,
    pages: [],
    ext_defs: Map::new(),
    limits,
    include_hidden: false,
  }
  xdw_refresh(doc)
  if doc.pages.length() > limits.max_pages {
    raise XdwTooLarge(
      "\{doc.pages.length()} pages (limit maxPages \{limits.max_pages})",
    )
  }
  doc
}

///|
/// Re-read pages and definitions after the records changed.
fn xdw_refresh(doc : XdwDocument) -> Unit {
  doc.ext_defs.clear()
  for i in 0..<doc.records.length() {
    let a = doc.records[i].get(A_DEFS)
    match a {
      Some(attr) =>
        if (attr.class & 0xc0) == 0xc0 {
          // the definitions live in an entry: (entry index, offset)
          let pairs = xdw_value_ints(attr.value)
          if pairs.length() >= 2 {
            let n = pairs[0].to_int()
            let at = pairs[1].to_int()
            match doc.entry_body_at(n, at) {
              Some(body) => doc.ext_defs[i] = xdw_parse_defs(body)
              None => ()
            }
          }
        }
      None => ()
    }
  }
  doc.pages = xdw_find_pages(doc)
}

///|
/// Body of entry `n` from offset `at` within it, as raw data.
fn XdwDocument::entry_body_at(self : XdwDocument, n : Int, at : Int) -> Bytes? {
  if n < 0 || n >= self.entries.length() {
    return None
  }
  let (bo, bl) = self.entries[n].body_range
  let offset = at
  if offset < bo || offset > bo + bl {
    return None
  }
  Some(self.b[offset : bo + bl].to_owned())
}

///|
/// A record's attribute definitions (stored in it or in an entry).
fn XdwDocument::defs(self : XdwDocument, record : Int) -> Array[PropAttrDef] {
  match self.ext_defs.get(record) {
    Some(v) => v
    None =>
      if record >= 0 && record < self.records.length() {
        self.records[record].defs()
      } else {
        []
      }
  }
}

///|
/// The attribute of `record` named `name`.
fn XdwDocument::named(
  self : XdwDocument,
  record : Int,
  name : String,
) -> PropAttr? {
  let defs = self.defs(record)
  for d in defs {
    if d.name == name {
      if record >= 0 && record < self.records.length() {
        let a = self.records[record].get(d.tag)
        if a is Some(_) {
          return a
        }
      }
    }
  }
  None
}

///|
fn XdwDocument::named_ints(
  self : XdwDocument,
  record : Int,
  name : String,
) -> Array[Int64] {
  match self.named(record, name) {
    Some(a) => xdw_value_ints(a.value)
    None => []
  }
}

///|
/// Body of entry `n` (the file's own or one added since opening): the
/// stored data. `Fields` bodies when compressed keep their stored form.
fn XdwDocument::entry_data(self : XdwDocument, n : Int) -> Bytes? {
  if n < 0 || n >= self.entries.length() {
    return None
  }
  Some(self.entries[n].data(self.b))
}

///|
/// The data of entry `n` as the program uses it: expanded when compressed.
fn XdwDocument::entry_expanded(self : XdwDocument, n : Int) -> Bytes? raise {
  if n < 0 || n >= self.entries.length() {
    return None
  }
  Some(self.entries[n].expanded(self.b, self.limits))
}

///|
/// UTF-16LE text, lossy; trailing NULs are cut.
fn xdw_utf16(v : Bytes) -> String {
  let s = try @utf16.decode(v, ignore_bom=true, endianness=@utf16.Little) catch {
    _ => @utf16.decode_lossy(v, endianness=@utf16.Little)
  }
  xdw_trim_nul(s)
}

///|
/// Shift_JIS text (old ANSI text records).
fn xdw_sjis(b : Bytes) -> String {
  match @encoding.decode(b, "Shift_JIS") {
    Ok(s) => s
    Err(_) => @utf8.decode_lossy(b)
  }
}

///|
fn xdw_upto_nul(b : Bytes) -> Bytes {
  for i in 0..<b.length() {
    if b[i].to_int() == 0 {
      return b[:i].to_owned()
    }
  }
  b
}

///|
/// The documents of a binder, in order (empty for a plain document).
fn XdwDocument::binder_docs(self : XdwDocument) -> Array[(Int, String, Int, Int)] {
  if self.records.length() == 0 || self.records[0].kind_num() != K_BINDER {
    return []
  }
  let r = self.records
  let out : Array[(Int, String, Int, Int)] = []
  for i in 0..<r.length() {
    if r[i].kind_num() != K_ROOT || i == 0 {
      continue
    }
    // the end of this document's subtree: the next record at this depth
    let mut end = r.length()
    let mut k = i + 1
    while k < r.length() {
      if r[k].depth < r[i].depth {
        end = k
        break
      }
      k += 1
    }
    let mut first : Int? = None
    let mut n = 0
    for p in 0..<self.pages.length() {
      let rec = self.pages[p].record
      if rec > i && rec < end {
        if first is None {
          first = Some(p)
        }
        n += 1
      }
    }
    let start = match first {
      Some(f) => f
      None => {
        let mut carry = 0
        if out.length() > 0 {
          let last = out[out.length() - 1]
          carry = last.2 + last.3
        }
        carry
      }
    }
    out.push((i, xdw_doc_name(r[i]), start, n))
  }
  out
}

///|
/// The binder's own name.
fn XdwDocument::binder_name(self : XdwDocument) -> String? {
  if self.records.length() == 0 || self.records[0].kind_num() != K_BINDER {
    return None
  }
  match self.records[0].get(4) {
    Some(a) => Some(xdw_decode_name(a.value))
    None => Some("")
  }
}

///|
/// Pages in order (walks every document of a binder too).
fn xdw_find_pages(doc : XdwDocument) -> Array[XdwPage] {
  let r = doc.records
  let pages : Array[XdwPage] = []
  for i in 0..<r.length() {
    if r[i].kind_num() != K_PAGE {
      continue
    }
    let d = r[i].depth
    let size = r[i].ints(5)
    let objects : Array[XdwObject] = []
    let mut j = i + 1
    while j < r.length() && r[j].depth > d {
      if r[j].depth == d + 1 && r[j].kind_num() == K_PLACE {
        let pl = j
        let pos = r[j].ints(52)
        let dim = doc.named_ints(j, "childdim")
        let pl_depth = r[pl].depth
        // the first child record with the placement's depth is the object
        let mut k = j + 1
        while k < r.length() && r[k].depth > pl_depth {
          if r[k].depth == pl_depth + 1 {
            let kind = r[k].kind_num()
            let osize = r[k].ints(5)
            // a text annotation's text; a sticky note's: the text on it
            let tidx : Int? = if kind == K_TEXT {
              Some(k)
            } else if kind == K_FUSEN {
              // The note's own text is its direct child. A deeper text belongs
              // to something the note contains, so it is only a fallback.
              let mut m = k + 1
              let mut direct : Int? = None
              let mut deeper : Int? = None
              while m < r.length() && r[m].depth > r[k].depth {
                if r[m].kind_num() == K_TEXT {
                  if r[m].depth == r[k].depth + 1 {
                    direct = Some(m)
                    break
                  } else if deeper is None {
                    deeper = Some(m)
                  }
                }
                m += 1
              }
              match direct {
                Some(t) => Some(t)
                None => deeper
              }
            } else {
              None
            }
            let text : String? = match tidx {
              Some(t) =>
                match doc.named(t, "%Text(w") {
                  Some(a) => Some(xdw_utf16(a.value))
                  None =>
                    match doc.named(t, "%Text") {
                      Some(a) => Some(xdw_sjis(xdw_upto_nul(a.value)))
                      None => None
                    }
                }
              None => None
            }
            objects.push({
              place: j,
              record: k,
              kind,
              x: match pos.get(0) {
                Some(v) => v
                None => 0L
              },
              y: match pos.get(1) {
                Some(v) => v
                None => 0L
              },
              w: match dim.get(0) {
                Some(v) => v
                None =>
                  match osize.get(0) {
                    Some(v) => v
                    None => 0L
                  }
              },
              h: match dim.get(1) {
                Some(v) => v
                None =>
                  match osize.get(1) {
                    Some(v) => v
                    None => 0L
                  }
              },
              rotation: match r[k].int(61) {
                Some(v) => v
                None => 0L
              },
              text,
            })
            k = r.length()
          } else {
            k += 1
          }
        }
      }
      j += 1
    }
    pages.push({
      record: i,
      w: match size.get(0) {
        Some(v) => v
        None => 21000L
      },
      h: match size.get(1) {
        Some(v) => v
        None => 29700L
      },
      objects,
    })
  }
  pages
}
