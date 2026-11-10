///|
// The names of the data of a template, and the schema of the names that a
// fill leaves open (form/partial.go of upstream).

///|
fn schema_sorted_kids(node : SchemaNode) -> Array[SchemaNode] {
  let kids = node.kids.copy()
  kids.sort_by(fn(a, b) { a.first - b.first })
  kids
}

///|
fn schema_is_object(node : SchemaNode) -> Bool {
  !schema_list(node) && !node.kids.is_empty()
}

///|
fn schema_join(prefix : String, name : String) -> String {
  if prefix == "" {
    name
  } else {
    prefix + "." + name
  }
}

///|
fn schema_under(open : Array[String], name : String) -> Bool {
  for o in open {
    if name == o || name.has_prefix(o + ".") {
      return true
    }
  }
  false
}

///|
fn schema_within(open : Array[String], name : String) -> Bool {
  for o in open {
    if o.has_prefix(name + ".") {
      return true
    }
  }
  false
}

///|
fn schema_names(node : SchemaNode, prefix : String, out : Array[String]) -> Unit {
  for kid in schema_sorted_kids(node) {
    let path = schema_join(prefix, kid.name)
    if schema_is_object(kid) {
      schema_names(kid, path, out)
    } else {
      out.push(path)
    }
  }
}

///|
/// The names of the data that the tags of a template look up: those of
/// values, pictures, conditions and lists, in objects, with dots between
/// the names of objects, in the order of the template. A list is a name as
/// a whole: the names in it are not.
pub fn names(
  fields : Array[@tag.Field],
  sample : Json?,
) -> Array[String] raise SchemaError {
  let root = schema_root(fields, sample)
  let out : Array[String] = []
  schema_names(root, "", out)
  out
}

///|
fn schema_open_object(
  node : SchemaNode,
  prefix : String,
  open : Array[String],
) -> Json {
  let object : Map[String, Json] = Map([])
  object["type"] = Json::string("object")
  let properties : Map[String, Json] = Map([])
  for kid in schema_sorted_kids(node) {
    let path = schema_join(prefix, kid.name)
    if schema_under(open, path) {
      properties[kid.name] = schema_of(kid)
    } else if schema_is_object(kid) && schema_within(open, path) {
      let nested = schema_open_object(kid, path, open)
      match nested {
        Json::Object(fields) =>
          fields["title"] = Json::string(
            if kid.label != "" {
              kid.label
            } else {
              kid.name
            },
          )
        _ => ()
      }
      properties[kid.name] = nested
    }
  }
  object["properties"] = Json::object(properties)
  Json::object(object)
}

///|
/// The JSON Schema of the names of the data that a fill leaves open: an
/// object with a property for each of them, and for the objects that hold
/// them. A partly filled form holds it, so that a program asks for what is
/// left to fill in.
pub fn schema_open(
  fields : Array[@tag.Field],
  sample : Json?,
  open : Array[String],
) -> Json raise SchemaError {
  let root = schema_root(fields, sample)
  let output : Map[String, Json] = Map([])
  output["$schema"] = Json::string(SCHEMA_DIALECT)
  let object = schema_open_object(root, "", open)
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
/// Whether a name with dots is a name of the data of a template that a
/// fill can leave open: a name in an object, not in a list.
pub fn has_name(
  fields : Array[@tag.Field],
  sample : Json?,
  name : String,
) -> Bool raise SchemaError {
  let root = schema_root(fields, sample)
  let mut at = root
  for part in name.split(".") {
    if !schema_is_object(at) {
      return false
    }
    match at.by_name.get(part.to_owned()) {
      Some(kid) => at = kid
      None => return false
    }
  }
  true
}
