///|
#export_name("read_fixture")
pub fn read_fixture(data : Bytes, label : String) -> String {
  let parsed = try! @csv.parse(data, charset=label)
  let decoded = try! @csv.decode_text(data, charset=label)
  let rows = parsed.rows.map(row => Json::array(row.map(Json::string)))
  Json::object({
    "charset": Json::string(parsed.charset),
    "bom": Json::boolean(parsed.bom),
    "text": Json::string(decoded.text),
    "delimiter": Json::number(parsed.dialect.delimiter.to_int().to_double()),
    "quote": Json::number(parsed.dialect.quote.to_int().to_double()),
    "escape": Json::number(parsed.dialect.escape.to_int().to_double()),
    "rows": Json::array(rows),
    "header": Json::boolean(parsed.header),
    "columns": Json::number(parsed.columns.to_double()),
    "warnings": Json::array(parsed.warnings.map(Json::string)),
  }).stringify()
}

///|
#export_name("decode_only")
pub fn decode_only(data : Bytes, label : String) -> String {
  (try! @csv.decode_text(data, charset=label)).text
}
