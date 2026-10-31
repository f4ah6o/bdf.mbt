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
  let bytes = package.read(part)
  let content = @utf8.decode_lossy(bytes[:], ignore_bom=true)
  if content.contains("<!ENTITY") {
    raise InvalidPptx("OOXML part declares entities")
  }
  let reader = @xml.NamespaceReader::from_string(content)
  let path : Array[String] = []
  let result : Array[PptxPlaceholder] = []
  let mut csld_seen = false
  let mut tree_seen = false
  let mut csld_depth = -1
  let mut tree_depth = -1
  let mut shape_depth = -1
  let mut nv_depth = -1
  let mut nvpr_depth = -1
  let mut nv_rank = -1
  let mut nvpr_seen = false
  let mut ph_seen = false
  let seen_nv : Map[String, Bool] = Map([])
  let mut best_rank = 10
  let mut best : PptxPlaceholder? = None
  while true {
    let event = reader.read_event()
    match event.kind {
      Start(element) | Empty(element) => {
        let name = element.name.local_name
        let depth = path.length()
        if depth == 1 && name == "cSld" && !csld_seen {
          csld_seen = true
          if event.kind is Start(_) {
            csld_depth = depth + 1
          }
        } else if depth == csld_depth && name == "spTree" && !tree_seen {
          tree_seen = true
          if event.kind is Start(_) {
            tree_depth = depth + 1
          }
        } else if depth == tree_depth {
          seen_nv.clear()
          best_rank = 10
          best = None
          if event.kind is Start(_) {
            shape_depth = depth + 1
          }
        } else if depth == shape_depth {
          let rank = match name {
            "nvSpPr" => 0
            "nvPicPr" => 1
            "nvGraphicFramePr" => 2
            "nvGrpSpPr" => 3
            "nvCxnSpPr" => 4
            _ => -1
          }
          if rank >= 0 && !seen_nv.contains(name) {
            seen_nv[name] = true
            nv_rank = rank
            nvpr_seen = false
            ph_seen = false
            if event.kind is Start(_) {
              nv_depth = depth + 1
            }
          }
        } else if depth == nv_depth && name == "nvPr" && !nvpr_seen {
          nvpr_seen = true
          if event.kind is Start(_) {
            nvpr_depth = depth + 1
          }
        } else if depth == nvpr_depth && name == "ph" && !ph_seen {
          ph_seen = true
          if nv_rank < best_rank {
            best_rank = nv_rank
            best = Some({
              kind: pptx_attribute(element, "type", "obj"),
              index: pptx_placeholder_attribute(element, "idx"),
            })
          }
        }
        if event.kind is Start(_) {
          path.push(name)
        }
      }
      End(_) => {
        if path.length() == nvpr_depth {
          nvpr_depth = -1
        }
        if path.length() == nv_depth {
          nv_depth = -1
          nv_rank = -1
        }
        if path.length() == shape_depth {
          match best {
            Some(ph) => result.push(ph)
            None => ()
          }
          shape_depth = -1
        }
        if path.length() == tree_depth {
          tree_depth = -1
        }
        if path.length() == csld_depth {
          csld_depth = -1
        }
        ignore(path.pop())
      }
      Eof => break
      _ => ()
    }
  }
  result
}
