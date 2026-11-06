///|
// The job template attributes of IPP (RFC 8011 §5.2 and IPP Everywhere).
pub fn job_template_attrs() -> Array[String] {
  [
  "copies",
  "finishings",
  "ipp-attribute-fidelity",
  "job-account-id",
  "job-accounting-user-id",
  "job-hold-until",
  "job-name",
  "job-priority",
  "media",
  "media-col",
  "multiple-document-handling",
  "number-up",
  "orientation-requested",
  "output-bin",
  "overrides",
  "page-ranges",
  "print-color-mode",
  "print-content-optimize",
  "print-quality",
  "print-rendering-intent",
  "print-scaling",
  "printer-resolution",
  "sides",
  ]
}

///|
/// The requested-attributes of an operation group, or def without it.
pub fn requested(group : Group, def : Array[String]) -> Array[String] {
  match group.get("requested-attributes") {
    Some(attribute) => attribute.strings()
    None => def
  }
}

///|
/// Keep the attributes named, or the names of the groups that groups maps.
pub fn filter(
  attrs : Array[Attribute],
  requested : Array[String],
  groups : Map[String, Array[String]],
) -> Array[Attribute] {
  let want : Map[String, Bool] = Map([])
  for name in requested {
    if name == "all" {
      return attrs
    }
    match groups.get(name) {
      Some(names) =>
        for item in names {
          want[item] = true
        }
      None => want[name] = true
    }
  }
  let out : Array[Attribute] = []
  for attribute in attrs {
    if want.get(attribute.name).unwrap_or(false) {
      out.push(attribute)
    }
  }
  out
}

///|
fn list_has(values : Array[String], value : String) -> Bool {
  for item in values {
    if item == value {
      return true
    }
  }
  false
}

///|
/// The groups of a printer's attributes that requested-attributes names.
pub fn printer_groups(attrs : Array[Attribute]) -> Map[String, Array[String]] {
  let template : Array[String] = []
  let description : Array[String] = []
  let suffixes = ["-default", "-supported", "-ready", "-database"]
  for attribute in attrs {
    let mut base = attribute.name
    for suffix in suffixes {
      if base.has_suffix(suffix) {
        base = base[:base.length() - suffix.length()].to_owned()
      }
    }
    if base != attribute.name &&
      (list_has(job_template_attrs(), base) || base == "media-col") {
      template.push(attribute.name)
    } else {
      description.push(attribute.name)
    }
  }
  let groups : Map[String, Array[String]] = Map([])
  groups["job-template"] = template
  groups["printer-description"] = description
  groups
}

///|
/// Keyword values of an attribute.
pub fn keywords(values : Array[String]) -> Array[Value] {
  values.map(fn(value) { keyword(value) })
}

///|
/// MIME type values of an attribute.
pub fn mime_types(values : Array[String]) -> Array[Value] {
  values.map(fn(value) { mime_type(value) })
}

///|
/// Enum values of an attribute.
pub fn enums(values : Array[Int]) -> Array[Value] {
  values.map(fn(value) { enum_value(value) })
}
