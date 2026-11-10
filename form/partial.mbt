///|
// Partly filled forms: a fill that leaves names of the data open makes a
// .bdff of the values it holds, which another fill completes
// (form/partial.go of upstream).

///|
/// `OPEN_ALL` in `Options.open` leaves open every name that the data does
/// not give.
pub const OPEN_ALL : String = "*"

///|
/// The warning of a fill that the data has no name.
const WARNING_NO_DATA : String = "the data has no \""

///|
/// A fill of a template that is partly filled, or makes one.
priv struct Partial {
  /// The data that fills the template: the values filled and those given.
  data : Json
  /// The names left open after the fill (none: the form is complete).
  open : Array[String]
  /// The values of the partly filled form that the fill makes.
  filled : Json
}

///|
fn partial_join(prefix : String, name : String) -> String {
  if prefix == "" {
    name
  } else {
    prefix + "." + name
  }
}

///|
fn partial_under(open : Array[String], name : String) -> Bool {
  for o in open {
    if name == o || name.has_prefix(o + ".") {
      return true
    }
  }
  false
}

///|
fn partial_within(open : Array[String], name : String) -> Bool {
  for o in open {
    if o.has_prefix(name + ".") {
      return true
    }
  }
  false
}

///|
fn partial_lookup(data : Map[String, Json], name : String) -> Json? {
  let mut current = Json::object(data)
  for part in name.split(".") {
    let object = match current {
      Json::Object(object) => object
      _ => return None
    }
    match object.get(part.to_owned()) {
      Some(value) => current = value
      None => return None
    }
  }
  Some(current)
}

///|
/// The data as JSON keeps it: what a partly filled form holds.
fn partial_copy(value : Json) -> Map[String, Json] raise FormError {
  let object = match value {
    Json::Object(object) => object
    Json::Null => Map([])
    _ =>
      raise FormError(
        "form: the data is not data of JSON: it is not an object",
      )
  }
  let parsed = @json.parse(Json::object(object).stringify()) catch {
    _ => raise FormError("form: the data is not data of JSON")
  }
  match parsed {
    Json::Object(object) => object
    _ => raise FormError("form: the data is not data of JSON")
  }
}

///|
/// Copy the values of `src` into `dst`, into the objects of the same names.
fn partial_merge(dst : Map[String, Json], src : Map[String, Json]) -> Unit {
  for key, value in src {
    match value {
      Json::Object(inner) =>
        match dst.get(key) {
          Some(Json::Object(existing)) => partial_merge(existing, inner)
          _ => dst[key] = value
        }
      _ => dst[key] = value
    }
  }
}

///|
/// Check that the data gives only names left open, and none that are
/// filled: `prefix` is where the data is.
fn partial_check_given(
  data : Map[String, Json],
  prefix : String,
  open : Array[String],
  filled : Map[String, Json],
) -> Unit raise FormError {
  let keys = data.keys().to_array()
  keys.sort()
  for key in keys {
    let path = partial_join(prefix, key)
    if partial_under(open, path) {
      continue
    }
    if partial_within(open, path) {
      match data.get(key) {
        Some(Json::Object(inner)) =>
          partial_check_given(inner, path, open, filled)
        _ =>
          raise FormError(
            "form: \"" +
            path +
            "\" of the data is not an object: the form leaves names in it open",
          )
      }
      continue
    }
    if partial_lookup(filled, path) is Some(_) {
      raise FormError(
        "form: \"" +
        path +
        "\" is filled already; the data may give only the names that the form leaves open",
      )
    }
    raise FormError(
      "form: the form does not leave \"" +
      path +
      "\" open; the data may give only the names that it leaves open",
    )
  }
}

///|
fn partial_uniq(names : Array[String]) -> Array[String] {
  let seen : Map[String, Bool] = Map([])
  let out : Array[String] = []
  for name in names {
    if !seen.contains(name) {
      seen[name] = true
      out.push(name)
    }
  }
  out
}

///|
/// Drop the warnings of names that the data lacks because they are left
/// open.
fn without_open(warnings : Array[String], open : Array[String]) -> Array[String] {
  let out : Array[String] = []
  for warning in warnings {
    let mut drop = false
    match warning.find(WARNING_NO_DATA) {
      Some(index) => {
        let rest = warning[index + WARNING_NO_DATA.length():]
        match rest.find("\"") {
          Some(end) => {
            let name = rest[:end].to_owned()
            if partial_under(open, name) || partial_within(open, name) {
              drop = true
            }
          }
          None => ()
        }
      }
      None => ()
    }
    if !drop {
      out.push(warning)
    }
  }
  out
}

///|
/// Work out a fill of a template whose description is `def` (`None` for a
/// template that is not compiled), with the fields of the template. It
/// returns `None` for a fill that has nothing to do with partly filled
/// forms.
fn prepare(
  def : Template?,
  fields : Array[@tag.Field],
  given_value : Json,
  open_options : Array[String],
) -> Partial? raise FormError {
  let filled = match def {
    Some(template) => template.filled
    None => None
  }
  let open = match def {
    Some(template) => template.open
    None => []
  }
  if filled is None && open.is_empty() && open_options.is_empty() {
    return None
  }
  let held = match filled {
    Some(value) => partial_copy(value)
    None => Map([])
  }
  let given = partial_copy(given_value)
  if filled is Some(_) {
    partial_check_given(given, "", open, held)
  }
  let data = partial_copy(Json::object(held))
  partial_merge(data, given)
  let names = @schema.names(fields, Some(Json::object(data))) catch {
    @schema.SchemaError(message) => raise FormError(message)
  }
  let mut left : Array[String] = []
  for name in open_options {
    if name == OPEN_ALL {
      for candidate in names {
        if partial_lookup(data, candidate) is None &&
          (def is None || filled is None || partial_under(open, candidate)) {
          left.push(candidate)
        }
      }
      continue
    }
    let trimmed = name.trim().to_owned()
    let known = @schema.has_name(fields, Some(Json::object(data)), trimmed) catch {
      @schema.SchemaError(message) => raise FormError(message)
    }
    if !known {
      raise FormError(
        "form: \"" +
        trimmed +
        "\" is not a name of the data of the template that can be left open (a name in a list is left open with its list)",
      )
    }
    if def is Some(_) && filled is Some(_) && !partial_under(open, trimmed) {
      raise FormError(
        "form: \"" + trimmed + "\" is filled already; it cannot be left open again",
      )
    }
    left.push(trimmed)
  }
  left = partial_uniq(left)
  for name in left {
    if partial_lookup(given, name) is Some(_) {
      raise FormError(
        "form: the data gives \"" + name + "\", which it leaves open",
      )
    }
  }
  for name in names {
    if partial_lookup(data, name) is Some(_) || partial_under(left, name) {
      continue
    }
    if def is Some(_) && filled is Some(_) {
      raise FormError(
        "form: the data has no \"" +
        name +
        "\", which the form leaves open; give it (null for none), or leave it open again",
      )
    }
    raise FormError(
      "form: the data has no \"" +
      name +
      "\"; give it (null for none), or leave it open",
    )
  }
  Some({ data: Json::object(data), open: left, filled: Json::object(data) })
}

///|
/// Make the document of a partly filled form: `bdf` is the template filled
/// with the values of `plan`.
fn partly_filled(
  bdf : Bytes,
  source : Bytes,
  def : Template?,
  format : String,
  from : String,
  fields : Array[@tag.Field],
  plan : Partial,
) -> (Bytes, Template) raise FormError {
  let schema = @schema.schema_open(fields, Some(plan.filled), plan.open) catch {
    @schema.SchemaError(message) => raise FormError(message)
  }
  let template : Template = {
    version: TEMPLATE_VERSION,
    format,
    name: match def {
      Some(template) => template.name
      None => ""
    },
    source: @core.hash_of(source),
    fields,
    sample: None,
    schema: Some(schema),
    filled: Some(plan.filled),
    open: plan.open,
    from,
    signed: match def {
      Some(template) => template.signed
      None => []
    },
    digest: "",
  }
  let description = @utf8.encode(template.to_json().stringify())
  let bdf = document_with_parts(bdf, [
    (PART_SOURCE, source),
    (PART_TEMPLATE, description),
  ])
  (bdf, template)
}

///|
/// Make the document of a completed form whose values were signed: the
/// record of its values, with the signatures that the partly filled form
/// held (form/values.go of upstream).
fn record_fill(
  bdf : Bytes,
  format : String,
  source : Bytes,
  from : String,
  filled : Json,
  signed : Array[String],
) -> Bytes raise FormError {
  let record : Map[String, Json] = Map([])
  record["version"] = Json::number(RECORD_VERSION.to_double())
  record["format"] = Json::string(format)
  record["source"] = Json::string(@core.hash_of(source))
  if from != "" {
    record["from"] = Json::string(from)
  }
  record["filled"] = filled
  record["signed"] = Json::array(signed.map(Json::string))
  document_with_parts(bdf, [
    (PART_FILL, @utf8.encode(Json::object(record).stringify())),
  ])
}
