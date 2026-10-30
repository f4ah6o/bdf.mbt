///|
/// Result of converting the explicitly limited plain-sheet subset of XLSX.
pub(all) struct XlsxPlainResult {
  bdf : Bytes
  warnings : Array[String]
  sheets : Int32
}

///|
fn XlsxWorkbook::xlsx_check_plain_sheet(
  self : XlsxWorkbook,
  part : String,
) -> (Array[@sheet.GridLink], Bool, XlsxRange?) raise {
  let data = self.package.read(part) catch {
    @ooxml.InvalidOoxml(message) => raise InvalidXlsxInput(message)
  }
  let text = @utf8.decode_lossy(data[:], ignore_bom=true)
  if text.contains("<!ENTITY") {
    raise InvalidXlsxInput("xlsx: the part declares entities")
  }
  let reader = @xml.NamespaceReader::from_string(text)
  let mut depth = 0
  let mut sheet_data_depth = -1
  let mut row_depth = -1
  let mut cell_depth = -1
  let mut inline_depth = -1
  let mut run_depth = -1
  let mut run_texts = 0
  let mut props_seen = false
  let mut props_depth = -1
  let mut run_font_seen = false
  let mut run_size_seen = false
  let mut link_depth = -1
  let mut extension_depth = -1
  let mut table_depth = -1
  let mut has_conditional = false
  let mut auto_filter : XlsxRange? = None
  let links : Array[@sheet.GridLink] = []
  let relationships = self.package.relationships(part)
  while true {
    let event = reader.read_event()
    match event.kind {
      Start(element) | Empty(element) => {
        let name = element.name.local_name
        if depth == 1 {
          // The upstream worksheet reader ignores unrecognized top-level
          // metadata. These elements have rendering semantics there and must
          // remain unsupported until they are implemented here.
          if name == "AlternateContent" {
            raise InvalidXlsxInput(
              "xlsx: plain conversion does not support worksheet feature " +
              name,
            )
          }
          if name == "drawing" {
            let id = xlsx_rel_id(element, "id")
            if id != "" && self.package.target(part, id) is Some(_) {
              raise InvalidXlsxInput(
                "xlsx: plain conversion does not support worksheet feature drawing",
              )
            }
          }
          if name == "tableParts" && event.kind is Start(_) {
            table_depth = depth + 1
          }
          if name == "sheetData" && event.kind is Start(_) {
            sheet_data_depth = depth + 1
          }
          if name == "hyperlinks" && event.kind is Start(_) {
            link_depth = depth + 1
          }
          if name == "conditionalFormatting" {
            has_conditional = true
          }
          if name == "autoFilter" {
            if xlsx_parse_range(xlsx_attr(element, "ref", "")) is Some(range) {
              auto_filter = Some(range)
            }
          }
          if name == "extLst" && event.kind is Start(_) {
            extension_depth = depth + 1
          }
        } else if depth == table_depth && name == "tablePart" {
          let id = xlsx_rel_id(element, "id")
          if self.package.target(part, id) is Some(_) {
            raise InvalidXlsxInput(
              "xlsx: plain conversion does not support worksheet feature tableParts",
            )
          }
        } else if extension_depth >= 0 &&
          depth >= extension_depth &&
          name == "conditionalFormattings" {
          raise InvalidXlsxInput(
            "xlsx: plain conversion does not support extended conditional formatting",
          )
        } else if depth == link_depth && name == "hyperlink" {
          xlsx_add_plain_links(links, relationships, element)
        } else if depth == sheet_data_depth &&
          name == "row" &&
          event.kind is Start(_) {
          row_depth = depth + 1
        } else if depth == row_depth && name == "c" {
          let kind = xlsx_attr(element, "t", "")
          if kind != "" &&
            kind != "n" &&
            kind != "str" &&
            kind != "s" &&
            kind != "inlineStr" &&
            kind != "b" &&
            kind != "e" &&
            kind != "d" {
            raise InvalidXlsxInput(
              "xlsx: plain conversion supports only numeric, plain string, boolean and error cells",
            )
          }
          if event.kind is Start(_) {
            cell_depth = depth + 1
          }
        } else if depth == cell_depth && name == "is" && event.kind is Start(_) {
          inline_depth = depth + 1
          props_seen = false
          run_font_seen = false
          run_size_seen = false
        } else if depth == inline_depth && name == "r" {
          props_seen = false
          run_font_seen = false
          run_size_seen = false
          run_texts = 0
          if event.kind is Start(_) {
            run_depth = depth + 1
          } else {
            raise InvalidXlsxInput(
              "xlsx: plain conversion does not support rich text",
            )
          }
        } else if depth == run_depth && name == "rPr" {
          if props_seen {
            raise InvalidXlsxInput(
              "xlsx: plain conversion does not support rich text",
            )
          }
          props_seen = true
          if event.kind is Start(_) {
            props_depth = depth + 1
          }
        } else if depth == props_depth && name == "rFont" {
          if run_font_seen {
            raise InvalidXlsxInput(
              "xlsx: plain conversion does not support rich text with repeated run fonts",
            )
          }
          run_font_seen = true
        } else if depth == props_depth && name == "sz" {
          if run_size_seen {
            raise InvalidXlsxInput(
              "xlsx: plain conversion does not support rich text with repeated run font sizes",
            )
          }
          run_size_seen = true
          let raw = xlsx_trim(xlsx_attr(element, "val", "")).to_lower()
          let size = @string.parse_double(raw) catch { _ => 0.0 }
          if size.is_inf() ||
            size >= 1000.0 ||
            raw.has_prefix("0x") ||
            raw.has_prefix("+0x") ||
            raw.has_prefix("-0x") {
            raise InvalidXlsxInput(
              "xlsx: plain conversion does not support rich text with this run font size",
            )
          }
        } else if depth == run_depth && name == "t" {
          run_texts += 1
          if run_texts > 1 {
            raise InvalidXlsxInput(
              "xlsx: plain conversion does not support rich text",
            )
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
        if depth + 1 == props_depth {
          props_depth = -1
        }
        if depth + 1 == run_depth {
          if run_texts == 0 {
            raise InvalidXlsxInput(
              "xlsx: plain conversion does not support rich text",
            )
          }
          run_depth = -1
        }
        if depth + 1 == link_depth {
          link_depth = -1
        }
        if depth + 1 == extension_depth {
          extension_depth = -1
        }
        if depth + 1 == table_depth {
          table_depth = -1
        }
        if depth + 1 == inline_depth {
          inline_depth = -1
        }
        if depth + 1 == cell_depth {
          cell_depth = -1
        }
        if depth + 1 == row_depth {
          row_depth = -1
        }
        if depth + 1 == sheet_data_depth {
          sheet_data_depth = -1
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
  (links, has_conditional, auto_filter)
}

///|
fn xlsx_add_plain_links(
  links : Array[@sheet.GridLink],
  relationships : Array[@ooxml.OoxmlRelationship],
  element : @xml.NamespaceElement,
) -> Unit raise {
  let id = xlsx_rel_id(element, "id")
  if id == "" {
    return
  }
  let mut target = ""
  let mut external = false
  for rel in relationships {
    if rel.id == id {
      target = rel.target
      external = rel.external
      break
    }
  }
  if !external {
    return
  }
  if !target.has_prefix("http:") &&
    !target.has_prefix("https:") &&
    !target.has_prefix("mailto:") {
    return
  }
  if (target.has_prefix("http:") && !target.has_prefix("http://")) ||
    (target.has_prefix("https:") && !target.has_prefix("https://")) {
    raise InvalidXlsxInput("xlsx: unsupported hyperlink URL")
  }
  let location = xlsx_attr(element, "location", "")
  if location != "" {
    target = target + "#" + location
  }
  let bytes = @utf8.encode(target)
  let mut index = 0
  while index < bytes.length() {
    let b = bytes[index]
    let n = b.to_int()
    if n < 33 ||
      n > 126 ||
      b == b'[' ||
      b == b']' ||
      b == b'\\' ||
      b == b'"' ||
      b == b'<' ||
      b == b'>' ||
      b == b'`' ||
      b == b'{' ||
      b == b'}' ||
      b == b'^' ||
      b == b'|' {
      raise InvalidXlsxInput("xlsx: unsupported hyperlink URL")
    }
    if b == b'%' {
      if index + 2 >= bytes.length() ||
        !xlsx_url_hex(bytes[index + 1]) ||
        !xlsx_url_hex(bytes[index + 2]) {
        raise InvalidXlsxInput("xlsx: unsupported hyperlink URL")
      }
      index += 2
    }
    index += 1
  }
  // Keep the HTTP authority to a simple host and optional numeric port.
  // Other forms are rejected until URL parsing matches Go's url.Parse.
  if target.has_prefix("http://") || target.has_prefix("https://") {
    let bytes = @utf8.encode(target)
    let mut i = if target.has_prefix("http://") { 7 } else { 8 }
    let mut port = false
    while i < bytes.length() {
      let b = bytes[i]
      if b == b'/' || b == b'?' || b == b'#' {
        break
      }
      if b == b':' && !port {
        port = true
      } else if port {
        if b < b'0' || b > b'9' {
          raise InvalidXlsxInput("xlsx: unsupported hyperlink URL")
        }
      } else if !((b >= b'a' && b <= b'z') ||
        (b >= b'A' && b <= b'Z') ||
        (b >= b'0' && b <= b'9') ||
        b == b'.' ||
        b == b'-') {
        raise InvalidXlsxInput("xlsx: unsupported hyperlink URL")
      }
      i += 1
    }
  }
  let buffer = StringBuilder()
  for ch in xlsx_attr(element, "ref", "") {
    if ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r' {
      buffer.write_char(' ')
    } else {
      buffer.write_char(ch)
    }
  }
  for item in buffer.to_string().split(" ") {
    if item == "" {
      continue
    }
    if xlsx_parse_range(item.to_owned()) is Some(range) &&
      range.row_start < 1048576L &&
      range.column_start < 16384 {
      links.push({
        row_start: range.row_start.to_int(),
        row_end: Int64::min(range.row_end, 1048575L).to_int(),
        column_start: range.column_start,
        column_end: Int32::min(range.column_end, 16383),
        target,
      })
    }
  }
}

///|
fn xlsx_url_hex(b : Byte) -> Bool {
  (b >= b'0' && b <= b'9') ||
  (b >= b'A' && b <= b'F') ||
  (b >= b'a' && b <= b'f')
}

///|
fn XlsxWorkbook::xlsx_check_plain_strings(self : XlsxWorkbook) -> Unit raise {
  let rel = match
    self.package.relationship_of_type(self.part, "/sharedStrings") {
    Some(r) => r
    None => return
  }
  let data = self.package.read(rel.target) catch { _ => return }
  let text = @utf8.decode_lossy(data[:], ignore_bom=true)
  if text.contains("<!ENTITY") {
    raise InvalidXlsxInput("xlsx: the part declares entities")
  }
  let reader = @xml.NamespaceReader::from_string(text)
  let mut depth = 0
  let mut string_depth = -1
  let mut run_depth = -1
  let mut run_texts = 0
  let mut props_seen = false
  let mut props_depth = -1
  let mut run_font_seen = false
  let mut run_size_seen = false
  while true {
    let event = reader.read_event()
    match event.kind {
      Start(element) | Empty(element) => {
        let name = element.name.local_name
        if depth == 1 && name == "si" && event.kind is Start(_) {
          string_depth = depth + 1
          props_seen = false
          run_font_seen = false
          run_size_seen = false
        } else if depth == string_depth && name == "r" {
          props_seen = false
          run_font_seen = false
          run_size_seen = false
          run_texts = 0
          if event.kind is Start(_) {
            run_depth = depth + 1
          } else {
            raise InvalidXlsxInput(
              "xlsx: plain conversion does not support rich text",
            )
          }
        } else if depth == run_depth && name == "rPr" {
          if props_seen {
            raise InvalidXlsxInput(
              "xlsx: plain conversion does not support rich text",
            )
          }
          props_seen = true
          if event.kind is Start(_) {
            props_depth = depth + 1
          }
        } else if depth == props_depth && name == "rFont" {
          if run_font_seen {
            raise InvalidXlsxInput(
              "xlsx: plain conversion does not support rich text with repeated run fonts",
            )
          }
          run_font_seen = true
        } else if depth == props_depth && name == "sz" {
          if run_size_seen {
            raise InvalidXlsxInput(
              "xlsx: plain conversion does not support rich text with repeated run font sizes",
            )
          }
          run_size_seen = true
          let raw = xlsx_trim(xlsx_attr(element, "val", "")).to_lower()
          let size = @string.parse_double(raw) catch { _ => 0.0 }
          if size.is_inf() ||
            size >= 1000.0 ||
            raw.has_prefix("0x") ||
            raw.has_prefix("+0x") ||
            raw.has_prefix("-0x") {
            raise InvalidXlsxInput(
              "xlsx: plain conversion does not support rich text with this run font size",
            )
          }
        } else if depth == run_depth && name == "t" {
          run_texts += 1
          if run_texts > 1 {
            raise InvalidXlsxInput(
              "xlsx: plain conversion does not support rich text",
            )
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
        if depth + 1 == props_depth {
          props_depth = -1
        }
        if depth + 1 == run_depth {
          if run_texts == 0 {
            raise InvalidXlsxInput(
              "xlsx: plain conversion does not support rich text",
            )
          }
          run_depth = -1
        }
        if depth + 1 == string_depth {
          string_depth = -1
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
}

///|
fn xlsx_check_plain_style(styles : XlsxStyles, style : Int32) -> Unit raise {
  let index = if style < 0 || style >= styles.cell_formats.length() {
    0
  } else {
    style
  }
  let format = styles.cell_formats[index]
  let a = format.alignment
  let font_index = if format.font < 0 || format.font >= styles.fonts.length() {
    0
  } else {
    format.font
  }
  let font = styles.fonts[font_index]
  let nondefault_fill = format.fill >= 0 &&
    format.fill < styles.fills.length() &&
    (
      styles.fills[format.fill].pattern != "" ||
      styles.fills[format.fill].gradient is Some(_)
    )
  let solid_fill = format.fill >= 0 &&
    format.fill < styles.fills.length() &&
    styles.fills[format.fill].pattern == "solid" &&
    styles.fills[format.fill].gradient is None
  let nondefault_border = if format.border >= 0 &&
    format.border < styles.borders.length() {
    let b = styles.borders[format.border]
    b.left.style != "" ||
    b.right.style != "" ||
    b.top.style != "" ||
    b.bottom.style != "" ||
    b.diagonal.style != "" ||
    b.vertical.style != "" ||
    b.horizontal.style != "" ||
    b.diagonal_up ||
    b.diagonal_down
  } else {
    false
  }
  let complex_border = if format.border >= 0 &&
    format.border < styles.borders.length() {
    let b = styles.borders[format.border]
    b.vertical.style != "" || b.horizontal.style != ""
  } else {
    false
  }
  if (font.scheme != "" && font.scheme != "minor" && font.scheme != "major") ||
    (
      font.vertical != "" &&
      font.vertical != "superscript" &&
      font.vertical != "subscript"
    ) ||
    (
      a.horizontal != "general" &&
      a.horizontal != "center" &&
      a.horizontal != "centerContinuous" &&
      a.horizontal != "left" &&
      a.horizontal != "right"
    ) ||
    (a.vertical != "bottom" && a.vertical != "top" && a.vertical != "center") ||
    a.rotation != 0 ||
    (nondefault_fill && (index == 0 || !solid_fill)) ||
    (index == 0 && nondefault_border) ||
    complex_border {
    raise InvalidXlsxInput(
      "xlsx: plain conversion does not support styled cells",
    )
  }
}

///|
/// Convert worksheets using estimated font metrics without embedding fonts.
/// Supports sheet views with numeric, plain string, boolean and error cells,
/// number formats, named and themed fonts, font colors, bold, italic, underlined
/// and struck text, superscript and subscript, horizontal alignment, top or
/// center vertical alignment, solid fills, line borders, merged cells, wrapping,
/// shrink-to-fit, indentation and center-across-selection.
/// Multiple border colors per line weight must use exact 8-bit RGB components;
/// patterned row and column fills, complex borders and other features are
/// rejected. Supported numeric conditional rules may apply a differential font,
/// solid fill and border or be inactive. For blank-cell fills or borders,
/// ranges are limited to 200,000 cells. Other conditional
/// formats are rejected.
/// Views with base fills are limited to 1,000,000 cells, and views
/// with base borders to 200,000 cells. External links support simple ASCII
/// HTTP(S) and mailto URLs with simple ASCII authorities; other URL forms are
/// rejected.
pub fn convert_plain_no_fonts(
  data : Bytes,
  data_mode~ : String = "",
  no_text_index~ : Bool = false,
) -> XlsxPlainResult raise {
  if data_mode != "" &&
    data_mode != "default" &&
    data_mode != "all" &&
    data_mode != "none" {
    raise InvalidXlsxInput("xlsx: invalid data mode")
  }
  let workbook = read_xlsx_workbook(data)
  let metadata = workbook.package.core_properties()
  let locale = workbook.locale()
  let styles = workbook.styles()
  let theme_colors = workbook.xlsx_plain_theme_colors()
  xlsx_check_plain_style(styles, 0)
  workbook.xlsx_check_plain_strings()
  let shared_runs = workbook.xlsx_shared_run_texts()
  let dc : Map[String, Json] = Map([])
  for
    (key, values) in [
      ("title", metadata.title),
      ("creator", metadata.creator),
      ("subject", metadata.subject),
      ("description", metadata.description),
      ("identifier", metadata.identifier),
      ("language", metadata.language),
      ("created", metadata.created),
      ("modified", metadata.modified),
    ] {
    if values.length() == 1 {
      dc[key] = Json::string(values[0])
    } else if values.length() > 1 {
      dc[key] = Json::array(values.map(Json::string))
    }
  }
  let meta : Map[String, Json] = {
    "source": Json::string("xlsx"),
    "generator": Json::string("bdf-go/0.1"),
  }
  if !dc.is_empty() {
    meta["dc"] = Json::object(dc)
  }
  let writer = @core.DocumentWriter::new(meta=Json::object(meta))
  let mode = if data_mode == "default" { "" } else { data_mode }
  let warnings = workbook.warnings.copy()
  let grids : Array[@sheet.NamedGrid] = []
  let mut counter = 0
  let mut warned_rtl = false
  let warned_sheets : Map[String, Bool] = Map([])
  let doc_language = metadata.language.get(0).unwrap_or("")
  for index, ref in workbook.sheets {
    if ref.hidden {
      continue
    }
    if ref.chart {
      raise InvalidXlsxInput(
        "xlsx: plain conversion does not support chart sheets",
      )
    }
    let number = index + 1
    let id = "sheet" + number.to_string()
    let (drawn, geo, missing_formula_values) = workbook.xlsx_draw_plain_sheet(
      ref, styles, locale, doc_language, theme_colors, shared_runs,
    )
    let (next, table_warnings) = workbook.store_sheet_tables(
      writer,
      ref.part,
      ref.name,
      number,
      id,
      mode,
      counter,
      locale.number_locale,
    )
    counter = next
    for warning in table_warnings {
      warnings.push(warning)
    }
    if !warned_sheets.contains(ref.name) && missing_formula_values > 0 {
      warnings.push(
        "sheet " +
        xlsx_go_quote(ref.name, '"') +
        ": " +
        missing_formula_values.to_string() +
        " formula cell(s) have no calculated value and are left empty (the workbook was saved without calculating them)",
      )
    }
    if !warned_sheets.contains(ref.name) && geo.right_to_left && !warned_rtl {
      warnings.push(
        "sheet " +
        xlsx_go_quote(ref.name, '"') +
        ": right-to-left sheets are drawn left to right",
      )
      warned_rtl = true
    }
    warned_sheets[ref.name] = true
    grids.push({
      id,
      title: ref.name,
      grid: drawn,
      gridlines: geo.show_grid,
      frozen_columns: Int32::min(geo.frozen_columns, 16384),
    })
  }
  @sheet.store_grids(writer, grids, !no_text_index)
  { bdf: writer.write_single(), warnings, sheets: grids.length(), }
}

///|
fn XlsxWorkbook::xlsx_draw_plain_sheet(
  workbook : XlsxWorkbook,
  ref : XlsxSheetRef,
  input_styles : XlsxStyles,
  locale : XlsxLocale,
  doc_language : String,
  theme_colors : Map[Int32, XlsxRgb],
  shared_runs : Array[XlsxPlainRun?],
) -> (@sheet.DrawnGrid, XlsxSheetGeometry, Int32) raise {
  let (links, has_conditional, filter_range) = workbook.xlsx_check_plain_sheet(
    ref.part,
  )
  let (parsed, rich_cells) = workbook.xlsx_read_sheet_cells_with_runs(
    ref.part,
    shared_runs,
  )
  let mut styled_runs = false
  for _, columns in rich_cells {
    for _, run in columns {
      if run.font is Some(_) {
        styled_runs = true
      }
    }
  }
  let styles = if has_conditional || styled_runs {
    {
      ..input_styles,
      fonts: input_styles.fonts.copy(),
      fills: input_styles.fills.copy(),
      borders: input_styles.borders.copy(),
      cell_formats: input_styles.cell_formats.map(format => {
        ..format,
        font: if format.font < 0 || format.font >= input_styles.fonts.length() {
          0
        } else {
          format.font
        },
        fill: if format.fill < 0 || format.fill >= input_styles.fills.length() {
          -1
        } else {
          format.fill
        },
        border: if format.border < 0 ||
          format.border >= input_styles.borders.length() {
          -1
        } else {
          format.border
        },
      }),
    }
  } else {
    input_styles
  }
  let mut rows = parsed.sorted_rows()
  let notes = workbook.xlsx_plain_notes(ref.part)
  let geo = workbook.read_sheet_geometry(ref.part)
  let (spans, region_rows, merge_regions) = xlsx_plain_spans(geo.merges)
  let center_across : Map[Int32, Map[Int32, Bool]] = Map([])
  for row in rows {
    for cell in row.cells {
      let index = if cell.style < 0 ||
        cell.style >= styles.cell_formats.length() {
        0
      } else {
        cell.style
      }
      let alignment = styles.cell_formats[index].alignment
      if alignment.horizontal == "centerContinuous" {
        let columns = match center_across.get(row.index) {
          Some(columns) => columns
          None => {
            let columns : Map[Int32, Bool] = Map([])
            center_across[row.index] = columns
            columns
          }
        }
        columns[cell.column] = cell.kind == 0
      }
    }
  }
  let mut base_fills = false
  let mut base_borders = false
  for column in geo.columns {
    if column.style >= 0 {
      let (fill, border) = xlsx_check_base_style(styles, column.style)
      base_fills = fill || base_fills
      base_borders = border || base_borders
    }
  }
  let (row_count, col_count) = xlsx_initial_extent(parsed, geo, notes)
  if has_conditional || styled_runs {
    rows = xlsx_normalize_conditional_styles(rows, styles.cell_formats.length())
  }
  let (layout_rows, layout_styles) = if styled_runs {
    let layout_styles : XlsxStyles = {
      ..styles,
      fonts: styles.fonts.copy(),
      cell_formats: styles.cell_formats.copy(),
    }
    (xlsx_apply_plain_run_fonts(rows, layout_styles, rich_cells), layout_styles)
  } else {
    (rows, styles)
  }
  if has_conditional {
    rows = workbook.xlsx_apply_plain_conditionals(
      ref.part,
      rows,
      styles,
      geo,
      row_count,
      col_count,
    )
  }
  if styled_runs {
    rows = xlsx_apply_plain_run_fonts(rows, styles, rich_cells)
  }
  let visible_cols = xlsx_column_runs(geo, col_count, 7.0)
  let all_cols = xlsx_column_runs(geo, 16384, 7.0)
  let widths : Array[Double] = []
  for run in all_cols {
    for _ in 0..<run.count {
      widths.push(run.size.to_double())
    }
  }
  let columns : Array[@sheet.Run] = visible_cols.map(run => {
    count: run.count,
    size: run.size,
  })
  let all_columns : Array[@sheet.Run] = all_cols.map(run => {
    count: run.count,
    size: run.size,
  })
  let default_size = styles.fonts[0].size
  let fitted = xlsx_plain_fitted_rows(
    layout_rows,
    layout_styles,
    geo,
    spans,
    widths,
    workbook.date1904,
    locale.number_locale,
    default_size,
    rich_cells,
  )
  let heights : Array[@sheet.Run] = xlsx_row_runs(
    layout_rows,
    geo,
    row_count,
    (0.9 + 0.25) * default_size,
    fitted,
  ).map(run => { count: run.count, size: run.size, })
  let geometry : @sheet.GridGeometry = {
    columns,
    rows: heights,
    frozen_rows: Int32::min(geo.frozen_rows, row_count),
  }
  let cells : Array[@sheet.SizedGridRow] = []
  let verticals : Map[Int32, Map[Int32, String]] = Map([])
  let horizontals : Map[Int32, Map[Int32, String]] = Map([])
  let bolds : Map[Int32, Map[Int32, Bool]] = Map([])
  let italics : Map[Int32, Map[Int32, Bool]] = Map([])
  let decorations : Map[Int32, Map[Int32, @sheet.GridTextDecoration]] = Map([])
  let rich_colors : Map[Int32, Map[Int32, Array[@sheet.GridRichColorRun]]] = Map([],
  )
  let scripts : Map[Int32, Map[Int32, String]] = Map([])
  let shrink_scales : Map[Int32, Map[Int32, Double]] = Map([])
  let indents : Map[Int32, Map[Int32, Double]] = Map([])
  let fills : Map[Int32, Map[Int32, @sheet.GridSolidFill]] = Map([])
  let sizes : Map[Int32, Map[Int32, Double]] = Map([])
  let wraps : Map[Int32, Map[Int32, Bool]] = Map([])
  let font_families : Map[Int32, Map[Int32, String]] = Map([])
  let east_asian_fonts : Map[Int32, Map[Int32, String]] = Map([])
  let theme = workbook.package.theme_fonts(workbook.part)
  let borders : Map[Int32, Map[Int32, @sheet.GridCellBorder]] = Map([])
  let diagonals : Map[Int32, Map[Int32, @sheet.GridCellDiagonal]] = Map([])
  let border_colors : Map[Int32, Map[Int32, Array[UInt32]]] = Map([])
  let border_colors_by_weight : Map[Int32, XlsxRgb] = Map([])
  let checked_styles : Map[Int32, Bool] = Map([])
  let format_cache : Map[Int32, Array[XlsxFormatSection]] = Map([])
  let color_cache : Map[Int32, UInt32] = Map([])
  let border_cache : Map[Int32, (@sheet.GridCellBorder, Array[XlsxRgb])] = Map([])
  for row in rows {
    if row.style >= 0 {
      let (fill, border) = xlsx_check_base_style(styles, row.style)
      base_fills = fill || base_fills
      base_borders = border || base_borders
    }
    let entries : Array[@sheet.SizedGridCell] = []
    for cell in row.cells {
      if cell.kind != 0 &&
        cell.kind != 1 &&
        cell.kind != 2 &&
        cell.kind != 3 &&
        cell.kind != 4 {
        raise InvalidXlsxInput(
          "xlsx: plain conversion does not support this cell",
        )
      }
      if !checked_styles.contains(cell.style) {
        xlsx_check_plain_style(styles, cell.style)
        checked_styles[cell.style] = true
      }
      let format_index = if cell.style < 0 ||
        cell.style >= styles.cell_formats.length() {
        0
      } else {
        cell.style
      }
      let font_id = styles.cell_formats[format_index].font
      let font_index = if font_id < 0 || font_id >= styles.fonts.length() {
        0
      } else {
        font_id
      }
      let font_size = styles.fonts[font_index].size
      let font = styles.fonts[font_index]
      let drawn_size = if font.vertical == "" {
        font_size
      } else {
        font_size * (2.0 / 3.0)
      }
      let themed_latin = if font.scheme == "minor" {
        theme.resolve("+mn-lt", locale.script)
      } else if font.scheme == "major" {
        theme.resolve("+mj-lt", locale.script)
      } else {
        ""
      }
      let font_name = if themed_latin != "" {
        themed_latin
      } else if font.name != "" {
        font.name
      } else {
        "Calibri"
      }
      if font_name != "Calibri" {
        let columns = match font_families.get(row.index) {
          Some(columns) => columns
          None => {
            let columns : Map[Int32, String] = Map([])
            font_families[row.index] = columns
            columns
          }
        }
        columns[cell.column] = font_name
      }
      let east_asian = if font.scheme == "minor" {
        theme.resolve("+mn-ea", locale.script)
      } else if font.scheme == "major" {
        theme.resolve("+mj-ea", locale.script)
      } else {
        ""
      }
      if east_asian != "" {
        let columns = match east_asian_fonts.get(row.index) {
          Some(columns) => columns
          None => {
            let columns : Map[Int32, String] = Map([])
            east_asian_fonts[row.index] = columns
            columns
          }
        }
        columns[cell.column] = east_asian
      }
      let span = xlsx_plain_region_at(
        spans,
        region_rows,
        row.index,
        cell.column,
      )
      let wrap = styles.cell_formats[format_index].alignment.wrap
      let indent = xlsx_plain_indent(
        styles.cell_formats[format_index].alignment,
        cell.kind,
      )
      let (border, colors) = match border_cache.get(format_index) {
        Some(border) => border
        None => {
          let border = xlsx_plain_border(styles, format_index, theme_colors)
          border_cache[format_index] = border
          border
        }
      }
      let border_id = styles.cell_formats[format_index].border
      if border_id >= 0 && border_id < styles.borders.length() {
        let source_border = styles.borders[border_id]
        if source_border.diagonal_up || source_border.diagonal_down {
          let (weight, color) = xlsx_plain_border_side(
            styles,
            source_border.diagonal,
            theme_colors,
          )
          if weight != 0 {
            xlsx_check_border_color(border_colors_by_weight, weight, color)
            let columns = match diagonals.get(row.index) {
              Some(columns) => columns
              None => {
                let columns : Map[Int32, @sheet.GridCellDiagonal] = Map([])
                diagonals[row.index] = columns
                columns
              }
            }
            columns[cell.column] = {
              weight,
              color: color.rgba(),
              up: source_border.diagonal_up,
              down: source_border.diagonal_down,
            }
          }
        }
      }
      if border.top != 0 ||
        border.bottom != 0 ||
        border.left != 0 ||
        border.right != 0 {
        let weights = [border.top, border.bottom, border.left, border.right]
        for i, weight in weights {
          if weight == 0 {
            continue
          }
          xlsx_check_border_color(border_colors_by_weight, weight, colors[i])
        }
        let columns = match borders.get(row.index) {
          Some(columns) => columns
          None => {
            let columns : Map[Int32, @sheet.GridCellBorder] = Map([])
            borders[row.index] = columns
            columns
          }
        }
        columns[cell.column] = if span is Some(region) {
          {
            top: if row.index == region.row_start {
              border.top
            } else {
              0
            },
            bottom: if row.index == region.row_end {
              border.bottom
            } else {
              0
            },
            left: if cell.column == region.column_start {
              border.left
            } else {
              0
            },
            right: if cell.column == region.column_end {
              border.right
            } else {
              0
            },
          }
        } else {
          border
        }
        let row_colors = match border_colors.get(row.index) {
          Some(row_colors) => row_colors
          None => {
            let row_colors : Map[Int32, Array[UInt32]] = Map([])
            border_colors[row.index] = row_colors
            row_colors
          }
        }
        row_colors[cell.column] = colors.map(color => color.rgba())
      }
      let fill_index = styles.cell_formats[format_index].fill
      if fill_index >= 0 && fill_index < styles.fills.length() {
        let fill = styles.fills[fill_index]
        if fill.pattern == "solid" {
          let columns = match fills.get(row.index) {
            Some(columns) => columns
            None => {
              let columns : Map[Int32, @sheet.GridSolidFill] = Map([])
              fills[row.index] = columns
              columns
            }
          }
          let black : XlsxRgb = { red: 0.0, green: 0.0, blue: 0.0, }
          columns[cell.column] = {
            key: xlsx_solid_fill_key(fill),
            color: styles
            .resolve_color(fill.foreground, black, theme_colors)
            .rgba(),
          }
        }
      }
      let formatted = if cell.kind == 1 {
        Some(
          xlsx_format_number(
            styles.cached_number_sections(
              cell.style,
              locale.number_locale,
              format_cache,
            ),
            cell.number,
            workbook.date1904,
          ),
        )
      } else if cell.kind == 2 &&
        rich_cells.get(row.index) is Some(columns) &&
        columns.get(cell.column) is Some(text) {
        Some(xlsx_plain_run_format(text.text))
      } else if cell.kind == 2 {
        Some(
          xlsx_format_text(
            styles.cached_number_sections(
              cell.style,
              locale.number_locale,
              format_cache,
            ),
            cell.text,
          ),
        )
      } else {
        styles.format_cell(cell, workbook.date1904, locale.number_locale)
      }
      if formatted is Some(formatted) {
        for piece in formatted.pieces {
          if piece.kind != 0 {
            raise InvalidXlsxInput(
              "xlsx: plain conversion does not support format gaps or fills",
            )
          }
        }
        let mut text = formatted.text()
        if styles.cell_formats[format_index].alignment.shrink &&
          !wrap &&
          cell.kind != 1 {
          let mut cell_width = if cell.column >= 0 &&
            cell.column < widths.length() {
            widths[cell.column]
          } else {
            0.0
          }
          if span is Some(region) && cell.column == region.column_start {
            cell_width = 0.0
            for column in region.column_start..<=region.column_end {
              cell_width += widths[column]
            }
          }
          if styles.cell_formats[format_index].alignment.horizontal ==
            "centerContinuous" {
            let last = xlsx_plain_center_end(
              center_across,
              row.index,
              cell.column,
              col_count,
            )
            if last > cell.column {
              cell_width = 0.0
              for column in cell.column..<=last {
                cell_width += widths[column]
              }
            }
          }
          let scale = xlsx_plain_shrink_scale(
            text,
            Double::max(cell_width - 3.75 - indent, 0.0),
            drawn_size,
          )
          if scale != 1.0 {
            let columns = match shrink_scales.get(row.index) {
              Some(columns) => columns
              None => {
                let columns : Map[Int32, Double] = Map([])
                shrink_scales[row.index] = columns
                columns
              }
            }
            columns[cell.column] = scale
          }
        }
        if cell.kind == 1 && !wrap {
          let mut cell_width = if cell.column >= 0 &&
            cell.column < widths.length() {
            widths[cell.column]
          } else {
            0.0
          }
          if span is Some(region) && cell.column == region.column_start {
            cell_width = 0.0
            for column in region.column_start..<=region.column_end {
              cell_width += widths[column]
            }
          }
          if styles.cell_formats[format_index].alignment.horizontal ==
            "centerContinuous" {
            let last = xlsx_plain_center_end(
              center_across,
              row.index,
              cell.column,
              col_count,
            )
            if last > cell.column {
              cell_width = 0.0
              for column in cell.column..<=last {
                cell_width += widths[column]
              }
            }
          }
          let mut width = 0.0
          for c in text {
            width += @sheet.sized_fallback_advance(c, false, drawn_size)
          }
          if cell.column >= 0 &&
            cell.column < widths.length() &&
            cell_width > 0.0 &&
            width > cell_width - 3.75 - indent + 0.01 {
            let available = Double::max(cell_width - 3.75 - indent, 0.0)
            text = if formatted.general {
              xlsx_fit_plain_number(cell.number, available, drawn_size)
            } else {
              "#".repeat(
                (available /
                @sheet.sized_fallback_advance('#', false, drawn_size)).to_int(),
              )
            }
          }
        }
        let vertical = styles.cell_formats[format_index].alignment.vertical
        let horizontal = styles.cell_formats[format_index].alignment.horizontal
        if indent != 0.0 {
          let columns = match indents.get(row.index) {
            Some(columns) => columns
            None => {
              let columns : Map[Int32, Double] = Map([])
              indents[row.index] = columns
              columns
            }
          }
          columns[cell.column] = indent
        }
        if wrap {
          let columns = match wraps.get(row.index) {
            Some(columns) => columns
            None => {
              let columns : Map[Int32, Bool] = Map([])
              wraps[row.index] = columns
              columns
            }
          }
          columns[cell.column] = true
        }
        if font_size != 11.0 {
          let columns = match sizes.get(row.index) {
            Some(columns) => columns
            None => {
              let columns : Map[Int32, Double] = Map([])
              sizes[row.index] = columns
              columns
            }
          }
          columns[cell.column] = font_size
        }
        if styles.fonts[font_index].bold {
          let columns = match bolds.get(row.index) {
            Some(columns) => columns
            None => {
              let columns : Map[Int32, Bool] = Map([])
              bolds[row.index] = columns
              columns
            }
          }
          columns[cell.column] = true
        }
        if styles.fonts[font_index].italic {
          let columns = match italics.get(row.index) {
            Some(columns) => columns
            None => {
              let columns : Map[Int32, Bool] = Map([])
              italics[row.index] = columns
              columns
            }
          }
          columns[cell.column] = true
        }
        if font.underline != "" || font.strike {
          let columns = match decorations.get(row.index) {
            Some(columns) => columns
            None => {
              let columns : Map[Int32, @sheet.GridTextDecoration] = Map([])
              decorations[row.index] = columns
              columns
            }
          }
          columns[cell.column] = {
            underline: font.underline,
            strike: font.strike,
          }
        }
        if font.vertical != "" {
          let columns = match scripts.get(row.index) {
            Some(columns) => columns
            None => {
              let columns : Map[Int32, String] = Map([])
              scripts[row.index] = columns
              columns
            }
          }
          columns[cell.column] = font.vertical
        }
        if vertical != "bottom" {
          let columns = match verticals.get(row.index) {
            Some(columns) => columns
            None => {
              let columns : Map[Int32, String] = Map([])
              verticals[row.index] = columns
              columns
            }
          }
          columns[cell.column] = vertical
        }
        if horizontal == "left" || horizontal == "right" {
          let columns = match horizontals.get(row.index) {
            Some(columns) => columns
            None => {
              let columns : Map[Int32, String] = Map([])
              horizontals[row.index] = columns
              columns
            }
          }
          columns[cell.column] = horizontal
        }
        if rich_cells.get(row.index) is Some(columns) &&
          columns.get(cell.column) is Some(run) &&
          !run.segments.is_empty() {
          let alignment = styles.cell_formats[format_index].alignment
          if font.bold ||
            font.italic ||
            font.underline != "" ||
            font.strike ||
            font.vertical != "" ||
            alignment.wrap ||
            alignment.shrink ||
            (horizontal != "general" && horizontal != "left") ||
            run.text == "" ||
            run.text.length() > 1024 ||
            run.text.trim().to_string() != run.text {
            raise InvalidXlsxInput(
              "xlsx: plain conversion does not support these styled rich text runs",
            )
          }
          for ch in run.text {
            if ch.to_int() < 0x20 || ch.to_int() > 0x7e {
              raise InvalidXlsxInput(
                "xlsx: plain conversion does not support these styled rich text runs",
              )
            }
          }
          let default_color = xlsx_plain_font_color(
            styles,
            cell.style,
            theme_colors,
          )
          let black : XlsxRgb = { red: 0.0, green: 0.0, blue: 0.0, }
          let segments : Array[@sheet.GridRichColorRun] = []
          let mut previous_plain = false
          for segment in run.segments {
            if segment.text == "" {
              continue
            }
            let color = match segment.font {
              None => default_color
              Some(segment_font) => {
                if segment_font.name != "" ||
                  segment_font.size != 0.0 ||
                  segment_font.bold ||
                  segment_font.italic ||
                  segment_font.underline != "" ||
                  segment_font.strike ||
                  segment_font.vertical != "" {
                  raise InvalidXlsxInput(
                    "xlsx: plain conversion does not support these styled rich text runs",
                  )
                }
                if segment_font.color.kind == 0 {
                  default_color
                } else {
                  if segment_font.color.kind == 2 &&
                    segment_font.color.index >= 0 &&
                    segment_font.color.index < 12 &&
                    !theme_colors.contains(segment_font.color.index) {
                    raise InvalidXlsxInput(
                      "xlsx: plain conversion does not support this theme color",
                    )
                  }
                  styles
                  .resolve_color(segment_font.color, black, theme_colors)
                  .rgba()
                }
              }
            }
            let plain = segment.font is None
            if plain && previous_plain && !segments.is_empty() {
              let last = segments.length() - 1
              segments[last] = {
                ..segments[last],
                text: segments[last].text + segment.text,
              }
            } else {
              segments.push({ text: segment.text, color, })
            }
            previous_plain = plain
          }
          let row_colors = match rich_colors.get(row.index) {
            Some(row_colors) => row_colors
            None => {
              let row_colors : Map[Int32, Array[@sheet.GridRichColorRun]] = Map([],
              )
              rich_colors[row.index] = row_colors
              row_colors
            }
          }
          row_colors[cell.column] = segments
        }
        entries.push({
          column: cell.column,
          cell: { text, number: cell.kind == 1, },
          center: horizontal == "center" ||
          horizontal == "centerContinuous" ||
          (horizontal == "general" && (cell.kind == 3 || cell.kind == 4)),
          visible: !(cell.kind == 1 && cell.number == 0.0 && !geo.show_zero),
          occupied: cell.kind != 0 && !(cell.kind == 2 && cell.text == ""),
          color: match formatted.color {
            Some(rgb) => (rgb << 8) | 255U
            None =>
              match color_cache.get(cell.style) {
                Some(cached) => cached
                None => {
                  let color = xlsx_plain_font_color(
                    styles,
                    cell.style,
                    theme_colors,
                  )
                  color_cache[cell.style] = color
                  color
                }
              }
          },
        })
      }
    }
    cells.push({ index: row.index, cells: entries, })
  }
  let draw_cells = if base_fills || base_borders {
    xlsx_plain_base_paint(
      rows, cells, geo, styles, theme_colors, spans, region_rows, fills, borders,
      border_colors, diagonals, border_colors_by_weight, row_count, col_count, base_borders,
    )
  } else {
    cells
  }
  let drawn = @sheet.draw_sized_grid_no_fonts(
    draw_cells,
    geometry,
    all_columns,
    locale.language,
    doc_language,
    verticals~,
    horizontals~,
    bolds~,
    fills~,
    sizes~,
    borders~,
    spans~,
    border_colors~,
    merge_regions~,
    east_asian_fonts~,
    wraps~,
    diagonals~,
    font_families~,
    italics~,
    decorations~,
    scripts~,
    shrink_scales~,
    indents~,
    center_across~,
    links~,
    auto_filter=match filter_range {
      Some(range) if range.row_start >= 0L &&
        range.row_start < row_count.to_int64() =>
        Some((range.row_start.to_int(), range.column_start, range.column_end))
      _ => None
    },
    notes~,
    rich_colors~,
  ) catch {
    @sheet.InvalidArgument(message) => raise InvalidXlsxInput(message)
    error => raise error
  }
  (drawn, geo, parsed.missing_formula_values)
}

///|
fn xlsx_plain_base_paint(
  rows : Array[XlsxRow],
  cells : Array[@sheet.SizedGridRow],
  geo : XlsxSheetGeometry,
  styles : XlsxStyles,
  theme_colors : Map[Int32, XlsxRgb],
  spans : Map[Int32, Map[Int32, Int32]],
  region_rows : Map[Int32, Map[Int32, @sheet.GridMergeRegion]],
  fills : Map[Int32, Map[Int32, @sheet.GridSolidFill]],
  borders : Map[Int32, Map[Int32, @sheet.GridCellBorder]],
  border_colors : Map[Int32, Map[Int32, Array[UInt32]]],
  diagonals : Map[Int32, Map[Int32, @sheet.GridCellDiagonal]],
  border_colors_by_weight : Map[Int32, XlsxRgb],
  row_count : Int32,
  col_count : Int32,
  base_borders : Bool,
) -> Array[@sheet.SizedGridRow] raise {
  // Materializing missing formatted cells must stay bounded for huge views.
  if row_count.to_int64() * col_count.to_int64() > 1000000L {
    raise InvalidXlsxInput(
      "xlsx: row or column fill exceeds the supported view size",
    )
  }
  if base_borders && row_count.to_int64() * col_count.to_int64() > 200000L {
    raise InvalidXlsxInput(
      "xlsx: row or column border exceeds the supported view size",
    )
  }
  let column_base = Array::make(col_count, -1)
  let column_last = Array::make(col_count, -1)
  for column in geo.columns {
    let first = Int32::max(column.first, 0)
    let last = Int32::min(column.last, col_count - 1)
    if first <= last {
      for c in first..<=last {
        column_last[c] = column.style
        if column.style >= 0 {
          column_base[c] = column.style
        }
      }
    }
  }
  let by_row : Map[Int32, XlsxRow] = Map([])
  let drawn_by_row : Map[Int32, @sheet.SizedGridRow] = Map([])
  for row in rows {
    by_row[row.index] = row
  }
  for row in cells {
    drawn_by_row[row.index] = row
  }
  let result : Array[@sheet.SizedGridRow] = []
  let black : XlsxRgb = { red: 0.0, green: 0.0, blue: 0.0, }
  for r in 0..<row_count {
    let source = by_row.get(r)
    let explicit : Map[Int32, Bool] = Map([])
    let row_style = if source is Some(row) {
      for cell in row.cells {
        explicit[cell.column] = true
      }
      row.style
    } else {
      -1
    }
    for c in 0..<col_count {
      if explicit.contains(c) {
        continue
      }
      let region = xlsx_plain_region_at(spans, region_rows, r, c)
      let style = if row_style >= 0 {
        row_style
      } else if region is Some(_) {
        column_last[c]
      } else {
        column_base[c]
      }
      if style < 0 {
        continue
      }
      let index = if style >= styles.cell_formats.length() { 0 } else { style }
      if base_borders {
        xlsx_put_base_border(
          styles, index, theme_colors, r, c, region, borders, border_colors, diagonals,
          border_colors_by_weight,
        )
      }
      let fill_index = styles.cell_formats[index].fill
      if fill_index < 0 || fill_index >= styles.fills.length() {
        continue
      }
      let fill = styles.fills[fill_index]
      if fill.pattern != "solid" {
        continue
      }
      let columns = match fills.get(r) {
        Some(columns) => columns
        None => {
          let columns : Map[Int32, @sheet.GridSolidFill] = Map([])
          fills[r] = columns
          columns
        }
      }
      columns[c] = {
        key: xlsx_solid_fill_key(fill),
        color: styles.resolve_color(fill.foreground, black, theme_colors).rgba(),
      }
    }
    match drawn_by_row.get(r) {
      Some(row) => result.push(row)
      None =>
        if fills.contains(r) || borders.contains(r) || diagonals.contains(r) {
          result.push({ index: r, cells: [], })
        }
    }
  }
  result
}

///|
fn xlsx_put_base_border(
  styles : XlsxStyles,
  format : Int32,
  theme : Map[Int32, XlsxRgb],
  row : Int32,
  col : Int32,
  region : @sheet.GridMergeRegion?,
  borders : Map[Int32, Map[Int32, @sheet.GridCellBorder]],
  colors_by_row : Map[Int32, Map[Int32, Array[UInt32]]],
  diagonals : Map[Int32, Map[Int32, @sheet.GridCellDiagonal]],
  colors_by_weight : Map[Int32, XlsxRgb],
) -> Unit raise {
  let (border, colors) = xlsx_plain_border(styles, format, theme)
  let weights = [border.top, border.bottom, border.left, border.right]
  if weights.any(weight => weight != 0) {
    for i, weight in weights {
      if weight != 0 {
        xlsx_check_border_color(colors_by_weight, weight, colors[i])
      }
    }
    let columns = match borders.get(row) {
      Some(columns) => columns
      None => {
        let columns : Map[Int32, @sheet.GridCellBorder] = Map([])
        borders[row] = columns
        columns
      }
    }
    columns[col] = if region is Some(region) {
      {
        top: if row == region.row_start {
          border.top
        } else {
          0
        },
        bottom: if row == region.row_end {
          border.bottom
        } else {
          0
        },
        left: if col == region.column_start {
          border.left
        } else {
          0
        },
        right: if col == region.column_end {
          border.right
        } else {
          0
        },
      }
    } else {
      border
    }
    let row_colors = match colors_by_row.get(row) {
      Some(row_colors) => row_colors
      None => {
        let row_colors : Map[Int32, Array[UInt32]] = Map([])
        colors_by_row[row] = row_colors
        row_colors
      }
    }
    row_colors[col] = colors.map(color => color.rgba())
  }
  let id = styles.cell_formats[format].border
  if id >= 0 && id < styles.borders.length() {
    let source = styles.borders[id]
    if source.diagonal_up || source.diagonal_down {
      let (weight, color) = xlsx_plain_border_side(
        styles,
        source.diagonal,
        theme,
      )
      if weight != 0 {
        xlsx_check_border_color(colors_by_weight, weight, color)
        let columns = match diagonals.get(row) {
          Some(columns) => columns
          None => {
            let columns : Map[Int32, @sheet.GridCellDiagonal] = Map([])
            diagonals[row] = columns
            columns
          }
        }
        columns[col] = {
          weight,
          color: color.rgba(),
          up: source.diagonal_up,
          down: source.diagonal_down,
        }
      }
    }
  }
}

///|
fn xlsx_check_base_style(
  styles : XlsxStyles,
  style : Int32,
) -> (Bool, Bool) raise {
  let index = if style < 0 || style >= styles.cell_formats.length() {
    0
  } else {
    style
  }
  let format = styles.cell_formats[index]
  let mut solid = false
  if format.fill >= 0 && format.fill < styles.fills.length() {
    let fill = styles.fills[format.fill]
    if (fill.pattern != "" && fill.pattern != "solid") ||
      fill.gradient is Some(_) {
      raise InvalidXlsxInput(
        "xlsx: row or column styles with fills are not supported",
      )
    }
    solid = fill.pattern == "solid"
  }
  let mut has_border = false
  if format.border >= 0 && format.border < styles.borders.length() {
    let border = styles.borders[format.border]
    if border.vertical.style != "" || border.horizontal.style != "" {
      raise InvalidXlsxInput(
        "xlsx: row or column styles with complex borders are not supported",
      )
    }
    has_border = border.left.style != "" ||
      border.right.style != "" ||
      border.top.style != "" ||
      border.bottom.style != "" ||
      (
        border.diagonal.style != "" &&
        (border.diagonal_up || border.diagonal_down)
      )
  }
  (solid, has_border)
}

///|
fn xlsx_check_border_color(
  colors : Map[Int32, XlsxRgb],
  weight : Int32,
  color : XlsxRgb,
) -> Unit raise {
  if colors.get(weight) is Some(previous) {
    if (
        previous.red != color.red ||
        previous.green != color.green ||
        previous.blue != color.blue
      ) &&
      (!xlsx_plain_byte_color(previous) || !xlsx_plain_byte_color(color)) {
      raise InvalidXlsxInput(
        "xlsx: mixed border colors require 8-bit RGB components",
      )
    }
  } else {
    colors[weight] = color
  }
}

///|
fn xlsx_plain_byte_color(color : XlsxRgb) -> Bool {
  for value in [color.red, color.green, color.blue] {
    let scaled = value * 255.0
    if (scaled - scaled.round()).abs() > 1.0e-9 {
      return false
    }
  }
  true
}

///|
fn xlsx_plain_border(
  styles : XlsxStyles,
  format : Int32,
  theme : Map[Int32, XlsxRgb],
) -> (@sheet.GridCellBorder, Array[XlsxRgb]) raise {
  let id = styles.cell_formats[format].border
  if id < 0 || id >= styles.borders.length() {
    let black : XlsxRgb = { red: 0.0, green: 0.0, blue: 0.0, }
    return (
      { top: 0, bottom: 0, left: 0, right: 0, },
      [black, black, black, black],
    )
  }
  let border = styles.borders[id]
  let (top, top_color) = xlsx_plain_border_side(styles, border.top, theme)
  let (bottom, bottom_color) = xlsx_plain_border_side(
    styles,
    border.bottom,
    theme,
  )
  let (left, left_color) = xlsx_plain_border_side(styles, border.left, theme)
  let (right, right_color) = xlsx_plain_border_side(styles, border.right, theme)
  (
    { top, bottom, left, right, },
    [top_color, bottom_color, left_color, right_color],
  )
}

///|
fn xlsx_plain_border_side(
  styles : XlsxStyles,
  side : XlsxBorderSide,
  theme : Map[Int32, XlsxRgb],
) -> (Int32, XlsxRgb) raise {
  let weight = match side.style {
    "" => 0
    "hair" => 1
    "dotted" => 2
    "dashDotDot" => 3
    "dashDot" => 4
    "dashed" => 5
    "thin" => 6
    "mediumDashDotDot" => 7
    "slantDashDot" => 8
    "mediumDashDot" => 9
    "mediumDashed" => 10
    "medium" => 11
    "double" => 12
    "thick" => 13
    _ =>
      raise InvalidXlsxInput(
        "xlsx: plain conversion does not support this border style",
      )
  }
  let black : XlsxRgb = { red: 0.0, green: 0.0, blue: 0.0, }
  (weight, styles.resolve_color(side.color, black, theme))
}

///|
fn xlsx_plain_spans(
  ranges : Array[XlsxRange],
) -> (
  Map[Int32, Map[Int32, Int32]],
  Map[Int32, Map[Int32, @sheet.GridMergeRegion]],
  Array[@sheet.GridMergeRegion],
) raise {
  let spans : Map[Int32, Map[Int32, Int32]] = Map([])
  let region_rows : Map[Int32, Map[Int32, @sheet.GridMergeRegion]] = Map([])
  let regions : Array[@sheet.GridMergeRegion] = []
  let mut room = 4194304L
  for range in ranges {
    if range.row_start < 0L ||
      range.row_end >= 1048576L ||
      range.row_start > range.row_end ||
      range.column_start < 0 ||
      range.column_end >= 16384 ||
      range.column_start > range.column_end {
      raise InvalidXlsxInput("xlsx: merged cells are outside the sheet")
    }
    let length = (range.column_end - range.column_start + 1).to_int64() *
      (range.row_end - range.row_start + 1L)
    if length > room {
      raise InvalidXlsxInput("xlsx: too many merged cells for plain conversion")
    }
    room -= length
    let region : @sheet.GridMergeRegion = {
      row_start: range.row_start.to_int(),
      row_end: range.row_end.to_int(),
      column_start: range.column_start,
      column_end: range.column_end,
    }
    regions.push(region)
    for row in region.row_start..<=region.row_end {
      let columns = match spans.get(row) {
        Some(columns) => columns
        None => {
          let columns : Map[Int32, Int32] = Map([])
          spans[row] = columns
          columns
        }
      }
      for start, end in columns {
        if range.column_start <= end && range.column_end >= start {
          raise InvalidXlsxInput(
            "xlsx: plain conversion does not support overlapping merges",
          )
        }
      }
      columns[range.column_start] = range.column_end
      let row_regions = match region_rows.get(row) {
        Some(columns) => columns
        None => {
          let columns : Map[Int32, @sheet.GridMergeRegion] = Map([])
          region_rows[row] = columns
          columns
        }
      }
      row_regions[range.column_start] = region
    }
  }
  (spans, region_rows, regions)
}

///|
fn xlsx_plain_region_at(
  spans : Map[Int32, Map[Int32, Int32]],
  region_rows : Map[Int32, Map[Int32, @sheet.GridMergeRegion]],
  row : Int32,
  column : Int32,
) -> @sheet.GridMergeRegion? {
  if xlsx_plain_span_at(spans, row, column) is Some((start, _)) &&
    region_rows.get(row) is Some(columns) {
    return columns.get(start)
  }
  None
}

///|
fn xlsx_plain_span_at(
  spans : Map[Int32, Map[Int32, Int32]],
  row : Int32,
  column : Int32,
) -> (Int32, Int32)? {
  if spans.get(row) is Some(columns) {
    for start, end in columns {
      if column >= start && column <= end {
        return Some((start, end))
      }
    }
  }
  None
}

///|
fn xlsx_plain_center_end(
  cells : Map[Int32, Map[Int32, Bool]],
  row : Int32,
  start : Int32,
  count : Int32,
) -> Int32 {
  let mut last = start
  if cells.get(row) is Some(columns) {
    while last + 1 < count && columns.get(last + 1) == Some(true) {
      last += 1
    }
  }
  last
}

///|
fn xlsx_apply_plain_run_fonts(
  rows : Array[XlsxRow],
  styles : XlsxStyles,
  rich_cells : Map[Int32, Map[Int32, XlsxPlainRun]],
) -> Array[XlsxRow] {
  rows.map(row => {
    let cells = row.cells.map(cell => {
      let run = match rich_cells.get(row.index) {
        Some(columns) => columns.get(cell.column)
        None => None
      }
      match run {
        Some({ font: Some(font), .. }) => {
          let index = if cell.style < 0 ||
            cell.style >= styles.cell_formats.length() {
            0
          } else {
            cell.style
          }
          let format = styles.cell_formats[index]
          let font_index = if format.font < 0 ||
            format.font >= styles.fonts.length() {
            0
          } else {
            format.font
          }
          let base = styles.fonts[font_index]
          let next : XlsxFont = {
            ..base,
            name: if font.name != "" {
              font.name
            } else {
              base.name
            },
            size: if font.size > 0.0 {
              font.size
            } else {
              base.size
            },
            bold: font.bold,
            italic: font.italic,
            underline: font.underline,
            strike: font.strike,
            vertical: font.vertical,
            color: if font.color.kind != 0 {
              font.color
            } else {
              base.color
            },
            scheme: if font.name != "" {
              font.scheme
            } else {
              base.scheme
            },
          }
          let new_font = styles.fonts.length()
          styles.fonts.push(next)
          let new_style = styles.cell_formats.length()
          styles.cell_formats.push({ ..format, font: new_font, })
          { ..cell, style: new_style, }
        }
        _ => cell
      }
    })
    { ..row, cells, }
  })
}

///|
fn xlsx_plain_run_format(text : String) -> XlsxFormatted {
  { pieces: [{ kind: 0, text, }], color: None, general: false, number: false, }
}

///|
fn xlsx_plain_format_cell(
  styles : XlsxStyles,
  cell : XlsxCell,
  row : Int32,
  rich_cells : Map[Int32, Map[Int32, XlsxPlainRun]],
  date1904 : Bool,
  locale : String,
) -> XlsxFormatted? {
  if cell.kind == 2 &&
    rich_cells.get(row) is Some(columns) &&
    columns.get(cell.column) is Some(text) {
    Some(xlsx_plain_run_format(text.text))
  } else {
    styles.format_cell(cell, date1904, locale)
  }
}

///|
fn xlsx_plain_fitted_rows(
  rows : Array[XlsxRow],
  styles : XlsxStyles,
  geometry : XlsxSheetGeometry,
  spans : Map[Int32, Map[Int32, Int32]],
  widths : Array[Double],
  date1904 : Bool,
  locale : String,
  default_size : Double,
  rich_cells : Map[Int32, Map[Int32, XlsxPlainRun]],
) -> Map[Int32, Double] {
  let result : Map[Int32, Double] = Map([])
  for row in rows {
    if row.hidden || row.height >= 0.0 {
      continue
    }
    let mut best = 0.0
    for cell in row.cells {
      if cell.kind == 0 ||
        (cell.kind == 1 && cell.number == 0.0 && !geometry.show_zero) ||
        xlsx_plain_span_at(spans, row.index, cell.column) is Some(_) {
        continue
      }
      let format_index = if cell.style < 0 ||
        cell.style >= styles.cell_formats.length() {
        0
      } else {
        cell.style
      }
      let font_id = styles.cell_formats[format_index].font
      let font_index = if font_id < 0 || font_id >= styles.fonts.length() {
        0
      } else {
        font_id
      }
      let size = styles.fonts[font_index].size
      let indent = xlsx_plain_indent(
        styles.cell_formats[format_index].alignment,
        cell.kind,
      )
      if styles.cell_formats[format_index].alignment.wrap {
        if xlsx_plain_format_cell(
            styles,
            cell,
            row.index,
            rich_cells,
            date1904,
            locale,
          )
          is Some(formatted) {
          let text = xlsx_plain_wrap_text(formatted.text())
          let width = if cell.column >= 0 && cell.column < widths.length() {
            Double::max(widths[cell.column] - 3.75 - indent, 0.0)
          } else {
            0.0
          }
          let bold = styles.fonts[font_index].bold
          let drawn_size = if styles.fonts[font_index].vertical == "" {
            size
          } else {
            size * (2.0 / 3.0)
          }
          let advance = (c : Char, b : Bool) => {
            @sheet.sized_fallback_advance(c, b, drawn_size)
          }
          let lines = @sheet.wrap_text(text, width, bold~, advance~)
          let mut text_height = 0.0
          for _ in lines {
            text_height += 0.9 * size + 0.25 * size
          }
          text_height = text_height + 1.5 - 1.5
          best = Double::max(best, text_height)
        }
      } else if (0.9 + 0.25) * size > (0.9 + 0.25) * default_size + 0.01 {
        let mut actual_size = size
        if styles.cell_formats[format_index].alignment.shrink && cell.kind != 1 {
          if xlsx_plain_format_cell(
              styles,
              cell,
              row.index,
              rich_cells,
              date1904,
              locale,
            )
            is Some(formatted) {
            let width = if cell.column >= 0 && cell.column < widths.length() {
              Double::max(widths[cell.column] - 3.75 - indent, 0.0)
            } else {
              0.0
            }
            let drawn_size = if styles.fonts[font_index].vertical == "" {
              size
            } else {
              size * (2.0 / 3.0)
            }
            let scale = xlsx_plain_shrink_scale(
              formatted.text(),
              width,
              drawn_size,
            )
            actual_size = if scale == 0.0 { size } else { size * scale }
          }
        }
        let text_height = 0.9 * actual_size + 0.25 * actual_size + 1.5 - 1.5
        best = Double::max(best, text_height)
      }
    }
    if best > 0.0 {
      result[row.index] = ((best / 0.75 - 0.05).ceil() + 2.0) * 0.75
    }
  }
  result
}

///|
fn xlsx_plain_indent(alignment : XlsxAlignment, kind : Int32) -> Double {
  let horizontal = alignment.horizontal
  if alignment.indent > 0 &&
    (
      horizontal == "left" ||
      horizontal == "right" ||
      (horizontal == "general" && (kind == 1 || kind == 2))
    ) {
    alignment.indent.to_double() * 7.5
  } else {
    0.0
  }
}

///|
fn xlsx_plain_shrink_scale(
  text : String,
  available : Double,
  size : Double,
) -> Double {
  let mut width = 0.0
  let mut shown = 0
  for c in text {
    if c == '\n' {
      shown += 1
    } else {
      let ch = if c == '\t' { ' ' } else { c }
      if ch.to_int() < 0x20 {
        continue
      }
      width += @sheet.sized_fallback_advance(ch, false, size)
      shown += 1
    }
    if shown >= 1024 {
      break
    }
  }
  if width > available + 0.01 && width > 0.0 {
    available / width
  } else {
    1.0
  }
}

///|
fn xlsx_plain_wrap_text(text : String) -> String {
  let output = StringBuilder()
  let mut shown = 0
  for c in text {
    let ch = if c == '\t' { ' ' } else { c }
    if ch == '\n' || ch.to_int() >= 0x20 {
      output.write_char(ch)
      shown += 1
      if shown >= 1024 {
        break
      }
    }
  }
  output.to_string()
}

///|
fn xlsx_solid_fill_key(fill : XlsxFill) -> String {
  let fg = fill.foreground
  let bg = fill.background
  fg.kind.to_string() +
  ":" +
  fg.rgb.to_string() +
  ":" +
  fg.index.to_string() +
  ":" +
  fg.tint.to_string() +
  ":" +
  bg.kind.to_string() +
  ":" +
  bg.rgb.to_string() +
  ":" +
  bg.index.to_string() +
  ":" +
  bg.tint.to_string()
}

///|
fn xlsx_fit_plain_number(
  value : Double,
  available : Double,
  size : Double,
) -> String {
  for n = 10; n >= 1; n = n - 1 {
    let candidate = xlsx_format_general(value, n)
    if candidate == "" {
      continue
    }
    let mut width = 0.0
    for c in candidate {
      width += @sheet.sized_fallback_advance(c, false, size)
    }
    if width <= available + 0.01 {
      return candidate
    }
  }
  let n = (available /
  Double::max(@sheet.sized_fallback_advance('#', false, size), 0.01)).to_int()
  "#".repeat(n)
}

///|
fn xlsx_plain_font_color(
  styles : XlsxStyles,
  style : Int32,
  theme : Map[Int32, XlsxRgb],
) -> UInt32 raise {
  let index = if style < 0 || style >= styles.cell_formats.length() {
    0
  } else {
    style
  }
  let raw_font = styles.cell_formats[index].font
  let font_index = if raw_font < 0 || raw_font >= styles.fonts.length() {
    0
  } else {
    raw_font
  }
  let black : XlsxRgb = { red: 0.0, green: 0.0, blue: 0.0, }
  let color = styles.fonts[font_index].color
  if color.kind == 2 &&
    color.index >= 0 &&
    color.index < 12 &&
    !theme.contains(color.index) {
    raise InvalidXlsxInput(
      "xlsx: plain conversion does not support this theme color",
    )
  }
  styles.resolve_color(color, black, theme).rgba()
}
