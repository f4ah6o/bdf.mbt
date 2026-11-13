///|
// Preserve externally addressed DrawingML click links without fetching them.
// Resolve internal links in the context of the selected output pages.
// External targets follow the upstream URL scheme allowlist.
fn pptx_shape_link_target(
  ctx : PptxShapeContext,
  part : String,
  shape : PptxXmlNode,
) -> String {
  let click = match pptx_child(pptx_shape_cnpr(shape), "hlinkClick") {
    Some(node) => node
    None => return ""
  }
  let action = pptx_attribute(click.element, "action", "")
  if action.has_prefix("ppaction://hlinkshowjump") {
    let page = if action.contains("nextslide") {
      ctx.link_page + 1
    } else if action.contains("previousslide") {
      ctx.link_page - 1
    } else if action.contains("firstslide") {
      1
    } else if action.contains("lastslide") {
      ctx.link_page_count
    } else {
      0
    }
    if page < 1 || page > ctx.link_page_count {
      return ""
    }
    return "#page=" + page.to_string()
  }
  let mut id = ""
  for attr in click.element.attributes {
    if attr.name.local_name == "id" &&
      attr.name.namespace_uri.unwrap_or("").has_suffix("relationships") {
      id = attr.value
      break
    }
  }
  if id == "" {
    return ""
  }
  for rel in ctx.package.relationships(part) {
    if rel.id == id && !rel.external && rel.kind.has_suffix("/slide") {
      return match ctx.link_pages.get(rel.target) {
        Some(page) => "#page=" + page.to_string()
        None => ""
      }
    }
    if rel.id == id && rel.external {
      let target = rel.target
      if !(target.has_prefix("http:") ||
        target.has_prefix("https:") ||
        target.has_prefix("mailto:")) {
        return ""
      }
      // Reject controls, spaces and invalid percent escapes. This is not a
      // complete implementation of Go's URL parser.
      let bytes = @utf8.encode(target)
      let mut i = 0
      while i < bytes.length() {
        let c = bytes[i].to_int()
        if c <= 32 || c == 127 {
          return ""
        }
        if c == 37 {
          if i + 2 >= bytes.length() ||
            !pptx_link_hex(bytes[i + 1]) ||
            !pptx_link_hex(bytes[i + 2]) {
            return ""
          }
          i += 2
        }
        i += 1
      }
      return target
    }
  }
  ""
}

///|
fn pptx_link_hex(c : Byte) -> Bool {
  (c >= b'0' && c <= b'9') ||
  (c >= b'a' && c <= b'f') ||
  (c >= b'A' && c <= b'F')
}

///|
// Link rectangles are axis-aligned bounds of the rotated shape. The center
// and angle match the existing shape and picture rendering transform.
fn pptx_emit_shape_link(
  ctx : PptxShapeContext,
  part : String,
  object : @core.ObjectBuilder,
  shape : PptxXmlNode,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  rotation : Double,
  cx : Double,
  cy : Double,
) -> Unit {
  let target = pptx_shape_link_target(ctx, part, shape)
  if target == "" {
    return
  }
  let radians = rotation * 3.141592653589793 / 180.0
  let sine = @math.sin(radians)
  let cosine = @math.cos(radians)
  let mut min_x = 1.0e100
  let mut min_y = 1.0e100
  let mut max_x = -1.0e100
  let mut max_y = -1.0e100
  for
    (px, py) in [
      (x, y),
      (x + width, y),
      (x, y + height),
      (x + width, y + height),
    ] {
    let dx = px - cx
    let dy = py - cy
    let rx = cx + dx * cosine - dy * sine
    let ry = cy + dx * sine + dy * cosine
    min_x = @math.minimum(min_x, rx)
    min_y = @math.minimum(min_y, ry)
    max_x = @math.maximum(max_x, rx)
    max_y = @math.maximum(max_y, ry)
  }
  object.link(
    Float::from_double(min_x),
    Float::from_double(min_y),
    Float::from_double(max_x - min_x),
    Float::from_double(max_y - min_y),
    target,
  )
}
