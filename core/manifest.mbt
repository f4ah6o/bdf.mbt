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
  layers : Array[Layer]
}

///|
pub(all) struct View {
  id : String
  kind : String
  title : String
  text_index : String?
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
        layers,
      })
    }
    let text_index = match optional_string(view, "textIndex", "") {
      "" => None
      hash => Some(hash)
    }
    views.push({
      id,
      kind,
      title: optional_string(view, "title", ""),
      text_index,
      pages,
    })
  }
  { parts, views, }
}
