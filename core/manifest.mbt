///|
pub(all) struct Part {
  hash : String
  kind : String
  encoding : String
  offset : Int
  length : Int
  size : Int
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
  layers : Array[Layer]
}

///|
pub(all) struct View {
  id : String
  kind : String
  title : String
  pages : Array[Page]
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
    _ => raise BadFormat("expected array: " + key)
  }
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
pub fn parse_manifest(input : String) -> Manifest raise {
  let root = @json.parse(input) catch {
    _ => raise BadFormat("invalid manifest JSON")
  }
  if required_number(root, "bdf") != 1.0 {
    raise BadFormat("unsupported manifest version")
  }
  if root is { "opset": Number(opset, ..), .. } {
    if opset < 0.0 || opset > 1.0 {
      raise BadFormat("unsupported opset")
    }
  }
  if root is { "encryption": _, .. } {
    raise Unsupported("encrypted manifest")
  }
  let parts : Array[Part] = []
  for json in required_array(root, "parts") {
    let hash = required_string(json, "h")
    if !valid_hash(hash) {
      raise BadFormat("invalid part hash")
    }
    let length = required_number(json, "len").to_int()
    let size = required_number(json, "size").to_int()
    let offset = if json is { "off": Number(n, ..), .. } {
      n.to_int()
    } else {
      0
    }
    let encoding = optional_string(json, "enc", "identity")
    if (encoding != "identity" && encoding != "deflate-raw") ||
      length < 0 || size < 0 || offset < 0 {
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
  for view in required_array(root, "views") {
    let id = required_string(view, "id")
    let kind = required_string(view, "kind")
    if kind != "fixed" && kind != "flow" && kind != "scroll" && kind != "sheet" {
      raise BadFormat("unknown view kind")
    }
    let pages : Array[Page] = []
    if view is { "pages": Array(items), .. } {
      for page in items {
        let layers : Array[Layer] = []
        for layer in required_array(page, "layers") {
          let hash = required_string(layer, "obj")
          if !valid_hash(hash) {
            raise BadFormat("invalid layer hash")
          }
          layers.push({ role: required_string(layer, "role"), object: hash })
        }
        pages.push({
          width: sized_number(page, "w"),
          height: sized_number(page, "h"),
          layers,
        })
      }
    }
    views.push({ id, kind, title: optional_string(view, "title", ""), pages })
  }
  { parts, views }
}
