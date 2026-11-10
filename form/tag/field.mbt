///|
/// The kinds of a field.
pub const FIELD_VALUE : String = "value"
pub const FIELD_SECTION : String = "section"
pub const FIELD_IMAGE : String = "image"

///|
/// What the tags of a template say of a name: how a filler finds it, where
/// it is in sections, and what a program that asks for it needs to know.
pub(all) struct Field {
  name : String
  mut kind : String
  mut in_sections : Array[String]
  mut format : String
  mut mode : String
  mut slots : Int
  mut inverted : Bool
  mut code : String
  mut input : String
  mut at : Array[String]
  mut value_type : String
  mut options : Array[String]
  mut labels : Array[String]
  mut label : String
  mut default : Json
  mut max_len : Int
  mut multiline : Bool
} derive(Debug, Eq)

///|
fn field_new(name : String, kind : String, in_sections : Array[String]) -> Field {
  {
    name,
    kind,
    in_sections,
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
}

///|
priv struct FieldFrame {
  name : String
  mode : String
  inverted : Bool
}

///|
fn field_key(field : Field) -> String {
  field.kind + "\u{0}" + field.in_sections.join(".") + "\u{0}" + field.name
}

///|
fn field_put(
  out : Array[Field],
  index : Map[String, Int],
  field : Field,
  at : String,
) -> Unit {
  let key = field_key(field)
  match index.get(key) {
    Some(i) => {
      let old = out[i]
      if old.format == "" {
        old.format = field.format
      }
      if old.mode == "" {
        old.mode = field.mode
      }
      if old.code == "" {
        old.code = field.code
      }
      if old.input == "" {
        old.input = field.input
      }
      old.inverted = old.inverted || field.inverted
      if at != "" && old.at.length() < 16 && !old.at.contains(at) {
        old.at.push(at)
      }
    }
    None => {
      index[key] = out.length()
      if at != "" {
        field.at.push(at)
      }
      out.push(field)
    }
  }
}

///|
/// Collect the fields of the tags of a template, in the order of the tags.
/// Sections name the fields inside them, and a close must close the
/// innermost section.
pub fn fields(tokens : Array[TagToken]) -> Array[Field] raise TagError {
  fields_at(tokens, [])
}

///|
/// Collect the fields of the tags of a template, with where each tag is:
/// `at[i]` is where `tokens[i]` is ("" for a tag without a place). A field
/// that several tags name keeps up to 16 places.
pub fn fields_at(
  tokens : Array[TagToken],
  at : Array[String],
) -> Array[Field] raise TagError {
  let out : Array[Field] = []
  let index : Map[String, Int] = Map([])
  let stack : Array[FieldFrame] = []
  for i, token in tokens {
    let place = if i < at.length() { at[i] } else { "" }
    match token.kind {
      TagKind::Text => ()
      TagKind::Open | TagKind::Inverted => {
        let in_sections = stack.map(fn(frame) { frame.name })
        let field = field_new(token.name, FIELD_SECTION, in_sections)
        field.mode = token.mode
        field.inverted = token.kind == TagKind::Inverted
        field_put(out, index, field, place)
        stack.push({
          name: token.name,
          mode: token.mode,
          inverted: token.kind == TagKind::Inverted,
        })
      }
      TagKind::Close => {
        if stack.is_empty() {
          raise TagError(
            "a tag closes the section " + token.name + " that is not open",
            token.pos,
          )
        }
        let last = stack[stack.length() - 1]
        if token.name != "" && token.name != last.name {
          raise TagError(
            "a tag closes the section " +
            token.name +
            " inside " +
            last.name,
            token.pos,
          )
        }
        ignore(stack.pop())
      }
      TagKind::Value | TagKind::Image => {
        let in_sections = stack.map(fn(frame) { frame.name })
        let kind = if token.kind == TagKind::Image {
          FIELD_IMAGE
        } else {
          FIELD_VALUE
        }
        let field = field_new(token.name, kind, in_sections)
        field.format = token.format
        field.code = token.code
        field.input = token.input
        field_put(out, index, field, place)
      }
    }
  }
  if !stack.is_empty() {
    let last = stack[stack.length() - 1]
    raise TagError("the section " + last.name + " is not closed", 0)
  }
  out
}
