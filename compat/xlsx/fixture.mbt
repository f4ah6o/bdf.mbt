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
