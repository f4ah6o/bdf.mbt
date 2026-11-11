///|
// The form page of the site: the form module of bdf.mbt, as the JavaScript
// of the page calls it. The page reads a template, makes the form of the
// JSON Schema of its tags, fills the template with what is typed into it,
// and offers the filled document as a .bdf (or a .bdff, when names are left
// for another person) and as a PDF.
//
// The functions here are the same calls that `bdf template schema`,
// `bdf fill` and `bdf template compile` make of the form module of
// upstream (shibukawa/bdf, MIT); the page is a port of `site/form/main.ts`
// of upstream, with the Go runtime of the upstream page replaced by these
// calls.

///|
/// The JSON of a failure: the page shows `error` and does nothing else.
fn form_page_error(message : String) -> String {
  Json::object({
    "ok": Json::boolean(false),
    "error": Json::string(message),
  }).stringify()
}

///|
fn form_page_warnings(warnings : Array[String]) -> Json {
  Json::array(warnings.map(Json::string))
}

///|
fn form_page_strings(values : Array[String]) -> Json {
  Json::array(values.map(Json::string))
}

///|
/// The values that data holds: those that are not objects (the count that
/// the page shows of a partly filled form, as `countValues` of upstream).
fn form_page_count_values(value : Json) -> Int {
  match value {
    Json::Object(object) => {
      let mut count = 0
      for _, child in object {
        count += form_page_count_values(child)
      }
      count
    }
    _ => 1
  }
}

///|
/// The names that a fill leaves open, as the page sends them: a JSON array
/// of texts (an empty text for none).
fn form_page_names(text : String) -> Array[String] {
  if text.trim() == "" {
    return []
  }
  let parsed = @json.parse(text) catch {
    _ => return []
  }
  match parsed {
    Json::Array(items) => {
      let out : Array[String] = []
      for item in items {
        match item {
          Json::String(name) => out.push(name)
          _ => ()
        }
      }
      out
    }
    _ => []
  }
}

///|
/// What a partly filled form leaves open, and how many values it holds.
fn form_page_partial(template : Bytes) -> (Array[String], Int) {
  let (def, _) = @form.read_template(template) catch {
    @form.FormError(_) => return ([], 0)
  }
  if !def.is_partial() {
    return ([], 0)
  }
  let held = match def.filled {
    Some(value) => form_page_count_values(value)
    None => 0
  }
  (def.open, held)
}

///|
/// Read a template: its format, the sample of its data (of a compiled
/// template the sample it was compiled with, of a template of pdfme what
/// its designer left in its fields), the JSON Schema of its data, and, for
/// a partly filled form, the names it leaves open and the values it holds.
///
/// `sample` is the data that the page gives the template (a JSON text, or
/// an empty text for none); it is what the schema is made of, so that a
/// template whose tags say nothing of a value still gets a type.
#export_name("bdf_form_describe")
pub fn bdf_form_describe(template : Bytes, sample : String) -> String {
  let (format, own_sample) = @form.describe(template) catch {
    @form.FormError(message) => return form_page_error(message)
  }
  let given = if sample.trim() == "" {
    own_sample
  } else {
    let parsed = @json.parse(sample) catch {
      _ => return form_page_error("the sample of the data is not JSON")
    }
    Some(parsed)
  }
  let schema = @form.schema_of(template, given) catch {
    @form.FormError(message) => return form_page_error(message)
  }
  let (open, held) = form_page_partial(template)
  Json::object({
    "ok": Json::boolean(true),
    "format": Json::string(format),
    "sample": match given {
      Some(value) => value
      None => Json::null()
    },
    "schema": Json::string(schema),
    "open": form_page_strings(open),
    "held": Json::number(held.to_double()),
  }).stringify()
}

///|
/// The views of the document that a fill made: their kinds, titles and pages.
/// A sheet view has no pages, so the page cannot write it as a PDF yet.
fn form_page_views(bdf : Bytes) -> (Json, Int) {
  let manifest = @core.manifest_json(bdf) catch {
    _ => return (Json::array([]), 0)
  }
  let views = match manifest {
    Json::Object(object) =>
      match object.get("views") {
        Some(Json::Array(views)) => views
        _ => []
      }
    _ => []
  }
  let out : Array[Json] = []
  let mut pages = 0
  for view in views {
    let object = match view {
      Json::Object(object) => object
      _ => Map([])
    }
    let kind = match object.get("kind") {
      Some(Json::String(kind)) => kind
      _ => ""
    }
    let title = match object.get("title") {
      Some(Json::String(title)) => title
      _ => ""
    }
    let count = match object.get("pages") {
      Some(Json::Array(pages)) => pages.length()
      _ => 0
    }
    pages += count
    out.push(
      Json::object({
        "kind": Json::string(kind),
        "title": Json::string(title),
        "pages": Json::number(count.to_double()),
      }),
    )
  }
  (Json::array(out), pages)
}

///|
/// Fill a template with data. `open` is a JSON array of the names that the
/// fill leaves for another person: with any, the document is a partly
/// filled form (.bdff), which another fill completes.
///
/// The document is the BDF that the page draws and offers as a .bdf: the
/// form module converts the filled template itself, so the bytes are a
/// document of BDF and not the source of the template.
#export_name("bdf_form_fill")
pub fn bdf_form_fill(
  template : Bytes,
  data : String,
  open : String,
  strict : Bool,
) -> String {
  let parsed = @json.parse(data) catch {
    _ => return form_page_error("the data is not JSON")
  }
  let names = form_page_names(open)
  let result = @form.fill(
    template,
    @form.Options::new(data=parsed, strict~, open=names),
  ) catch {
    @form.FormError(message) => return form_page_error(message)
  }
  let left = match result.partial {
    Some(def) => def.open
    None => []
  }
  let (views, pages) = form_page_views(result.bdf)
  Json::object({
    "ok": Json::boolean(true),
    "bdf": Json::string(@base64.encode(result.bdf)),
    "warnings": form_page_warnings(result.warnings),
    "format": Json::string(result.format),
    "partial": Json::boolean(result.partial is Some(_)),
    "open": form_page_strings(left),
    "views": views,
    "pages": Json::number(pages.to_double()),
  }).stringify()
}

///|
/// Compile a template: the .bdft that holds it with what it asks of data.
/// `data` is the sample that the pages show the template filled with (an
/// empty text for none: the pages then show the template with its tags).
#export_name("bdf_form_compile")
pub fn bdf_form_compile(template : Bytes, name : String, data : String) -> String {
  let options = if data.trim() == "" {
    @form.Options::new()
  } else {
    let parsed = @json.parse(data) catch {
      _ => return form_page_error("the sample of the data is not JSON")
    }
    @form.Options::new(data=parsed)
  }
  let compiled = @form.compile(template, name, options) catch {
    @form.FormError(message) => return form_page_error(message)
  }
  Json::object({
    "ok": Json::boolean(true),
    "bdft": Json::string(@base64.encode(compiled.bdf)),
    "warnings": form_page_warnings(compiled.warnings),
    "format": Json::string(compiled.template.format),
  }).stringify()
}
