///|
// The fields of a template of pdfme, and the data that it has for itself
// (converter/pdfme of upstream).

///|
fn pdfme_read_only(field : Json) -> Bool {
  match json_field(field, "readOnly") {
    Some(Json::True) => true
    _ => false
  }
}

///|
fn pdfme_strings(field : Json, name : String) -> Array[String] {
  match json_field(field, name) {
    Some(Json::Array(values)) =>
      values.map(fn(value) {
        match value {
          Json::String(text) => text
          _ => ""
        }
      })
    _ => []
  }
}

///|
fn pdfme_variables(text : String) -> Array[String] {
  let out : Array[String] = []
  let mut pos = 0
  while pos < text.length() {
    let rest = text[pos:]
    let start = match rest.find("{") {
      Some(index) => pos + index
      None => break
    }
    if start + 1 < text.length() && text[start + 1] == '{' {
      pos = start + 2
      continue
    }
    let after = text[start + 1:]
    let end = match after.find("}") {
      Some(index) => start + 1 + index
      None => break
    }
    let name = text[start + 1:end].trim().to_owned()
    if name != "" && !out.contains(name) {
      out.push(name)
    }
    pos = end + 1
  }
  out
}

///|
fn pdfme_inspect_put(
  out : Array[@tag.Field],
  index : Map[String, Int],
  field : @tag.Field,
  at : String,
) -> Unit {
  let key = field.kind +
    "\u{0}" +
    field.in_sections.join("\u{0}") +
    "\u{0}" +
    field.name
  match index.get(key) {
    Some(i) => {
      let old = out[i]
      if old.at.length() < 16 && !old.at.contains(at) {
        old.at.push(at)
      }
    }
    None => {
      field.at.push(at)
      index[key] = out.length()
      out.push(field)
    }
  }
}

///|
fn pdfme_inspect_field(
  out : Array[@tag.Field],
  index : Map[String, Int],
  field : Json,
  at : String,
) -> Unit {
  let name = text_of(json_field(field, "name"), "")
  if name == "" || pdfme_read_only(field) {
    return
  }
  let typ = text_of(json_field(field, "type"), "text")
  let content = text_of(json_field(field, "content"), "")
  let value : @tag.Field = {
    name,
    kind: @tag.FIELD_VALUE,
    in_sections: [],
    format: "",
    mode: "",
    slots: 0,
    inverted: false,
    code: "",
    input: "",
    at: [],
    value_type: "",
    options: [],
    labels: [],
    label: "",
    default: Json::null(),
    max_len: 0,
    multiline: false,
  }
  match typ {
    "qrcode" => {
      value.kind = @tag.FIELD_IMAGE
      value.code = "qr"
      if content != "" {
        value.default = Json::string(content)
      }
    }
    "barcode" => {
      value.kind = @tag.FIELD_IMAGE
      value.code = text_of(json_field(field, "format"), "code39")
      if content != "" {
        value.default = Json::string(content)
      }
    }
    "image" | "svg" => value.kind = @tag.FIELD_IMAGE
    "signature" => {
      value.kind = @tag.FIELD_IMAGE
      value.input = @tag.INPUT_SIGNATURE
    }
    "checkbox" => {
      value.value_type = "boolean"
      value.default = Json::boolean(content == "true")
    }
    "radioGroup" => {
      value.value_type = "string"
      for option in pdfme_strings(field, "options") {
        value.options.push(option)
      }
      if content != "" {
        value.default = Json::string(content)
      }
    }
    "table" => {
      let section = value
      section.kind = @tag.FIELD_SECTION
      section.mode = @tag.MODE_ROWS
      pdfme_inspect_put(out, index, section, at)
      for head in pdfme_strings(field, "head") {
        let column : @tag.Field = {
          name: head,
          kind: @tag.FIELD_VALUE,
          in_sections: [name],
          format: "",
          mode: "",
          slots: 0,
          inverted: false,
          code: "",
          input: "",
          at: [],
          value_type: "",
          options: [],
          labels: [],
          label: "",
          default: Json::null(),
          max_len: 0,
          multiline: false,
        }
        pdfme_inspect_put(out, index, column, at)
      }
      return
    }
    "list" => {
      let section = value
      section.kind = @tag.FIELD_SECTION
      pdfme_inspect_put(out, index, section, at)
      let item : @tag.Field = {
        name: ".",
        kind: @tag.FIELD_VALUE,
        in_sections: [name],
        format: "",
        mode: "",
        slots: 0,
        inverted: false,
        code: "",
        input: "",
        at: [],
        value_type: "",
        options: [],
        labels: [],
        label: "",
        default: Json::null(),
        max_len: 0,
        multiline: false,
      }
      pdfme_inspect_put(out, index, item, at)
      return
    }
    "multiVariableText" => {
      value.value_type = "string"
      for variable in pdfme_variables(text_of(json_field(field, "text"), "")) {
        let part : @tag.Field = {
          name: name + "." + variable,
          kind: @tag.FIELD_VALUE,
          in_sections: [],
          format: "",
          mode: "",
          slots: 0,
          inverted: false,
          code: "",
          input: "",
          at: [],
          value_type: "string",
          options: [],
          labels: [],
          label: "",
          default: Json::null(),
          max_len: 0,
          multiline: false,
        }
        pdfme_inspect_put(out, index, part, at)
      }
      return
    }
    "text" | "select" | "date" | "time" | "dateTime" => {
      value.value_type = "string"
      if typ == "date" {
        value.value_type = "date"
      } else if typ == "dateTime" {
        value.value_type = "date-time"
      } else if typ == "select" {
        for option in pdfme_strings(field, "options") {
          value.options.push(option)
        }
      }
    }
    "circleMark" => {
      value.value_type = "boolean"
      value.default = Json::boolean(content == "true")
    }
    // (a shape, or a type that is not known: nothing to fill)
    _ => return
  }
  pdfme_inspect_put(out, index, value, at)
}

///|
fn pdfme_pages(template : Json) -> Array[Json] raise PdfmeError {
  match json_field(template, "schemas") {
    Some(Json::Array(pages)) => pages
    _ => raise PdfmeError("pdfme: the template has no schemas")
  }
}

///|
/// The fields of a template of pdfme, in the order of its pages: the names
/// that data for it has, and what each asks for.
pub fn inspect(data : Bytes) -> Array[@tag.Field] raise PdfmeError {
  let template = @json.parse(@utf8.decode_lossy(data[:])) catch {
    _ => raise PdfmeError("pdfme: the template is not JSON")
  }
  let out : Array[@tag.Field] = []
  let index : Map[String, Int] = Map([])
  for page_index, page in pdfme_pages(template) {
    let at = "page " + (page_index + 1).to_string()
    let fields = match page {
      Json::Array(fields) => fields
      _ => []
    }
    for field in fields {
      pdfme_inspect_field(out, index, field, at)
    }
  }
  out
}

///|
/// The data that a template of pdfme has for itself: the content that its
/// designer left in each field, as the value of the field. It is a sample
/// of the data of the template.
pub fn defaults(data : Bytes) -> Json raise PdfmeError {
  let template = @json.parse(@utf8.decode_lossy(data[:])) catch {
    _ => raise PdfmeError("pdfme: the template is not JSON")
  }
  let out : Map[String, Json] = Map([])
  for page in pdfme_pages(template) {
    let fields = match page {
      Json::Array(fields) => fields
      _ => []
    }
    for field in fields {
      let name = text_of(json_field(field, "name"), "")
      if name == "" || pdfme_read_only(field) || out.contains(name) {
        continue
      }
      let typ = text_of(json_field(field, "type"), "text")
      let content = text_of(json_field(field, "content"), "")
      match typ {
        "checkbox" => out[name] = Json::boolean(content == "true")
        "image" | "signature" | "svg" | "table" | "list" => ()
        "multiVariableText" => {
          let values = @json.parse(content[:]) catch { _ => Json::null() }
          match values {
            Json::Object(_) => out[name] = values
            _ => ()
          }
        }
        _ => out[name] = Json::string(content)
      }
    }
  }
  Json::object(out)
}
