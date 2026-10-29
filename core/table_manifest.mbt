///|
/// A Parquet-backed table listed in the BDF manifest.
pub(all) struct Table {
  id : String
  title : String
  part : String
  rows : Int64
  columns : Array[TableColumn]
  view : String
  page : Int64
} derive(Debug, Eq)

///|
pub(all) struct TableColumn {
  name : String
  kind : String
} derive(Debug, Eq)

///|
fn table_integer(json : Json, name : String) -> Int64 raise {
  guard json is Object(fields) else { raise BadFormat("expected object") }
  match fields.get(name) {
    None | Some(Null) => 0L
    Some(Number(_, repr=Some(repr))) =>
      @string.parse_int64(repr) catch {
        _ => raise BadFormat("invalid integer: " + name)
      }
    Some(Number(value, ..)) => {
      if value.is_nan() ||
        value.is_inf() ||
        value < 0.0 ||
        value >= 9223372036854775808.0 ||
        value.floor() != value {
        raise BadFormat("invalid integer: " + name)
      }
      value.to_int64()
    }
    _ => raise BadFormat("invalid integer: " + name)
  }
}

///|
fn table_string(json : Json, name : String) -> String raise {
  guard json is Object(fields) else { raise BadFormat("expected object") }
  match fields.get(name) {
    None | Some(Null) => ""
    Some(String(value)) => value
    _ => raise BadFormat("expected string: " + name)
  }
}

///|
fn parse_tables(root : Json) -> Array[Table] raise {
  let entries = optional_array(root, "tables")
  if entries.length() > 65536 {
    raise BadFormat("too many tables")
  }
  let result : Array[Table] = []
  let ids : Map[String, Bool] = Map([])
  for entry in entries {
    let id = table_string(entry, "id")
    if id == "" || ids.contains(id) {
      raise BadFormat("missing or duplicate table id")
    }
    ids[id] = true
    let part = table_string(entry, "part")
    if !valid_hash(part) {
      raise BadFormat("invalid table part hash")
    }
    let rows = table_integer(entry, "rows")
    let page = table_integer(entry, "page")
    if rows < 0L || page < 0L {
      raise BadFormat("table numbers out of range")
    }
    let column_values = optional_array(entry, "columns")
    if column_values.length() > 16384 {
      raise BadFormat("too many table columns")
    }
    let columns : Array[TableColumn] = []
    for column in column_values {
      if column is Null {
        columns.push({ name: "", kind: "", })
      } else {
        columns.push({
          name: table_string(column, "name"),
          kind: table_string(column, "type"),
        })
      }
    }
    result.push({
      id,
      title: table_string(entry, "title"),
      part,
      rows,
      columns,
      view: table_string(entry, "view"),
      page,
    })
  }
  result
}
