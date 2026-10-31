///|
// Presentation metadata used by the eventual slide renderer.
priv suberror PptxError {
  InvalidPptx(String)
}

///|
priv struct PptxPresentation {
  part : String
  width : Double
  height : Double
  first_slide : Int64
  slides : Array[PptxSlide]
}

///|
priv struct PptxSlide {
  part : String
  hidden : Bool
} derive(Debug, Eq)

///|
fn pptx_attribute(
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
fn pptx_trim(value : String) -> String {
  value.trim().to_owned()
}

///|
fn pptx_measure(value : String, default : Double) -> Double {
  let value = pptx_trim(value)
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
  (@string.parse_double(value) / 12700.0) catch {
    _ => default
  }
}

///|
fn pptx_hidden(package : @ooxml.OoxmlPackage, part : String) -> Bool {
  let bytes = package.read(part) catch { _ => return false }
  let text = @utf8.decode_lossy(bytes[:], ignore_bom=true)
  if text.contains("<!ENTITY") {
    return false
  }
  let reader = @xml.NamespaceReader::from_string(text)
  let mut seen = false
  let mut hidden = false
  while true {
    let event = reader.read_event() catch { _ => return false }
    match event.kind {
      Start(element) | Empty(element) =>
        if !seen {
          seen = true
          hidden = ["0", "false", "off"].contains(
            pptx_trim(pptx_attribute(element, "show", "")),
          )
        }
      Eof => return hidden
      _ => ()
    }
  }
  false
}

///|
fn pptx_presentation(data : Bytes) -> PptxPresentation raise {
  let package = @ooxml.open_ooxml(data)
  let part = match package.relationship_of_type("", "/officeDocument") {
    Some(rel) => rel.target
    None => "ppt/presentation.xml"
  }
  let root = pptx_read_xml(package, part)
  let first_slide = pptx_int64(
    pptx_attribute(root.element, "firstSlideNum", "1"),
    1L,
  )
  let (width, height) = match pptx_child(Some(root), "sldSz") {
    Some(size) =>
      (
        pptx_measure(pptx_attribute(size.element, "cx", ""), 720.0),
        pptx_measure(pptx_attribute(size.element, "cy", ""), 540.0),
      )
    None => (720.0, 540.0)
  }
  let slides : Array[PptxSlide] = []
  let list = pptx_child(Some(root), "sldIdLst")
  for slide in pptx_children(list) {
    if slide.element.name.local_name != "sldId" {
      continue
    }
    let mut id = ""
    for attr in slide.element.attributes {
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
      Some(rel) =>
        slides.push({
          part: rel.target,
          hidden: pptx_hidden(package, rel.target),
        })
      None => ()
    }
  }
  let (width, height) = if width <= 0.0 ||
    height <= 0.0 ||
    width > 20000.0 ||
    height > 20000.0 {
    (720.0, 540.0)
  } else {
    (width, height)
  }
  { part, width, height, first_slide, slides, }
}
