///|
fn xlsx_text_element(reader : @xml.NamespaceReader) -> String raise {
  let text = StringBuilder()
  let mut depth = 1
  while depth > 0 {
    let event = reader.read_event()
    match event.kind {
      Start(_) => depth += 1
      End(_) => depth -= 1
      Text(value) | CData(value) => if depth == 1 { text.write_string(value) }
      Eof => raise InvalidXlsxInput("xlsx: unexpected EOF")
      _ => ()
    }
  }
  text.to_string()
}

///|
fn xlsx_rich_text(reader : @xml.NamespaceReader) -> String raise {
  let (plain, _, _) = xlsx_rich_text_info(reader)
  plain
}

///|
// Keep the plain value for formulas and data extraction, and the run-only
// text for drawing when the source contains multiple runs.
fn xlsx_rich_text_info(
  reader : @xml.NamespaceReader,
) -> (String, String, Bool) raise {
  let out = StringBuilder()
  let runs = StringBuilder()
  let mut depth = 1
  let mut run_depth = -1
  let mut run_count = 0
  while depth > 0 {
    let event = reader.read_event()
    match event.kind {
      Start(element) | Empty(element) => {
        let name = element.name.local_name
        if name == "r" && depth == 1 && event.kind is Start(_) {
          run_depth = 2
          run_count += 1
        }
        if name == "t" && (depth == 1 || depth == run_depth) {
          let text = if event.kind is Start(_) {
            xlsx_text_element(reader)
          } else {
            ""
          }
          let text = xlsx_decode_string(text)
          out.write_string(text)
          if depth == run_depth {
            runs.write_string(text)
          }
        } else if event.kind is Start(_) {
          depth += 1
        }
      }
      End(_) => {
        depth -= 1
        if depth < run_depth {
          run_depth = -1
        }
      }
      Eof => raise InvalidXlsxInput("xlsx: unexpected EOF")
      _ => ()
    }
  }
  (out.to_string(), runs.to_string(), run_count > 1)
}

///|
fn XlsxWorkbook::xlsx_shared_run_texts(self : XlsxWorkbook) -> Array[String?] {
  let rel = match
    self.package.relationship_of_type(self.part, "/sharedStrings") {
    Some(rel) => rel
    None => return []
  }
  let bytes = self.package.read(rel.target) catch { _ => return [] }
  let text = @utf8.decode_lossy(bytes[:], ignore_bom=true)
  let reader = @xml.NamespaceReader::from_string(text)
  let result : Array[String?] = []
  let mut depth = 0
  while true {
    let event = reader.read_event() catch { _ => return [] }
    match event.kind {
      Start(element) | Empty(element) =>
        if depth == 1 && element.name.local_name == "si" {
          if event.kind is Start(_) {
            let (_, runs, multiple) = xlsx_rich_text_info(reader) catch {
              _ => return []
            }
            result.push(if multiple { Some(runs) } else { None })
          } else {
            result.push(None)
          }
        } else if event.kind is Start(_) {
          depth += 1
        }
      End(_) => {
        depth -= 1
        if depth == 0 {
          break
        }
      }
      Eof => if depth == 0 { break } else { return [] }
      _ => ()
    }
  }
  result
}

///|
/// Load the workbook's shared strings as displayed text.
/// A missing or invalid string table is treated as empty, as in upstream.
pub fn XlsxWorkbook::shared_strings(self : XlsxWorkbook) -> Array[String] {
  self.load_shared_strings().copy()
}

///|
fn XlsxWorkbook::load_shared_strings(self : XlsxWorkbook) -> Array[String] {
  if self.cached_shared_strings is Some(strings) {
    return strings
  }
  let strings = self.parse_shared_strings()
  self.cached_shared_strings = Some(strings)
  strings
}

///|
fn XlsxWorkbook::parse_shared_strings(self : XlsxWorkbook) -> Array[String] {
  let rel = match
    self.package.relationship_of_type(self.part, "/sharedStrings") {
    Some(rel) => rel
    None => return []
  }
  let data = self.package.read(rel.target) catch { _ => return [] }
  let text = @utf8.decode_lossy(data[:], ignore_bom=true)
  if text.contains("<!ENTITY") {
    return []
  }
  let reader = @xml.NamespaceReader::from_string(text)
  let result : Array[String] = []
  let mut depth = 0
  while true {
    let event = reader.read_event() catch { _ => return [] }
    match event.kind {
      Start(element) | Empty(element) =>
        if depth == 1 && element.name.local_name == "si" {
          if event.kind is Start(_) {
            result.push(xlsx_rich_text(reader) catch { _ => return [] })
          } else {
            result.push("")
          }
        } else if event.kind is Start(_) {
          depth += 1
        } else if depth == 0 {
          return result
        }
      End(_) => {
        depth -= 1
        if depth == 0 {
          return result
        }
      }
      Eof => return result
      _ => ()
    }
  }
  result
}
