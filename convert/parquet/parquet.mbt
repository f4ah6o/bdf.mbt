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
fn parquet_floor_div(value : Int64, divisor : Int64) -> Int64 {
  let quotient = value / divisor
  let remainder = value - quotient * divisor
  if remainder < 0L {
    quotient - 1L
  } else {
    quotient
  }
}

///|
fn parquet_civil_from_days(days : Int64) -> (Int64, Int64, Int64) {
  let z = days + 719468L
  let era = parquet_floor_div(z, 146097L)
  let doe = z - era * 146097L
  let yoe = (doe - doe / 1460L + doe / 36524L - doe / 146096L) / 365L
  let mut year = yoe + era * 400L
  let doy = doe - (365L * yoe + yoe / 4L - yoe / 100L)
  let mp = (5L * doy + 2L) / 153L
  let day = doy - (153L * mp + 2L) / 5L + 1L
  let month = if mp < 10L { mp + 3L } else { mp - 9L }
  if month <= 2L {
    year += 1L
  }
  (year, month, day)
}

///|
fn parquet_pad2(value : Int64) -> String {
  if value < 10L { "0" + value.to_string() } else { value.to_string() }
}

///|
fn parquet_date_text(days : Int64) -> String {
  let (year, month, day) = parquet_civil_from_days(days)
  year.to_string() + "-" + parquet_pad2(month) + "-" + parquet_pad2(day)
}

///|
fn parquet_datetime_text(millis : Int64) -> String {
  let days = parquet_floor_div(millis, 86400000L)
  let rest = millis - days * 86400000L
  let (year, month, day) = parquet_civil_from_days(days)
  let hour = rest / 3600000L
  let minute = (rest % 3600000L) / 60000L
  let second = (rest % 60000L) / 1000L
  let millisecond = rest % 1000L
  let mut fraction = millisecond.to_string()
  while fraction.length() < 3 {
    fraction = "0" + fraction
  }
  year.to_string() + "-" + parquet_pad2(month) + "-" + parquet_pad2(day) + " " +
  parquet_pad2(hour) + ":" + parquet_pad2(minute) + ":" + parquet_pad2(second) + "." +
  fraction + "000"
}

///|
fn parquet_value_text(value : @parquet.Value) -> String {
  match value {
    @parquet.Null => ""
    @parquet.StringValue(text) => text
    @parquet.NumberValue(number) => number.to_string()
    @parquet.IntegerValue(number) => number.to_string()
    @parquet.BooleanValue(flag) => if flag { "true" } else { "false" }
    @parquet.DateValue(days) => parquet_date_text(days)
    @parquet.DateTimeValue(millis) => parquet_datetime_text(millis)
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
    table_data=Some(data),
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
