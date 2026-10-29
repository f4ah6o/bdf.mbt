///|
/// CSV-specific converter parameters after validation.
pub(all) struct Params {
  charset : String
  delimiter : Byte
  quote : Int32
  header : Header
  data_mode : DataMode
  table_style : String
}

///|
/// Parse the CSV converter's named parameters using upstream conventions.
pub fn parse_params(params : Map[String, String]) -> Params raise {
  let raw_delimiter = params.get("delimiter").unwrap_or("")
  let delimiter : Byte = match raw_delimiter.to_lower() {
    "comma" => b','
    "tab" | "\\t" => b'\t'
    "semicolon" => b';'
    "pipe" | "bar" => b'|'
    "space" => b' '
    _ =>
      if raw_delimiter == "" || raw_delimiter == "auto" {
        0
      } else {
        let bytes = @utf8.encode(raw_delimiter)
        if bytes.length() != 1 || bytes[0] >= 128 {
          raise InvalidDialect(
            "csv: parameter delimiter: " +
            csv_go_quote(raw_delimiter, '"') +
            " is not comma, tab, semicolon, pipe or an ASCII character",
          )
        }
        bytes[0]
      }
  }
  let raw_quote = params.get("quote").unwrap_or("")
  let quote = match raw_quote.to_lower() {
    "" | "auto" => 0
    "double" | "\"" => 34
    "single" | "'" => 39
    "none" => -1
    _ =>
      raise InvalidDialect(
        "csv: parameter quote: " +
        csv_go_quote(raw_quote, '"') +
        " is not double, single or none",
      )
  }
  let raw_data = params.get("data").unwrap_or("")
  let data_mode = match raw_data.to_lower() {
    "" | "default" => DataDefault
    "all" => DataAll
    "none" => DataNone
    _ =>
      raise InvalidDialect(
        "csv: parameter data: " +
        csv_go_quote(raw_data, '"') +
        " is not none, all or default",
      )
  }
  let raw_header = params.get("header").unwrap_or("").to_lower()
  let header = match raw_header {
    "" | "auto" => HeaderAuto
    "1" | "t" | "true" => HeaderYes
    "0" | "f" | "false" => HeaderNo
    _ =>
      raise InvalidDialect(
        "csv: parameter header: " +
        csv_go_quote(raw_header, '"') +
        " is not true, false or auto",
      )
  }
  {
    charset: params.get("charset").unwrap_or(""),
    delimiter,
    quote,
    header,
    data_mode,
    table_style: params.get("table").unwrap_or(""),
  }
}

///|
/// Name a CSV sheet from its input path, as the upstream converter does.
pub fn sheet_name(path : String) -> String {
  if path == "" {
    return "."
  }
  let parts = path.split("/").to_array()
  let mut index = parts.length() - 1
  while index >= 0 && parts[index].length() == 0 {
    index -= 1
  }
  if index < 0 {
    return "/"
  }
  let base = parts[index].to_owned()
  let bytes = @utf8.encode(base)
  let mut dot = -1
  for i in 0..<bytes.length() {
    if bytes[i] == b'.' {
      dot = i
    }
  }
  if dot < 0 {
    base
  } else {
    @utf8.decode_lossy(bytes[:dot])
  }
}

///|
/// Describe a conversion using the upstream CSV summary format.
pub fn summary(parsed : ParseResult) -> String {
  let delimiter = match parsed.dialect.delimiter {
    b',' => "comma"
    b'\t' => "tab"
    b';' => "semicolon"
    b'|' => "pipe"
    b' ' => "space"
    other => csv_quote_rune(other.to_int())
  }
  let details : Array[String] = [
    parsed.charset + (if parsed.bom { " with BOM" } else { "" }),
    delimiter + "-separated",
  ]
  if parsed.dialect.quote == 0 {
    details.push("no quotes")
  } else if parsed.dialect.quote == 39 {
    details.push("single quotes")
  }
  if parsed.dialect.escape != 0 {
    details.push("backslash escapes")
  }
  details.push(if parsed.header { "header row" } else { "no header row" })
  "\{parsed.rows.length()} row(s) × \{parsed.columns} column(s) (" +
  details.join(", ") +
  "), 0 embedded font(s)"
}
