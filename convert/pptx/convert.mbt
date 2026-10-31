///|
pub suberror PptxConvertError {
  PptxInvalid(String)
}

///|
pub(all) struct PptxResult {
  bdf : Bytes
  pages : Int32
  summary : String
  warnings : Array[String]
}

///|
priv struct PptxLineItem {
  text : String
  weight : Int32
  style : Int32
  size : Double
  color : UInt32
  x : Double
  advance : Double
}

///|
fn pptx_hex_color(value : String) -> UInt32 {
  let text = value.trim().to_owned()
  if text.length() != 6 {
    return 0x000000ffU
  }
  let mut result = 0U
  for c in text {
    let digit = match c {
      '0'..<='9' => c.to_int() - '0'.to_int()
      'a'..<='f' => c.to_int() - 'a'.to_int() + 10
      'A'..<='F' => c.to_int() - 'A'.to_int() + 10
      _ => return 0x000000ffU
    }
    result = result * 16U + digit.reinterpret_as_uint()
  }
  (result << 8) | 0xffU
}

///|
fn pptx_node_color(node : PptxXmlNode?, key : String) -> UInt32? {
  let color = pptx_child(pptx_child(node, key), "srgbClr")
  match color {
    Some(value) =>
      match pptx_attribute(value.element, "val", "") {
        "" => None
        hex => Some(pptx_hex_color(hex))
      }
    None => None
  }
}

///|
fn pptx_run_size(run : PptxXmlNode) -> Double {
  let rpr = pptx_child(Some(run), "rPr")
  match rpr {
    Some(value) =>
      match pptx_attribute(value.element, "sz", "") {
        "" => 18.0
        text => (@string.parse_double(text) / 100.0) catch { _ => 18.0 }
      }
    None => 18.0
  }
}

///|
fn pptx_run_bold(run : PptxXmlNode) -> Bool {
  let rpr = pptx_child(Some(run), "rPr")
  match rpr {
    Some(value) => pptx_bool(value.element, "b", false)
    None => false
  }
}

///|
fn pptx_run_italic(run : PptxXmlNode) -> Bool {
  let rpr = pptx_child(Some(run), "rPr")
  match rpr {
    Some(value) => pptx_bool(value.element, "i", false)
    None => false
  }
}

///|
fn pptx_run_color(run : PptxXmlNode) -> UInt32 {
  let rpr = pptx_child(Some(run), "rPr")
  match pptx_node_color(rpr, "solidFill") {
    Some(value) => value
    None => 0x000000ffU
  }
}

///|
fn pptx_char_width(c : Char, size : Double) -> Double {
  let code = c.to_int()
  if c == ' ' {
    size * 0.25
  } else if code >= 0x2e80 {
    size
  } else {
    size * 0.5
  }
}

///|
fn pptx_text_width(text : String, size : Double) -> Double {
  let mut width = 0.0
  for c in text {
    width += pptx_char_width(c, size)
  }
  width
}

///|
fn pptx_attribute_any(
  element : @xml.NamespaceElement,
  name : String,
  default : String,
) -> String {
  for attr in element.attributes {
    if attr.name.local_name == name {
      return attr.value
    }
  }
  default
}

///|
fn pptx_collect_shapes(
  node : PptxXmlNode,
  offset_x : Double,
  offset_y : Double,
  out : Array[(PptxXmlNode, Double, Double)],
) -> Unit {
  for shape in pptx_children(Some(node)) {
    match shape.element.name.local_name {
      "sp" | "pic" => out.push((shape, offset_x, offset_y))
      "grpSp" => {
        let transform = pptx_transform_node(
          pptx_child(pptx_child(Some(shape), "grpSpPr"), "xfrm"),
        )
        let (dx, dy) = match transform {
          Some(value) => (value.x, value.y)
          None => (0.0, 0.0)
        }
        pptx_collect_shapes(shape, offset_x + dx, offset_y + dy, out)
      }
      _ => ()
    }
  }
}

///|
fn pptx_render_slide(
  package : @ooxml.OoxmlPackage,
  part : String,
  width : Double,
  height : Double,
  writer : @core.DocumentWriter,
) -> Json raise {
  let object = @core.ObjectBuilder::new()
  let fonts : Map[String, Int32] = Map([])
  let root = pptx_read_xml(package, part)
  let tree = pptx_child(pptx_child(Some(root), "cSld"), "spTree")
  let background = pptx_node_color(
    pptx_child(pptx_child(pptx_child(Some(root), "cSld"), "bg"), "bgPr"),
    "solidFill",
  )
  match background {
    Some(color) => {
      object.fill_color(color)
      object.fill_rect(
        0.0,
        0.0,
        Float::from_double(width),
        Float::from_double(height),
      )
    }
    None => ()
  }
  let shapes : Array[(PptxXmlNode, Double, Double)] = []
  match tree {
    Some(value) => pptx_collect_shapes(value, 0.0, 0.0, shapes)
    None => ()
  }
  for shape_entry in shapes {
    let (shape, offset_x, offset_y) = shape_entry
    let transform = pptx_transform_node(
      pptx_child(pptx_child(Some(shape), "spPr"), "xfrm"),
    )
    let transform = match transform {
      Some(value) => value
      None => continue
    }
    if transform.width <= 0.0 || transform.height <= 0.0 {
      continue
    }
    let shape_x = transform.x + offset_x
    let shape_y = transform.y + offset_y
    if shape.element.name.local_name == "pic" {
      let blip = pptx_child(pptx_child(Some(shape), "blipFill"), "blip")
      let embed = match blip {
        Some(value) => pptx_attribute_any(value.element, "embed", "")
        None => ""
      }
      if embed == "" {
        raise PptxInvalid("PPTX picture has no embedded image")
      }
      let mut target = ""
      let mut external = false
      for rel in package.relationships(part) {
        if rel.id == embed {
          target = rel.target
          external = rel.external
        }
      }
      if target == "" || external {
        raise PptxInvalid("PPTX picture relationship is missing")
      }
      let bytes = package.read(target) catch {
        _ => raise PptxInvalid("PPTX picture part is missing")
      }
      let hash = writer.add_part("img", bytes)
      let index = object.add_image(hash)
      object.image(
        index,
        Float::from_double(shape_x),
        Float::from_double(shape_y),
        Float::from_double(transform.width),
        Float::from_double(transform.height),
      )
      continue
    }
    let fill = pptx_node_color(pptx_child(Some(shape), "spPr"), "solidFill")
    match fill {
      Some(color) => {
        object.fill_color(color)
        object.fill_rect(
          Float::from_double(shape_x),
          Float::from_double(shape_y),
          Float::from_double(transform.width),
          Float::from_double(transform.height),
        )
      }
      None => ()
    }
    let body = match pptx_child(Some(shape), "txBody") {
      Some(value) => value
      None => continue
    }
    let line : Array[PptxLineItem] = []
    let mut line_width = 0.0
    let mut line_height = 21.6
    let mut y = shape_y + line_height
    let mut paragraph_index = 0
    for paragraph in pptx_children(Some(body)) {
      if paragraph.element.name.local_name != "p" {
        continue
      }
      let align = match pptx_child(Some(paragraph), "pPr") {
        Some(ppr) =>
          match pptx_attribute(ppr.element, "algn", "") {
            "ctr" => "center"
            "r" => "right"
            _ => "left"
          }
        None => "left"
      }
      let mut x = shape_x
      if paragraph_index > 0 {
        y += line_height
      }
      paragraph_index += 1
      let flush = fn() raise {
        let mut offset = 0.0
        if !line.is_empty() {
          let total = line[line.length() - 1].x +
            line[line.length() - 1].advance -
            shape_x
          match align {
            "right" => offset = Double::max(0.0, transform.width - total)
            "center" =>
              offset = Double::max(0.0, (transform.width - total) / 2.0)
            _ => ()
          }
        }
        for item in line {
          let key = item.weight.to_string() + "|" + item.style.to_string()
          let index = match fonts.get(key) {
            Some(value) => value
            None => {
              let value = object.add_font({
                hash: None,
                family: "sans-serif",
                weight: item.weight,
                style: item.style,
              })
              fonts[key] = value
              value
            }
          }
          object.font(index, Float::from_double(item.size))
          object.fill_color(item.color)
          object.fill_text(
            item.text,
            Float::from_double(shape_x + offset + item.x),
            Float::from_double(y),
            Float::from_double(item.advance),
          )
          x += item.advance
        }
        line.clear()
        line_width = 0.0
      }
      for child in pptx_children(Some(paragraph)) {
        match child.element.name.local_name {
          "br" => {
            flush()
            y += line_height
            x = transform.x
          }
          "r" | "fld" => {
            let text = match pptx_child(Some(child), "t") {
              Some(value) => value.text.to_string()
              None => ""
            }
            if text == "" {
              continue
            }
            let size = pptx_run_size(child)
            let advance = pptx_text_width(text, size)
            if line.is_empty() {
              line_height = size * 1.2
            }
            let item_x = x - shape_x
            if x + advance > shape_x + transform.width && !line.is_empty() {
              flush()
              y += line_height
              x = shape_x
            }
            if y > shape_y + transform.height {
              flush()
              break
            }
            line.push({
              text,
              weight: if pptx_run_bold(child) {
                700
              } else {
                400
              },
              style: if pptx_run_italic(child) {
                1
              } else {
                0
              },
              size,
              color: pptx_run_color(child),
              x: item_x,
              advance,
            })
            x += advance
            line_width = x - shape_x
          }
          _ => ()
        }
      }
      flush()
      y += line_height
    }
  }
  let encoded = object.encode()
  let hash = writer.add_part("obj", encoded)
  Json::object({
    "w": Json::number(width, repr=width.to_string()),
    "h": Json::number(height, repr=height.to_string()),
    "layers": Json::array([
      Json::object({ "role": Json::string("body"), "obj": Json::string(hash) }),
    ]),
  })
}

///|
/// Detect a PresentationML package.
pub fn detect(data : Bytes) -> Bool {
  if data.length() < 4 || data[0] != b'P' || data[1] != b'K' {
    return false
  }
  let pkg = @ooxml.open_ooxml(data) catch { _ => return false }
  match pkg.relationship_of_type("", "/officeDocument") {
    Some(rel) =>
      rel.target == "ppt/presentation.xml" || rel.target.has_prefix("ppt/")
    None => {
      ignore(pkg.read("ppt/presentation.xml")) catch {
        _ => return false
      }
      true
    }
  }
}

///|
/// Convert the supported PresentationML shape/text subset to BDF.
pub fn convert(data : Bytes, title~ : String = "") -> PptxResult raise {
  let presentation = pptx_presentation(data) catch {
    InvalidPptx(message) => raise PptxInvalid(message)
    error => raise PptxInvalid(error.to_string())
  }
  let pkg = @ooxml.open_ooxml(data) catch {
    _ => raise PptxInvalid("invalid PPTX package")
  }
  let meta : Map[String, Json] = {
    "source": Json::string("pptx"),
    "generator": Json::string("bdf-go/0.1"),
  }
  if title != "" {
    meta["title"] = Json::string(title)
  }
  let writer = @core.DocumentWriter::new(meta=Json::object(meta))
  let pages : Array[Json] = []
  for slide in presentation.slides {
    if slide.hidden {
      continue
    }
    pages.push(
      pptx_render_slide(
        pkg,
        slide.part,
        presentation.width,
        presentation.height,
        writer,
      ),
    )
  }
  if pages.is_empty() {
    let object = @core.ObjectBuilder::new()
    let hash = writer.add_part("obj", object.encode())
    pages.push(
      Json::object({
        "w": Json::number(
          presentation.width,
          repr=presentation.width.to_string(),
        ),
        "h": Json::number(
          presentation.height,
          repr=presentation.height.to_string(),
        ),
        "layers": Json::array([
          Json::object({
            "role": Json::string("body"),
            "obj": Json::string(hash),
          }),
        ]),
      }),
    )
  }
  let view : Map[String, Json] = {
    "id": Json::string("pages"),
    "kind": Json::string("fixed"),
    "pages": Json::array(pages),
  }
  if title != "" {
    view["title"] = Json::string(title)
  }
  writer.add_view(Json::object(view))
  let count = pages.length()
  {
    bdf: writer.write_single(),
    pages: count,
    summary: "\{count} slide" + (if count == 1 { "" } else { "s" }),
    warnings: ["PPTX rendering uses a limited shape and text subset"],
  }
}
