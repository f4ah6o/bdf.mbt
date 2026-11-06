///|
// The data of a form: JSON objects, and CSV/TSV files as lists of objects.
pub const MAX_DATA_SIZE : Int = 256 << 20

///|
pub suberror DataError {
  DataError(String)
}

///|
pub(all) struct Source {
  name : String
  file_name : String
  data : Bytes
}

///|
fn data_trim(value : String) -> String {
  value.trim().to_owned()
}

///|
fn data_ext(file_name : String) -> String {
  let normalized = file_name.replace(old="\\", new="/")
  let parts = normalized.split("/").to_array()
  let base = if parts.is_empty() {
    normalized
  } else {
    parts[parts.length() - 1].to_owned()
  }
  let pieces = base.split(".").map(fn(piece) { piece.to_owned() }).to_array()
  if pieces.length() < 2 {
    ""
  } else {
    ("." + pieces[pieces.length() - 1]).to_lower()
  }
}

///|
fn data_base(file_name : String) -> String {
  let normalized = file_name.replace(old="\\", new="/")
  let parts = normalized.split("/").to_array()
  let base = if parts.is_empty() {
    normalized
  } else {
    parts[parts.length() - 1].to_owned()
  }
  let pieces = base.split(".").map(fn(piece) { piece.to_owned() }).to_array()
  if pieces.length() < 2 {
    base
  } else {
    pieces[:pieces.length() - 1].join(".")
  }
}

///|
fn plain_number(value : String) -> Bool {
  let text = if value.has_prefix("-") {
    value[1:]
  } else {
    value
  }
  let pieces = text.split(".").map(fn(piece) { piece.to_owned() }).to_array()
  if pieces.length() > 2 {
    return false
  }
  let whole = pieces[0]
  let frac = if pieces.length() == 2 { pieces[1] } else { "" }
  if whole == "" || whole.length() > 15 || (whole.length() > 1 && whole[0] == '0') ||
    (pieces.length() == 2 && frac == "") {
    return false
  }
  for c in whole {
    if c < '0' || c > '9' {
      return false
    }
  }
  for c in frac {
    if c < '0' || c > '9' {
      return false
    }
  }
  true
}

///|
fn csv_value(value : String) -> Json {
  let text = data_trim(value)
  if text == "" {
    return Json::null()
  }
  if text.to_lower() == "true" {
    return Json::boolean(true)
  }
  if text.to_lower() == "false" {
    return Json::boolean(false)
  }
  if plain_number(text) {
    let number = @string.parse_double(text[:]) catch { _ => 0.0 }
    return Json::number(number)
  }
  Json::string(value)
}

///|
fn data_key(value : Json) -> String {
  match value {
    Json::Null => ""
    Json::String(text) => data_trim(text)
    Json::True => "true"
    Json::False => "false"
    Json::Number(number, ..) =>
      if number.floor() == number {
        number.to_int().to_string()
      } else {
        number.to_string()
      }
    _ => ""
  }
}

///|
fn data_table(rows : Array[Array[Json]]) -> Array[Json] raise DataError {
  let keys : Array[String] = []
  let out : Array[Json] = []
  let mut header = false
  for row in rows {
    let mut empty = true
    for value in row {
      if value != Json::null() {
        empty = false
      }
    }
    if empty {
      continue
    }
    if !header {
      let seen : Map[String, Bool] = Map([])
      for value in row {
        let key = data_key(value)
        if key != "" && seen.contains(key) {
          raise DataError("two columns are named " + key)
        }
        seen[key] = true
        keys.push(key)
      }
      header = true
      continue
    }
    let object : Map[String, Json] = Map([])
    for i, key in keys {
      if key == "" {
        continue
      }
      object[key] = if i < row.length() {
        row[i]
      } else {
        Json::null()
      }
    }
    out.push(Json::object(object))
  }
  out
}

///|
fn put(root : Map[String, Json], name : String, value : Json) -> Unit raise DataError {
  let parts = name.split(".").to_array().map(fn(part) { data_trim(part.to_owned()) })
  let mut current = root
  for i, part in parts {
    if part == "" {
      raise DataError("the name " + name + " has an empty part")
    }
    if i == parts.length() - 1 {
      current[part] = value
      return
    }
    match current.get(part) {
      Some(Json::Object(next)) => current = next
      _ => {
        let next : Map[String, Json] = Map([])
        current[part] = Json::object(next)
        current = next
      }
    }
  }
}

///|
fn yaml_to_json(value : @yaml.Yaml) -> Json raise DataError {
  match value {
    Null => Json::null()
    Boolean(value) => Json::boolean(value)
    Integer(value) => Json::number(value.to_double())
    Real(value, repr=_) => Json::number(value)
    String(value) => Json::string(value)
    Array(values) => {
      let array : Array[Json] = []
      for item in values {
        array.push(yaml_to_json(item))
      }
      Json::array(array)
    }
    Map(values) => {
      let object : Map[String, Json] = Map([])
      for key, item in values {
        object[key] = yaml_to_json(item)
      }
      Json::object(object)
    }
    BadValue => raise DataError("the YAML data is not a value")
  }
}

///|
fn read_yaml(source : Source) -> Json raise DataError {
  let text = @utf8.decode(source.data) catch {
    _ => raise DataError("the data is not UTF-8")
  }
  let documents = @yaml.Yaml::load_from_string(text[:]) catch {
    _ => raise DataError("the YAML data is not valid")
  }
  if documents.length() == 0 {
    Json::null()
  } else {
    yaml_to_json(documents[0])
  }
}

///|
fn xlsx_cell_json(cell : @xlsx.XlsxCell) -> Json {
  if cell.kind == 2 {
    Json::string(cell.text)
  } else if cell.kind == 3 {
    Json::boolean(cell.number != 0.0)
  } else if cell.kind == 1 {
    Json::number(cell.number)
  } else {
    Json::null()
  }
}

///|
fn xlsx_sheet_rows(cells : @xlsx.XlsxSheetCells) -> Array[Array[Json]] {
  let rows = cells.sorted_rows()
  let mut max_column = 0
  for row in rows {
    for cell in row.cells {
      max_column = Int::max(max_column, cell.column + 1)
    }
  }
  let table : Array[Array[Json]] = []
  for row in rows {
    let values = Array::make(max_column, Json::null())
    for cell in row.cells {
      let column = cell.column
      if column >= 0 && column < max_column {
        values[column] = xlsx_cell_json(cell)
      }
    }
    table.push(values)
  }
  table
}

///|
fn read_xlsx(source : Source) -> Json raise DataError {
  let workbook = @xlsx.read_xlsx_workbook(source.data) catch {
    _ => raise DataError("the workbook cannot be read")
  }
  let object : Map[String, Json] = Map([])
  let mut only : Json = Json::null()
  let mut count = 0
  for sheet in workbook.sheets {
    if sheet.chart {
      continue
    }
    let cells = workbook.read_sheet_cells(sheet.part) catch {
      _ => raise DataError("the sheet cannot be read")
    }
    let list = data_table(xlsx_sheet_rows(cells))
    object[sheet.name] = Json::array(list)
    only = Json::array(list)
    count += 1
  }
  if source.name != "" && count == 1 {
    only
  } else {
    Json::object(object)
  }
}

///|
fn read_source(source : Source) -> Json raise DataError {
  let ext = data_ext(source.file_name)
  if ext == ".json" {
    let text = @utf8.decode(source.data) catch {
      _ => raise DataError("the data is not UTF-8")
    }
    let text = if text.has_prefix("\u{feff}") {
      text[1:]
    } else {
      text
    }
    return @json.parse(text[:]) catch {
      error => raise DataError(error.to_string())
    }
  }
  if ext == ".csv" || ext == ".tsv" || ext == ".txt" {
    let parsed = @csv.parse(source.data, header=@csv.Header::HeaderNo) catch {
      error => raise DataError(error.to_string())
    }
    let rows : Array[Array[Json]] = []
    for row in parsed.rows {
      rows.push(row.map(csv_value))
    }
    let list = data_table(rows)
    let base = data_base(source.file_name)
    if source.name == "" {
      let object : Map[String, Json] = Map([])
      object[base] = Json::array(list)
      return Json::object(object)
    }
    return Json::array(list)
  }
  if ext == ".yaml" || ext == ".yml" {
    return read_yaml(source)
  }
  if ext == ".xlsx" || ext == ".xlsm" {
    return read_xlsx(source)
  }
  raise DataError(
    "data is JSON (.json), YAML (.yaml), CSV (.csv, .tsv) or a workbook (.xlsx)",
  )
}

///|
/// Read files of data into the data of a template. A source without a name
/// must be a JSON object and merges its names; a named source becomes the
/// value of that name (a CSV file is a list of objects).
pub fn load_data(sources : Array[Source]) -> Map[String, Json] raise DataError {
  let root : Map[String, Json] = Map([])
  for source in sources {
    if source.data.length() > MAX_DATA_SIZE {
      raise DataError("the data is larger than 256 MiB")
    }
    let value = read_source(source) catch {
      DataError(message) => raise DataError(source.file_name + ": " + message)
    }
    if source.name != "" {
      put(root, source.name, value) catch {
        DataError(message) => raise DataError(source.file_name + ": " + message)
      }
      continue
    }
    match value {
      Json::Object(object) =>
        for key, entry in object {
          root[key] = entry
        }
      _ =>
        raise DataError(
          source.file_name +
          ": the data of a template is an object; give a list or a value a name",
        )
    }
  }
  root
}
