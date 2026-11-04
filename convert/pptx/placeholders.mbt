///|
// Identity of a slide, layout, or master placeholder.
#derive(Debug, Eq)
priv struct PptxPlaceholder {
  kind : String
  index : String?
}

///|
fn pptx_master_placeholder_type(kind : String) -> String {
  match kind {
    "ctrTitle" | "title" => "title"
    "dt" | "ftr" | "sldNum" | "hdr" => kind
    _ => "body"
  }
}

///|
// Return the first matching layout or master placeholder, or -1.
fn pptx_find_placeholder(
  list : Array[PptxPlaceholder],
  placeholder : PptxPlaceholder,
  master : Bool,
) -> Int32 {
  if master {
    let kind = pptx_master_placeholder_type(placeholder.kind)
    for i in 0..<list.length() {
      if list[i].kind == kind {
        return i
      }
    }
    return -1
  }
  match placeholder.index {
    Some(index) =>
      for i in 0..<list.length() {
        if list[i].index == Some(index) {
          return i
        }
      }
    None => ()
  }
  for i in 0..<list.length() {
    if list[i].kind == placeholder.kind {
      return i
    }
  }
  if placeholder.kind == "title" || placeholder.kind == "ctrTitle" {
    for i in 0..<list.length() {
      if list[i].kind == "title" || list[i].kind == "ctrTitle" {
        return i
      }
    }
  }
  -1
}

///|
fn pptx_placeholder_attribute(
  element : @xml.NamespaceElement,
  key : String,
) -> String? {
  for attr in element.attributes {
    if attr.name.local_name == key &&
      (match attr.name.namespace_uri {
        Some(uri) => !uri.has_suffix("relationships")
        None => true
      }) {
      return Some(attr.value)
    }
  }
  None
}

///|
// Read the direct shape placeholders in a slide, layout, or master.
fn pptx_placeholders(
  package : @ooxml.OoxmlPackage,
  part : String,
) -> Array[PptxPlaceholder] raise {
  let root = pptx_read_xml(package, part)
  let tree = pptx_child(pptx_child(Some(root), "cSld"), "spTree")
  let result : Array[PptxPlaceholder] = []
  for shape in pptx_children(tree) {
    for
      name in [
        "nvSpPr", "nvPicPr", "nvGraphicFramePr", "nvGrpSpPr", "nvCxnSpPr",
      ] {
      let ph = pptx_child(
        pptx_child(pptx_child(Some(shape), name), "nvPr"),
        "ph",
      )
      match ph {
        Some(value) => {
          result.push({
            kind: pptx_attribute(value.element, "type", "obj"),
            index: pptx_placeholder_attribute(value.element, "idx"),
          })
          break
        }
        None => ()
      }
    }
  }
  result
}

///|
// The p:ph element of a shape, or nil.
fn pptx_placeholder_element(shape : PptxXmlNode) -> PptxXmlNode? {
  for
    name in ["nvSpPr", "nvPicPr", "nvGraphicFramePr", "nvGrpSpPr", "nvCxnSpPr"] {
    match pptx_child(pptx_child(pptx_child(Some(shape), name), "nvPr"), "ph") {
      Some(value) => return Some(value)
      None => ()
    }
  }
  None
}

///|
// The placeholder identity of a shape, or nil when it is not a placeholder.
fn pptx_placeholder_info(shape : PptxXmlNode) -> PptxPlaceholder? {
  match pptx_placeholder_element(shape) {
    Some(value) =>
      Some({
        kind: pptx_attribute(value.element, "type", "obj"),
        index: pptx_placeholder_attribute(value.element, "idx"),
      })
    None => None
  }
}

///|
// The direct placeholder shapes of a layout or master, in tree order.
fn pptx_placeholder_shapes(root : PptxXmlNode) -> Array[PptxXmlNode] {
  let out : Array[PptxXmlNode] = []
  let tree = pptx_child(pptx_child(Some(root), "cSld"), "spTree")
  for shape in pptx_children(tree) {
    if pptx_placeholder_element(shape) is Some(_) {
      out.push(shape)
    }
  }
  out
}

///|
// Find the layout or master placeholder a placeholder inherits from.
fn pptx_find_placeholder_shape(
  list : Array[PptxXmlNode],
  placeholder : PptxPlaceholder,
  master : Bool,
) -> PptxXmlNode? {
  for i in 0..<list.length() {
    match pptx_placeholder_info(list[i]) {
      Some(info) => {
        // match an entry of the list against the identity of placeholder
        let matches = if master {
          info.kind == pptx_master_placeholder_type(placeholder.kind)
        } else {
          match placeholder.index {
            Some(index) => info.index == Some(index)
            None => info.kind == placeholder.kind
          }
        }
        if matches {
          return Some(list[i])
        }
      }
      None => ()
    }
  }
  if !master && (placeholder.kind == "title" || placeholder.kind == "ctrTitle") {
    for shape in list {
      match pptx_placeholder_info(shape) {
        Some(info) =>
          if info.kind == "title" || info.kind == "ctrTitle" {
            return Some(shape)
          }
        None => ()
      }
    }
  }
  None
}

///|
// The layout and master placeholders a shape inherits properties from,
// most specific first: its layout placeholder and that placeholder's master
// counterpart.
fn pptx_shape_inheritance(
  ctx : PptxShapeContext,
  shape : PptxXmlNode,
) -> Array[PptxXmlNode] {
  let out : Array[PptxXmlNode] = []
  match pptx_placeholder_info(shape) {
    Some(info) => {
      let mut master_info = info
      match pptx_find_placeholder_shape(ctx.layout_placeholders, info, false) {
        Some(value) => {
          out.push(value)
          match pptx_placeholder_info(value) {
            Some(layout_info) => master_info = layout_info
            None => ()
          }
        }
        None => ()
      }
      match
        pptx_find_placeholder_shape(ctx.master_placeholders, master_info, true) {
        Some(value) => out.push(value)
        None => ()
      }
    }
    None => ()
  }
  out
}
