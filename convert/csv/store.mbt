///|
/// Controls whether inferred CSV values are attached to the document.
pub(all) enum DataMode {
  DataDefault
  DataAll
  DataNone
} derive(Debug, Eq)

///|
/// Attach CSV values to a BDF writer as a Parquet part and a table manifest
/// entry. Returns a warning if the default size limits exclude the table.
/// The view argument identifies the sheet displaying the values.
pub fn store_table(
  writer : @core.DocumentWriter,
  table : Table,
  title~ : String = "",
  view~ : String = "",
  mode~ : DataMode = DataDefault,
) -> String? raise {
  if mode == DataNone {
    return None
  }
  let data = encode_table(table)
  if mode == DataDefault &&
    (table.rows.length() > 1048576 || data.length() > 67108864) {
    return Some(
      "the values (\{table.rows.length()} rows, \{data.length() >> 20} MiB) are not stored as a table: more than the default allows (data=all stores them)",
    )
  }
  let part = writer.add_part("table", data)
  let columns = table.columns.map(column => {
    let kind = match column.kind {
      TextColumn => "string"
      NumberColumn => "number"
      IntegerColumn => "integer"
      BooleanColumn => "boolean"
      DateColumn => "date"
      DateTimeColumn => "datetime"
    }
    Json::object({
      "name": Json::string(column.name),
      "type": Json::string(kind),
    })
  })
  let entry : Map[String, Json] = {
    "id": Json::string("data"),
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
  None
}
