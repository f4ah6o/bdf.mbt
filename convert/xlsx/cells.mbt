///|
/// A cell as stored in a worksheet: blank, number, string, boolean or error.
pub(all) struct XlsxCell {
  column : Int32
  style : Int32
  kind : Int32
  number : Double
  text : String
}

///|
/// A worksheet row and its stored cells, in file order.
pub(all) struct XlsxRow {
  index : Int32
  height : Double
  custom_height : Bool
  hidden : Bool
  style : Int32
  cells : Array[XlsxCell]
}

///|
/// The rows parsed from a worksheet and the count of uncached formulas.
pub(all) struct XlsxSheetCells {
  rows : Array[XlsxRow]
  missing_formula_values : Int32
}

///|
fn xlsx_int(value : String) -> Int64? {
  let data = @utf8.encode(value)
  let mut i = if data.length() > 0 && (data[0] == b'+' || data[0] == b'-') {
    1
  } else {
    0
  }
  if i == data.length() {
    return None
  }
  while i < data.length() {
    if data[i] < b'0' || data[i] > b'9' {
      return None
    }
    i += 1
  }
  Some(@string.parse_int64(value)) catch {
    _ => None
  }
}

///|
fn xlsx_attr_int(
  element : @xml.NamespaceElement,
  name : String,
  default : Int32,
) -> Int32 {
  match xlsx_int(xlsx_attr(element, name, "")) {
    Some(n) =>
      if n >= -2147483648L && n <= 2147483647L {
        n.to_int()
      } else {
        default
      }
    None => default
  }
}

///|
fn xlsx_attr_bool(element : @xml.NamespaceElement, name : String) -> Bool {
  ["1", "true", "on"].contains(xlsx_trim(xlsx_attr(element, name, "")))
}

///|
fn xlsx_cell_value(
  typ : String,
  value : String,
  inline : String?,
  strings : Array[String],
  date1904 : Bool,
) -> (Int32, Double, String) {
  match typ {
    "s" =>
      match xlsx_int(xlsx_trim(value)) {
        Some(i) =>
          if i >= 0L && i < strings.length().to_int64() {
            (2, 0.0, strings[i.to_int()])
          } else {
            (0, 0.0, "")
          }
        None => (0, 0.0, "")
      }
    "inlineStr" =>
      match inline {
        Some(text) => (2, 0.0, text)
        None => if value != "" { (2, 0.0, value) } else { (0, 0.0, "") }
      }
    "str" => (2, 0.0, xlsx_decode_string(value))
    "b" => {
      let v = xlsx_trim(value)
      (3, if v == "1" || v.to_lower() == "true" { 1.0 } else { 0.0 }, "")
    }
    "e" => (4, 0.0, xlsx_trim(value))
    "d" =>
      match xlsx_iso_serial(xlsx_trim(value), date1904) {
        Some(v) => (1, v, "")
        None => (0, 0.0, "")
      }
    _ => {
      let trimmed = xlsx_trim(value)
      if trimmed == "" {
        return (0, 0.0, "")
      }
      let number = @string.parse_double(trimmed) catch {
        _ => return (0, 0.0, "")
      }
      (1, number, "")
    }
  }
}

///|
fn xlsx_read_cell(
  reader : @xml.NamespaceReader,
  element : @xml.NamespaceElement,
  empty : Bool,
  column : Int32,
  strings : Array[String],
  date1904 : Bool,
) -> (XlsxCell, Bool) raise {
  let reference = xlsx_attr(element, "r", "")
  let (c, _, valid) = xlsx_parse_ref(reference)
  let column = if valid { c } else { column }
  let style = xlsx_attr_int(element, "s", 0)
  let typ = xlsx_attr(element, "t", "n")
  let mut value = ""
  let mut inline : String? = None
  let mut has_formula = false
  let mut has_value = false
  let mut depth = if empty { 0 } else { 1 }
  while depth > 0 {
    let event = reader.read_event()
    match event.kind {
      Start(child) | Empty(child) =>
        if depth == 1 && child.name.local_name == "v" {
          value = if event.kind is Start(_) {
            xlsx_text_element(reader)
          } else {
            ""
          }
          has_value = true
        } else if depth == 1 && child.name.local_name == "is" {
          inline = Some(
            if event.kind is Start(_) {
              xlsx_rich_text(reader)
            } else {
              ""
            },
          )
          has_value = true
        } else {
          if depth == 1 && child.name.local_name == "f" {
            has_formula = true
          }
          if event.kind is Start(_) {
            depth += 1
          }
        }
      End(_) => depth -= 1
      Eof => raise InvalidXlsxInput("xlsx: unexpected EOF")
      _ => ()
    }
  }
  let (kind, number, text) = xlsx_cell_value(
    typ, value, inline, strings, date1904,
  )
  (
    { column, style, kind, number, text, },
    has_formula && (!has_value || (xlsx_trim(value) == "" && inline is None)),
  )
}

///|
/// Read the row and cell data from a workbook sheet, retaining file order.
pub fn XlsxWorkbook::read_sheet_cells(
  self : XlsxWorkbook,
  part : String,
) -> XlsxSheetCells raise {
  let bytes = self.package.read(part) catch {
    @ooxml.InvalidOoxml(message) => raise InvalidXlsxInput(message)
  }
  let text = @utf8.decode_lossy(bytes[:], ignore_bom=true)
  if text.contains("<!ENTITY") {
    raise InvalidXlsxInput("ooxml: the part declares entities")
  }
  let reader = @xml.NamespaceReader::from_string(text)
  let strings = self.load_shared_strings()
  let rows : Array[XlsxRow] = []
  let mut missing = 0
  let mut depth = 0
  let mut data_depth = -1
  let mut row_depth = -1
  let mut next_row = 0
  let mut next_col = 0
  while true {
    let event = reader.read_event()
    match event.kind {
      Start(element) | Empty(element) => {
        let name = element.name.local_name
        if depth == 1 && name == "sheetData" {
          next_row = 0
          if event.kind is Start(_) {
            data_depth = depth + 1
          }
        } else if depth == data_depth && name == "row" {
          let raw = xlsx_int(xlsx_attr(element, "r", ""))
          let index = match raw {
            Some(n) =>
              if n >= 1L {
                Int64::min(n, 1048576L).to_int() - 1
              } else {
                Int32::min(next_row, 1048575)
              }
            None => Int32::min(next_row, 1048575)
          }
          let raw_height = xlsx_attr(element, "ht", "")
          let h = @string.parse_double(raw_height) catch { _ => -1.0 }
          let height = if h.is_nan() || h.is_inf() || h < 0.0 {
            -1.0
          } else {
            Double::min(h, 409.5)
          }
          let style = if xlsx_attr_bool(element, "customFormat") {
            xlsx_attr_int(element, "s", -1)
          } else {
            -1
          }
          rows.push({
            index,
            height,
            custom_height: xlsx_attr_bool(element, "customHeight"),
            hidden: xlsx_attr_bool(element, "hidden"),
            style,
            cells: [],
          })
          next_row = index + 1
          next_col = 0
          if event.kind is Start(_) {
            row_depth = depth + 1
          }
        } else if depth == row_depth && name == "c" && !rows.is_empty() {
          let (cell, no_value) = xlsx_read_cell(
            reader,
            element,
            event.kind is Empty(_),
            next_col,
            strings,
            self.date1904,
          )
          rows[rows.length() - 1].cells.push(cell)
          next_col = cell.column + 1
          if no_value {
            missing += 1
          }
          continue
        }
        if event.kind is Start(_) {
          depth += 1
        }
      }
      End(_) => {
        depth -= 1
        if depth + 1 == row_depth {
          row_depth = -1
        }
        if depth + 1 == data_depth {
          data_depth = -1
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
  { rows, missing_formula_values: missing, }
}

///|
priv struct XlsxRowBuilder {
  index : Int32
  mut height : Double
  custom_height : Bool
  hidden : Bool
  style : Int32
  cells : Array[XlsxCell]
}

///|
/// Sort rows and cells by position and merge duplicates, keeping the last cell.
pub fn XlsxSheetCells::sorted_rows(self : XlsxSheetCells) -> Array[XlsxRow] {
  let ordered = [ for i, row in self.rows => (i, row) ]
  ordered.sort_by((a, b) => {
    if a.1.index == b.1.index {
      a.0.compare(b.0)
    } else {
      a.1.index.compare(b.1.index)
    }
  })
  let merged : Array[XlsxRowBuilder] = []
  for (_, row) in ordered {
    if !merged.is_empty() && merged[merged.length() - 1].index == row.index {
      let previous = merged[merged.length() - 1]
      for cell in row.cells {
        previous.cells.push(cell)
      }
      if row.height >= 0.0 {
        previous.height = row.height
      }
    } else {
      merged.push({
        index: row.index,
        height: row.height,
        custom_height: row.custom_height,
        hidden: row.hidden,
        style: row.style,
        cells: row.cells.copy(),
      })
    }
  }
  let result : Array[XlsxRow] = []
  for row in merged {
    let ordered_cells = [ for i, cell in row.cells => (i, cell) ]
    ordered_cells.sort_by((a, b) => {
      if a.1.column == b.1.column {
        a.0.compare(b.0)
      } else {
        a.1.column.compare(b.1.column)
      }
    })
    let cells : Array[XlsxCell] = []
    for (_, cell) in ordered_cells {
      if !cells.is_empty() && cells[cells.length() - 1].column == cell.column {
        cells[cells.length() - 1] = cell
      } else if cell.column < 16384 {
        cells.push(cell)
      }
    }
    result.push({
      index: row.index,
      height: row.height,
      custom_height: row.custom_height,
      hidden: row.hidden,
      style: row.style,
      cells,
    })
  }
  result
}
