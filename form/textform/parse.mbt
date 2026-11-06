///|
// Reading a plain-text template: front matter, lines, tags and sections.
const SEC_WIDE : String = "_wide"
const SEC_TALL : String = "_tall"
const SEC_BIG : String = "_big"
const SEC_PAPER : String = "preprinted"

const ATTR_WIDE : Int = 1
const ATTR_TALL : Int = 2
const ATTR_PAPER : Int = 4

const MAX_TEMPLATE : Int = 16 << 20
const MAX_BODY_LINES : Int = 1 << 18

///|
priv struct TextLine {
  no : Int
  src : String
  toks : Array[@tag.TagToken]
  mut matches : Array[Int]
  mut line_level : Array[Bool]
  brk : Bool
  mut tag_only : Bool
  mut tagged : Bool
  mut attrs : Int
}

///|
priv struct TextSection {
  name : String
  path : Array[String]
  inverted : Bool
  mut mode : String
  a : Int
  b : Int
  open_line : Int
  open_token : Int
  mut parent : TextSection?
  mut children : Array[TextSection]
  at : String
}

///|
priv struct TextTemplate {
  grid : Grid
  lines : Array[TextLine]
  root : TextSection
  mut grows : Bool
  sections : Map[String, TextSection]
  warnings : Array[String]
}

///|
fn attr_of(name : String) -> Int {
  if name == SEC_WIDE {
    ATTR_WIDE
  } else if name == SEC_TALL {
    ATTR_TALL
  } else if name == SEC_BIG {
    ATTR_WIDE | ATTR_TALL
  } else if name == SEC_PAPER {
    ATTR_PAPER
  } else {
    0
  }
}

///|
fn text_section_new(
  name : String,
  path : Array[String],
  inverted : Bool,
  mode : String,
  a : Int,
  b : Int,
  open_line : Int,
  open_token : Int,
  at : String,
) -> TextSection {
  {
    name,
    path,
    inverted,
    mode,
    a,
    b,
    open_line,
    open_token,
    parent: None,
    children: [],
    at,
  }
}

///|
fn text_section_slots(section : TextSection, tpl : TextTemplate) -> Array[Int] {
  let out : Array[Int] = []
  for i in section.a..=section.b {
    if !tpl.lines[i].tag_only && !tpl.lines[i].brk {
      out.push(i)
    }
  }
  out
}

///|
fn column_of(value : String, pos : Int) -> Int {
  let chars = value.to_array()
  let mut byte = 0
  let mut column = 1
  for c in chars {
    if byte >= pos {
      break
    }
    byte += c.to_string().length()
    column += 1
  }
  column
}

///|
/// Whether the start of a file is UTF-8 text without NUL bytes (the last
/// character may be cut by the end of the start).
pub fn is_text(head : Bytes) -> Bool {
  let text = @utf8.decode(head) catch { _ => return false }
  text != "" && !text.contains("\u{0}")
}

///|
/// Whether a file looks like a text template: UTF-8 that starts with front
/// matter or has a tag.
pub fn is_template(head : Bytes) -> Bool {
  let text = @utf8.decode(head) catch { _ => return false }
  text.has_prefix("---\n") || text.has_prefix("---\r\n") || @tag.has(text)
}

///|
fn parse_template(data : Bytes) -> TextTemplate raise TextFormError {
  if data.length() > MAX_TEMPLATE {
    raise TextFormError("text: the template is larger than 16 MiB")
  }
  let decoded = @utf8.decode(data) catch {
    _ => raise TextFormError("text: the template is not text of UTF-8")
  }
  let text = if decoded.has_prefix("\u{feff}") {
    decoded[1:].to_owned()
  } else {
    decoded
  }
  let text = text.replace(old="\r\n", new="\n").replace(old="\r", new="\n")
  let (front, body, first, _) = split_front_matter(text)
  let warnings : Array[String] = []
  let grid = parse_front_matter(front, warnings)
  let body = if body.has_suffix("\n") {
    body[:body.length() - 1]
  } else {
    body
  }
  let raw = if body == "" {
    []
  } else {
    body.split("\n").map(fn(line) { line.to_owned() }).to_array()
  }
  if raw.length() > MAX_BODY_LINES {
    raise TextFormError(
      "text: the template has more than " + MAX_BODY_LINES.to_string() + " lines",
    )
  }
  let lines : Array[TextLine] = []
  for i, source in raw {
    let no = first + i
    let parts = source.split("\u{c}").map(fn(part) { part.to_owned() }).to_array()
    for k, part in parts {
      if k > 0 {
        lines.push({
          no,
          src: "",
          toks: [],
          matches: [],
          line_level: [],
          brk: true,
          tag_only: false,
          tagged: false,
          attrs: 0,
        })
      }
      if part == "" && parts.length() > 1 {
        continue
      }
      let tokens = @tag.parse_text(part) catch {
        TagError(message, pos) =>
          raise TextFormError(
            "text: line " +
            no.to_string() +
            ", column " +
            column_of(part, pos).to_string() +
            ": " +
            message,
          )
      }
      for token in tokens {
        if token.kind == @tag.TagKind::Image {
          raise TextFormError(
            "text: line " +
            no.to_string() +
            ": {{%" +
            token.name +
            "}}: a template of text has no pictures nor codes (its lines are printed in the text mode of printers)",
          )
        }
      }
      lines.push({
        no,
        src: part,
        toks: tokens,
        matches: [],
        line_level: [],
        brk: false,
        tag_only: false,
        tagged: false,
        attrs: 0,
      })
    }
  }
  let tpl : TextTemplate = {
    grid,
    lines,
    root: text_section_new("", [], false, "", 0, lines.length() - 1, 0, 0, ""),
    grows: false,
    sections: Map([]),
    warnings,
  }
  tpl.sections_of()
  tpl
}

///|
fn text_color_error(at : String, message : String) -> TextFormError {
  TextFormError("text: " + at + ": " + message)
}

///|
fn TextTemplate::sections_of(self : TextTemplate) -> Unit raise TextFormError {
  let stack : Array[(Int, Int, @tag.TagToken)] = []
  for li, line in self.lines {
    let matches = Array::make(line.toks.length(), -1)
    let levels = Array::make(line.toks.length(), false)
    line.matches = matches
    line.line_level = levels
    for ti, token in line.toks {
      if token.kind == @tag.TagKind::Open || token.kind == @tag.TagKind::Inverted {
        let attr = attr_of(token.name)
        if attr != 0 && (token.kind == @tag.TagKind::Inverted || token.mode != "") {
          raise text_color_error(
            line.at(),
            "{{#" +
            token.name +
            "}} marks how characters are printed; it is not inverted and takes no " +
            token.mode,
          )
        }
        stack.push((li, ti, token))
      } else if token.kind == @tag.TagKind::Close {
        if stack.is_empty() {
          raise text_color_error(
            line.at(),
            "{{/" + token.name + "}} closes no section",
          )
        }
        let (open_line, open_token, open) = stack.pop().unwrap()
        if token.name != "" && token.name != open.name {
          raise text_color_error(
            line.at(),
            "{{/" +
            token.name +
            "}} closes {{#" +
            open.name +
            "}} of line " +
            self.lines[open_line].no.to_string(),
          )
        }
        if open_line == li && open.mode == "" {
          line.matches[open_token] = ti
          continue
        }
        line.line_level[ti] = true
        self.lines[open_line].line_level[open_token] = true
        let attr = attr_of(open.name)
        if attr != 0 {
          for k in open_line..=li {
            self.lines[k].attrs = self.lines[k].attrs | attr
          }
          continue
        }
        let section = text_section_new(
          open.name,
          open.path,
          open.kind == @tag.TagKind::Inverted,
          open.mode,
          open_line,
          li,
          open_line,
          open_token,
          self.lines[open_line].at(),
        )
        self.sections[
          open_line.to_string() + ":" + open_token.to_string()
        ] = section
        self.place(section)
      }
    }
  }
  if !stack.is_empty() {
    let (open_line, _, open) = stack[stack.length() - 1]
    raise text_color_error(
      self.lines[open_line].at(),
      "the section {{#" +
      open.name +
      "}} is not closed with {{/" +
      open.name +
      "}}",
    )
  }
  for line in self.lines {
    if line.brk {
      continue
    }
    line.tag_only = !line.toks.is_empty()
    for ti, token in line.toks {
      let is_line_level = line.line_level[ti]
      if !is_line_level &&
        !(token.kind == @tag.TagKind::Text && token.text.trim() == "") {
        line.tag_only = false
      }
      if !is_line_level && token.kind != @tag.TagKind::Text {
        line.tagged = true
      }
    }
  }
  self.check(self.root)
}

///|
fn TextLine::at(self : TextLine) -> String {
  "line " + self.no.to_string()
}

///|
fn TextTemplate::place(self : TextTemplate, section : TextSection) -> Unit {
  let kept : Array[TextSection] = []
  for child in self.root.children {
    if child.open_line > section.open_line ||
      (child.open_line == section.open_line &&
        child.open_token > section.open_token) {
      child.parent = Some(section)
      section.children.push(child)
    } else {
      kept.push(child)
    }
  }
  section.parent = Some(self.root)
  self.root.children = kept
  self.root.children.push(section)
}

///|
fn TextTemplate::check(self : TextTemplate, section : TextSection) -> Unit raise TextFormError {
  for i, child in section.children {
    if child.inverted {
      if child.mode == @tag.MODE_SLOTS || child.mode == @tag.MODE_PAGES {
        raise text_color_error(
          child.at,
          "the inverted section {{^" +
          child.name +
          "}} does not repeat: it takes no " +
          child.mode,
        )
      }
      child.mode = @tag.MODE_ROWS
    } else if child.mode == "" && child.a == child.b {
      child.mode = @tag.MODE_ROWS
    } else if child.mode == "" {
      child.mode = @tag.MODE_SLOTS
    }
    if child.mode == @tag.MODE_ROWS && !child.inverted {
      self.grows = true
    }
    if child.mode == @tag.MODE_SLOTS && !child.children.is_empty() {
      let inner = child.children[0]
      raise text_color_error(
        inner.at,
        "the section {{#" +
        child.name +
        "}} is in the lines of {{#" +
        inner.name +
        "}}, which are slots (a line for an item); write {{#" +
        inner.name +
        " | rows}} to repeat the lines instead",
      )
    }
    if child.mode == @tag.MODE_SLOTS &&
      text_section_slots(child, self).is_empty() {
      raise text_color_error(
        child.at,
        "the section {{#" + child.name + "}} has no line to fill",
      )
    }
    if i > 0 && child.a <= section.children[i - 1].b {
      let previous = section.children[i - 1]
      raise text_color_error(
        child.at,
        "the sections {{#" +
        previous.name +
        "}} and {{#" +
        child.name +
        "}} both repeat line " +
        self.lines[child.a].no.to_string() +
        "; a line is repeated by one section, or by sections one inside the other",
      )
    }
    self.check(child)
  }
}

///|
fn TextTemplate::section_at(self : TextTemplate, li : Int) -> TextSection {
  let mut section = self.root
  while true {
    let mut inside : TextSection? = None
    for child in section.children {
      if child.a <= li && li <= child.b {
        inside = Some(child)
        break
      }
    }
    match inside {
      Some(child) => section = child
      None => break
    }
  }
  section
}

///|
fn TextTemplate::fields(self : TextTemplate) -> Array[@tag.Field] {
  let out : Array[@tag.Field] = []
  let index : Map[String, Int] = Map([])
  let add = fn(field : @tag.Field, at : String) -> Unit {
    if field.name.has_prefix("_") ||
      (field.name == "." && field.in_sections.is_empty()) ||
      (field.kind == @tag.FIELD_SECTION && attr_of(field.name) != 0) {
      return
    }
    let key = field.kind +
      "\u{0}" +
      field.in_sections.join("\u{0}") +
      "\u{0}\u{0}" +
      field.name
    match index.get(key) {
      Some(i) => {
        let old = out[i]
        if old.format == "" {
          old.format = field.format
        }
        if old.mode == "" {
          old.mode = field.mode
          old.slots = field.slots
        }
        old.inverted = old.inverted && field.inverted
        if old.at.length() < 16 && old.at[old.at.length() - 1] != at {
          old.at.push(at)
        }
      }
      None => {
        field.at = [at]
        index[key] = out.length()
        out.push(field)
      }
    }
  }
  for li, line in self.lines {
    if line.brk {
      continue
    }
    let in_sections : Array[String] = []
    let mut sec = self.section_at(li)
    while true {
      if sec.name != "" {
        in_sections.insert(0, sec.name)
      }
      match sec.parent {
        Some(parent) =>
          if parent.name == "" {
            break
          } else {
            sec = parent
          }
        None => break
      }
    }
    let current = in_sections
    for ti, token in line.toks {
      if token.kind == @tag.TagKind::Value {
        let field = @tag.Field::{
          name: token.name,
          kind: @tag.FIELD_VALUE,
          in_sections: current.copy(),
          format: token.format,
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
        add(field, line.at())
      } else if token.kind == @tag.TagKind::Open || token.kind == @tag.TagKind::Inverted {
        let field = @tag.Field::{
          name: token.name,
          kind: @tag.FIELD_SECTION,
          in_sections: current,
          format: "",
          mode: "",
          slots: 0,
          inverted: token.kind == @tag.TagKind::Inverted,
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
        match self.sections.get(li.to_string() + ":" + ti.to_string()) {
          Some(section) => {
            field.in_sections = []
            let mut parent = section.parent
            while true {
              match parent {
                Some(value) =>
                  if value.name == "" {
                    break
                  } else {
                    field.in_sections.insert(0, value.name)
                    parent = value.parent
                  }
                None => break
              }
            }
            field.mode = section.mode
            if section.mode == @tag.MODE_SLOTS {
              field.slots = text_section_slots(section, self).length()
            }
            add(field, line.at())
          }
          None => {
            add(field, line.at())
            if !line.line_level[ti] && attr_of(token.name) == 0 {
              current.push(token.name)
            }
          }
        }
      } else if token.kind == @tag.TagKind::Close {
        if !line.line_level[ti] && !current.is_empty() && !line.matches.is_empty() {
          let mut k = ti - 1
          while k >= 0 {
            if line.matches[k] == ti {
              if attr_of(line.toks[k].name) == 0 {
                ignore(current.pop())
              }
              break
            }
            k -= 1
          }
        }
      }
    }
  }
  out
}
