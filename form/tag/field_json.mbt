///|
// The JSON form of a field: the description of a compiled template holds
// its fields as JSON (form/tag of upstream). The names are those of the
// upstream `tag.Field`, so a description written there reads here.

///|
fn field_json_string(object : Map[String, Json], name : String) -> String raise TagError {
  match object.get(name) {
    Some(Json::String(text)) => text
    Some(Json::Null) | None => ""
    Some(_) => raise TagError("the field's " + name + " is not a text", 0)
  }
}

///|
fn field_json_strings(
  object : Map[String, Json],
  name : String,
) -> Array[String] raise TagError {
  match object.get(name) {
    Some(Json::Array(values)) => {
      let out : Array[String] = []
      for value in values {
        match value {
          Json::String(text) => out.push(text)
          Json::Null => ()
          _ => raise TagError("the field's " + name + " is not a list of texts", 0)
        }
      }
      out
    }
    Some(Json::Null) | None => []
    Some(_) => raise TagError("the field's " + name + " is not a list of texts", 0)
  }
}

///|
fn field_json_bool(object : Map[String, Json], name : String) -> Bool raise TagError {
  match object.get(name) {
    Some(Json::True) => true
    Some(Json::False) | Some(Json::Null) | None => false
    Some(_) => raise TagError("the field's " + name + " is not true or false", 0)
  }
}

///|
fn field_json_int(object : Map[String, Json], name : String) -> Int raise TagError {
  match object.get(name) {
    Some(Json::Number(number, ..)) => number.to_int()
    Some(Json::Null) | None => 0
    Some(_) => raise TagError("the field's " + name + " is not a number", 0)
  }
}

///|
/// The JSON form of a field, as the description of a compiled template
/// holds it.
pub fn Field::to_json(self : Field) -> Json {
  let out : Map[String, Json] = Map([])
  out["name"] = Json::string(self.name)
  out["kind"] = Json::string(self.kind)
  if !self.in_sections.is_empty() {
    out["in"] = Json::array(self.in_sections.map(Json::string))
  }
  if self.format != "" {
    out["format"] = Json::string(self.format)
  }
  if self.mode != "" {
    out["mode"] = Json::string(self.mode)
  }
  if self.slots != 0 {
    out["slots"] = Json::number(self.slots.to_double())
  }
  if self.inverted {
    out["inverted"] = Json::boolean(true)
  }
  if self.code != "" {
    out["code"] = Json::string(self.code)
  }
  if self.input != "" {
    out["input"] = Json::string(self.input)
  }
  out["at"] = Json::array(self.at.map(Json::string))
  if self.value_type != "" {
    out["type"] = Json::string(self.value_type)
  }
  if !self.options.is_empty() {
    out["options"] = Json::array(self.options.map(Json::string))
  }
  if !self.labels.is_empty() {
    out["labels"] = Json::array(self.labels.map(Json::string))
  }
  if self.label != "" {
    out["label"] = Json::string(self.label)
  }
  if self.default != Json::null() {
    out["default"] = self.default
  }
  if self.max_len != 0 {
    out["maxLength"] = Json::number(self.max_len.to_double())
  }
  if self.multiline {
    out["multiline"] = Json::boolean(true)
  }
  Json::object(out)
}

///|
/// Read a field of the description of a compiled template.
pub fn Field::from_json(value : Json) -> Field raise TagError {
  let object = match value {
    Json::Object(object) => object
    _ => raise TagError("a field of the template is not an object", 0)
  }
  let name = field_json_string(object, "name")
  let kind = field_json_string(object, "kind")
  if name == "" {
    raise TagError("a field of the template has no name", 0)
  }
  if kind != FIELD_VALUE && kind != FIELD_SECTION && kind != FIELD_IMAGE {
    raise TagError("the field " + name + " is not a value, a section or a picture", 0)
  }
  let field = field_new(name, kind, field_json_strings(object, "in"))
  field.format = field_json_string(object, "format")
  field.mode = field_json_string(object, "mode")
  field.slots = field_json_int(object, "slots")
  field.inverted = field_json_bool(object, "inverted")
  field.code = field_json_string(object, "code")
  field.input = field_json_string(object, "input")
  for at in field_json_strings(object, "at") {
    field.at.push(at)
  }
  field.value_type = field_json_string(object, "type")
  for option in field_json_strings(object, "options") {
    field.options.push(option)
  }
  for label in field_json_strings(object, "labels") {
    field.labels.push(label)
  }
  field.label = field_json_string(object, "label")
  match object.get("default") {
    Some(value) => field.default = value
    None => ()
  }
  field.max_len = field_json_int(object, "maxLength")
  field.multiline = field_json_bool(object, "multiline")
  field
}
