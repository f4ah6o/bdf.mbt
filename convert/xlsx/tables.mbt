///|
/// An XLSX ListObject and its column names, before header/totals are removed.
pub(all) struct XlsxListTable {
  range : XlsxRange
  name : String
  columns : Array[String]
  header_rows : Int32
  totals_rows : Int32
}

///|
fn xlsx_read_list_table(data : Bytes) -> XlsxListTable? raise {
  let text = @utf8.decode_lossy(data[:], ignore_bom=true)
  if text.contains("<!ENTITY") {
    raise InvalidXlsxInput("xlsx: the part declares entities")
  }
  let reader = @xml.NamespaceReader::from_string(text)
  let mut range : XlsxRange? = None
  let mut name = ""
  let mut header = 1
  let mut totals = 0
  let columns : Array[String] = []
  let mut depth = 0
  let mut columns_depth = -1
  let mut seen_columns = false
  while true {
    let event = reader.read_event()
    match event.kind {
      Start(element) | Empty(element) => {
        let local = element.name.local_name
        if depth == 0 {
          range = xlsx_parse_range(xlsx_attr(element, "ref", ""))
          name = xlsx_decode_string(xlsx_attr(element, "displayName", ""))
          if name == "" {
            name = xlsx_decode_string(xlsx_attr(element, "name", ""))
          }
          header = xlsx_node_int(element, "headerRowCount", 1)
          totals = xlsx_node_int(element, "totalsRowCount", 0)
        } else if depth == 1 && local == "tableColumns" && !seen_columns {
          seen_columns = true
          if event.kind is Start(_) {
            columns_depth = depth + 1
          }
        } else if depth == columns_depth && local == "tableColumn" {
          columns.push(xlsx_decode_string(xlsx_attr(element, "name", "")))
        }
        if event.kind is Start(_) {
          depth += 1
        } else if depth == 0 {
          break
        }
      }
      End(_) => {
        depth -= 1
        if depth + 1 == columns_depth {
          columns_depth = -1
        }
        if depth == 0 {
          break
        }
      }
      Eof =>
        if depth == 0 {
          break
        } else {
          raise InvalidXlsxInput("xlsx: unexpected EOF")
        }
      _ => ()
    }
  }
  match range {
    Some(r) =>
      Some({
        range: r,
        name,
        columns,
        header_rows: header,
        totals_rows: totals,
      })
    None => None
  }
}

///|
/// Read the table parts referenced by a worksheet, skipping missing or invalid parts.
pub fn XlsxWorkbook::read_sheet_tables(
  self : XlsxWorkbook,
  part : String,
) -> Array[XlsxListTable] raise {
  let data = self.package.read(part) catch {
    @ooxml.InvalidOoxml(message) => raise InvalidXlsxInput(message)
  }
  let text = @utf8.decode_lossy(data[:], ignore_bom=true)
  if text.contains("<!ENTITY") {
    raise InvalidXlsxInput("xlsx: the part declares entities")
  }
  let reader = @xml.NamespaceReader::from_string(text)
  let refs : Array[String] = []
  let mut depth = 0
  let mut table_depth = -1
  while true {
    let event = reader.read_event()
    match event.kind {
      Start(element) | Empty(element) => {
        let name = element.name.local_name
        if depth == 1 && name == "tableParts" {
          if event.kind is Start(_) {
            table_depth = depth + 1
          }
        } else if depth == table_depth && name == "tablePart" {
          refs.push(xlsx_rel_id(element, "id"))
        }
        if event.kind is Start(_) {
          depth += 1
        } else if depth == 0 {
          break
        }
      }
      End(_) => {
        depth -= 1
        if depth + 1 == table_depth {
          table_depth = -1
        }
        if depth == 0 {
          break
        }
      }
      Eof =>
        if depth == 0 {
          break
        } else {
          raise InvalidXlsxInput("xlsx: unexpected EOF")
        }
      _ => ()
    }
  }
  let out : Array[XlsxListTable] = []
  for id in refs {
    let rel = match self.package.target(part, id) {
      Some(r) => r
      None => continue
    }
    let bytes = self.package.read(rel.target) catch { _ => continue }
    let table = xlsx_read_list_table(bytes) catch { _ => None }
    match table {
      Some(table) => out.push(table)
      None => ()
    }
  }
  out
}
