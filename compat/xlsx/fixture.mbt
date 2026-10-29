///|
#export_name("xlsx_workbook")
pub fn xlsx_workbook(data : Bytes) -> String {
  try {
    let workbook = @xlsx.read_xlsx_workbook(data)
    let sheets = workbook.sheets.map(sheet => {
      Json::array([
        Json::string(sheet.name),
        Json::string(sheet.part),
        Json::boolean(sheet.chart),
        Json::boolean(sheet.hidden),
        Json::number(sheet.index.to_double()),
      ])
    })
    Json::array([
      Json::string(workbook.part),
      Json::boolean(workbook.date1904),
      Json::array(sheets),
      Json::array(workbook.warnings.map(w => Json::string(w))),
    ]).stringify()
  } catch {
    _ => "null"
  }
}

///|
#export_name("xlsx_reference")
pub fn xlsx_reference(text : String, column : Int32) -> String {
  let (col, row, ok) = @xlsx.xlsx_parse_ref(text)
  Json::array([
    Json::number(col.to_double()),
    Json::number(row.to_double()),
    Json::boolean(ok),
    Json::string(@xlsx.xlsx_col_name(column)),
    Json::string(@xlsx.xlsx_decode_string(text)),
  ]).stringify()
}

///|
#export_name("xlsx_strings")
pub fn xlsx_strings(data : Bytes) -> String {
  try {
    let workbook = @xlsx.read_xlsx_workbook(data)
    Json::array(workbook.shared_strings().map(s => Json::string(s))).stringify()
  } catch {
    _ => "null"
  }
}

///|
#export_name("xlsx_iso_date")
pub fn xlsx_iso_date(value : String, date1904 : Bool) -> String {
  match @xlsx.xlsx_iso_serial(value, date1904) {
    None => Json::array([Json::number(0.0), Json::boolean(false)]).stringify()
    Some(v) => Json::array([Json::number(v), Json::boolean(true)]).stringify()
  }
}

///|
fn xlsx_row_json(row : @xlsx.XlsxRow) -> Json {
  let cells = row.cells.map(fn(c) {
    Json::array([
      Json::number(c.column.to_double()),
      Json::number(c.style.to_double()),
      Json::number(c.kind.to_double()),
      Json::number(c.number),
      Json::string(c.text),
    ])
  })
  Json::array([
    Json::number(row.index.to_double()),
    Json::number(row.height),
    Json::boolean(row.custom_height),
    Json::boolean(row.hidden),
    Json::number(row.style.to_double()),
    Json::array(cells),
  ])
}

///|
#export_name("xlsx_cells")
pub fn xlsx_cells(data : Bytes, part : String) -> String {
  try {
    let workbook = @xlsx.read_xlsx_workbook(data)
    let sheet = workbook.read_sheet_cells(part)
    Json::array([
      Json::array(sheet.rows.map(xlsx_row_json)),
      Json::number(sheet.missing_formula_values.to_double()),
      Json::array(sheet.sorted_rows().map(xlsx_row_json)),
    ]).stringify()
  } catch {
    _ => "null"
  }
}

///|
#export_name("xlsx_range")
pub fn xlsx_range(value : String) -> String {
  match @xlsx.xlsx_parse_range(value) {
    None =>
      Json::array([
        Json::number(0.0),
        Json::number(0.0),
        Json::number(0.0),
        Json::number(0.0),
        Json::boolean(false),
      ]).stringify()
    Some(r) =>
      Json::array([
        Json::number(r.row_start.to_double()),
        Json::number(r.column_start.to_double()),
        Json::number(r.row_end.to_double()),
        Json::number(r.column_end.to_double()),
        Json::boolean(true),
      ]).stringify()
  }
}

///|
fn xlsx_range_json(r : @xlsx.XlsxRange) -> Json {
  Json::array([
    Json::number(r.row_start.to_double()),
    Json::number(r.column_start.to_double()),
    Json::number(r.row_end.to_double()),
    Json::number(r.column_end.to_double()),
  ])
}

///|
#export_name("xlsx_geometry")
pub fn xlsx_geometry(data : Bytes, part : String) -> String {
  try {
    let workbook = @xlsx.read_xlsx_workbook(data)
    let s = workbook.read_sheet_geometry(part)
    let cols = s.columns.map(c => {
      Json::array([
        Json::number(c.first.to_double()),
        Json::number(c.last.to_double()),
        Json::number(c.width),
        Json::boolean(c.hidden),
        Json::number(c.style.to_double()),
      ])
    })
    Json::array([
      Json::number(s.default_column_width),
      Json::number(s.base_column_width),
      Json::number(s.default_row_height),
      Json::boolean(s.zero_height),
      Json::boolean(s.show_grid),
      Json::boolean(s.show_zero),
      Json::boolean(s.right_to_left),
      Json::number(s.frozen_columns.to_double()),
      Json::number(s.frozen_rows.to_double()),
      Json::array(cols),
      Json::array(s.merges.map(xlsx_range_json)),
      match s.auto_filter {
        None => Json::null()
        Some(r) => xlsx_range_json(r)
      },
    ]).stringify()
  } catch {
    _ => "null"
  }
}

///|
#export_name("xlsx_styles")
pub fn xlsx_styles(data : Bytes) -> String {
  try {
    let workbook = @xlsx.read_xlsx_workbook(data)
    let styles = workbook.styles()
    let fonts = styles.fonts.map(fn(f) {
      let color = f.color
      Json::array([
        Json::string(f.name),
        Json::number(f.size),
        Json::boolean(f.bold),
        Json::boolean(f.italic),
        Json::string(f.underline),
        Json::boolean(f.strike),
        Json::number(color.kind.to_double()),
        Json::number(((color.rgb >> 16) & 255U).to_double() / 255.0),
        Json::number(((color.rgb >> 8) & 255U).to_double() / 255.0),
        Json::number((color.rgb & 255U).to_double() / 255.0),
        Json::number(color.index.to_double()),
        Json::number(color.tint),
        Json::string(f.vertical),
        Json::string(f.scheme),
        Json::number(f.family.to_double()),
      ])
    })
    let ids : Array[Int32] = []
    for id, _ in styles.number_formats {
      ids.push(id)
    }
    ids.sort()
    let formats = ids.map(id => {
      Json::array([
        Json::number(id.to_double()),
        Json::string(styles.number_formats[id]),
      ])
    })
    let xfs = styles.cell_formats.map(fn(x) {
      let a = x.alignment
      Json::array([
        Json::number(x.number_format.to_double()),
        Json::number(x.font.to_double()),
        Json::number(x.fill.to_double()),
        Json::number(x.border.to_double()),
        Json::string(a.horizontal),
        Json::string(a.vertical),
        Json::boolean(a.wrap),
        Json::boolean(a.shrink),
        Json::number(a.indent.to_double()),
        Json::number(a.rotation.to_double()),
        Json::boolean(a.justify_last),
      ])
    })
    Json::array([Json::array(fonts), Json::array(formats), Json::array(xfs)]).stringify()
  } catch {
    _ => "null"
  }
}

///|
#export_name("xlsx_general")
pub fn xlsx_general(value : Double, width : Int32) -> String {
  @xlsx.xlsx_format_general(value, width)
}
