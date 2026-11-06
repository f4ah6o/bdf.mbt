///|
// JSON Schema of the data of a form template, from the fields of its tags
// and a sample of its data (form/schema.go of upstream).
pub const SCHEMA_DIALECT : String = "https://json-schema.org/draft/2020-12/schema"
pub const SCHEMA_KEYWORD : String = "x-bdf"
pub const MAX_SCHEMA_DEPTH : Int = 256
pub const MAX_SCHEMA_NODES : Int = 1 << 16

///|
pub suberror SchemaError {
  SchemaError(String)
}

///|
priv struct SchemaNode {
  name : String
  kids : Array[SchemaNode]
  by_name : Map[String, SchemaNode]
  depth : Int
  budget : Ref[Int]
  first : Int
  mut value : Bool
  mut image : Bool
  mut section : Bool
  mut sections : Int
  mut self : Bool
  mut inverted : Bool
  mut code : String
  mut input : String
  mut format : String
  mut mode : String
  mut slots : Int
  at : Array[String]
  mut typ : String
  mut options : Array[String]
  mut labels : Array[String]
  mut label : String
  mut def : Json
  mut max_len : Int
  mut multiline : Bool
  sample : Json
  sampled : Bool
}

///|
fn schema_node(
  name : String,
  depth : Int,
  first : Int,
  budget : Ref[Int],
  sample : Json,
  sampled : Bool,
) -> SchemaNode {
  {
    name,
    kids: [],
    by_name: Map([]),
    depth,
    budget,
    first,
    value: false,
    image: false,
    section: false,
    sections: 0,
    self: false,
    inverted: false,
    code: "",
    input: "",
    format: "",
    mode: "",
    slots: 0,
    at: [],
    typ: "",
    options: [],
    labels: [],
    label: "",
    def: Json::null(),
    max_len: 0,
    multiline: false,
    sample,
    sampled,
  }
}

///|
fn schema_item(node : SchemaNode) -> Json {
  if !node.sampled {
    return Json::null()
  }
  match node.sample {
    Json::Array(values) =>
      if values.is_empty() {
        Json::null()
      } else {
        values[0]
      }
    other => other
  }
}

///|
fn schema_has(node : SchemaNode, name : String) -> Bool {
  match schema_item(node) {
    Json::Object(object) =>
      if object.contains(name) {
        return true
      }
    _ => ()
  }
  node.by_name.contains(name)
}

///|
fn schema_kid(
  node : SchemaNode,
  name : String,
  field : Int,
) -> SchemaNode raise SchemaError {
  match node.by_name.get(name) {
    Some(kid) => kid
    None => {
      if node.depth >= MAX_SCHEMA_DEPTH {
        raise SchemaError("form: the schema is nested more than 256 levels")
      }
      if node.budget.val >= MAX_SCHEMA_NODES {
        raise SchemaError("form: the schema has more than 65536 nodes")
      }
      node.budget.val += 1
      let mut sample = Json::null()
      let mut sampled = false
      match schema_item(node) {
        Json::Object(object) =>
          match object.get(name) {
            Some(value) => {
              sample = value
              sampled = true
            }
            None => ()
          }
        _ => ()
      }
      let kid = schema_node(
        name,
        node.depth + 1,
        field,
        node.budget,
        sample,
        sampled,
      )
      node.by_name[name] = kid
      node.kids.push(kid)
      kid
    }
  }
}

///|
fn schema_find(
  chain : Array[SchemaNode],
  name : String,
  field : Int,
) -> SchemaNode raise SchemaError {
  let parts = name.split(".").map(fn(part) { part.to_owned() }).to_array()
  if parts.length() - 1 >= MAX_SCHEMA_DEPTH {
    raise SchemaError("form: the schema is nested more than 256 levels")
  }
  let mut at = chain[chain.length() - 1]
  let mut i = chain.length() - 1
  while i >= 0 {
    if schema_has(chain[i], parts[0]) {
      at = chain[i]
      break
    }
    i -= 1
  }
  for part in parts {
    if part == "" {
      continue
    }
    at = schema_kid(at, part, field)
  }
  at
}

///|
fn schema_place(
  root : SchemaNode,
  field : @tag.Field,
  in_sections : Array[String],
  index : Int,
) -> Unit raise SchemaError {
  let chain : Array[SchemaNode] = [root]
  for section in in_sections {
    let found = schema_find(chain, section, index)
    found.section = true
    chain.push(found)
  }
  if field.name == "." {
    if chain.length() > 1 {
      chain[chain.length() - 1].self = true
    }
    return
  }
  if field.name == "" || field.name.has_prefix("_") {
    return
  }
  let leaf = schema_find(chain, field.name, index)
  if field.kind == @tag.FIELD_SECTION {
    leaf.inverted = field.inverted && (leaf.inverted || leaf.sections == 0)
    leaf.sections += 1
    leaf.section = true
    if leaf.mode == "" {
      leaf.mode = field.mode
      leaf.slots = field.slots
    }
  } else if field.kind == @tag.FIELD_IMAGE {
    leaf.image = true
    if leaf.code == "" {
      leaf.code = field.code
    }
    if leaf.input == "" {
      leaf.input = field.input
    }
  } else {
    leaf.value = true
    if leaf.format == "" {
      leaf.format = field.format
    }
  }
  if leaf.typ == "" {
    leaf.typ = field.value_type
  }
  if leaf.options.is_empty() {
    leaf.options = field.options
    leaf.labels = field.labels
  }
  if leaf.label == "" {
    leaf.label = field.label
  }
  if leaf.def == Json::null() && field.default != Json::null() {
    leaf.def = field.default
  }
  leaf.max_len = Int::max(leaf.max_len, field.max_len)
  leaf.multiline = leaf.multiline || field.multiline
  for at in field.at {
    if leaf.at.length() < 16 {
      leaf.at.push(at)
    }
  }
}

///|
fn schema_depths(fields : Array[@tag.Field]) -> Array[Int] {
  let depth : Array[Int] = []
  for field in fields {
    let mut count = 0
    for section in field.in_sections {
      if !section.has_prefix("_") {
        count += 1
      }
    }
    depth.push(count)
  }
  depth
}

///|
fn schema_scalar(sample : Json) -> Json {
  match sample {
    Json::String(_) => Json::string("string")
    Json::Number(_, ..) => Json::string("number")
    Json::True | Json::False => Json::string("boolean")
    _ => Json::array([Json::string("string"), Json::string("number")])
  }
}

///|
fn schema_list(node : SchemaNode) -> Bool {
  if !node.section {
    return false
  }
  if node.sampled && node.sample != Json::null() {
    return node.sample is Json::Array(_)
  }
  !node.value &&
  !node.image &&
  (!node.kids.is_empty() || node.self || node.mode != "")
}

///|
fn schema_code_name(code : String) -> String {
  if code == "qr" {
    "QR code"
  } else {
    "barcode (" + code + ")"
  }
}

///|
fn schema_format_kind(code : String) -> String {
  if code == "" {
    return ""
  }
  let chars = code.to_array()
  let kept = StringBuilder()
  let mut i = 0
  while i < chars.length() {
    let c = chars[i]
    if c == '"' {
      i += 1
      while i < chars.length() && chars[i] != '"' {
        i += 1
      }
    } else if c == '\\' || c == '_' || c == '*' {
      i += 1
    } else if c == '[' {
      let mut j = i + 1
      while j < chars.length() && chars[j] != ']' {
        j += 1
      }
      let inside = String::from_array(chars[i + 1:j]).to_lower()
      let stripped = inside.replace(old="h", new="").replace(old="m", new="").replace(old="s", new="")
      if inside != "" && stripped == "" {
        kept.write_string(inside)
      }
      i = j
    } else if c == ';' {
      break
    } else {
      kept.write_char(c)
    }
    i += 1
  }
  let text = kept.to_string().to_lower()
  if text.contains("general") || text.contains("@") {
    return ""
  }
  let digits = text.contains("0") || text.contains("#") || text.contains("?")
  if digits && (text.contains("e+") || text.contains("e-")) {
    return "number"
  }
  let text = text
    .replace(old="am/pm", new="")
    .replace(old="a/p", new="")
  let day = text.contains("y") ||
    text.contains("d") ||
    text.contains("g") ||
    text.contains("e") ||
    text.contains("aaa")
  let clock = text.contains("h") || text.contains("s")
  let day = if text.contains("m") && !day && !clock { true } else { day }
  if day && clock {
    "date-time"
  } else if day {
    "date"
  } else if clock {
    ""
  } else if digits {
    "number"
  } else {
    ""
  }
}

///|
fn schema_scalar_object(node : SchemaNode) -> Json {
  let object : Map[String, Json] = Map([])
  object["type"] = schema_scalar(schema_item(node))
  Json::object(object)
}

///|
fn schema_info(node : SchemaNode) -> Map[String, Json] {
  let info : Map[String, Json] = Map([])
  info["kind"] = Json::string(
    if node.image {
      @tag.FIELD_IMAGE
    } else if node.section {
      @tag.FIELD_SECTION
    } else {
      @tag.FIELD_VALUE
    },
  )
  if node.mode != "" {
    info["mode"] = Json::string(node.mode)
  }
  if node.slots > 0 {
    info["slots"] = Json::number(node.slots.to_double())
  }
  if node.inverted {
    info["inverted"] = Json::boolean(true)
  }
  if node.input != "" {
    info["input"] = Json::string(node.input)
  }
  if node.code != "" {
    info["code"] = Json::string(node.code)
  }
  if !node.labels.is_empty() && node.labels.length() == node.options.length() {
    info["labels"] = Json::array(node.labels.map(Json::string))
  }
  if node.multiline {
    info["multiline"] = Json::boolean(true)
  }
  if node.format != "" {
    info["format"] = Json::string(node.format)
  }
  if !node.at.is_empty() {
    info["at"] = Json::array(node.at.map(Json::string))
  }
  info
}

///|
fn schema_object(node : SchemaNode) -> Json {
  let object : Map[String, Json] = Map([])
  object["type"] = Json::string("object")
  let kids = node.kids.copy()
  kids.sort_by(fn(a, b) { a.first - b.first })
  let properties : Map[String, Json] = Map([])
  for kid in kids {
    properties[kid.name] = schema_of(kid)
  }
  object["properties"] = Json::object(properties)
  Json::object(object)
}

///|
fn schema_of(node : SchemaNode) -> Json {
  let info = schema_info(node)
  let object : Map[String, Json] = Map([])
  if schema_list(node) {
    object["type"] = Json::string("array")
    if !node.kids.is_empty() {
      object["items"] = schema_object(node)
    } else if node.self {
      object["items"] = schema_scalar_object(node)
    } else {
      object["items"] = Json::object(Map([]))
    }
    if node.mode == @tag.MODE_SLOTS && node.slots > 0 {
      object["maxItems"] = Json::number(node.slots.to_double())
    }
  } else if !node.kids.is_empty() {
    object["type"] = Json::string("object")
    let kids = node.kids.copy()
    kids.sort_by(fn(a, b) { a.first - b.first })
    let properties : Map[String, Json] = Map([])
    for kid in kids {
      properties[kid.name] = schema_of(kid)
    }
    object["properties"] = Json::object(properties)
  } else if node.section && !node.value && !node.image {
    let scalar = schema_scalar(node.sample)
    let scalar_name = match scalar {
      Json::String(name) => name
      _ => ""
    }
    if scalar_name == "string" || scalar_name == "number" {
      object["type"] = Json::string(scalar_name)
    } else {
      object["type"] = Json::string("boolean")
    }
    object["description"] = Json::string(
      if node.inverted {
        "A part of the form is shown when this is false."
      } else {
        "A part of the form is shown when this is true."
      },
    )
  } else if node.image && node.code == "" {
    object["type"] = Json::string("string")
    object["format"] = Json::string("uri-reference")
    object["description"] = Json::string(
      if node.input == @tag.INPUT_SIGNATURE {
        "A signature that a person draws: a picture, the path of a file or a data: URL."
      } else if node.input == @tag.INPUT_SEAL {
        "The picture of a seal: the path of a file, or a data: URL."
      } else {
        "A picture: the path of a file, or a data: URL."
      },
    )
  } else if node.code != "" {
    object["type"] = Json::string("string")
    object["description"] = Json::string(
      "The text of the " + schema_code_name(node.code) + " drawn in the form.",
    )
  } else {
    let mut kind = node.typ
    if kind == "" {
      kind = schema_format_kind(node.format)
    }
    if kind == "number" || kind == "boolean" || kind == "string" {
      object["type"] = Json::string(kind)
    } else if kind == "date" || kind == "date-time" {
      object["type"] = Json::string("string")
      object["format"] = Json::string(kind)
    } else {
      object["type"] = schema_scalar(node.sample)
    }
    if !node.options.is_empty() {
      object["enum"] = Json::array(node.options.map(Json::string))
    }
    if node.max_len > 0 {
      object["maxLength"] = Json::number(node.max_len.to_double())
    }
    if node.def != Json::null() {
      object["default"] = node.def
    }
  }
  object["title"] = Json::string(if node.label != "" { node.label } else { node.name })
  object[SCHEMA_KEYWORD] = Json::object(info)
  Json::object(object)
}

///|
/// The JSON Schema of the data of a template: an object with a property
/// for each name its tags look up, in the order of the template.
pub fn schema(
  fields : Array[@tag.Field],
  sample : Json?,
) -> Json raise SchemaError {
  if fields.length() > MAX_SCHEMA_NODES {
    raise SchemaError("form: the schema has more than 65536 fields")
  }
  let budget : Ref[Int] = Ref::new(1)
  let root = match sample {
    Some(value) => schema_node("", 0, 0, budget, value, true)
    None => schema_node("", 0, 0, budget, Json::null(), false)
  }
  let depth = schema_depths(fields)
  let order : Array[Int] = []
  for i in 0..<fields.length() {
    order.push(i)
  }
  order.sort_by(fn(a, b) { depth[a] - depth[b] })
  for i in order {
    if depth[i] > MAX_SCHEMA_DEPTH {
      raise SchemaError("form: the schema is nested more than 256 levels")
    }
    let in_sections : Array[String] = []
    for section in fields[i].in_sections {
      if !section.has_prefix("_") {
        in_sections.push(section)
      }
    }
    schema_place(root, fields[i], in_sections, i)
  }
  let output : Map[String, Json] = Map([])
  output["$schema"] = Json::string(SCHEMA_DIALECT)
  let object = schema_object(root)
  match object {
    Json::Object(properties) =>
      for key, value in properties {
        output[key] = value
      }
    _ => ()
  }
  Json::object(output)
}

///|
pub fn schema_text(
  fields : Array[@tag.Field],
  sample : Json?,
) -> String raise SchemaError {
  schema(fields, sample).stringify()
}
