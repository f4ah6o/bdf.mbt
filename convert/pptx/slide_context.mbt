///|
// The sources of the master layers used when rendering a slide.
priv struct PptxSlideContext {
  layout_part : String
  master_part : String
  draw_layout : Bool
  draw_master : Bool
  color_map : Array[(String, String)]
} derive(Debug, Eq)

///|
fn pptx_read_slide_source(
  package : @ooxml.OoxmlPackage,
  part : String,
  master : Bool,
) -> (Bool, Array[(String, String)]) raise {
  let bytes = package.read(part)
  let content = @utf8.decode_lossy(bytes[:], ignore_bom=true)
  if content.contains("<!ENTITY") {
    raise InvalidPptx("OOXML part declares entities")
  }
  let reader = @xml.NamespaceReader::from_string(content)
  let mut root = false
  let mut result = true
  let path : Array[String] = []
  let colors : Array[(String, String)] = []
  let mut found = false
  let mut parent_seen = false
  let mut parent_depth = -1
  while true {
    let event = reader.read_event()
    match event.kind {
      Start(element) | Empty(element) => {
        let name = element.name.local_name
        if !root {
          root = true
          let value = pptx_trim(pptx_attribute(element, "showMasterSp", ""))
          if value == "0" || value == "false" || value == "off" {
            result = false
          }
        }
        if !master && path.length() == 1 && name == "clrMapOvr" {
          if !parent_seen && event.kind is Start(_) {
            parent_depth = 2
          }
          parent_seen = true
        }
        let selected = if master {
          path.length() == 1 && name == "clrMap"
        } else {
          path.length() == parent_depth && name == "overrideClrMapping"
        }
        if selected && !found {
          found = true
          for attr in element.attributes {
            colors.push((attr.name.local_name, attr.value))
          }
        }
        if event.kind is Start(_) {
          path.push(name)
        }
      }
      End(_) => {
        if path.length() == parent_depth {
          parent_depth = -1
        }
        ignore(path.pop())
      }
      Eof => break
      _ => ()
    }
  }
  if !root {
    raise InvalidPptx("empty slide XML")
  }
  (result, colors)
}

///|
fn pptx_slide_context(
  package : @ooxml.OoxmlPackage,
  part : String,
) -> PptxSlideContext raise {
  let (show, slide_colors) = pptx_read_slide_source(package, part, false)
  let layout_colors : Array[(String, String)] = []
  let master_colors : Array[(String, String)] = []
  let mut layout_part = ""
  let mut master_part = ""
  let mut layout_ok = false
  let mut master_ok = false
  let mut layout_show = true
  match package.relationship_of_type(part, "/slideLayout") {
    Some(rel) => {
      layout_part = rel.target
      match
        (Some(pptx_read_slide_source(package, layout_part, false)) catch {
          _ => None
        }) {
        Some((value, colors)) => {
          layout_ok = true
          layout_show = value
          for color in colors {
            layout_colors.push(color)
          }
          match package.relationship_of_type(layout_part, "/slideMaster") {
            Some(master) => {
              master_part = master.target
              match
                (Some(pptx_read_slide_source(package, master_part, true)) catch {
                  _ => None
                }) {
                Some((_, colors)) => {
                  master_ok = true
                  for color in colors {
                    master_colors.push(color)
                  }
                }
                None => ()
              }
            }
            None => ()
          }
        }
        None => ()
      }
    }
    None => ()
  }
  let color_map : Array[(String, String)] = []
  for source in [master_colors, layout_colors, slide_colors] {
    for (key, value) in source {
      let mut replaced = false
      for i in 0..<color_map.length() {
        if color_map[i].0 == key {
          color_map[i] = (key, value)
          replaced = true
          break
        }
      }
      if !replaced {
        color_map.push((key, value))
      }
    }
  }
  {
    layout_part,
    master_part,
    color_map,
    draw_layout: show && layout_ok,
    draw_master: show && layout_ok && layout_show && master_ok,
  }
}
