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

///|
#export_name("table_fixture")
pub fn table_fixture(value : String) -> String {
  let parsed : @csv.ParseResult = {
    rows: [[value]],
    columns: 1,
    charset: "UTF-8",
    bom: false,
    dialect: { delimiter: b',', quote: b'"', escape: 0, },
    header: false,
    warnings: [],
  }
  let table = @csv.values_table(parsed).unwrap()
  let kind = match table.columns[0].kind {
    TextColumn => "string"
    NumberColumn => "number"
    IntegerColumn => "integer"
    BooleanColumn => "boolean"
    DateColumn => "date"
    DateTimeColumn => "datetime"
  }
  let actual = match table.rows[0][0] {
    TextValue(text) => text
    NumberValue(number) =>
      if number.reinterpret_as_uint64() == 0x8000000000000000UL {
        "-0"
      } else {
        number.to_string()
      }
    IntegerValue(number) => number.to_string()
    BooleanValue(boolean) => boolean.to_string()
    DateValue(day) => day.to_string()
    DateTimeValue(ms) => ms.to_string()
    NullValue => ""
  }
  Json::object({ "kind": Json::string(kind), "value": Json::string(actual) }).stringify()
}
