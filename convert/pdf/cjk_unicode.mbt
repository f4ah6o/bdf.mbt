///|
priv struct PdfCjkUnicodeEntry {
  code : Int64
  vertical : Bool
  rank : Int64
}

///|
priv struct PdfCjkUnicodeTable {
  entries : Map[Int64, PdfCjkUnicodeEntry]
  vertical_forms : Map[Int64, Int64]
}

///|
let pdf_cjk_unicode_tables : Map[String, PdfCjkUnicodeTable] = Map([])

///|
fn pdf_cjk_unicode_sources(collection : String) -> Array[String] {
  match collection {
    "Adobe-Japan1" =>
      [
        "UniJIS-UTF32-H", "UniJIS2004-UTF32-H", "UniJISX0213-UTF32-H", "UniJISX02132004-UTF32-H",
        "UniJIS-UCS2-HW-H", "UniJIS-UTF32-V", "UniJIS2004-UTF32-V", "UniJISX0213-UTF32-V",
        "UniJISX02132004-UTF32-V", "UniJIS-UCS2-HW-V",
      ]
    "Adobe-Japan2" => ["UniHojo-UTF32-H", "UniHojo-UTF32-V"]
    "Adobe-GB1" => ["UniGB-UTF32-H", "UniGB-UTF32-V"]
    "Adobe-CNS1" => ["UniCNS-UTF32-H", "UniCNS-UTF32-V"]
    "Adobe-Korea1" => ["UniKS-UTF32-H", "UniKS-UTF32-V"]
    _ => []
  }
}

///|
fn pdf_cjk_char_class(code : Int64) -> Int64 {
  if code >= 0x20L && code < 0x7fL {
    0L
  } else if (code >= 0xfe10L && code <= 0xfe19L) ||
    (code >= 0xfe30L && code <= 0xfe4fL) {
    2L
  } else if (code >= 0xf900L && code <= 0xfaffL) ||
    (code >= 0x2f800L && code <= 0x2fa1fL) ||
    (code >= 0x2e80L && code <= 0x2fdfL) {
    3L
  } else if (code >= 0xe000L && code <= 0xf8ffL) || code >= 0xf0000L {
    4L
  } else {
    1L
  }
}

///|
fn pdf_cjk_unicode_table(collection : String) -> PdfCjkUnicodeTable? {
  match pdf_cjk_unicode_tables.get(collection) {
    Some(table) => return Some(table)
    None => ()
  }
  let sources = pdf_cjk_unicode_sources(collection)
  if sources.is_empty() {
    return None
  }
  let table : PdfCjkUnicodeTable = {
    entries: Map([]),
    vertical_forms: Map([]),
  }
  for priority, name in sources {
    match pdf_cjk_maps.get(name) {
      None => ()
      Some(map) => {
        let vertical = name.has_suffix("-V")
        for range in map.ranges {
          let mut offset = 0L
          while offset <= range.high - range.low {
            let code = range.low + offset
            let cid = range.cid + offset
            if cid < 0x20000L && code <= 0x10ffffL {
              let class = pdf_cjk_char_class(code)
              if class == 2L && !table.vertical_forms.contains(cid) {
                table.vertical_forms[cid] = code
              }
              let rank = (class << 48) | (priority.to_int64() << 32) | code
              match table.entries.get(cid) {
                Some(old) =>
                  if rank < old.rank {
                    table.entries[cid] = { code, vertical, rank, }
                  }
                None => table.entries[cid] = { code, vertical, rank, }
              }
            }
            offset += 1L
          }
        }
      }
    }
  }
  pdf_cjk_unicode_tables[collection] = table
  Some(table)
}

///|
fn pdf_cjk_unicode(collection : String, cid : Int64) -> (Int64, Bool)? {
  match pdf_cjk_unicode_table(collection) {
    Some(table) =>
      match table.entries.get(cid) {
        Some(entry) =>
          if entry.code == 0L && !entry.vertical {
            None
          } else {
            Some((entry.code, entry.vertical))
          }
        None => None
      }
    None => None
  }
}

///|
fn pdf_cjk_vertical_form(collection : String, cid : Int64) -> Int64? {
  match pdf_cjk_unicode_table(collection) {
    Some(table) => table.vertical_forms.get(cid)
    None => None
  }
}
