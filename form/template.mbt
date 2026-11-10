///|
// The description of a compiled template: the part of the type "tpl" of a
// .bdft or a .bdff, as JSON (form/form.go of upstream).

///|
/// The version of the description of compiled templates.
pub const TEMPLATE_VERSION : Int = 1

///|
/// The most bytes of the template that a compiled template holds.
pub const MAX_TEMPLATE_SIZE : Int = 256 << 20

///|
/// The most bytes of the description of a compiled template.
pub const MAX_TEMPLATE_PART : Int = 64 << 20

///|
/// The type of the part that describes a compiled template.
pub const PART_TEMPLATE : String = "tpl"

///|
/// The type of the part that is the template of a compiled template.
pub const PART_SOURCE : String = "src"

///|
/// A compiled template: the template it holds, the names that its tags
/// look up, the schema of its data, and, for a partly filled form, the
/// values it holds and the names it leaves open.
pub(all) struct Template {
  /// The version of the description: `TEMPLATE_VERSION`.
  version : Int
  /// The format of the template (`FORMAT_XLSX` …).
  format : String
  /// The file name of the template, when it had one.
  name : String
  /// The hash of the part that is the template.
  source : String
  /// The names that the tags of the template look up.
  fields : Array[@tag.Field]
  /// The data that the pages show the template filled with (a compiled
  /// template only).
  sample : Json?
  /// The JSON Schema of the data (a compiled template only).
  schema : Json?
  /// The values of a partly filled form: its pages show the template
  /// filled with them.
  filled : Json?
  /// The names that a partly filled form leaves open, which the data that
  /// completes it gives, and no others.
  open : Array[String]
  /// The SHA-256 (in hex) of the description of the compiled template that
  /// the form was made of ("" for a template that was not compiled).
  from : String
  /// The signatures of the values of a partly filled form, as base64. This
  /// port does not make signatures; it keeps those that it reads.
  signed : Array[String]
  /// The SHA-256 (in hex) of the description as it was read ("" for a
  /// description that was not read).
  mut digest : String
}

///|
/// Whether a description is that of a partly filled form.
pub fn Template::is_partial(self : Template) -> Bool {
  match self.filled {
    Some(_) => true
    None => !self.open.is_empty()
  }
}

///|
fn template_string(object : Map[String, Json], name : String) -> String raise FormError {
  match object.get(name) {
    Some(Json::String(text)) => text
    Some(Json::Null) | None => ""
    Some(_) => raise FormError("form: the " + name + " of the compiled template is not a text")
  }
}

///|
fn template_strings(
  object : Map[String, Json],
  name : String,
) -> Array[String] raise FormError {
  match object.get(name) {
    Some(Json::Array(values)) => {
      let out : Array[String] = []
      for value in values {
        match value {
          Json::String(text) => out.push(text)
          Json::Null => ()
          _ =>
            raise FormError(
              "form: the " + name + " of the compiled template is not a list of texts",
            )
        }
      }
      out
    }
    Some(Json::Null) | None => []
    Some(_) =>
      raise FormError(
        "form: the " + name + " of the compiled template is not a list of texts",
      )
  }
}

///|
fn template_int(object : Map[String, Json], name : String) -> Int raise FormError {
  match object.get(name) {
    Some(Json::Number(number, ..)) => number.to_int()
    Some(Json::Null) | None => 0
    Some(_) =>
      raise FormError("form: the " + name + " of the compiled template is not a number")
  }
}

///|
fn template_fields(
  object : Map[String, Json],
  name : String,
) -> Array[@tag.Field] raise FormError {
  match object.get(name) {
    Some(Json::Array(values)) => {
      let out : Array[@tag.Field] = []
      for value in values {
        out.push(
          @tag.Field::from_json(value) catch {
            @tag.TagError(message, _) => raise FormError("form: " + message)
          },
        )
      }
      out
    }
    Some(Json::Null) | None => []
    Some(_) =>
      raise FormError("form: the " + name + " of the compiled template is not a list")
  }
}

///|
/// The JSON form of the description of a compiled template.
pub fn Template::to_json(self : Template) -> Json {
  let out : Map[String, Json] = Map([])
  out["version"] = Json::number(self.version.to_double())
  out["format"] = Json::string(self.format)
  if self.name != "" {
    out["name"] = Json::string(self.name)
  }
  out["source"] = Json::string(self.source)
  out["fields"] = Json::array(self.fields.map(fn(field) { field.to_json() }))
  match self.sample {
    Some(value) => out["sample"] = value
    None => ()
  }
  match self.schema {
    Some(value) => out["schema"] = value
    None => ()
  }
  match self.filled {
    Some(value) => out["filled"] = value
    None => ()
  }
  if !self.open.is_empty() {
    out["open"] = Json::array(self.open.map(Json::string))
  }
  if self.from != "" {
    out["from"] = Json::string(self.from)
  }
  if !self.signed.is_empty() {
    out["signed"] = Json::array(self.signed.map(Json::string))
  }
  Json::object(out)
}

///|
/// Read the description of a compiled template.
pub fn Template::from_json(value : Json) -> Template raise FormError {
  let object = match value {
    Json::Object(object) => object
    _ =>
      raise FormError(
        "form: the description of the compiled template is not an object",
      )
  }
  let sample = match object.get("sample") {
    Some(Json::Null) | None => None
    Some(value) => Some(value)
  }
  let schema = match object.get("schema") {
    Some(Json::Null) | None => None
    Some(value) => Some(value)
  }
  let filled = match object.get("filled") {
    Some(Json::Null) | None => None
    Some(value) => Some(value)
  }
  {
    version: template_int(object, "version"),
    format: template_string(object, "format"),
    name: template_string(object, "name"),
    source: template_string(object, "source"),
    fields: template_fields(object, "fields"),
    sample,
    schema,
    filled,
    open: template_strings(object, "open"),
    from: template_string(object, "from"),
    signed: template_strings(object, "signed"),
    digest: "",
  }
}

///|
fn template_part(
  document : @core.Document,
  hash : String,
  kind : String,
  name : String,
  limit : Int,
) -> Bytes raise FormError {
  let mut found : @core.Part? = None
  for part in document.manifest.parts {
    if part.hash == hash {
      found = Some(part)
    }
  }
  let part = match found {
    Some(part) => part
    None =>
      raise FormError("form: the compiled template does not hold its " + name)
  }
  if part.kind != kind {
    raise FormError("form: the compiled template does not hold its " + name)
  }
  if part.size < 0 || part.length < 0 {
    raise FormError("form: the " + name + " has a negative size")
  }
  if part.size > limit || part.length > limit {
    raise FormError(
      "form: the " + name + " is larger than " + (limit >> 20).to_string() + " MiB",
    )
  }
  if (part.encoding == "identity" || part.encoding == "") &&
    part.length != part.size {
    raise FormError(
      "form: the " + name + " has inconsistent stored and decoded sizes",
    )
  }
  let data = document.part(hash) catch {
    @core.BadFormat(message) => raise FormError("form: " + message)
    @core.Unsupported(message) => raise FormError("form: " + message)
    _ => raise FormError("form: the " + name + " cannot be read")
  }
  if data.length() != part.size || @core.hash_of(data) != hash {
    raise FormError("form: the " + name + " is damaged")
  }
  data
}

///|
/// Read a compiled template: its description, and the template it holds.
pub fn read_template(data : Bytes) -> (Template, Bytes) raise FormError {
  let document = @core.open_single(data) catch {
    error => raise FormError("form: " + error.to_string())
  }
  let mut template_hash = ""
  for part in document.manifest.parts {
    if part.kind == PART_TEMPLATE {
      template_hash = part.hash
      break
    }
  }
  if template_hash == "" {
    raise FormError(
      "form: the document is not a compiled template (it has no \"" +
      PART_TEMPLATE +
      "\" part)",
    )
  }
  let description = template_part(
    document,
    template_hash,
    PART_TEMPLATE,
    "description of the compiled template",
    MAX_TEMPLATE_PART,
  )
  let parsed = @json.parse(@utf8.decode_lossy(description[:])) catch {
    _ =>
      raise FormError(
        "form: the description of the compiled template is not JSON",
      )
  }
  let template = Template::from_json(parsed)
  if template.version != TEMPLATE_VERSION {
    raise FormError(
      "form: the compiled template is of version " +
      template.version.to_string() +
      "; this reads version " +
      TEMPLATE_VERSION.to_string() +
      " (compile the template again)",
    )
  }
  if !@core.valid_hash(template.source) {
    raise FormError("form: the compiled template does not name its template")
  }
  let source = template_part(
    document,
    template.source,
    PART_SOURCE,
    "template of the compiled template",
    MAX_TEMPLATE_SIZE,
  )
  template.digest = @core.sha256_hex(description)
  (template, source)
}
