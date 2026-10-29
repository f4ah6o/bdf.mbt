///|
/// One inclusive column range with its width, visibility and style.
pub(all) struct XlsxColumn {
  first : Int32
  last : Int32
  width : Double
  hidden : Bool
  style : Int32
}

///|
/// Sheet layout properties that affect its BDF grid and view.
pub(all) struct XlsxSheetGeometry {
  default_column_width : Double
  base_column_width : Double
  default_row_height : Double
  zero_height : Bool
  show_grid : Bool
  show_zero : Bool
  right_to_left : Bool
  frozen_columns : Int32
  frozen_rows : Int32
  columns : Array[XlsxColumn]
  merges : Array[XlsxRange]
  auto_filter : XlsxRange?
}

///|
fn xlsx_has_attr(element : @xml.NamespaceElement, name : String) -> Bool {
  for attr in element.attributes {
    if attr.name.local_name == name &&
      !attr.name.namespace_uri.unwrap_or("").has_suffix("relationships") {
      return true
    }
  }
  false
}

///|
fn xlsx_bool_or(
  element : @xml.NamespaceElement,
  name : String,
  default : Bool,
) -> Bool {
  match xlsx_trim(xlsx_attr(element, name, "")) {
    "1" | "true" | "on" => true
    "0" | "false" | "off" => false
    _ => default
  }
}

///|
fn xlsx_float_or(
  element : @xml.NamespaceElement,
  name : String,
  default : Double,
) -> Double {
  @string.parse_double(xlsx_trim(xlsx_attr(element, name, ""))) catch {
    _ => default
  }
}

///|
fn xlsx_node_int(
  element : @xml.NamespaceElement,
  name : String,
  default : Int32,
) -> Int32 {
  let value = xlsx_trim(xlsx_attr(element, name, ""))
  match xlsx_int(value) {
    Some(n) =>
      if n >= -2147483648L && n <= 2147483647L {
        n.to_int()
      } else {
        default
      }
    None => {
      let f = @string.parse_double(value) catch { _ => return default }
      if f.is_nan() || f.is_inf() || f < -2147483648.0 || f > 2147483647.0 {
        default
      } else {
        f.to_int()
      }
    }
  }
}

///|
fn xlsx_column_width(value : Double) -> Double {
  if value.is_nan() || value < 0.0 {
    0.0
  } else if value.is_inf() {
    255.0
  } else {
    Double::min(value, 255.0)
  }
}

///|
/// Read dimensions, merged cells and view settings from a worksheet.
pub fn XlsxWorkbook::read_sheet_geometry(
  self : XlsxWorkbook,
  part : String,
) -> XlsxSheetGeometry raise {
  let bytes = self.package.read(part) catch {
    @ooxml.InvalidOoxml(message) => raise InvalidXlsxInput(message)
  }
  let text = @utf8.decode_lossy(bytes[:], ignore_bom=true)
  if text.contains("<!ENTITY") {
    raise InvalidXlsxInput("ooxml: the part declares entities")
  }
  let reader = @xml.NamespaceReader::from_string(text)
  let mut default_col = 0.0
  let mut base_col = 8.0
  let mut default_row = 0.0
  let mut zero = false
  let mut grid = true
  let mut show_zero = true
  let mut rtl = false
  let mut freeze_c = 0
  let mut freeze_r = 0
  let columns : Array[XlsxColumn] = []
  let merges : Array[XlsxRange] = []
  let mut filter : XlsxRange? = None
  let mut depth = 0
  let mut cols_depth = -1
  let mut merge_depth = -1
  let mut views_depth = -1
  let mut view_depth = -1
  let mut saw_view = false
  let mut saw_pane = false
  while true {
    let event = reader.read_event()
    match event.kind {
      Start(element) | Empty(element) => {
        let name = element.name.local_name
        if depth == 1 && name == "sheetFormatPr" {
          default_col = xlsx_column_width(
            xlsx_float_or(element, "defaultColWidth", 0.0),
          )
          base_col = xlsx_column_width(
            xlsx_float_or(element, "baseColWidth", 8.0),
          )
          let height = xlsx_float_or(element, "defaultRowHeight", 0.0)
          if !height.is_nan() && !height.is_inf() && height >= 0.0 {
            default_row = Double::min(height, 409.5)
          }
          zero = xlsx_bool_or(element, "zeroHeight", false)
        } else if depth == 1 && name == "cols" {
          if event.kind is Start(_) {
            cols_depth = depth + 1
          }
        } else if depth == cols_depth && name == "col" {
          let first = xlsx_node_int(element, "min", 1) - 1
          let last = xlsx_node_int(element, "max", 1) - 1
          if first >= 0 && last >= first {
            let width = if xlsx_has_attr(element, "width") {
              xlsx_column_width(xlsx_float_or(element, "width", 0.0))
            } else {
              -1.0
            }
            columns.push({
              first,
              last: Int32::min(last, 16383),
              width,
              hidden: xlsx_bool_or(element, "hidden", false),
              style: xlsx_node_int(element, "style", -1),
            })
          }
        } else if depth == 1 && name == "mergeCells" {
          if event.kind is Start(_) {
            merge_depth = depth + 1
          }
        } else if depth == merge_depth && name == "mergeCell" {
          match xlsx_parse_range(xlsx_attr(element, "ref", "")) {
            Some(range) =>
              if range.row_end > range.row_start ||
                range.column_end > range.column_start {
                merges.push(range)
              }
            None => ()
          }
        } else if depth == 1 && name == "autoFilter" {
          match xlsx_parse_range(xlsx_attr(element, "ref", "")) {
            Some(range) => filter = Some(range)
            None => ()
          }
        } else if depth == 1 && name == "sheetViews" {
          saw_view = false
          saw_pane = false
          if event.kind is Start(_) {
            views_depth = depth + 1
          } else {
            grid = true
            show_zero = true
            rtl = false
          }
        } else if depth == views_depth && name == "sheetView" && !saw_view {
          saw_view = true
          grid = xlsx_bool_or(element, "showGridLines", true)
          show_zero = xlsx_bool_or(element, "showZeros", true)
          rtl = xlsx_bool_or(element, "rightToLeft", false)
          if event.kind is Start(_) {
            view_depth = depth + 1
          }
        } else if depth == view_depth && name == "pane" && !saw_pane {
          saw_pane = true
          if xlsx_attr(element, "state", "split").has_prefix("frozen") {
            freeze_c = xlsx_float_or(element, "xSplit", 0.0).to_int()
            freeze_r = xlsx_float_or(element, "ySplit", 0.0).to_int()
          }
        }
        if event.kind is Start(_) {
          depth += 1
        }
      }
      End(_) => {
        depth -= 1
        if depth + 1 == cols_depth {
          cols_depth = -1
        }
        if depth + 1 == merge_depth {
          merge_depth = -1
        }
        if depth + 1 == view_depth {
          view_depth = -1
        }
        if depth + 1 == views_depth {
          if !saw_view {
            grid = true
            show_zero = true
            rtl = false
          }
          views_depth = -1
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
  {
    default_column_width: default_col,
    base_column_width: base_col,
    default_row_height: default_row,
    zero_height: zero,
    show_grid: grid,
    show_zero,
    right_to_left: rtl,
    frozen_columns: freeze_c,
    frozen_rows: freeze_r,
    columns,
    merges,
    auto_filter: filter,
  }
}
