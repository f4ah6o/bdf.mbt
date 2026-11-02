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
fn parquet_pad4(value : Int64) -> String {
  let text = value.to_string()
  let mut padded = text
  while padded.length() < 4 {
    padded = "0" + padded
  }
  padded
}

///|
fn parquet_date_text(days : Int64) -> String {
  let (year, month, day) = parquet_civil_from_days(days)
  parquet_pad4(year) + "-" + parquet_pad2(month) + "-" + parquet_pad2(day)
}

///|
fn parquet_datetime_text(millis : Int64, digits~ : Int = 3) -> String {
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
  let base = parquet_pad4(year) + "-" + parquet_pad2(month) + "-" + parquet_pad2(day) +
    " " + parquet_pad2(hour) + ":" + parquet_pad2(minute) + ":" +
    parquet_pad2(second)
  if digits <= 0 {
    base
  } else {
    base + "." + fraction[:digits].to_owned()
  }
}

///|
/// Normalize the exponent of a floating-point number to at least two digits,
/// as Go writes it (1e-07 rather than 1e-7).
fn parquet_normalize_exponent(text : String) -> String {
  match text.find("e") {
    Some(index) => {
      let mantissa = text[:index].to_owned()
      let rest = text[index + 1:].to_owned()
      if rest.length() < 2 {
        return text
      }
      let sign = rest[:1].to_owned()
      let digits = rest[1:].to_owned()
      if digits.length() >= 2 {
        return text
      }
      mantissa + "e" + sign + "0" + digits
    }
    None => text
  }
}

///|
fn parquet_number_text(number : Double) -> String {
  if number.is_nan() {
    "NaN"
  } else if number.is_inf() {
    if number > 0.0 {
      "Infinity"
    } else {
      "-Infinity"
    }
  } else {
    parquet_normalize_exponent(number.to_string())
  }
}

///|
fn parquet_value_text(value : @parquet.Value, digits~ : Int = -1) -> String {
  match value {
    @parquet.Null => ""
    @parquet.StringValue(text) => text
    @parquet.NumberValue(number) => parquet_number_text(number)
    @parquet.IntegerValue(number) => number.to_string()
    @parquet.BooleanValue(flag) => if flag { "true" } else { "false" }
    @parquet.DateValue(days) => parquet_date_text(days)
    @parquet.DateTimeValue(millis) =>
      parquet_datetime_text(millis, digits=if digits < 0 { 3 } else { digits })
  }
}

///|
/// The fraction digits a millisecond timestamp column needs: whole seconds
/// have none, other values use the millisecond precision.
fn parquet_datetime_digits(millis : Int64) -> Int {
  if millis % 1000L == 0L { 0 } else { 3 }
}

///|
fn parquet_column_digits(table : @parquet.Table) -> Array[Int] {
  let digits : Array[Int] = []
  for column_index, _ in table.columns {
    let mut used = 0
    for row in table.rows {
      if column_index < row.length() {
        match row[column_index] {
          @parquet.DateTimeValue(millis) =>
            used = Int::max(used, parquet_datetime_digits(millis))
          _ => ()
        }
      }
    }
    digits.push(used)
  }
  digits
}

///|
fn parquet_to_csv(table : @parquet.Table) -> Bytes {
  let digits = parquet_column_digits(table)
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
      output.write_string(
        parquet_csv_field(parquet_value_text(value, digits=digits[index])),
      )
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
  let (table, decode_warnings) = @parquet.decode_with_warnings(data) catch {
    @parquet.InvalidTable(message) => raise ParquetInputInvalid(message)
    _ => raise ParquetInputInvalid("parquet: invalid table")
  }
  if table.columns.is_empty() {
    raise ParquetInputInvalid("parquet: the table has no columns")
  }
  let csv = parquet_to_csv(table)
  let info = @parquet.info(data) catch {
    @parquet.InvalidTable(message) => raise ParquetInputInvalid(message)
    _ => raise ParquetInputInvalid("parquet: invalid metadata")
  }
  let result = @csv.convert_no_fonts(
    csv,
    name="table.parquet",
    title~,
    no_text_index~,
    table_data=Some(data),
    table_columns=Some(table.columns.map(column => {
      let kind = match column.kind {
        @parquet.StringColumn => @csv.TextColumn
        @parquet.NumberColumn => @csv.NumberColumn
        @parquet.IntegerColumn => @csv.IntegerColumn
        @parquet.BooleanColumn => @csv.BooleanColumn
        @parquet.DateColumn => @csv.DateColumn
        @parquet.DateTimeColumn => @csv.DateTimeColumn
      }
      @csv.TableColumn::{ name: column.name, kind }
    })),
  ) catch {
    _ => raise ParquetInputInvalid("parquet: the table could not be drawn")
  }
  let codecs = if info.codecs.is_empty() { "" } else { "; " + info.codecs.join(", ") }
  let warnings : Array[String] = []
  for warning in result.warnings {
    warnings.push(warning)
  }
  for warning in decode_warnings {
    warnings.push(warning)
  }
  {
    bdf: result.bdf,
    pages: 1,
    summary: "1 page (\{table.rows.length()} rows × \{table.columns.length()} columns; \{info.row_groups} row group(s)\{codecs})",
    warnings,
  }
}
