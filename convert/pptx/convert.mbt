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
  family : String
  weight : Int32
  style : Int32
  size : Double
  color : UInt32
  x : Double
  advance : Double
}

///|
priv struct PptxPlaceholderDefaults {
  size : Double?
  color : UInt32?
  bold : Bool?
  italic : Bool?
  family : String?
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
fn pptx_color_channel(color : UInt32, shift : Int32) -> Double {
  ((color >> shift) & 0xffU).to_double()
}

///|
fn pptx_pack_color(red : Double, green : Double, blue : Double) -> UInt32 {
  let r = (Double::min(255.0, Double::max(0.0, red)) + 0.5)
    .to_int()
    .reinterpret_as_uint()
  let g = (Double::min(255.0, Double::max(0.0, green)) + 0.5)
    .to_int()
    .reinterpret_as_uint()
  let b = (Double::min(255.0, Double::max(0.0, blue)) + 0.5)
    .to_int()
    .reinterpret_as_uint()
  (r << 24) | (g << 16) | (b << 8) | 0xffU
}

///|
fn pptx_color_modifier(node : PptxXmlNode, name : String) -> Double? {
  match pptx_child(Some(node), name) {
    Some(value) =>
      match pptx_attribute(value.element, "val", "") {
        "" => None
        text => Some((@string.parse_double(text) catch { _ => 0.0 }) / 100000.0)
      }
    None => None
  }
}

///|
fn pptx_apply_color_modifiers(color : UInt32, node : PptxXmlNode) -> UInt32 {
  let mut red = pptx_color_channel(color, 24)
  let mut green = pptx_color_channel(color, 16)
  let mut blue = pptx_color_channel(color, 8)
  for child in node.children {
    let factor = pptx_color_modifier(node, child.element.name.local_name)
    match child.element.name.local_name {
      "lumMod" | "shade" =>
        match factor {
          Some(value) => {
            red *= value
            green *= value
            blue *= value
          }
          None => ()
        }
      "lumOff" =>
        match factor {
          Some(value) => {
            red += value * 255.0
            green += value * 255.0
            blue += value * 255.0
          }
          None => ()
        }
      "tint" =>
        match factor {
          Some(value) => {
            red += (255.0 - red) * value
            green += (255.0 - green) * value
            blue += (255.0 - blue) * value
          }
          None => ()
        }
      _ => ()
    }
  }
  pptx_pack_color(red, green, blue)
}

///|
fn pptx_solid_color(
  node : PptxXmlNode?,
  theme : Map[String, UInt32],
) -> UInt32? {
  match node {
    Some(value) =>
      match pptx_child(Some(value), "srgbClr") {
        Some(color) => {
          let hex = pptx_attribute(color.element, "val", "")
          if hex == "" {
            None
          } else {
            Some(pptx_hex_color(hex))
          }
        }
        None =>
          match pptx_child(Some(value), "schemeClr") {
            Some(color) => {
              let name = pptx_attribute(color.element, "val", "")
              if name == "" {
                None
              } else {
                match theme.get(name) {
                  Some(base) => Some(pptx_apply_color_modifiers(base, color))
                  None => None
                }
              }
            }
            None => None
          }
      }
    None => None
  }
}

///|
fn pptx_node_color(
  node : PptxXmlNode?,
  key : String,
  theme : Map[String, UInt32],
) -> UInt32? {
  pptx_solid_color(pptx_child(node, key), theme)
}

///|
fn pptx_theme_colors(package : @ooxml.OoxmlPackage) -> Map[String, UInt32] {
  let colors : Map[String, UInt32] = {}
  let part = match package.relationship_of_type("", "/theme") {
    Some(rel) => rel.target
    None => "ppt/theme/theme1.xml"
  }
  if !package.has(part) {
    return colors
  }
  let root = pptx_read_xml(package, part) catch { _ => return colors }
  let scheme = pptx_child(
    pptx_child(pptx_child(Some(root), "themeElements"), "clrScheme"),
    "",
  )
  ignore(scheme)
  let scheme = pptx_child(pptx_child(Some(root), "themeElements"), "clrScheme")
  for entry in pptx_children(scheme) {
    let name = entry.element.name.local_name
    let color = match pptx_child(Some(entry), "srgbClr") {
      Some(value) =>
        match pptx_attribute(value.element, "val", "") {
          "" => None
          hex => Some(pptx_hex_color(hex))
        }
      None =>
        match pptx_child(Some(entry), "sysClr") {
          Some(value) =>
            match pptx_attribute(value.element, "lastClr", "") {
              "" => None
              hex => Some(pptx_hex_color(hex))
            }
          None => None
        }
    }
    match color {
      Some(value) => colors[name] = value
      None => ()
    }
  }
  colors
}

///|
fn pptx_theme_fonts(package : @ooxml.OoxmlPackage) -> (String, String) {
  let part = match package.relationship_of_type("", "/theme") {
    Some(rel) => rel.target
    None => "ppt/theme/theme1.xml"
  }
  if !package.has(part) {
    return ("sans-serif", "sans-serif")
  }
  let root = pptx_read_xml(package, part) catch {
    _ => return ("sans-serif", "sans-serif")
  }
  let scheme = pptx_child(pptx_child(Some(root), "themeElements"), "fontScheme")
  let major = match pptx_child(pptx_child(scheme, "majorFont"), "latin") {
    Some(value) =>
      match pptx_attribute(value.element, "typeface", "") {
        "" => "sans-serif"
        name => name
      }
    None => "sans-serif"
  }
  let minor = match pptx_child(pptx_child(scheme, "minorFont"), "latin") {
    Some(value) =>
      match pptx_attribute(value.element, "typeface", "") {
        "" => "sans-serif"
        name => name
      }
    None => "sans-serif"
  }
  (major, minor)
}

///|
fn pptx_run_family(
  run : PptxXmlNode,
  fonts : (String, String),
  inherited : PptxPlaceholderDefaults?,
) -> String {
  let (major, minor) = fonts
  let rpr = pptx_child(Some(run), "rPr")
  let latin = match rpr {
    Some(value) => pptx_child(Some(value), "latin")
    None => None
  }
  match latin {
    Some(value) =>
      match pptx_attribute(value.element, "typeface", "") {
        "" => minor
        "+mj-lt" => major
        "+mn-lt" => minor
        name => name
      }
    None =>
      match inherited {
        Some(value) =>
          match value.family {
            Some(name) => name
            None => minor
          }
        None => minor
      }
  }
}

///|
fn pptx_paragraph_defrpr(paragraph : PptxXmlNode) -> PptxXmlNode? {
  pptx_child(pptx_child(Some(paragraph), "pPr"), "defRPr")
}

///|
fn pptx_run_size(
  run : PptxXmlNode,
  paragraph : PptxXmlNode,
  inherited : PptxPlaceholderDefaults?,
) -> Double {
  let rpr = pptx_child(Some(run), "rPr")
  match rpr {
    Some(value) =>
      match pptx_attribute(value.element, "sz", "") {
        "" => ()
        text => return (@string.parse_double(text) / 100.0) catch { _ => 18.0 }
      }
    None => ()
  }
  match pptx_paragraph_defrpr(paragraph) {
    Some(value) =>
      match pptx_attribute(value.element, "sz", "") {
        "" => ()
        text => return (@string.parse_double(text) / 100.0) catch { _ => 18.0 }
      }
    None => ()
  }
  match inherited {
    Some(value) =>
      match value.size {
        Some(size) => size
        None => 18.0
      }
    None => 18.0
  }
}

///|
fn pptx_toggle(
  run : PptxXmlNode,
  paragraph : PptxXmlNode,
  key : String,
  inherited : Bool?,
) -> Bool {
  let rpr = pptx_child(Some(run), "rPr")
  match rpr {
    Some(value) =>
      if pptx_attribute(value.element, key, "") != "" {
        return pptx_bool(value.element, key, false)
      }
    None => ()
  }
  match pptx_paragraph_defrpr(paragraph) {
    Some(value) =>
      if pptx_attribute(value.element, key, "") != "" {
        return pptx_bool(value.element, key, false)
      }
    None => ()
  }
  inherited.unwrap_or(false)
}

///|
fn pptx_run_bold(
  run : PptxXmlNode,
  paragraph : PptxXmlNode,
  inherited : PptxPlaceholderDefaults?,
) -> Bool {
  pptx_toggle(
    run,
    paragraph,
    "b",
    match inherited {
      Some(value) => value.bold
      None => None
    },
  )
}

///|
fn pptx_run_italic(
  run : PptxXmlNode,
  paragraph : PptxXmlNode,
  inherited : PptxPlaceholderDefaults?,
) -> Bool {
  pptx_toggle(
    run,
    paragraph,
    "i",
    match inherited {
      Some(value) => value.italic
      None => None
    },
  )
}

///|
fn pptx_run_color(
  run : PptxXmlNode,
  paragraph : PptxXmlNode,
  theme : Map[String, UInt32],
  inherited : PptxPlaceholderDefaults?,
) -> UInt32 {
  let rpr = pptx_child(Some(run), "rPr")
  match pptx_node_color(rpr, "solidFill", theme) {
    Some(value) => value
    None =>
      match
        pptx_node_color(pptx_paragraph_defrpr(paragraph), "solidFill", theme) {
        Some(value) => value
        None =>
          match inherited {
            Some(value) =>
              match value.color {
                Some(color) => color
                None => 0x000000ffU
              }
            None => 0x000000ffU
          }
      }
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
fn pptx_has_placeholder(shape : PptxXmlNode) -> Bool {
  let container = if shape.element.name.local_name == "pic" {
    "nvPicPr"
  } else {
    "nvSpPr"
  }
  pptx_child(pptx_child(Some(shape), container), "nvPr") is Some(_) &&
  pptx_child(pptx_child(pptx_child(Some(shape), container), "nvPr"), "ph")
  is Some(_)
}

///|
fn pptx_placeholder_key(shape : PptxXmlNode) -> String? {
  let container = if shape.element.name.local_name == "pic" {
    "nvPicPr"
  } else {
    "nvSpPr"
  }
  let placeholder = pptx_child(
    pptx_child(pptx_child(Some(shape), container), "nvPr"),
    "ph",
  )
  match placeholder {
    Some(value) => {
      let idx = pptx_attribute(value.element, "idx", "0")
      let kind = pptx_attribute(value.element, "type", "body")
      Some(idx + "|" + kind)
    }
    None => None
  }
}

///|
fn pptx_placeholder_transforms(
  root : PptxXmlNode,
) -> Map[String, PptxTransform] {
  let result : Map[String, PptxTransform] = Map([])
  let tree = pptx_child(pptx_child(Some(root), "cSld"), "spTree")
  for shape in pptx_children(tree) {
    let kind = shape.element.name.local_name
    if kind != "sp" && kind != "pic" {
      continue
    }
    let key = match pptx_placeholder_key(shape) {
      Some(value) => value
      None => continue
    }
    let transform = pptx_transform_node(
      pptx_child(pptx_child(Some(shape), "spPr"), "xfrm"),
    )
    match transform {
      Some(value) => result[key] = value
      None => ()
    }
  }
  result
}

///|
fn pptx_placeholder_defaults(
  root : PptxXmlNode,
  theme : Map[String, UInt32],
) -> Map[String, PptxPlaceholderDefaults] {
  let result : Map[String, PptxPlaceholderDefaults] = Map([])
  let tree = pptx_child(pptx_child(Some(root), "cSld"), "spTree")
  for shape in pptx_children(tree) {
    let key = match pptx_placeholder_key(shape) {
      Some(value) => value
      None => continue
    }
    let body = match pptx_child(Some(shape), "txBody") {
      Some(value) => value
      None => continue
    }
    let mut rpr = match pptx_child(Some(body), "p") {
      Some(paragraph) =>
        pptx_child(pptx_child(Some(paragraph), "pPr"), "defRPr")
      None => None
    }
    if rpr is None {
      rpr = pptx_child(
        pptx_child(pptx_child(Some(body), "lstStyle"), "lvl1pPr"),
        "defRPr",
      )
    }
    let rpr = match rpr {
      Some(value) => value
      None => continue
    }
    let size = match pptx_attribute(rpr.element, "sz", "") {
      "" => None
      text => Some((@string.parse_double(text) / 100.0) catch { _ => 18.0 })
    }
    let bold = if pptx_attribute(rpr.element, "b", "") != "" {
      Some(pptx_bool(rpr.element, "b", false))
    } else {
      None
    }
    let italic = if pptx_attribute(rpr.element, "i", "") != "" {
      Some(pptx_bool(rpr.element, "i", false))
    } else {
      None
    }
    let family = match pptx_child(Some(rpr), "latin") {
      Some(value) =>
        match pptx_attribute(value.element, "typeface", "") {
          "" => None
          name => Some(name)
        }
      None => None
    }
    result[key] = {
      size,
      color: pptx_node_color(Some(rpr), "solidFill", theme),
      bold,
      italic,
      family,
    }
  }
  result
}

///|
fn pptx_collect_shapes(
  node : PptxXmlNode,
  offset_x : Double,
  offset_y : Double,
  skip_placeholders : Bool,
  out : Array[(PptxXmlNode, Double, Double)],
) -> Unit {
  for shape in pptx_children(Some(node)) {
    match shape.element.name.local_name {
      "sp" | "pic" | "graphicFrame" =>
        if !(skip_placeholders && pptx_has_placeholder(shape)) {
          out.push((shape, offset_x, offset_y))
        }
      "grpSp" => {
        let transform = pptx_transform_node(
          pptx_child(pptx_child(Some(shape), "grpSpPr"), "xfrm"),
        )
        let (dx, dy) = match transform {
          Some(value) => (value.x, value.y)
          None => (0.0, 0.0)
        }
        pptx_collect_shapes(
          shape,
          offset_x + dx,
          offset_y + dy,
          skip_placeholders,
          out,
        )
      }
      _ => ()
    }
  }
}

///|

///|
fn pptx_table_lines(shape : PptxXmlNode) -> Array[String] {
  let table = pptx_child(
    pptx_child(pptx_child(Some(shape), "graphic"), "graphicData"),
    "tbl",
  )
  let lines : Array[String] = []
  for row in pptx_children(table) {
    if row.element.name.local_name != "tr" {
      continue
    }
    let line = StringBuilder()
    let mut first = true
    for cell in pptx_children(Some(row)) {
      if cell.element.name.local_name != "tc" {
        continue
      }
      if !first {
        line.write_string("\t")
      }
      first = false
      let cell_text = StringBuilder()
      for paragraph in pptx_children(pptx_child(Some(cell), "txBody")) {
        if paragraph.element.name.local_name != "p" {
          continue
        }
        for run in pptx_children(Some(paragraph)) {
          if run.element.name.local_name == "r" {
            match pptx_child(Some(run), "t") {
              Some(value) => cell_text.write_string(value.text.to_string())
              None => ()
            }
          }
        }
      }
      line.write_string(cell_text.to_string())
    }
    if line.to_string() != "" {
      lines.push(line.to_string())
    }
  }
  lines
}

///|
fn pptx_emit_table(
  shape : PptxXmlNode,
  object : @core.ObjectBuilder,
  x : Double,
  y : Double,
  fonts : (String, String),
) -> Unit raise {
  let lines = pptx_table_lines(shape)
  if lines.is_empty() {
    return
  }
  let (_, minor) = fonts
  let index = object.add_font({
    hash: None,
    family: minor,
    weight: 400,
    style: 0,
  })
  let mut baseline = y + 12.0
  for line in lines {
    object.font(index, 12.0)
    object.fill_color(0x000000ffU)
    object.fill_text(
      line,
      Float::from_double(x),
      Float::from_double(baseline),
      Float::from_double(pptx_text_width(line, 12.0)),
    )
    baseline += 14.4
  }
}

///|
fn pptx_render_slide(
  package : @ooxml.OoxmlPackage,
  part : String,
  width : Double,
  height : Double,
  writer : @core.DocumentWriter,
  theme : Map[String, UInt32],
  theme_fonts : (String, String),
) -> Json raise {
  let object = @core.ObjectBuilder::new()
  let fonts : Map[String, Int32] = Map([])
  let root = pptx_read_xml(package, part)
  let mut layout_root : PptxXmlNode? = None
  let mut master_root : PptxXmlNode? = None
  match (Some(pptx_slide_context(package, part)) catch { _ => None }) {
    Some(context) => {
      if context.draw_master && context.master_part != "" {
        master_root = Some(pptx_read_xml(package, context.master_part))
      }
      if context.draw_layout && context.layout_part != "" {
        layout_root = Some(pptx_read_xml(package, context.layout_part))
      }
    }
    None => ()
  }
  let mut background = pptx_node_color(
    pptx_child(pptx_child(pptx_child(Some(root), "cSld"), "bg"), "bgPr"),
    "solidFill",
    theme,
  )
  if background is None && layout_root is Some(value) {
    background = pptx_node_color(
      pptx_child(pptx_child(pptx_child(Some(value), "cSld"), "bg"), "bgPr"),
      "solidFill",
      theme,
    )
  }
  if background is None && master_root is Some(value) {
    background = pptx_node_color(
      pptx_child(pptx_child(pptx_child(Some(value), "cSld"), "bg"), "bgPr"),
      "solidFill",
      theme,
    )
  }
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
  let roots : Array[PptxXmlNode] = []
  match master_root {
    Some(value) => roots.push(value)
    None => ()
  }
  match layout_root {
    Some(value) => roots.push(value)
    None => ()
  }
  roots.push(root)
  let layout_placeholders = match layout_root {
    Some(value) => pptx_placeholder_transforms(value)
    None => Map([])
  }
  let master_placeholders = match master_root {
    Some(value) => pptx_placeholder_transforms(value)
    None => Map([])
  }
  let layout_defaults = match layout_root {
    Some(value) => pptx_placeholder_defaults(value, theme)
    None => Map([])
  }
  let master_defaults = match master_root {
    Some(value) => pptx_placeholder_defaults(value, theme)
    None => Map([])
  }
  let shapes : Array[(PptxXmlNode, Double, Double)] = []
  for index in 0..<roots.length() {
    let tree = pptx_child(pptx_child(Some(roots[index]), "cSld"), "spTree")
    match tree {
      Some(value) =>
        pptx_collect_shapes(value, 0.0, 0.0, index + 1 < roots.length(), shapes)
      None => ()
    }
  }
  for shape_entry in shapes {
    let (shape, offset_x, offset_y) = shape_entry
    let mut transform = if shape.element.name.local_name == "graphicFrame" {
      pptx_transform_node(pptx_child(Some(shape), "xfrm"))
    } else {
      pptx_transform_node(pptx_child(pptx_child(Some(shape), "spPr"), "xfrm"))
    }
    if transform is None {
      match pptx_placeholder_key(shape) {
        Some(key) =>
          match layout_placeholders.get(key) {
            Some(value) => transform = Some(value)
            None =>
              match master_placeholders.get(key) {
                Some(value) => transform = Some(value)
                None => ()
              }
          }
        None => ()
      }
    }
    let transform = match transform {
      Some(value) => value
      None => continue
    }
    let mut inherited : PptxPlaceholderDefaults? = None
    match pptx_placeholder_key(shape) {
      Some(key) =>
        match layout_defaults.get(key) {
          Some(value) => inherited = Some(value)
          None =>
            match master_defaults.get(key) {
              Some(value) => inherited = Some(value)
              None => ()
            }
        }
      None => ()
    }
    if transform.width <= 0.0 || transform.height <= 0.0 {
      continue
    }
    let shape_x = transform.x + offset_x
    let shape_y = transform.y + offset_y
    if shape.element.name.local_name == "graphicFrame" {
      pptx_emit_table(shape, object, shape_x, shape_y, theme_fonts)
      continue
    }
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
    let fill = pptx_node_color(
      pptx_child(Some(shape), "spPr"),
      "solidFill",
      theme,
    )
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
          let key = item.family +
            "|" +
            item.weight.to_string() +
            "|" +
            item.style.to_string()
          let index = match fonts.get(key) {
            Some(value) => value
            None => {
              let value = object.add_font({
                hash: None,
                family: item.family,
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
            let size = pptx_run_size(child, paragraph, inherited)
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
              family: pptx_run_family(child, theme_fonts, inherited),
              weight: if pptx_run_bold(child, paragraph, inherited) {
                700
              } else {
                400
              },
              style: if pptx_run_italic(child, paragraph, inherited) {
                1
              } else {
                0
              },
              size,
              color: pptx_run_color(child, paragraph, theme, inherited),
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
  let theme = pptx_theme_colors(pkg)
  let theme_fonts = pptx_theme_fonts(pkg)
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
        theme,
        theme_fonts,
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
