///|
/// The kinds of a field.
pub const FIELD_VALUE : String = "value"
pub const FIELD_SECTION : String = "section"
pub const FIELD_IMAGE : String = "image"

///|
/// What the tags of a template say of a name: how a filler finds it, where
/// it is in sections, and what a program that asks for it needs to know.
#derive(Debug, Eq)
pub(all) struct Field {
  name : String
  kind : String
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
}

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
fn field_put(out : Array[Field], index : Map[String, Int], field : Field) -> Unit {
  let key = field_key(field)
  match index.get(key) {
    Some(at) => {
      let old = out[at]
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
    }
    None => {
      index[key] = out.length()
      out.push(field)
    }
  }
}

///|
/// Collect the fields of the tags of a template, in the order of the tags.
/// Sections name the fields inside them, and a close must close the
/// innermost section.
pub fn fields(tokens : Array[TagToken]) -> Array[Field] raise TagError {
  let out : Array[Field] = []
  let index : Map[String, Int] = Map([])
  let stack : Array[FieldFrame] = []
  for token in tokens {
    match token.kind {
      TagKind::Text => ()
      TagKind::Open | TagKind::Inverted => {
        let in_sections = stack.map(fn(frame) { frame.name })
        let field = field_new(token.name, FIELD_SECTION, in_sections)
        field.mode = token.mode
        field.inverted = token.kind == TagKind::Inverted
        field_put(out, index, field)
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
        field_put(out, index, field)
      }
    }
  }
  if !stack.is_empty() {
    let last = stack[stack.length() - 1]
    raise TagError("the section " + last.name + " is not closed", 0)
  }
  out
}
