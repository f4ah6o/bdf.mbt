///|
pub(all) struct Part {
  hash : String
  kind : String
  encoding : String
  offset : Int32
  length : Int32
  size : Int32
}

///|
pub(all) struct Layer {
  role : String
  object : String
}

///|
pub(all) struct Page {
  width : Double
  height : Double
  body : PageRect?
  layers : Array[Layer]
}

///|
/// A page's body rectangle, in page coordinates.
pub(all) struct PageRect {
  x : Double
  y : Double
  width : Double
  height : Double
} derive(Eq, Debug)

///|
/// A sheet tile's coordinates and referenced object.
pub(all) struct Tile {
  x : Int32
  y : Int32
  object : String
} derive(Eq, Debug)

///|
/// A run of rows or columns with the same size; zero size means hidden.
pub(all) struct SheetRun {
  count : Int32
  size : Double
} derive(Eq, Debug)

///|
pub(all) struct View {
  id : String
  kind : String
  title : String
  direction : String
  continuous_gap : Double?
  text_index : String?
  pages : Array[Page]
  tile_size : Double
  tiles : Array[Tile]
  tiles_ref : String?
  cols : Array[SheetRun]
  rows : Array[SheetRun]
  frozen_cols : Int32
  frozen_rows : Int32
  gridlines : Bool
}

///|
pub(all) struct Manifest {
  parts : Array[Part]
  views : Array[View]
}

///|
fn field(object : Json, key : String) -> Json raise {
  if object is Object(fields) {
    match fields.get(key) {
      Some(value) => value
      None => raise BadFormat("missing field: " + key)
    }
  } else {
    raise BadFormat("expected object")
  }
}

///|
fn optional_string(object : Json, key : String, default : String) -> String {
  if object is Object(fields) {
    match fields.get(key) {
      Some(String(value)) => value
      _ => default
    }
  } else {
    default
  }
}

///|
fn required_string(object : Json, key : String) -> String raise {
  match field(object, key) {
    String(value) => value
    _ => raise BadFormat("expected string: " + key)
  }
}

///|
fn required_number(object : Json, key : String) -> Double raise {
  match field(object, key) {
    Number(value, ..) => value
    _ => raise BadFormat("expected number: " + key)
  }
}

///|
fn required_array(object : Json, key : String) -> Array[Json] raise {
  match field(object, key) {
    Array(value) => value
    Null => []
    _ => raise BadFormat("expected array: " + key)
  }
}

///|
fn optional_array(object : Json, key : String) -> Array[Json] raise {
  if object is Object(fields) {
    match fields.get(key) {
      None | Some(Null) => []
      Some(Array(values)) => values
      _ => raise BadFormat("expected array: " + key)
    }
  } else {
    raise BadFormat("expected object")
  }
}

///|
fn checked_size(value : Double, key : String) -> Int32 raise {
  if value.is_nan() ||
    value < 0.0 ||
    value > 2147483647.0 ||
    value.floor() != value {
    raise BadFormat("invalid integer: " + key)
  }
  value.to_int()
}

///|
fn sized_number(object : Json, key : String) -> Double raise {
  let value = required_number(object, key)
  if value < 0.0 || value > 16777216.0 || value.is_nan() {
    raise BadFormat("page dimension out of range")
  }
  value
}

///|
fn signed_page_number(object : Json, key : String) -> Double raise {
  let value = required_number(object, key)
  if value.is_nan() || value.is_inf() || value.abs() > 16777216.0 {
    raise BadFormat("page coordinate out of range")
  }
  value
}

///|
fn page_body(page : Json) -> PageRect? raise {
  guard page is Object(fields) else { raise BadFormat("expected page object") }
  match fields.get("body") {
    None => None
    Some(body) =>
      Some({
        x: signed_page_number(body, "x"),
        y: signed_page_number(body, "y"),
        width: sized_number(body, "w"),
        height: sized_number(body, "h"),
      })
  }
}

///|
fn view_continuous_gap(view : Json) -> Double? raise {
  guard view is Object(fields) else { raise BadFormat("expected view object") }
  match fields.get("continuous") {
    None => None
    Some(continuous) => Some(signed_page_number(continuous, "gap"))
  }
}

///|
fn parse_tile_coordinate(text : StringView) -> Int32 raise {
  if text.length() == 0 {
    raise BadFormat("invalid tile coordinate")
  }
  for c in text {
    if !c.is_ascii_digit() {
      raise BadFormat("invalid tile coordinate")
    }
  }
  @string.parse_int(text) catch {
    _ => raise BadFormat("tile coordinate out of range")
  }
}

///|
fn parse_tiles(view : Json) -> Array[Tile] raise {
  let tiles : Array[Tile] = []
  if view is Object(fields) {
    match fields.get("tiles") {
      None | Some(Null) => ()
      Some(Object(entries)) =>
        for key, value in entries {
          let coords = key.split(",").to_array()
          if coords.length() != 2 {
            raise BadFormat("invalid tile key")
          }
          let x = parse_tile_coordinate(coords[0])
          let y = parse_tile_coordinate(coords[1])
          let object = match value {
            String(hash) if valid_hash(hash) => hash
            _ => raise BadFormat("invalid tile object hash")
          }
          tiles.push({ x, y, object, })
        }
      _ => raise BadFormat("invalid tiles")
    }
  }
  tiles.sort_by((a, b) => {
    if a.y == b.y {
      a.x.compare(b.x)
    } else {
      a.y.compare(b.y)
    }
  })
  tiles
}

///|
fn parse_tile_size(view : Json) -> Double raise {
  if view is Object(fields) {
    match fields.get("tile") {
      None | Some(Null) => return 2048.0
      Some(Number(value, ..)) => {
        if value.is_nan() || value > 16777216.0 || (value > 0.0 && value < 1.0) {
          raise BadFormat("tile size out of range")
        }
        return if value <= 0.0 { 2048.0 } else { value }
      }
      _ => raise BadFormat("invalid tile size")
    }
  }
  2048.0
}

///|
fn parse_sheet_runs(view : Json, key : String) -> Array[SheetRun] raise {
  let result : Array[SheetRun] = []
  let mut total = 0
  for item in optional_array(view, key) {
    let pair = match item {
      Array(values) if values.length() == 2 => values
      _ => raise BadFormat("invalid sheet run")
    }
    let count = match pair[0] {
      Number(value, ..) => checked_size(value, key)
      _ => raise BadFormat("invalid sheet run count")
    }
    if count > 16777216 - total {
      raise BadFormat("too many sheet entries")
    }
    let size = match pair[1] {
      Number(value, ..) => value
      _ => raise BadFormat("invalid sheet run size")
    }
    if size.is_nan() ||
      size < 0.0 ||
      size > 16777216.0 ||
      (size > 0.0 && size < 0.015625) {
      raise BadFormat("sheet run size out of range")
    }
    result.push({ count, size, })
    total += count
  }
  result
}

///|
fn parse_sheet_freeze(view : Json, key : String) -> Int32 raise {
  if view is Object(fields) {
    match fields.get("freeze") {
      None | Some(Null) => return 0
      Some(Object(frozen)) =>
        match frozen.get(key) {
          None | Some(Null) => return 0
          Some(Number(value, ..)) => return checked_size(value, key)
          _ => raise BadFormat("invalid frozen pane count")
        }
      _ => raise BadFormat("invalid frozen panes")
    }
  }
  0
}

///|
fn parse_gridlines(view : Json) -> Bool raise {
  if view is Object(fields) {
    match fields.get("gridlines") {
      None | Some(Null) => return false
      Some(True) => return true
      Some(False) => return false
      _ => raise BadFormat("invalid gridlines")
    }
  }
  false
}

///|
pub fn parse_manifest(input : String) -> Manifest raise {
  parse_manifest_internal(input, false)
}

///|
fn parse_manifest_internal(
  input : String,
  allow_encryption : Bool,
) -> Manifest raise {
  let root = @json.parse(input) catch {
    _ => raise BadFormat("invalid manifest JSON")
  }
  if required_number(root, "bdf") != 1.0 {
    raise BadFormat("unsupported manifest version")
  }
  if root is Object(fields) {
    match fields.get("opset") {
      None | Some(Null) => ()
      Some(Number(opset, ..)) =>
        if opset != 0.0 && opset != 1.0 {
          raise BadFormat("unsupported opset")
        }
      _ => raise BadFormat("invalid opset")
    }
  }
  if root is { "encryption": encryption, .. } {
    match encryption {
      Null => ()
      _ => if !allow_encryption { raise Unsupported("encrypted manifest") }
    }
  }
  let parts : Array[Part] = []
  for json in required_array(root, "parts") {
    let hash = required_string(json, "h")
    if !valid_hash(hash) {
      raise BadFormat("invalid part hash")
    }
    let length = checked_size(required_number(json, "len"), "len")
    let size = checked_size(required_number(json, "size"), "size")
    let offset = if json is Object(fields) {
      match fields.get("off") {
        None | Some(Null) => 0
        Some(Number(n, ..)) => checked_size(n, "off")
        _ => raise BadFormat("invalid offset")
      }
    } else {
      raise BadFormat("expected object")
    }
    let encoding = optional_string(json, "enc", "identity")
    if (encoding != "identity" && encoding != "deflate-raw") ||
      length < 0 ||
      size < 0 ||
      offset < 0 {
      raise BadFormat("invalid part size or encoding")
    }
    for old in parts {
      if old.hash == hash {
        raise BadFormat("duplicate part hash")
      }
    }
    parts.push({
      hash,
      kind: required_string(json, "t"),
      encoding,
      offset,
      length,
      size,
    })
  }
  let views : Array[View] = []
  for view in optional_array(root, "views") {
    let id = required_string(view, "id")
    let kind = required_string(view, "kind")
    if kind != "fixed" && kind != "flow" && kind != "scroll" && kind != "sheet" {
      raise BadFormat("unknown view kind")
    }
    let pages : Array[Page] = []
    for page in optional_array(view, "pages") {
      let layers : Array[Layer] = []
      for layer in optional_array(page, "layers") {
        let hash = required_string(layer, "obj")
        if !valid_hash(hash) {
          raise BadFormat("invalid layer hash")
        }
        layers.push({ role: required_string(layer, "role"), object: hash, })
      }
      pages.push({
        width: sized_number(page, "w"),
        height: sized_number(page, "h"),
        body: page_body(page),
        layers,
      })
    }
    let text_index = match optional_string(view, "textIndex", "") {
      "" => None
      hash => Some(hash)
    }
    let tile_size = if kind == "sheet" { parse_tile_size(view) } else { 2048.0 }
    let tiles = if kind == "sheet" { parse_tiles(view) } else { [] }
    let tiles_ref = match optional_string(view, "tilesRef", "") {
      "" => None
      hash => Some(hash)
    }
    let cols = parse_sheet_runs(view, "cols")
    let rows = parse_sheet_runs(view, "rows")
    let frozen_cols = parse_sheet_freeze(view, "cols")
    let frozen_rows = parse_sheet_freeze(view, "rows")
    let gridlines = parse_gridlines(view)
    views.push({
      id,
      kind,
      title: optional_string(view, "title", ""),
      direction: optional_string(view, "direction", "ltr"),
      continuous_gap: view_continuous_gap(view),
      text_index,
      pages,
      tile_size,
      tiles,
      tiles_ref,
      cols,
      rows,
      frozen_cols,
      frozen_rows,
      gridlines,
    })
  }
  { parts, views, }
}
