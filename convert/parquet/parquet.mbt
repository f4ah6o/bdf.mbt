///|
/// A Parquet conversion failure.
pub suberror ParquetInputError {
  ParquetInputInvalid(String)
}

///|
pub(all) struct ParquetInputResult {
  bdf : Bytes
  pages : Int32
  summary : String
  warnings : Array[String]
}

///|
/// Detect a Parquet file.
pub fn detect(data : Bytes) -> Bool {
  data.length() >= 12 && data.has_prefix(b"PAR1") && data.has_suffix(b"PAR1")
}

///|
fn parquet_csv_field(text : String) -> String {
  let need_quote = text.contains(",") || text.contains("\"") ||
    text.contains("\n") || text.contains("\r")
  if !need_quote {
    return text
  }
  let output = StringBuilder()
  output.write_char('"')
  for character in text {
    if character == '"' {
      output.write_char('"')
    }
    output.write_char(character)
  }
  output.write_char('"')
  output.to_string()
}

///|
fn parquet_value_text(value : @parquet.Value) -> String {
  match value {
    @parquet.Null => ""
    @parquet.StringValue(text) => text
    @parquet.NumberValue(number) => number.to_string()
    @parquet.IntegerValue(number) => number.to_string()
    @parquet.BooleanValue(flag) => if flag { "true" } else { "false" }
    @parquet.DateValue(days) => days.to_string()
    @parquet.DateTimeValue(millis) => millis.to_string()
  }
}

///|
fn parquet_to_csv(table : @parquet.Table) -> Bytes {
  let output = StringBuilder()
  for index, column in table.columns {
    if index > 0 {
      output.write_char(',')
    }
    output.write_string(parquet_csv_field(column.name))
  }
  output.write_char('\n')
  for row in table.rows {
    for index, value in row {
      if index > 0 {
        output.write_char(',')
      }
      output.write_string(parquet_csv_field(parquet_value_text(value)))
    }
    output.write_char('\n')
  }
  @utf8.encode(output.to_string())
}

///|
/// Convert a flat Parquet table into a BDF sheet through the CSV renderer.
pub fn convert(
  data : Bytes,
  title~ : String = "",
  no_text_index~ : Bool = false,
) -> ParquetInputResult raise ParquetInputError {
  if data.length() > 1073741824 {
    raise ParquetInputInvalid("parquet: the file is larger than 1073741824 bytes")
  }
  let table = @parquet.decode(data) catch {
    @parquet.InvalidTable(message) => raise ParquetInputInvalid(message)
    _ => raise ParquetInputInvalid("parquet: invalid table")
  }
  if table.columns.is_empty() {
    raise ParquetInputInvalid("parquet: the table has no columns")
  }
  let csv = parquet_to_csv(table)
  let result = @csv.convert_no_fonts(
    csv,
    name="table.parquet",
    title~,
    no_text_index~,
  ) catch {
    _ => raise ParquetInputInvalid("parquet: the table could not be drawn")
  }
  {
    bdf: result.bdf,
    pages: 1,
    summary: "1 page (\{table.rows.length()} rows × \{table.columns.length()} columns)",
    warnings: result.warnings,
  }
}
