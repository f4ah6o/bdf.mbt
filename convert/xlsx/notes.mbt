///|
// The upstream reader uses the first comments relationship and paints a
// corner marker for each distinct valid cell reference. Invalid comment XML
// is ignored. Sort markers for deterministic output; their opaque shapes can
// be drawn in any order.
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
  let notes : Array[(Int32, Int32)] = []
  let seen : Map[Int32, Map[Int32, Bool]] = Map([])
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
            let columns = match seen.get(row) {
              Some(columns) => columns
              None => {
                let columns : Map[Int32, Bool] = Map([])
                seen[row] = columns
                columns
              }
            }
            if !columns.contains(column) {
              columns[column] = true
              notes.push((row, column))
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
  notes.sort_by((a, b) => {
    if a.0 != b.0 {
      a.0.compare(b.0)
    } else {
      a.1.compare(b.1)
    }
  })
  notes
}
