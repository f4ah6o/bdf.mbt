///|
// A SmartArt frame carries only a relationship to its diagram data model. The
// model's text is a reasonable fallback until the diagram layout is drawn.
fn pptx_smartart_data_id(shape : PptxXmlNode) -> String {
  let graphic = pptx_child(Some(shape), "graphic")
  let data = match graphic {
    Some(value) => pptx_child(Some(value), "graphicData")
    None => None
  }
  match data {
    Some(value) =>
      match pptx_child(Some(value), "relIds") {
        Some(rel_ids) => pptx_attribute_any(rel_ids.element, "dm", "")
        None => ""
      }
    None => ""
  }
}

///|
fn pptx_collect_diagram_text(
  node : PptxXmlNode,
  texts : Array[String],
) -> Unit {
  if node.element.name.local_name == "t" {
    let text = node.text.to_string().trim().to_string()
    if text != "" {
      texts.push(text)
    }
  }
  for child in node.children {
    pptx_collect_diagram_text(child, texts)
  }
}

///|
fn pptx_smartart_texts(
  package : @ooxml.OoxmlPackage,
  part : String,
  data_id : String,
) -> Array[String] raise {
  let mut target = ""
  let mut external = false
  for rel in package.relationships(part) {
    if rel.id == data_id {
      target = rel.target
      external = rel.external
    }
  }
  if target == "" || external {
    return []
  }
  let root = pptx_read_xml(package, target) catch { _ => return [] }
  let texts : Array[String] = []
  pptx_collect_diagram_text(root, texts)
  texts
}

///|
fn pptx_emit_smartart(
  shape : PptxXmlNode,
  package : @ooxml.OoxmlPackage,
  part : String,
  object : @core.ObjectBuilder,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
) -> Bool raise {
  let data_id = pptx_smartart_data_id(shape)
  if data_id == "" {
    return false
  }
  let texts = pptx_smartart_texts(package, part, data_id)
  if texts.is_empty() {
    return false
  }
  let font = object.add_font({
    hash: None,
    family: "sans-serif",
    weight: 400,
    style: 0,
  })
  let line_height = Double::min(
    18.0,
    Double::max(height / texts.length().to_double(), 8.0),
  )
  let size = Double::min(12.0, line_height * 0.7)
  for index, text in texts {
    pptx_chart_label(
      object,
      font,
      size,
      0x000000ffU,
      text,
      x + 6.0,
      y + 6.0 + line_height * index.to_double(),
    )
  }
  ignore(width)
  true
}
