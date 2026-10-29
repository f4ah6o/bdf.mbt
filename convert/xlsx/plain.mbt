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
              "colBreaks", "mergeCells",
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
    b.diagonal.style != "" ||
    b.vertical.style != "" ||
    b.horizontal.style != "" ||
    b.diagonal_up ||
    b.diagonal_down
  } else {
    false
  }
  if font.name != "Calibri" ||
    (index == 0 && font.size != 11.0) ||
    font.italic ||
    font.underline != "" ||
    font.strike ||
    (font.scheme != "" && font.scheme != "minor") ||
    font.vertical != "" ||
    (
      a.horizontal != "general" &&
      a.horizontal != "center" &&
      a.horizontal != "left" &&
      a.horizontal != "right"
    ) ||
    (a.vertical != "bottom" && a.vertical != "top" && a.vertical != "center") ||
    a.wrap ||
    a.shrink ||
    a.indent != 0 ||
    a.rotation != 0 ||
    a.justify_last ||
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
/// number formats, font colors, bold text, horizontal alignment, top or center
/// vertical alignment, solid fills, basic borders and merged cells. Border
/// colors are limited to one per line weight; complex features are rejected.
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
  let theme_colors = workbook.xlsx_plain_theme_colors()
  xlsx_check_plain_style(styles, 0)
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
      ref, styles, locale, doc_language, theme_colors,
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
  styles : XlsxStyles,
  locale : XlsxLocale,
  doc_language : String,
  theme_colors : Map[Int32, XlsxRgb],
) -> (@sheet.DrawnGrid, XlsxSheetGeometry, Int32) raise {
  workbook.xlsx_check_plain_sheet(ref.part)
  let parsed = workbook.read_sheet_cells(ref.part)
  let rows = parsed.sorted_rows()
  let geo = workbook.read_sheet_geometry(ref.part)
  let (spans, region_rows, merge_regions) = xlsx_plain_spans(geo.merges)
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
  let fitted = xlsx_plain_fitted_rows(rows, styles, geo, spans)
  let heights : Array[@sheet.Run] = xlsx_row_runs(
    rows, geo, row_count, 12.65, fitted,
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
  let fills : Map[Int32, Map[Int32, @sheet.GridSolidFill]] = Map([])
  let sizes : Map[Int32, Map[Int32, Double]] = Map([])
  let east_asian_fonts : Map[Int32, Map[Int32, String]] = Map([])
  let minor_east_asian = workbook.package
    .theme_fonts(workbook.part)
    .resolve("+mn-ea", locale.script)
  let borders : Map[Int32, Map[Int32, @sheet.GridCellBorder]] = Map([])
  let border_colors : Map[Int32, Map[Int32, Array[UInt32]]] = Map([])
  let border_colors_by_weight : Map[Int32, XlsxRgb] = Map([])
  let checked_styles : Map[Int32, Bool] = Map([])
  let format_cache : Map[Int32, Array[XlsxFormatSection]] = Map([])
  let color_cache : Map[Int32, UInt32] = Map([])
  let border_cache : Map[Int32, (@sheet.GridCellBorder, Array[XlsxRgb])] = Map([])
  for row in rows {
    if row.style >= 0 {
      raise InvalidXlsxInput(
        "xlsx: plain conversion does not support row styles",
      )
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
      if styles.fonts[font_index].scheme == "minor" && minor_east_asian != "" {
        let columns = match east_asian_fonts.get(row.index) {
          Some(columns) => columns
          None => {
            let columns : Map[Int32, String] = Map([])
            east_asian_fonts[row.index] = columns
            columns
          }
        }
        columns[cell.column] = minor_east_asian
      }
      let span = xlsx_plain_region_at(
        spans,
        region_rows,
        row.index,
        cell.column,
      )
      let (border, colors) = match border_cache.get(format_index) {
        Some(border) => border
        None => {
          let border = xlsx_plain_border(styles, format_index, theme_colors)
          border_cache[format_index] = border
          border
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
          let color = colors[i]
          if border_colors_by_weight.get(weight) is Some(previous) {
            if previous.red != color.red ||
              previous.green != color.green ||
              previous.blue != color.blue {
              raise InvalidXlsxInput(
                "xlsx: plain conversion supports one border color per line weight",
              )
            }
          } else {
            border_colors_by_weight[weight] = color
          }
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
        if cell.kind == 1 {
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
          let mut width = 0.0
          for c in text {
            width += @sheet.sized_fallback_advance(c, false, font_size)
          }
          if cell.column >= 0 &&
            cell.column < widths.length() &&
            cell_width > 0.0 &&
            width > cell_width - 3.75 + 0.01 {
            let available = Double::max(cell_width - 3.75, 0.0)
            text = if formatted.general {
              xlsx_fit_plain_number(cell.number, available, font_size)
            } else {
              "#".repeat(
                (available /
                @sheet.sized_fallback_advance('#', false, font_size)).to_int(),
              )
            }
          }
        }
        let vertical = styles.cell_formats[format_index].alignment.vertical
        let horizontal = styles.cell_formats[format_index].alignment.horizontal
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
        entries.push({
          column: cell.column,
          cell: { text, number: cell.kind == 1, },
          center: horizontal == "center" ||
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
  let drawn = @sheet.draw_sized_grid_no_fonts(
    cells,
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
  )
  (drawn, geo, parsed.missing_formula_values)
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
    "thin" => 6
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
fn xlsx_plain_fitted_rows(
  rows : Array[XlsxRow],
  styles : XlsxStyles,
  geometry : XlsxSheetGeometry,
  spans : Map[Int32, Map[Int32, Int32]],
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
      if (0.9 + 0.25) * size > (0.9 + 0.25) * 11.0 + 0.01 {
        let text_height = 0.9 * size + 0.25 * size + 1.5 - 1.5
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
