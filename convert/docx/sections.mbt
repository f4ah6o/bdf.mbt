///|
// Basic section geometry used by the document layout stage. Additional
// section features (columns, headers, footers and grids) are handled later.
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
    _ => ()
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
  let mut seen_size = false
  let mut seen_margins = false
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
          seen_size = false
          seen_margins = false
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
          let take = if name == "pgSz" && !seen_size {
            seen_size = true
            true
          } else if name == "pgMar" && !seen_margins {
            seen_margins = true
            true
          } else {
            false
          }
          if take {
            match section {
              Some(current) => docx_section_element(current, element)
              None => ()
            }
          }
        }
        if event.kind is Start(_) {
          path.push(name)
        }
      }
      End(_) => {
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
