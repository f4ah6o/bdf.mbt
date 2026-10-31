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
