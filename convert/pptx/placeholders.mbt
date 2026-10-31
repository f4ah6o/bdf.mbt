///|
// Identity of a slide, layout, or master placeholder.
priv struct PptxPlaceholder {
  kind : String
  index : String?
} derive(Debug, Eq)

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
