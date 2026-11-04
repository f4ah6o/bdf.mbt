///|
/// `showValue="0"` hides the numbers of cells covered by a data-bar or
/// icon-set conditional format.
fn XlsxWorkbook::xlsx_hidden_values(
  self : XlsxWorkbook,
  part : String,
  rows : Array[XlsxRow],
) -> Map[Int32, Map[Int32, Bool]] raise {
  let result : Map[Int32, Map[Int32, Bool]] = Map([])
  let bytes = self.package.read(part) catch { _ => return result }
  let text = @utf8.decode_lossy(bytes[:], ignore_bom=true)
  if text.contains("<!ENTITY") {
    return result
  }
  let reader = @xml.NamespaceReader::from_string(text)
  let mut depth = 0
  let mut conditional_depth = -1
  let mut rule_depth = -1
  let mut child_depth = -1
  let mut sqref = ""
  let mut hide = false
  while true {
    let event = reader.read_event()
    match event.kind {
      Start(element) | Empty(element) => {
        let name = element.name.local_name
        if depth == 1 && name == "conditionalFormatting" {
          conditional_depth = depth
          sqref = xlsx_attr(element, "sqref", "")
        } else if conditional_depth >= 0 &&
          depth == conditional_depth + 1 &&
          name == "cfRule" &&
          ["dataBar", "iconSet"].contains(xlsx_attr(element, "type", "")) {
          rule_depth = depth
          hide = false
        } else if rule_depth >= 0 &&
          depth == rule_depth + 1 &&
          (name == "dataBar" || name == "iconSet") {
          hide = ["0", "false", "off"].contains(xlsx_attr(element, "showValue", "1"))
          if event.kind is Start(_) {
            child_depth = depth
          }
        }
        if event.kind is Start(_) {
          depth += 1
        } else if depth == 0 {
          break
        }
      }
      End(_) => {
        if child_depth >= 0 && depth == child_depth {
          if hide {
            for item in sqref.split(" ") {
              match xlsx_parse_range(item.to_owned()) {
                Some(range) =>
                  for row in rows {
                    if row.index.to_int64() < range.row_start ||
                      row.index.to_int64() > range.row_end {
                      continue
                    }
                    for cell in row.cells {
                      if cell.kind == 1 &&
                        cell.column >= range.column_start &&
                        cell.column <= range.column_end {
                        let columns = match result.get(row.index) {
                          Some(value) => value
                          None => {
                            let value : Map[Int32, Bool] = Map([])
                            result[row.index] = value
                            value
                          }
                        }
                        columns[cell.column] = true
                      }
                    }
                  }
                None => ()
              }
            }
          }
          child_depth = -1
        } else if rule_depth >= 0 && depth == rule_depth {
          rule_depth = -1
        } else if conditional_depth >= 0 && depth == conditional_depth {
          conditional_depth = -1
        }
        depth -= 1
      }
      Eof => break
      _ => ()
    }
  }
  result
}