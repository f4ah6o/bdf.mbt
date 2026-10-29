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
) -> Unit raise {
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
  while true {
    let event = reader.read_event()
    match event.kind {
      Start(element) | Empty(element) => {
        let name = element.name.local_name
        if depth == 1 {
          if ![
              "sheetData", "dimension", "sheetViews", "cols", "sheetFormatPr", "sheetPr",
              "pageMargins", "pageSetup", "printOptions", "headerFooter", "rowBreaks",
              "colBreaks",
            ].contains(name) {
            raise InvalidXlsxInput(
              "xlsx: plain conversion does not support worksheet feature " +
              name,
            )
          }
          if name == "sheetData" && event.kind is Start(_) {
            sheet_data_depth = depth + 1
          }
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
            kind != "e" {
            raise InvalidXlsxInput(
              "xlsx: plain conversion supports only numeric, plain string, boolean and error cells",
            )
          }
          if event.kind is Start(_) {
            cell_depth = depth + 1
          }
        } else if depth == cell_depth && name == "is" && event.kind is Start(_) {
          inline_depth = depth + 1
        } else if depth == inline_depth && name == "r" {
          raise InvalidXlsxInput(
            "xlsx: plain conversion does not support rich text",
          )
        }
        if event.kind is Start(_) {
          depth += 1
        } else if depth == 0 {
          break
        }
      }
      End(_) => {
        depth -= 1
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
  while true {
    let event = reader.read_event()
    match event.kind {
      Start(element) | Empty(element) => {
        let name = element.name.local_name
        if depth == 1 && name == "si" && event.kind is Start(_) {
          string_depth = depth + 1
        } else if depth == string_depth && name == "r" {
          raise InvalidXlsxInput(
            "xlsx: plain conversion does not support rich text",
          )
        }
        if event.kind is Start(_) {
          depth += 1
        } else if depth == 0 {
          break
        }
      }
      End(_) => {
        depth -= 1
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
fn xlsx_check_plain_style(styles : XlsxStyles, locale : String) -> Unit raise {
  let format = styles.cell_formats[0]
  let a = format.alignment
  let font = styles.fonts[0]
  let nondefault_fill = format.fill >= 0 &&
    format.fill < styles.fills.length() &&
    (
      styles.fills[format.fill].pattern != "" ||
      styles.fills[format.fill].gradient is Some(_)
    )
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
  if format.font != 0 ||
    font.name != "Calibri" ||
    font.size != 11.0 ||
    font.bold ||
    font.italic ||
    font.underline != "" ||
    font.strike ||
    font.color.kind != 0 ||
    (font.scheme != "" && font.scheme != "minor") ||
    font.vertical != "" ||
    format.number_format != 0 ||
    styles.number_format(0, locale) != "General" ||
    a.horizontal != "general" ||
    a.vertical != "bottom" ||
    a.wrap ||
    a.shrink ||
    a.indent != 0 ||
    a.rotation != 0 ||
    a.justify_last ||
    nondefault_fill ||
    nondefault_border {
    raise InvalidXlsxInput(
      "xlsx: plain conversion does not support styled cells",
    )
  }
}

///|
/// Convert unstyled worksheets using estimated font metrics.
/// Supports sheet views with numeric, plain string, boolean and error cells only; complex
/// features are rejected. This entry point does not embed fonts.
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
  let theme = workbook.package.theme_fonts(workbook.part)
  if theme.resolve("+mn-lt", "") != "Calibri" {
    raise InvalidXlsxInput(
      "xlsx: plain conversion does not support themed fonts",
    )
  }
  let styles = workbook.styles()
  xlsx_check_plain_style(styles, locale.number_locale)
  workbook.xlsx_check_plain_strings()
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
    let drawn = workbook.xlsx_draw_plain_sheet(
      ref, styles, locale, doc_language,
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
    grids.push({ id, title: ref.name, grid: drawn, })
  }
  @sheet.store_grids(writer, grids, !no_text_index)
  { bdf: writer.write_single(), warnings, sheets: grids.length(), }
}

///|
fn XlsxWorkbook::xlsx_draw_plain_sheet(
  workbook : XlsxWorkbook,
  ref : XlsxSheetRef,
  styles : XlsxStyles,
  locale : XlsxLocale,
  doc_language : String,
) -> @sheet.DrawnGrid raise {
  workbook.xlsx_check_plain_sheet(ref.part)
  let parsed = workbook.read_sheet_cells(ref.part)
  if parsed.missing_formula_values > 0 {
    raise InvalidXlsxInput(
      "xlsx: plain conversion requires cached formula values",
    )
  }
  let rows = parsed.sorted_rows()
  let geo = workbook.read_sheet_geometry(ref.part)
  if !geo.merges.is_empty() ||
    geo.frozen_rows != 0 ||
    geo.frozen_columns != 0 ||
    !geo.show_grid ||
    !geo.show_zero ||
    geo.right_to_left {
    raise InvalidXlsxInput(
      "xlsx: plain conversion does not support worksheet layout features",
    )
  }
  for column in geo.columns {
    if column.style > 0 {
      raise InvalidXlsxInput(
        "xlsx: plain conversion does not support column styles",
      )
    }
  }
  let (row_count, col_count) = xlsx_initial_extent(parsed, geo, [])
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
  let heights : Array[@sheet.Run] = xlsx_row_runs(
    rows,
    geo,
    row_count,
    12.65,
    Map([]),
  ).map(run => { count: run.count, size: run.size, })
  let geometry : @sheet.GridGeometry = {
    columns,
    rows: heights,
    frozen_rows: 0,
  }
  let cells : Array[@sheet.SizedGridRow] = []
  for row in rows {
    if row.style >= 0 {
      raise InvalidXlsxInput(
        "xlsx: plain conversion does not support row styles",
      )
    }
    let entries : Array[@sheet.SizedGridCell] = []
    for cell in row.cells {
      if cell.style != 0 ||
        (
          cell.kind != 0 &&
          cell.kind != 1 &&
          cell.kind != 2 &&
          cell.kind != 3 &&
          cell.kind != 4
        ) {
        raise InvalidXlsxInput(
          "xlsx: plain conversion does not support this cell",
        )
      }
      if styles.format_cell(cell, workbook.date1904, locale.number_locale)
        is Some(formatted) {
        let text = formatted.text()
        if cell.kind == 1 || cell.kind == 3 || cell.kind == 4 {
          let mut width = 0.0
          for c in text {
            width += @sheet.fallback_advance(c, false)
          }
          if cell.column >= 0 &&
            cell.column < widths.length() &&
            widths[cell.column] > 0.0 &&
            width > widths[cell.column] - 3.75 + 0.01 {
            raise InvalidXlsxInput(
              "xlsx: plain conversion does not support narrow numeric cells",
            )
          }
        }
        entries.push({
          column: cell.column,
          cell: { text, number: cell.kind == 1, },
          center: cell.kind == 3 || cell.kind == 4,
        })
      }
    }
    cells.push({ index: row.index, cells: entries, })
  }
  @sheet.draw_sized_grid_no_fonts(
    cells,
    geometry,
    all_columns,
    locale.language,
    doc_language,
  )
}
