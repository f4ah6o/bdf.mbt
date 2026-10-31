///|
// The sources of the master layers used when rendering a slide.
priv struct PptxSlideContext {
  layout_part : String
  master_part : String
  draw_layout : Bool
  draw_master : Bool
} derive(Debug, Eq)

///|
fn pptx_master_shapes(
  package : @ooxml.OoxmlPackage,
  part : String,
) -> Bool raise {
  let bytes = package.read(part)
  let content = @utf8.decode_lossy(bytes[:], ignore_bom=true)
  if content.contains("<!ENTITY") {
    raise InvalidPptx("OOXML part declares entities")
  }
  let reader = @xml.NamespaceReader::from_string(content)
  let mut root = false
  let mut result = true
  while true {
    let event = reader.read_event()
    match event.kind {
      Start(element) | Empty(element) =>
        if !root {
          root = true
          let value = pptx_trim(pptx_attribute(element, "showMasterSp", ""))
          if value == "0" || value == "false" || value == "off" {
            result = false
          }
        }
      Eof => break
      _ => ()
    }
  }
  if !root {
    raise InvalidPptx("empty slide XML")
  }
  result
}

///|
fn pptx_slide_context(
  package : @ooxml.OoxmlPackage,
  part : String,
) -> PptxSlideContext raise {
  let show = pptx_master_shapes(package, part)
  let mut layout_part = ""
  let mut master_part = ""
  let mut layout_ok = false
  let mut master_ok = false
  let mut layout_show = true
  match package.relationship_of_type(part, "/slideLayout") {
    Some(rel) => {
      layout_part = rel.target
      match
        (Some(pptx_master_shapes(package, layout_part)) catch { _ => None }) {
        Some(value) => {
          layout_ok = true
          layout_show = value
          match package.relationship_of_type(layout_part, "/slideMaster") {
            Some(master) => {
              master_part = master.target
              master_ok = (Some(pptx_master_shapes(package, master_part)) catch {
                  _ => None
                })
                is Some(_)
            }
            None => ()
          }
        }
        None => ()
      }
    }
    None => ()
  }
  {
    layout_part,
    master_part,
    draw_layout: show && layout_ok,
    draw_master: show && layout_ok && layout_show && master_ok,
  }
}
