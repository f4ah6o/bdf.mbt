///|
/// Types of columns stored in a CSV document's table.
pub(all) enum ColumnType {
  TextColumn
  NumberColumn
  IntegerColumn
  BooleanColumn
  DateColumn
  DateTimeColumn
} derive(Debug, Eq)

///|
pub(all) struct TableColumn {
  name : String
  kind : ColumnType
} derive(Debug, Eq)

///|
/// Dates count days since 1970-01-01; date-times count milliseconds since the
/// Unix epoch in UTC, matching the Parquet representation.
pub(all) enum TableValue {
  NullValue
  TextValue(String)
  NumberValue(Double)
  IntegerValue(Int64)
  BooleanValue(Bool)
  DateValue(Int64)
  DateTimeValue(Int64)
} derive(Debug, Eq)

///|
pub(all) struct Table {
  columns : Array[TableColumn]
  rows : Array[Array[TableValue]]
} derive(Debug, Eq)

///|
let csv_int_re : @string.Regex = @string.Regex::unsafe_from_string(
  "^[+\\-]?(0|[1-9][0-9]{0,17})$",
)

///|
let csv_num_re : @string.Regex = @string.Regex::unsafe_from_string(
  "^[+\\-]?((0|[1-9][0-9]*)(\\.[0-9]*)?|\\.[0-9]+)([eE][+\\-]?[0-9]+)?$",
)

///|
let csv_date_re : @string.Regex = @string.Regex::unsafe_from_string(
  "^[0-9]{4}-[0-9]{2}-[0-9]{2}$",
)

///|
let csv_datetime_re : @string.Regex = @string.Regex::unsafe_from_string(
  "^[0-9]{4}-[0-9]{2}-[0-9]{2}[T ][0-9]{2}:[0-9]{2}(:[0-9]{2}(\\.[0-9]+)?)?(Z|[+\\-][0-9]{2}:?[0-9]{2})?$",
)

///|
/// Infer the strict table type of a nonempty CSV value. Unlike alignment
/// classification, formatted numbers such as currency remain text.
pub fn table_value_type(value : String) -> ColumnType {
  let text = csv_trim(value)
  if csv_int_re.execute(text) is Some(_) {
    return IntegerColumn
  }
  if csv_num_re.execute(text) is Some(_) {
    return NumberColumn
  }
  if csv_date_re.execute(text) is Some(_) && csv_table_date(text) is Some(_) {
    return DateColumn
  }
  if csv_datetime_re.execute(text) is Some(_) &&
    csv_table_datetime(text) is Some(_) {
    return DateTimeColumn
  }
  let lower = text.to_lower()
  if lower == "true" || lower == "false" {
    BooleanColumn
  } else {
    TextColumn
  }
}

///|
/// Build the typed table stored alongside the sheet, or `None` when there
/// are no columns. Original text is retained when a column has mixed types.
pub fn values_table(parsed : ParseResult) -> Table? {
  if parsed.columns == 0 {
    return None
  }
  let columns : Array[TableColumn] = []
  let used : Map[String, Bool] = Map([])
  let first : Array[String] = if parsed.rows.length() > 0 {
    parsed.rows[0]
  } else {
    []
  }
  let start = if parsed.header { 1 } else { 0 }
  for column in 0..<parsed.columns {
    let original = if parsed.header && column < first.length() {
      csv_trim(first[column])
    } else {
      ""
    }
    let mut name = if original == "" { "C\{column + 1}" } else { original }
    let mut suffix = 2
    while used.get(name).unwrap_or(false) {
      name = original + " (\{suffix})"
      suffix += 1
    }
    used[name] = true
    let mut kind : ColumnType? = None
    for i in start..<parsed.rows.length() {
      let row = parsed.rows[i]
      if column >= row.length() {
        continue
      }
      let text = csv_trim(row[column])
      if text == "" {
        continue
      }
      let current = table_value_type(text)
      kind = match kind {
        None => Some(current)
        Some(previous) if previous == current => Some(previous)
        Some(IntegerColumn) if current == NumberColumn => Some(NumberColumn)
        Some(NumberColumn) if current == IntegerColumn => Some(NumberColumn)
        _ => Some(TextColumn)
      }
      if kind is Some(TextColumn) {
        break
      }
    }
    columns.push({ name, kind: kind.unwrap_or(TextColumn), })
  }
  let rows : Array[Array[TableValue]] = []
  for i in start..<parsed.rows.length() {
    let source = parsed.rows[i]
    let row : Array[TableValue] = []
    for j in 0..<columns.length() {
      if j >= source.length() {
        row.push(NullValue)
      } else {
        row.push(csv_table_value(columns[j].kind, source[j]))
      }
    }
    rows.push(row)
  }
  Some({ columns, rows, })
}

///|
fn csv_table_value(kind : ColumnType, value : String) -> TableValue {
  let text = csv_trim(value)
  if text == "" {
    return NullValue
  }
  match kind {
    IntegerColumn => {
      let n = @string.parse_int64(text) catch { _ => return TextValue(value) }
      IntegerValue(n)
    }
    NumberColumn => {
      let n = @string.parse_double(text) catch { _ => return TextValue(value) }
      if n.is_inf() {
        TextValue(value)
      } else {
        NumberValue(n)
      }
    }
    BooleanColumn => BooleanValue(text.to_lower() == "true")
    DateColumn =>
      match csv_table_date(text) {
        Some(day) => DateValue(day)
        None => TextValue(value)
      }
    DateTimeColumn =>
      match csv_table_datetime(text) {
        Some(ms) => DateTimeValue(ms)
        None => TextValue(value)
      }
    TextColumn => TextValue(value)
  }
}
