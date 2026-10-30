///|
// The upstream reader uses the first comments relationship and paints a
// corner marker for each distinct valid cell reference. Invalid comment XML
// is ignored. Multiple distinct notes need stable upstream drawing order.
fn XlsxWorkbook::xlsx_plain_notes(
  self : XlsxWorkbook,
  part : String,
) -> Array[(Int32, Int32)] raise {
  let rel = match self.package.relationship_of_type(part, "/comments") {
    Some(rel) => rel
    None => return []
  }
  let data = self.package.read(rel.target) catch { _ => return [] }
  let text = @utf8.decode(data, ignore_bom=true) catch { _ => return [] }
  let reader = @xml.NamespaceReader::from_string(text)
  let mut depth = 0
  let mut list_depth = -1
  let mut seen_list = false
  let mut first : (Int32, Int32)? = None
  let mut multiple = false
  while true {
    let event = reader.read_event() catch { _ => return [] }
    match event.kind {
      Start(element) | Empty(element) => {
        let name = element.name.local_name
        if depth == 1 && name == "commentList" && !seen_list {
          seen_list = true
          if event.kind is Start(_) {
            list_depth = depth + 1
          }
        } else if depth == list_depth && name == "comment" {
          let (column, row, valid) = xlsx_parse_ref(
            xlsx_attr(element, "ref", ""),
          )
          if valid {
            match first {
              None => first = Some((row, column))
              Some((previous_row, previous_column)) =>
                if row != previous_row || column != previous_column {
                  multiple = true
                }
            }
          }
        }
        if event.kind is Start(_) {
          depth += 1
        } else if depth == 0 {
          break
        }
      }
      End(_) => {
        depth -= 1
        if depth + 1 == list_depth {
          list_depth = -1
        }
        if depth == 0 {
          break
        }
      }
      Eof => if depth == 0 { break } else { return [] }
      _ => ()
    }
  }
  if multiple {
    raise InvalidXlsxInput(
      "xlsx: plain conversion does not support multiple comments",
    )
  }
  match first {
    Some(note) => [note]
    None => []
  }
}
