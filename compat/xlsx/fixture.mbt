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
