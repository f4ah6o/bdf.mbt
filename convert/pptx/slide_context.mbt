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
  let root = pptx_read_xml(package, part)
  let value = pptx_trim(pptx_attribute(root.element, "showMasterSp", ""))
  let show = value != "0" && value != "false" && value != "off"
  let source = if master {
    pptx_child(Some(root), "clrMap")
  } else {
    pptx_child(pptx_child(Some(root), "clrMapOvr"), "overrideClrMapping")
  }
  let colors : Array[(String, String)] = []
  match source {
    Some(node) =>
      for attr in node.element.attributes {
        colors.push((attr.name.local_name, attr.value))
      }
    None => ()
  }
  (show, colors)
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
