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
