///|
/// Attach an XLSX values table to a BDF writer with the given unique ID.
/// Callers enforce the conversion's row, column and byte limits.
pub fn xlsx_store_values_table(
  writer : @core.DocumentWriter,
  table : @parquet.Table,
  id : String,
  title : String,
  view : String,
) -> Unit raise {
  if id == "" {
    raise InvalidXlsxInput("xlsx: a table needs an id")
  }
  let data = @parquet.encode(table)
  xlsx_store_encoded_table(writer, table, data, id, title, view)
}

///|
fn xlsx_store_encoded_table(
  writer : @core.DocumentWriter,
  table : @parquet.Table,
  data : Bytes,
  id : String,
  title : String,
  view : String,
) -> Unit raise {
  let part = writer.add_part("table", data)
  let columns = table.columns.map(fn(column) {
    let kind = match column.kind {
      @parquet.StringColumn => "string"
      @parquet.NumberColumn => "number"
      @parquet.IntegerColumn => "integer"
      @parquet.BooleanColumn => "boolean"
      @parquet.DateColumn => "date"
      @parquet.DateTimeColumn => "datetime"
    }
    Json::object({
      "name": Json::string(column.name),
      "type": Json::string(kind),
    })
  })
  let entry : Map[String, Json] = {
    "id": Json::string(id),
    "part": Json::string(part),
    "rows": Json::number(table.rows.length().to_double()),
    "columns": Json::array(columns),
  }
  if title != "" {
    entry["title"] = Json::string(title)
  }
  if view != "" {
    entry["view"] = Json::string(view)
  }
  writer.add_table(Json::object(entry))
}

///|
fn xlsx_store_range(
  writer : @core.DocumentWriter,
  styles : XlsxStyles,
  rows : Array[XlsxRow],
  range : XlsxRange,
  sheet_name : String,
  id : String,
  title : String,
  names : Array[String],
  view : String,
  mode : String,
  date1904 : Bool,
  locale : String,
) -> String? raise {
  let nrows = range.row_end - range.row_start + 1L
  let ncols = range.column_end.to_int64() - range.column_start.to_int64() + 1L
  let sheet = xlsx_go_quote(sheet_name, '"')
  if mode != "all" && nrows > 1048576L {
    return Some(
      "sheet \{sheet}: the values (\{nrows} rows) are not stored as the table \{id}: more than the default allows (data=all stores them)",
    )
  }
  if ncols > 16384L {
    return Some(
      "sheet \{sheet}: the values are not stored as the table \{id}: more than 16384 columns",
    )
  }
  let limit = if mode == "all" { 67108864L } else { 16777216L }
  if nrows > 0L && ncols > 0L && nrows > limit / ncols {
    return Some(
      "sheet \{sheet}: the values (\{nrows} rows × \{ncols} columns) are not stored as the table \{id}: more than \{limit} cells",
    )
  }
  let table = styles.values_table(rows, range, names, date1904, locale)
  let data = @parquet.encode(table)
  if mode != "all" && (nrows > 1048576L || data.length() > 67108864) {
    return Some(
      "sheet \{sheet}: the values (\{nrows} rows, \{data.length() >> 20} MiB) are not stored as the table \{id}: more than the default allows (data=all stores them)",
    )
  }
  xlsx_store_encoded_table(writer, table, data, id, title, view)
  None
}

///|
/// Store a sheet's used range and ListObjects as BDF tables.
/// Returns the next table counter and any size-limit warnings.
pub fn XlsxWorkbook::store_sheet_tables(
  self : XlsxWorkbook,
  writer : @core.DocumentWriter,
  part : String,
  sheet_name : String,
  sheet_number : Int32,
  view : String,
  mode : String,
  table_counter : Int32,
  locale : String,
) -> (Int32, Array[String]) raise {
  if mode == "none" {
    return (table_counter, [])
  }
  let rows = self.read_sheet_cells(part).sorted_rows()
  let styles = self.styles()
  let warnings : Array[String] = []
  let mut counter = table_counter
  if xlsx_used_range(rows) is Some(range) {
    if xlsx_store_range(
        writer,
        styles,
        rows,
        range,
        sheet_name,
        "sheet" + sheet_number.to_string(),
        sheet_name,
        [],
        view,
        mode,
        self.date1904,
        locale,
      )
      is Some(warning) {
      warnings.push(warning)
    }
  }
  for table in self.read_sheet_tables(part) {
    let range = table.range
    let adjusted : XlsxRange = {
      row_start: range.row_start + table.header_rows.to_int64(),
      row_end: range.row_end - table.totals_rows.to_int64(),
      column_start: range.column_start,
      column_end: range.column_end,
    }
    if adjusted.row_start > adjusted.row_end {
      continue
    }
    counter += 1
    if xlsx_store_range(
        writer,
        styles,
        rows,
        adjusted,
        sheet_name,
        "table-" + counter.to_string(),
        table.name,
        table.columns,
        view,
        mode,
        self.date1904,
        locale,
      )
      is Some(warning) {
      warnings.push(warning)
    }
  }
  (counter, warnings)
}
