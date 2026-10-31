///|
// Section geometry, columns, text grid, and story references for document layout.
priv struct DocxSection {
  mut width : Double
  mut height : Double
  mut top : Double
  mut bottom : Double
  mut left : Double
  mut right : Double
  mut header : Double
  mut footer : Double
  mut top_exact : Bool
  mut bottom_exact : Bool
  mut section_type : String
  mut title_page : Bool
  mut page_start : Int64
  mut page_format : String
  mut grid_type : String
  mut line_pitch : Double
  mut char_space : Double
  mut vertical : Bool
  mut column_sep : Bool
  mut column_count : Int32
  mut column_space : Double
  mut equal_width : Bool
  raw_columns : Array[(String, String)]
  columns : Array[(Double, Double)]
  headers : Array[(String, String)]
  footers : Array[(String, String)]
} derive(Debug, Eq)

///|
priv suberror DocxError {
  InvalidDocx(String)
}

///|
fn docx_attribute(
  element : @xml.NamespaceElement,
  name : String,
  default : String,
) -> String {
  for attr in element.attributes {
    if attr.name.local_name == name &&
      (match attr.name.namespace_uri {
        Some(uri) => !uri.has_suffix("relationships")
        None => true
      }) {
      return attr.value
    }
  }
  default
}

///|
fn docx_has_attribute(element : @xml.NamespaceElement, name : String) -> Bool {
  for attr in element.attributes {
    if attr.name.local_name == name &&
      (match attr.name.namespace_uri {
        Some(uri) => !uri.has_suffix("relationships")
        None => true
      }) {
      return true
    }
  }
  false
}

///|
fn docx_measure(value : String, default : Double) -> Double {
  let value = value.trim().to_owned()
  for
    (suffix, factor) in [
      ("pt", 1.0),
      ("in", 72.0),
      ("cm", 72.0 / 2.54),
      ("mm", 72.0 / 25.4),
      ("pc", 12.0),
      ("pi", 12.0),
    ] {
    if value.has_suffix(suffix) {
      let num = value[:value.length() - suffix.length()]
      return (@string.parse_double(num) * factor) catch { _ => default }
    }
  }
  (@string.parse_double(value) / 20.0) catch {
    _ => default
  }
}

///|
fn docx_new_section(previous : DocxSection?) -> DocxSection {
  let (width, height) = match previous {
    Some(section) => (section.width, section.height)
    None => (612.0, 792.0)
  }
  {
    width,
    height,
    top: 72.0,
    bottom: 72.0,
    left: 72.0,
    right: 72.0,
    header: 36.0,
    footer: 36.0,
    top_exact: false,
    bottom_exact: false,
    section_type: "nextPage",
    title_page: false,
    page_start: -1L,
    page_format: "decimal",
    grid_type: "",
    line_pitch: 0.0,
    char_space: 0.0,
    vertical: false,
    column_sep: false,
    column_count: 1,
    column_space: 36.0,
    equal_width: true,
    raw_columns: [],
    columns: [],
    headers: [],
    footers: [],
  }
}

///|
fn DocxSection::finish(self : DocxSection) -> Unit {
  if self.top < 0.0 {
    self.top = -self.top
    self.top_exact = true
  }
  if self.bottom < 0.0 {
    self.bottom = -self.bottom
    self.bottom_exact = true
  }
  self.width = Double::max(72.0, self.width)
  self.height = Double::max(72.0, self.height)
  let length = if self.vertical {
    Double::max(self.height - self.top - self.bottom, 36.0)
  } else {
    Double::max(self.width - self.left - self.right, 36.0)
  }
  self.columns.clear()
  if !self.raw_columns.is_empty() && !self.equal_width {
    let default_width = length / self.raw_columns.length().to_double()
    let mut x = 0.0
    for (width, space) in self.raw_columns {
      let w = docx_measure(width, default_width)
      self.columns.push((x, w))
      x += w + docx_measure(space, 0.0)
    }
  } else if self.column_count > 1 && self.column_count <= 45 {
    let count = self.column_count.to_double()
    let w = (length - (count - 1.0) * self.column_space) / count
    if w > 18.0 {
      for i in 0..<self.column_count {
        self.columns.push((i.to_double() * (w + self.column_space), w))
      }
    }
  }
  if self.columns.is_empty() {
    self.columns.push((0.0, length))
  }
}

///|
fn docx_section_element(
  section : DocxSection,
  element : @xml.NamespaceElement,
) -> Unit {
  match element.name.local_name {
    "pgSz" => {
      section.width = docx_measure(
        docx_attribute(element, "w", ""),
        section.width,
      )
      section.height = docx_measure(
        docx_attribute(element, "h", ""),
        section.height,
      )
    }
    "pgMar" => {
      section.top = docx_measure(docx_attribute(element, "top", ""), 72.0)
      section.bottom = docx_measure(docx_attribute(element, "bottom", ""), 72.0)
      section.left = docx_measure(docx_attribute(element, "left", ""), 72.0) +
        docx_measure(docx_attribute(element, "gutter", ""), 0.0)
      section.right = docx_measure(docx_attribute(element, "right", ""), 72.0)
      section.header = docx_measure(docx_attribute(element, "header", ""), 36.0)
      section.footer = docx_measure(docx_attribute(element, "footer", ""), 36.0)
    }
    "type" => section.section_type = docx_attribute(element, "val", "nextPage")
    "titlePg" => section.title_page = docx_bool(element, "val", true)
    "pgNumType" => {
      let start = docx_attribute(element, "start", "")
      if docx_has_attribute(element, "start") {
        section.page_start = docx_number(start, 1.0).to_int64()
      }
      section.page_format = docx_attribute(element, "fmt", "decimal")
    }
    "docGrid" => {
      section.grid_type = docx_attribute(element, "type", "default")
      section.line_pitch = docx_measure(
        docx_attribute(element, "linePitch", ""),
        0.0,
      )
      section.char_space = docx_number(
          docx_attribute(element, "charSpace", ""),
          0.0,
        ) /
        4096.0
    }
    "textDirection" => {
      let value = docx_attribute(element, "val", "")
      section.vertical = value == "tbRl" || value == "tbRlV" || value == "tbLrV"
    }
    "cols" => {
      section.column_count = docx_number(
        docx_attribute(element, "num", ""),
        1.0,
      ).to_int()
      section.column_space = docx_measure(
        docx_attribute(element, "space", ""),
        36.0,
      )
      section.column_sep = docx_bool(element, "sep", false)
      section.equal_width = docx_bool(element, "equalWidth", true)
    }
    _ => ()
  }
}

///|
fn docx_number(value : String, default : Double) -> Double {
  @string.parse_double(value.trim()) catch {
    _ => default
  }
}

///|
fn docx_bool(
  element : @xml.NamespaceElement,
  key : String,
  default : Bool,
) -> Bool {
  match docx_attribute(element, key, "").trim() {
    "1" | "true" | "on" => true
    "0" | "false" | "off" => false
    _ => default
  }
}

///|
fn docx_add_story_reference(
  section : DocxSection,
  package : @ooxml.OoxmlPackage,
  part : String,
  element : @xml.NamespaceElement,
  header : Bool,
) -> Unit {
  let mut id = ""
  for attr in element.attributes {
    if attr.name.local_name == "id" &&
      (match attr.name.namespace_uri {
        Some(uri) => uri.has_suffix("relationships")
        None => false
      }) {
      id = attr.value
      break
    }
  }
  match package.target(part, id) {
    Some(rel) => {
      let kind = docx_attribute(element, "type", "default")
      let stories = if header { section.headers } else { section.footers }
      for i in 0..<stories.length() {
        if stories[i].0 == kind {
          stories[i] = (kind, rel.target)
          return
        }
      }
      stories.push((kind, rel.target))
    }
    None => ()
  }
}

///|
fn docx_sections(data : Bytes) -> (String, Array[DocxSection]) raise {
  let package = @ooxml.open_ooxml(data)
  let part = match package.relationship_of_type("", "/officeDocument") {
    Some(rel) => rel.target
    None => "word/document.xml"
  }
  let xml = package.read(part)
  let text = @utf8.decode_lossy(xml[:], ignore_bom=true)
  if text.contains("<!ENTITY") {
    raise InvalidDocx("OOXML part declares entities")
  }
  let reader = @xml.NamespaceReader::from_string(text)
  let path : Array[String] = []
  let sections : Array[DocxSection] = []
  let mut section : DocxSection? = None
  let mut section_depth = -1
  let mut final_found = false
  let seen : Map[String, Bool] = Map([])
  let mut column_depth = -1
  let mut read_columns = false
  while true {
    let event = reader.read_event()
    match event.kind {
      Start(element) | Empty(element) => {
        let name = element.name.local_name
        let depth = path.length()
        let is_final = depth == 2 &&
          path[1] == "body" &&
          name == "sectPr" &&
          !final_found
        let is_para = depth == 4 &&
          path[1] == "body" &&
          path[2] == "p" &&
          path[3] == "pPr" &&
          name == "sectPr"
        if is_final || is_para {
          seen.clear()
          column_depth = -1
          read_columns = false
          let previous = if sections.is_empty() {
            None
          } else {
            Some(sections[sections.length() - 1])
          }
          let current = docx_new_section(previous)
          if is_final {
            final_found = true
          }
          if event.kind is Empty(_) {
            current.finish()
            sections.push(current)
          } else {
            section = Some(current)
            section_depth = depth + 1
          }
        } else if depth == section_depth {
          if name == "headerReference" || name == "footerReference" {
            match section {
              Some(current) =>
                docx_add_story_reference(
                  current,
                  package,
                  part,
                  element,
                  name == "headerReference",
                )
              None => ()
            }
          }
          let take = !seen.contains(name)
          if take {
            seen[name] = true
          }
          if name == "cols" {
            read_columns = take
            column_depth = if event.kind is Start(_) { depth + 1 } else { -1 }
          }
          if take {
            match section {
              Some(current) => docx_section_element(current, element)
              None => ()
            }
          }
        } else if depth == column_depth && name == "col" && read_columns {
          match section {
            Some(current) =>
              current.raw_columns.push(
                (
                  docx_attribute(element, "w", ""),
                  docx_attribute(element, "space", ""),
                ),
              )
            None => ()
          }
        }
        if event.kind is Start(_) {
          path.push(name)
        }
      }
      End(_) => {
        if path.length() == column_depth {
          column_depth = -1
          read_columns = false
        }
        if path.length() == section_depth {
          match section {
            Some(current) => {
              current.finish()
              sections.push(current)
            }
            None => ()
          }
          section = None
          section_depth = -1
        }
        ignore(path.pop())
      }
      Eof => break
      _ => ()
    }
  }
  if !final_found {
    let previous = if sections.is_empty() {
      None
    } else {
      Some(sections[sections.length() - 1])
    }
    let current = docx_new_section(previous)
    current.finish()
    sections.push(current)
  }
  (part, sections)
}
