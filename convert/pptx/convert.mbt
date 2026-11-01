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
priv struct PptxPlacement {
  sx : Double
  sy : Double
  tx : Double
  ty : Double
  rotation : Double
  cx : Double
  cy : Double
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
fn pptx_node_alpha(node : PptxXmlNode?, key : String) -> Double? {
  let solid = pptx_child(node, key)
  let color = match pptx_child(solid, "srgbClr") {
    Some(value) => Some(value)
    None => pptx_child(solid, "schemeClr")
  }
  match pptx_child(color, "alpha") {
    Some(value) =>
      match pptx_attribute(value.element, "val", "") {
        "" => None
        text =>
          Some((@string.parse_double(text) catch { _ => 100000.0 }) / 100000.0)
      }
    None => None
  }
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
fn PptxPlacement::compose(
  self : PptxPlacement,
  child : PptxPlacement,
) -> PptxPlacement {
  {
    sx: self.sx * child.sx,
    sy: self.sy * child.sy,
    tx: self.tx + self.sx * child.tx,
    ty: self.ty + self.sy * child.ty,
    rotation: self.rotation + child.rotation,
    cx: self.tx + self.sx * child.cx,
    cy: self.ty + self.sy * child.cy,
  }
}

///|
fn pptx_group_placement(shape : PptxXmlNode) -> PptxPlacement {
  let xfrm = pptx_child(pptx_child(Some(shape), "grpSpPr"), "xfrm")
  let off = pptx_child(xfrm, "off")
  let ext = pptx_child(xfrm, "ext")
  let ch_off = pptx_child(xfrm, "chOff")
  let ch_ext = pptx_child(xfrm, "chExt")
  let off_x = match off {
    Some(value) => pptx_measure(pptx_attribute(value.element, "x", ""), 0.0)
    None => 0.0
  }
  let off_y = match off {
    Some(value) => pptx_measure(pptx_attribute(value.element, "y", ""), 0.0)
    None => 0.0
  }
  let ext_x = match ext {
    Some(value) => pptx_measure(pptx_attribute(value.element, "cx", ""), 0.0)
    None => 0.0
  }
  let ext_y = match ext {
    Some(value) => pptx_measure(pptx_attribute(value.element, "cy", ""), 0.0)
    None => 0.0
  }
  let ch_x = match ch_off {
    Some(value) => pptx_measure(pptx_attribute(value.element, "x", ""), 0.0)
    None => 0.0
  }
  let ch_y = match ch_off {
    Some(value) => pptx_measure(pptx_attribute(value.element, "y", ""), 0.0)
    None => 0.0
  }
  let ch_w = match ch_ext {
    Some(value) => pptx_measure(pptx_attribute(value.element, "cx", ""), 0.0)
    None => 0.0
  }
  let ch_h = match ch_ext {
    Some(value) => pptx_measure(pptx_attribute(value.element, "cy", ""), 0.0)
    None => 0.0
  }
  let sx = if ch_w > 0.0 && ext_x > 0.0 { ext_x / ch_w } else { 1.0 }
  let sy = if ch_h > 0.0 && ext_y > 0.0 { ext_y / ch_h } else { 1.0 }
  let rotation = match xfrm {
    Some(value) =>
      pptx_int64(pptx_attribute(value.element, "rot", ""), 0L).to_double() /
      60000.0
    None => 0.0
  }
  {
    sx,
    sy,
    tx: off_x - ch_x * sx,
    ty: off_y - ch_y * sy,
    rotation,
    cx: off_x + ext_x / 2.0,
    cy: off_y + ext_y / 2.0,
  }
}

///|
fn pptx_collect_shapes(
  node : PptxXmlNode,
  placement : PptxPlacement,
  skip_placeholders : Bool,
  out : Array[(PptxXmlNode, PptxPlacement)],
) -> Unit {
  for shape in pptx_children(Some(node)) {
    match shape.element.name.local_name {
      "sp" | "pic" | "graphicFrame" =>
        if !(skip_placeholders && pptx_has_placeholder(shape)) {
          out.push((shape, placement))
        }
      "grpSp" =>
        pptx_collect_shapes(
          shape,
          placement.compose(pptx_group_placement(shape)),
          skip_placeholders,
          out,
        )
      _ => ()
    }
  }
}

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
fn pptx_cell_color(cell : PptxXmlNode, theme : Map[String, UInt32]) -> UInt32 {
  for paragraph in pptx_children(pptx_child(Some(cell), "txBody")) {
    if paragraph.element.name.local_name != "p" {
      continue
    }
    for run in pptx_children(Some(paragraph)) {
      if run.element.name.local_name == "r" {
        match
          pptx_node_color(pptx_child(Some(run), "rPr"), "solidFill", theme) {
          Some(color) => return color
          None => ()
        }
      }
    }
  }
  0x000000ffU
}

///|
fn pptx_cell_margin(
  cell : PptxXmlNode,
  name : String,
  default : Double,
) -> Double {
  match pptx_child(Some(cell), "tcPr") {
    Some(props) =>
      match pptx_attribute(props.element, name, "") {
        "" => default
        value =>
          (@string.parse_double(value) catch { _ => default * 12700.0 }) /
          12700.0
      }
    None => default
  }
}

///|
fn pptx_cell_vertical_anchor(cell : PptxXmlNode) -> String {
  match pptx_child(Some(cell), "tcPr") {
    Some(props) =>
      match pptx_attribute(props.element, "anchor", "") {
        "ctr" => "center"
        "b" => "bottom"
        _ => "top"
      }
    None => "top"
  }
}

///|
fn pptx_cell_alignment(cell : PptxXmlNode) -> String {
  for paragraph in pptx_children(pptx_child(Some(cell), "txBody")) {
    if paragraph.element.name.local_name != "p" {
      continue
    }
    match pptx_child(Some(paragraph), "pPr") {
      Some(props) =>
        match pptx_attribute(props.element, "algn", "") {
          "ctr" => return "center"
          "r" => return "right"
          _ => ()
        }
      None => ()
    }
  }
  "left"
}

///|
fn pptx_cell_bold(cell : PptxXmlNode) -> Int32 {
  for paragraph in pptx_children(pptx_child(Some(cell), "txBody")) {
    for run in pptx_children(Some(paragraph)) {
      match pptx_child(Some(run), "rPr") {
        Some(props) =>
          if pptx_attribute(props.element, "b", "0") == "1" {
            return 700
          }
        None => ()
      }
    }
  }
  400
}

///|
fn pptx_cell_italic(cell : PptxXmlNode) -> Int32 {
  for paragraph in pptx_children(pptx_child(Some(cell), "txBody")) {
    for run in pptx_children(Some(paragraph)) {
      match pptx_child(Some(run), "rPr") {
        Some(props) =>
          if pptx_attribute(props.element, "i", "0") == "1" {
            return 1
          }
        None => ()
      }
    }
  }
  0
}

///|
fn pptx_body_inset(body : PptxXmlNode, name : String) -> Double {
  match pptx_child(Some(body), "bodyPr") {
    Some(props) =>
      match pptx_attribute(props.element, name, "") {
        "" => 0.0
        value => (@string.parse_double(value) catch { _ => 0.0 }) / 12700.0
      }
    None => 0.0
  }
}

///|
fn pptx_cell_text_size(cell : PptxXmlNode) -> Double {
  for paragraph in pptx_children(pptx_child(Some(cell), "txBody")) {
    if paragraph.element.name.local_name != "p" {
      continue
    }
    for run in pptx_children(Some(paragraph)) {
      if run.element.name.local_name == "r" {
        match pptx_child(Some(run), "rPr") {
          Some(props) =>
            match pptx_attribute(props.element, "sz", "") {
              "" => ()
              value =>
                return (@string.parse_double(value) catch { _ => 1200.0 }) /
                  100.0
            }
          None => ()
        }
      }
    }
  }
  12.0
}

///|
fn pptx_cell_text(cell : PptxXmlNode) -> String {
  let text = StringBuilder()
  for paragraph in pptx_children(pptx_child(Some(cell), "txBody")) {
    if paragraph.element.name.local_name != "p" {
      continue
    }
    for run in pptx_children(Some(paragraph)) {
      if run.element.name.local_name == "r" {
        match pptx_child(Some(run), "t") {
          Some(value) => text.write_string(value.text.to_string())
          None => ()
        }
      }
    }
  }
  text.to_string()
}

///|
fn pptx_cell_row_span(cell : PptxXmlNode) -> Int32 {
  let span = @string.parse_int(pptx_attribute(cell.element, "rowSpan", "1")) catch {
    _ => 1
  }
  if span < 1 {
    1
  } else {
    span
  }
}

///|
fn pptx_gradient_paint(
  shape : PptxXmlNode,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  theme : Map[String, UInt32],
) -> @core.Paint? {
  let gradient = pptx_child(pptx_child(Some(shape), "spPr"), "gradFill")
  let stops : Array[@core.ColorStop] = []
  for stop in pptx_children(pptx_child(gradient, "gsLst")) {
    match pptx_solid_color(Some(stop), theme) {
      Some(color) => {
        let offset = (@string.parse_double(
            pptx_attribute(stop.element, "pos", "0"),
          ) catch {
            _ => 0.0
          }) /
          100000.0
        stops.push({ offset, color: color.reinterpret_as_int(), })
      }
      None => ()
    }
  }
  if stops.length() < 2 {
    return None
  }
  let angle = match pptx_child(gradient, "lin") {
    Some(value) =>
      (@string.parse_double(pptx_attribute(value.element, "ang", "0")) catch {
        _ => 0.0
      }) /
      60000.0 *
      3.141592653589793 /
      180.0
    None => 0.0
  }
  let center_x = x + width / 2.0
  let center_y = y + height / 2.0
  let length = (width * width + height * height).sqrt() / 2.0
  let dx = @math.cos(angle) * length
  let dy = @math.sin(angle) * length
  Some(
    @core.Gradient(
      0,
      [center_x - dx, center_y - dy, center_x + dx, center_y + dy],
      stops,
    ),
  )
}

///|
fn pptx_cell_grid_span(cell : PptxXmlNode) -> Int32 {
  let span = @string.parse_int(pptx_attribute(cell.element, "gridSpan", "1")) catch {
    _ => 1
  }
  if span < 1 {
    1
  } else {
    span
  }
}

///|
fn pptx_cell_borders(
  cell : PptxXmlNode,
  theme : Map[String, UInt32],
) -> Array[(Int32, Double, UInt32)] {
  let result : Array[(Int32, Double, UInt32)] = []
  let props = pptx_child(Some(cell), "tcPr")
  let names = ["lnT", "lnR", "lnB", "lnL"]
  for side, name in names {
    match pptx_child(props, name) {
      Some(line) => {
        let width = (@string.parse_double(
            pptx_attribute(line.element, "w", "0"),
          ) catch {
            _ => 0.0
          }) /
          12700.0
        if width > 0.0 {
          let color = pptx_node_color(Some(line), "solidFill", theme).unwrap_or(
            0x000000ffU,
          )
          result.push((side, width, color))
        }
      }
      None => ()
    }
  }
  result
}

///|
fn pptx_emit_table(
  shape : PptxXmlNode,
  object : @core.ObjectBuilder,
  x : Double,
  y : Double,
  width : Double,
  theme : Map[String, UInt32],
  fonts : (String, String),
) -> Unit raise {
  let lines = pptx_table_lines(shape)
  if lines.is_empty() {
    return
  }
  let table = pptx_child(
    pptx_child(pptx_child(Some(shape), "graphic"), "graphicData"),
    "tbl",
  )
  let rows = pptx_children(table)
  let grid : Array[Double] = []
  match pptx_child(table, "tblGrid") {
    Some(value) =>
      for column in pptx_children(Some(value)) {
        if column.element.name.local_name == "gridCol" {
          grid.push(pptx_measure(pptx_attribute(column.element, "w", ""), 0.0))
        }
      }
    None => ()
  }
  let row_heights : Array[Double] = []
  for row in rows {
    if row.element.name.local_name != "tr" {
      continue
    }
    row_heights.push(
      match pptx_attribute(row.element, "h", "") {
        "" => 14.4
        value => (@string.parse_double(value) catch { _ => 182880.0 }) / 12700.0
      },
    )
  }
  let mut row_index = 0
  let mut row_top = y
  for row in rows {
    if row.element.name.local_name != "tr" {
      continue
    }
    let row_height = row_heights[row_index]
    let cells = pptx_children(Some(row))
    let mut cell_count = 0
    for cell in cells {
      if cell.element.name.local_name == "tc" {
        cell_count += 1
      }
    }
    if cell_count == 0 {
      continue
    }
    let cell_width = width / cell_count.to_double()
    let mut cell_index = 0.0
    let mut cell_x = x
    for cell in cells {
      if cell.element.name.local_name != "tc" {
        continue
      }
      let span = pptx_cell_grid_span(cell)
      let mut column_width = if grid.length() == cell_count {
        grid[cell_index.to_int()]
      } else {
        cell_width
      }
      if span > 1 && cell_index.to_int() + span <= grid.length() {
        column_width = 0.0
        for k in 0..<span {
          column_width += grid[cell_index.to_int() + k]
        }
      }
      let row_span = pptx_cell_row_span(cell)
      let mut cell_height = row_height
      if row_span > 1 && row_index + row_span <= row_heights.length() {
        cell_height = 0.0
        for k in 0..<row_span {
          cell_height += row_heights[row_index + k]
        }
      }
      match
        pptx_node_color(pptx_child(Some(cell), "tcPr"), "solidFill", theme) {
        Some(color) => {
          object.fill_color(color)
          object.fill_rect(
            Float::from_double(cell_x),
            Float::from_double(row_top),
            Float::from_double(column_width),
            Float::from_double(cell_height),
          )
        }
        None => ()
      }
      for border in pptx_cell_borders(cell, theme) {
        let (side, border_width, border_color) = border
        let coordinates : Array[Double] = match side {
          0 => [cell_x, row_top, cell_x + column_width, row_top]
          1 =>
            [
              cell_x + column_width,
              row_top,
              cell_x + column_width,
              row_top + cell_height,
            ]
          2 =>
            [
              cell_x,
              row_top + cell_height,
              cell_x + column_width,
              row_top + cell_height,
            ]
          _ => [cell_x, row_top, cell_x, row_top + cell_height]
        }
        let path : @core.Path = { verbs: b"\x00\x01", coordinates, }
        object.line(Float::from_double(border_width), 0, 0, 8.0F)
        object.stroke_color(border_color)
        object.stroke_path(object.add_path(@core.Inline(path)))
      }
      cell_x += column_width
      cell_index += span.to_double()
    }
    row_top += row_height
    row_index += 1
  }
  let (_, minor) = fonts
  let index = object.add_font({
    hash: None,
    family: minor,
    weight: 400,
    style: 0,
  })
  object.font(index, 12.0)
  object.fill_color(0x000000ffU)
  let mut text_row = 0
  let mut text_top = y
  for row in rows {
    if row.element.name.local_name != "tr" {
      continue
    }
    let row_height = row_heights[text_row]
    let cells = pptx_children(Some(row))
    let mut cell_count = 0
    for cell in cells {
      if cell.element.name.local_name == "tc" {
        cell_count += 1
      }
    }
    if cell_count == 0 {
      continue
    }
    let cell_width = width / cell_count.to_double()
    let mut cell_index = 0.0
    let mut cell_x = x
    for cell in cells {
      if cell.element.name.local_name != "tc" {
        continue
      }
      let span = pptx_cell_grid_span(cell)
      let mut column_width = if grid.length() == cell_count {
        grid[cell_index.to_int()]
      } else {
        cell_width
      }
      if span > 1 && cell_index.to_int() + span <= grid.length() {
        column_width = 0.0
        for k in 0..<span {
          column_width += grid[cell_index.to_int() + k]
        }
      }
      let text = pptx_cell_text(cell)
      if text != "" {
        let size = pptx_cell_text_size(cell)
        let cell_font = object.add_font({
          hash: None,
          family: minor,
          weight: pptx_cell_bold(cell),
          style: pptx_cell_italic(cell),
        })
        object.font(cell_font, Float::from_double(size))
        object.fill_color(pptx_cell_color(cell, theme))
        let advance = pptx_text_width(text, size)
        let margin_left = pptx_cell_margin(cell, "marL", 7.2)
        let margin_right = pptx_cell_margin(cell, "marR", 7.2)
        let margin_top = pptx_cell_margin(cell, "marT", 3.6)
        let margin_bottom = pptx_cell_margin(cell, "marB", 3.6)
        let inner = column_width - margin_left - margin_right
        let text_x = match pptx_cell_alignment(cell) {
          "center" => cell_x + margin_left + (inner - advance) / 2.0
          "right" => cell_x + column_width - margin_right - advance
          _ => cell_x + margin_left
        }
        let text_y = match pptx_cell_vertical_anchor(cell) {
          "center" => text_top + row_height / 2.0 + size * 0.35
          "bottom" => text_top + row_height - margin_bottom
          _ => text_top + margin_top + 12.0
        }
        object.fill_text(
          text,
          Float::from_double(text_x),
          Float::from_double(text_y),
          Float::from_double(advance),
        )
      }
      cell_x += column_width
      cell_index += span.to_double()
    }
    text_top += row_height
    text_row += 1
  }
}

///|
fn pptx_ellipse_path(
  x : Double,
  y : Double,
  width : Double,
  height : Double,
) -> @core.Path {
  let cx = x + width / 2.0
  let cy = y + height / 2.0
  let rx = width / 2.0
  let ry = height / 2.0
  let verbs : Array[Byte] = [0]
  let coordinates : Array[Double] = [cx + rx, cy]
  for i in 1..<49 {
    let angle = 2.0 * 3.141592653589793 * i.to_double() / 48.0
    verbs.push(1)
    coordinates.push(cx + rx * @math.cos(angle))
    coordinates.push(cy + ry * @math.sin(angle))
  }
  verbs.push(4)
  { verbs: Bytes::from_array(verbs), coordinates, }
}

///|
fn pptx_rotated_rect_path_at(
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  rotation : Double,
  cx : Double,
  cy : Double,
) -> @core.Path {
  let radians = rotation * 3.141592653589793 / 180.0
  let sine = @math.sin(radians)
  let cosine = @math.cos(radians)
  let corners = [
    (x, y),
    (x + width, y),
    (x + width, y + height),
    (x, y + height),
  ]
  let verbs : Array[Byte] = [0, 1, 1, 1, 4]
  let coordinates : Array[Double] = []
  for corner in corners {
    let (px, py) = corner
    let dx = px - cx
    let dy = py - cy
    coordinates.push(cx + dx * cosine - dy * sine)
    coordinates.push(cy + dx * sine + dy * cosine)
  }
  { verbs: Bytes::from_array(verbs), coordinates, }
}

///|
fn pptx_rotated_rect_path(
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  rotation : Double,
) -> @core.Path {
  pptx_rotated_rect_path_at(
    x,
    y,
    width,
    height,
    rotation,
    x + width / 2.0,
    y + height / 2.0,
  )
}

///|
fn pptx_rotate_path(
  path : @core.Path,
  cx : Double,
  cy : Double,
  rotation : Double,
) -> @core.Path {
  if rotation == 0.0 {
    return path
  }
  let radians = rotation * 3.141592653589793 / 180.0
  let sine = @math.sin(radians)
  let cosine = @math.cos(radians)
  let coordinates : Array[Double] = []
  let mut index = 0
  while index + 1 < path.coordinates.length() {
    let dx = path.coordinates[index] - cx
    let dy = path.coordinates[index + 1] - cy
    coordinates.push(cx + dx * cosine - dy * sine)
    coordinates.push(cy + dx * sine + dy * cosine)
    index += 2
  }
  { verbs: path.verbs, coordinates, }
}

///|
fn pptx_round_rect_path(
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  radius : Double,
) -> @core.Path {
  let r = Double::min(radius, Double::min(width, height) / 2.0)
  if r <= 0.0 {
    return {
      verbs: b"\x00\x01\x01\x01\x04",
      coordinates: [x, y, x + width, y, x + width, y + height, x, y + height],
    }
  }
  let verbs : Array[Byte] = [0]
  let coordinates : Array[Double] = [x + r, y]
  verbs.push(1)
  coordinates.push(x + width - r)
  coordinates.push(y)
  let corners : Array[(Double, Double, Double)] = [
    (x + width - r, y + r, -3.141592653589793 / 2.0),
    (x + width - r, y + height - r, 0.0),
    (x + r, y + height - r, 3.141592653589793 / 2.0),
    (x + r, y + r, 3.141592653589793),
  ]
  for corner in corners {
    let (cx, cy, start) = corner
    for index in 1..<9 {
      let angle = start + 3.141592653589793 / 2.0 * index.to_double() / 8.0
      verbs.push(1)
      coordinates.push(cx + r * @math.cos(angle))
      coordinates.push(cy + r * @math.sin(angle))
    }
  }
  verbs.push(4)
  { verbs: Bytes::from_array(verbs), coordinates, }
}

///|
fn pptx_chart_values(node : PptxXmlNode?, child_name : String) -> Array[String] {
  let cache = pptx_child(
    pptx_child(pptx_child(node, child_name), "numRef"),
    "numCache",
  )
  let cache = match cache {
    Some(value) => Some(value)
    None =>
      pptx_child(pptx_child(pptx_child(node, child_name), "strRef"), "strCache")
  }
  let values : Array[String] = []
  for point in pptx_children(cache) {
    if point.element.name.local_name == "pt" {
      match pptx_child(Some(point), "v") {
        Some(value) => values.push(value.text.to_string())
        None => values.push("")
      }
    }
  }
  values
}

///|
fn pptx_line_path(
  values : Array[Double],
  maximum : Double,
  left : Double,
  top : Double,
  width : Double,
  height : Double,
) -> @core.Path {
  let verbs : Array[Byte] = [0]
  let coordinates : Array[Double] = []
  let count = values.length().to_double()
  for index, value in values {
    if index > 0 {
      verbs.push(1)
    }
    let x = if count <= 1.0 {
      left + width / 2.0
    } else {
      left + width * index.to_double() / (count - 1.0)
    }
    let y = top + height - height * value / maximum
    coordinates.push(x)
    coordinates.push(y)
  }
  { verbs: Bytes::from_array(verbs), coordinates, }
}

///|
fn pptx_pie_path(
  cx : Double,
  cy : Double,
  radius : Double,
  start : Double,
  sweep : Double,
) -> @core.Path {
  let verbs : Array[Byte] = [0]
  let coordinates : Array[Double] = [cx, cy]
  let steps = 32
  for index in 0..<(steps + 1) {
    let angle = start + sweep * index.to_double() / steps.to_double()
    verbs.push(1)
    coordinates.push(cx + radius * @math.cos(angle))
    coordinates.push(cy + radius * @math.sin(angle))
  }
  verbs.push(4)
  { verbs: Bytes::from_array(verbs), coordinates, }
}

///|
fn pptx_emit_chart(
  shape : PptxXmlNode,
  package : @ooxml.OoxmlPackage,
  part : String,
  object : @core.ObjectBuilder,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  theme : Map[String, UInt32],
  fonts : (String, String),
) -> Unit raise {
  let chart = pptx_child(
    pptx_child(pptx_child(Some(shape), "graphic"), "graphicData"),
    "chart",
  )
  let rel_id = match chart {
    Some(value) => pptx_attribute_any(value.element, "id", "")
    None => ""
  }
  if rel_id == "" {
    return
  }
  let mut target = ""
  for rel in package.relationships(part) {
    if rel.id == rel_id {
      target = rel.target
    }
  }
  if target == "" {
    return
  }
  let root = package.read(target) catch {
    _ => raise PptxInvalid("PPTX chart part is missing")
  }
  let root = pptx_parse_xml(@utf8.decode_lossy(root[:], ignore_bom=true))
  let plot_area = pptx_child(pptx_child(Some(root), "chart"), "plotArea")
  let bar = pptx_child(plot_area, "barChart")
  let line_chart = pptx_child(plot_area, "lineChart")
  let pie_chart = pptx_child(plot_area, "pieChart")
  let is_line = bar is None && line_chart is Some(_)
  let is_pie = bar is None && line_chart is None && pie_chart is Some(_)
  let chart = match bar {
    Some(value) => Some(value)
    None =>
      match line_chart {
        Some(value) => Some(value)
        None => pie_chart
      }
  }
  let series = pptx_children(chart)
  let values : Array[Double] = []
  let categories : Array[String] = []
  let mut fill = 0x4472c4ffU
  for item in series {
    if item.element.name.local_name != "ser" {
      continue
    }
    for value in pptx_chart_values(Some(item), "val") {
      values.push(@string.parse_double(value) catch { _ => 0.0 })
    }
    for value in pptx_chart_values(Some(item), "cat") {
      categories.push(value)
    }
    match pptx_node_color(pptx_child(Some(item), "spPr"), "solidFill", theme) {
      Some(color) => fill = color
      None => ()
    }
    break
  }
  if values.is_empty() {
    return
  }
  let mut maximum = 0.0
  for value in values {
    maximum = Double::max(maximum, value)
  }
  if maximum <= 0.0 {
    return
  }
  if is_pie {
    let total = values.fold(init=0.0, (sum, value) => sum + value)
    if total <= 0.0 {
      return
    }
    let cx = x + width / 2.0
    let cy = y + height / 2.0
    let radius = Double::min(width, height) / 2.0 - 20.0
    let palette = [
      0x4472c4ffU, 0xed7d31ffU, 0xa5a5a5ffU, 0xffc000ffU, 0x5b9bd5ffU,
    ]
    let mut start = -3.141592653589793 / 2.0
    for index, value in values {
      let sweep = 2.0 * 3.141592653589793 * value / total
      let path = object.add_path(
        @core.Inline(pptx_pie_path(cx, cy, radius, start, sweep)),
      )
      object.fill_color(palette[index % palette.length()])
      object.fill_path(path, 0)
      start += sweep
    }
    return
  }
  let left = x + 20.0
  let top = y + 20.0
  let plot_width = Double::max(1.0, width - 40.0)
  let plot_height = Double::max(1.0, height - 40.0)
  let baseline = top + plot_height
  object.line(1.0F, 0, 0, 8.0F)
  object.stroke_color(0x000000ffU)
  object.stroke_rect(
    Float::from_double(left),
    Float::from_double(top),
    Float::from_double(plot_width),
    Float::from_double(plot_height),
  )
  object.fill_color(fill)
  let slot = plot_width / values.length().to_double()
  let bar_width = slot * 0.6
  if is_line {
    let path = object.add_path(
      @core.Inline(
        pptx_line_path(values, maximum, left, top, plot_width, plot_height),
      ),
    )
    object.line(2.0F, 0, 0, 8.0F)
    object.stroke_color(fill)
    object.stroke_path(path)
    object.fill_color(fill)
    let count = values.length().to_double()
    for index, value in values {
      let x = if count <= 1.0 {
        left + plot_width / 2.0
      } else {
        left + plot_width * index.to_double() / (count - 1.0)
      }
      let y = baseline - plot_height * value / maximum
      object.fill_rect(
        Float::from_double(x - 2.0),
        Float::from_double(y - 2.0),
        4.0,
        4.0,
      )
    }
  } else {
    for index, value in values {
      let bar_height = plot_height * value / maximum
      object.fill_rect(
        Float::from_double(left + slot * index.to_double() + slot * 0.2),
        Float::from_double(baseline - bar_height),
        Float::from_double(bar_width),
        Float::from_double(bar_height),
      )
    }
  }
  if !categories.is_empty() {
    let (_, minor) = fonts
    let font = object.add_font({
      hash: None,
      family: minor,
      weight: 400,
      style: 0,
    })
    object.font(font, 8.0F)
    object.fill_color(0x000000ffU)
    for index in 0..<Int32::min(categories.length(), values.length()) {
      object.fill_text(
        categories[index],
        Float::from_double(left + slot * index.to_double()),
        Float::from_double(baseline + 10.0),
        Float::from_double(pptx_text_width(categories[index], 8.0)),
      )
    }
  }
}

///|
fn pptx_u32_be(data : Bytes, offset : Int32) -> Int32 {
  (data[offset].to_int() << 24) |
  (data[offset + 1].to_int() << 16) |
  (data[offset + 2].to_int() << 8) |
  data[offset + 3].to_int()
}

///|
fn pptx_png_size(data : Bytes) -> (Int32, Int32)? {
  if data.length() < 24 || data[:8] != b"\x89PNG\r\n\x1a\n"[:] {
    return None
  }
  Some((pptx_u32_be(data, 16), pptx_u32_be(data, 20)))
}

///|
fn pptx_src_rect(shape : PptxXmlNode) -> (Double, Double, Double, Double)? {
  let rect = pptx_child(pptx_child(Some(shape), "blipFill"), "srcRect")
  match rect {
    Some(value) => {
      let factor = fn(name) {
        (@string.parse_double(pptx_attribute(value.element, name, "0")) catch {
          _ => 0.0
        }) /
        100000.0
      }
      let left = factor("l")
      let top = factor("t")
      let right = factor("r")
      let bottom = factor("b")
      if left <= 0.0 && top <= 0.0 && right <= 0.0 && bottom <= 0.0 {
        None
      } else {
        Some((left, top, right, bottom))
      }
    }
    None => None
  }
}

///|
fn pptx_picture_alpha(shape : PptxXmlNode) -> Double? {
  let blip = pptx_child(pptx_child(Some(shape), "blipFill"), "blip")
  let fix = pptx_child(blip, "alphaModFix")
  match fix {
    Some(value) =>
      match pptx_attribute(value.element, "amt", "") {
        "" => None
        text =>
          Some((@string.parse_double(text) catch { _ => 100000.0 }) / 100000.0)
      }
    None => None
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
  page_index : Int32,
  index_runs : Array[@core.IndexRun],
  index_budget : @render.TextExtractionBudget,
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
  let shapes : Array[(PptxXmlNode, PptxPlacement)] = []
  let root_placement : PptxPlacement = {
    sx: 1.0,
    sy: 1.0,
    tx: 0.0,
    ty: 0.0,
    rotation: 0.0,
    cx: 0.0,
    cy: 0.0,
  }
  for index in 0..<roots.length() {
    let tree = pptx_child(pptx_child(Some(roots[index]), "cSld"), "spTree")
    match tree {
      Some(value) =>
        pptx_collect_shapes(
          value,
          root_placement,
          index + 1 < roots.length(),
          shapes,
        )
      None => ()
    }
  }
  for shape_entry in shapes {
    let (shape, placement) = shape_entry
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
    let draw_width = transform.width * placement.sx
    let draw_height = transform.height * placement.sy
    if draw_width <= 0.0 || draw_height <= 0.0 {
      continue
    }
    let shape_x = placement.tx + transform.x * placement.sx
    let shape_y = placement.ty + transform.y * placement.sy
    if shape.element.name.local_name == "graphicFrame" {
      if pptx_table_lines(shape).is_empty() {
        pptx_emit_chart(
          shape, package, part, object, shape_x, shape_y, draw_width, draw_height,
          theme, theme_fonts,
        )
      } else {
        pptx_emit_table(
          shape, object, shape_x, shape_y, draw_width, theme, theme_fonts,
        )
      }
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
      let pic_rotation = transform.rotation + placement.rotation
      let pic_transformed = pic_rotation != 0.0 ||
        transform.flip_h ||
        transform.flip_v
      let pic_cx = if placement.rotation != 0.0 {
        placement.cx
      } else {
        shape_x + draw_width / 2.0
      }
      let pic_cy = if placement.rotation != 0.0 {
        placement.cy
      } else {
        shape_y + draw_height / 2.0
      }
      if pic_transformed {
        let radians = pic_rotation * 3.141592653589793 / 180.0
        let sine = @math.sin(radians)
        let cosine = @math.cos(radians)
        object.save()
        object.translate(Float::from_double(pic_cx), Float::from_double(pic_cy))
        object.transform(
          Float::from_double(cosine),
          Float::from_double(sine),
          Float::from_double(-sine),
          Float::from_double(cosine),
          0.0F,
          0.0F,
        )
        if transform.flip_h || transform.flip_v {
          object.scale(
            if transform.flip_h {
              -1.0F
            } else {
              1.0F
            },
            if transform.flip_v {
              -1.0F
            } else {
              1.0F
            },
          )
        }
        object.translate(
          Float::from_double(-pic_cx),
          Float::from_double(-pic_cy),
        )
      }
      let alpha = pptx_picture_alpha(shape)
      if alpha is Some(_) {
        object.save()
        object.alpha(Float::from_double(alpha.unwrap()))
      }
      let index = object.add_image(hash)
      let mut cropped = false
      match (pptx_png_size(bytes), pptx_src_rect(shape)) {
        (Some((image_width, image_height)), Some((left, top, right, bottom))) => {
          let sx = left * image_width.to_double()
          let sy = top * image_height.to_double()
          let sw = (1.0 - left - right) * image_width.to_double()
          let sh = (1.0 - top - bottom) * image_height.to_double()
          if sw > 0.0 && sh > 0.0 {
            object.image_sub(
              index,
              Float::from_double(sx),
              Float::from_double(sy),
              Float::from_double(sw),
              Float::from_double(sh),
              Float::from_double(shape_x),
              Float::from_double(shape_y),
              Float::from_double(draw_width),
              Float::from_double(draw_height),
            )
            cropped = true
          }
        }
        _ => ()
      }
      if !cropped {
        object.image(
          index,
          Float::from_double(shape_x),
          Float::from_double(shape_y),
          Float::from_double(draw_width),
          Float::from_double(draw_height),
        )
      }
      if alpha is Some(_) {
        object.restore()
      }
      if pic_transformed {
        object.restore()
      }
      continue
    }
    let geom = pptx_child(pptx_child(Some(shape), "spPr"), "prstGeom")
    let geometry = match geom {
      Some(value) => pptx_attribute(value.element, "prst", "rect")
      None => "rect"
    }
    let corner_radius = if geometry == "roundRect" {
      let fraction = match pptx_child(pptx_child(geom, "avLst"), "gd") {
        Some(value) => {
          let fmla = pptx_attribute(value.element, "fmla", "val 16667")
          let token = match fmla.split(" ").last() {
            Some(value) => value.to_string()
            None => "16667"
          }
          (@string.parse_double(token) catch { _ => 16667.0 }) / 100000.0
        }
        None => 0.16667
      }
      fraction * Double::min(draw_width, draw_height)
    } else {
      0.0
    }
    let fill = pptx_node_color(
      pptx_child(Some(shape), "spPr"),
      "solidFill",
      theme,
    )
    let fill_alpha = pptx_node_alpha(
      pptx_child(Some(shape), "spPr"),
      "solidFill",
    )
    let gradient = pptx_gradient_paint(
      shape, shape_x, shape_y, draw_width, draw_height, theme,
    )
    let mut gradient_done = false
    match gradient {
      Some(paint) =>
        if geometry == "rect" {
          object.fill_paint(object.add_paint(paint))
          object.fill_rect(
            Float::from_double(shape_x),
            Float::from_double(shape_y),
            Float::from_double(draw_width),
            Float::from_double(draw_height),
          )
          gradient_done = true
        } else if geometry == "ellipse" {
          object.fill_paint(object.add_paint(paint))
          let mut path = pptx_rotate_path(
            pptx_ellipse_path(shape_x, shape_y, draw_width, draw_height),
            shape_x + draw_width / 2.0,
            shape_y + draw_height / 2.0,
            transform.rotation,
          )
          if placement.rotation != 0.0 {
            path = pptx_rotate_path(
              path,
              placement.cx,
              placement.cy,
              placement.rotation,
            )
          }
          object.fill_path(object.add_path(@core.Inline(path)), 0)
          gradient_done = true
        } else if geometry == "roundRect" {
          object.fill_paint(object.add_paint(paint))
          let mut path = pptx_rotate_path(
            pptx_round_rect_path(
              shape_x, shape_y, draw_width, draw_height, corner_radius,
            ),
            shape_x + draw_width / 2.0,
            shape_y + draw_height / 2.0,
            transform.rotation,
          )
          if placement.rotation != 0.0 {
            path = pptx_rotate_path(
              path,
              placement.cx,
              placement.cy,
              placement.rotation,
            )
          }
          object.fill_path(object.add_path(@core.Inline(path)), 0)
          gradient_done = true
        }
      None => ()
    }
    if !gradient_done {
      match fill {
        Some(color) => {
          if fill_alpha is Some(_) {
            object.save()
            object.alpha(Float::from_double(fill_alpha.unwrap()))
          }
          object.fill_color(color)
          if geometry == "rect" &&
            (transform.rotation != 0.0 || placement.rotation != 0.0) {
            let group = placement.rotation != 0.0
            let path_index = object.add_path(
              @core.Inline(
                pptx_rotated_rect_path_at(
                  shape_x,
                  shape_y,
                  draw_width,
                  draw_height,
                  transform.rotation + placement.rotation,
                  if group {
                    placement.cx
                  } else {
                    shape_x + draw_width / 2.0
                  },
                  if group {
                    placement.cy
                  } else {
                    shape_y + draw_height / 2.0
                  },
                ),
              ),
            )
            object.fill_path(path_index, 0)
          } else if geometry == "ellipse" {
            let mut path = pptx_rotate_path(
              pptx_ellipse_path(shape_x, shape_y, draw_width, draw_height),
              shape_x + draw_width / 2.0,
              shape_y + draw_height / 2.0,
              transform.rotation,
            )
            if placement.rotation != 0.0 {
              path = pptx_rotate_path(
                path,
                placement.cx,
                placement.cy,
                placement.rotation,
              )
            }
            object.fill_path(object.add_path(@core.Inline(path)), 0)
          } else if geometry == "roundRect" {
            let mut path = pptx_rotate_path(
              pptx_round_rect_path(
                shape_x, shape_y, draw_width, draw_height, corner_radius,
              ),
              shape_x + draw_width / 2.0,
              shape_y + draw_height / 2.0,
              transform.rotation,
            )
            if placement.rotation != 0.0 {
              path = pptx_rotate_path(
                path,
                placement.cx,
                placement.cy,
                placement.rotation,
              )
            }
            object.fill_path(object.add_path(@core.Inline(path)), 0)
          } else {
            object.fill_rect(
              Float::from_double(shape_x),
              Float::from_double(shape_y),
              Float::from_double(draw_width),
              Float::from_double(draw_height),
            )
          }
        }
        None => ()
      }
    }
    if fill_alpha is Some(_) {
      object.restore()
    }
    let stroke = pptx_child(pptx_child(Some(shape), "spPr"), "ln")
    let stroke_width = match stroke {
      Some(value) =>
        (@string.parse_double(pptx_attribute(value.element, "w", "0")) catch {
          _ => 0.0
        }) /
        12700.0
      None => 0.0
    }
    if stroke_width > 0.0 {
      let stroke_color = match pptx_node_color(stroke, "solidFill", theme) {
        Some(color) => color
        None => 0x000000ffU
      }
      if geometry == "rect" &&
        (transform.rotation != 0.0 || placement.rotation != 0.0) {
        let group = placement.rotation != 0.0
        let path_index = object.add_path(
          @core.Inline(
            pptx_rotated_rect_path_at(
              shape_x,
              shape_y,
              draw_width,
              draw_height,
              transform.rotation + placement.rotation,
              if group {
                placement.cx
              } else {
                shape_x + draw_width / 2.0
              },
              if group {
                placement.cy
              } else {
                shape_y + draw_height / 2.0
              },
            ),
          ),
        )
        object.line(Float::from_double(stroke_width), 0, 0, 8.0F)
        object.stroke_color(stroke_color)
        object.stroke_path(path_index)
      } else if geometry == "ellipse" {
        let mut path = pptx_rotate_path(
          pptx_ellipse_path(shape_x, shape_y, draw_width, draw_height),
          shape_x + draw_width / 2.0,
          shape_y + draw_height / 2.0,
          transform.rotation,
        )
        if placement.rotation != 0.0 {
          path = pptx_rotate_path(
            path,
            placement.cx,
            placement.cy,
            placement.rotation,
          )
        }
        object.line(Float::from_double(stroke_width), 0, 0, 8.0F)
        object.stroke_color(stroke_color)
        object.stroke_path(object.add_path(@core.Inline(path)))
      } else if geometry == "roundRect" {
        let mut path = pptx_rotate_path(
          pptx_round_rect_path(
            shape_x, shape_y, draw_width, draw_height, corner_radius,
          ),
          shape_x + draw_width / 2.0,
          shape_y + draw_height / 2.0,
          transform.rotation,
        )
        if placement.rotation != 0.0 {
          path = pptx_rotate_path(
            path,
            placement.cx,
            placement.cy,
            placement.rotation,
          )
        }
        object.line(Float::from_double(stroke_width), 0, 0, 8.0F)
        object.stroke_color(stroke_color)
        object.stroke_path(object.add_path(@core.Inline(path)))
      } else if geometry == "rect" || geometry == "" {
        object.line(Float::from_double(stroke_width), 0, 0, 8.0F)
        object.stroke_color(stroke_color)
        object.stroke_rect(
          Float::from_double(shape_x),
          Float::from_double(shape_y),
          Float::from_double(draw_width),
          Float::from_double(draw_height),
        )
      }
    }
    let body = match pptx_child(Some(shape), "txBody") {
      Some(value) => value
      None => continue
    }
    let text_rotation = transform.rotation + placement.rotation
    let text_cx = if placement.rotation != 0.0 {
      placement.cx
    } else {
      shape_x + draw_width / 2.0
    }
    let text_cy = if placement.rotation != 0.0 {
      placement.cy
    } else {
      shape_y + draw_height / 2.0
    }
    let text_rotated = text_rotation != 0.0
    if text_rotated {
      let radians = text_rotation * 3.141592653589793 / 180.0
      let sine = @math.sin(radians)
      let cosine = @math.cos(radians)
      object.save()
      object.translate(Float::from_double(text_cx), Float::from_double(text_cy))
      object.transform(
        Float::from_double(cosine),
        Float::from_double(sine),
        Float::from_double(-sine),
        Float::from_double(cosine),
        0.0F,
        0.0F,
      )
      object.translate(
        Float::from_double(-text_cx),
        Float::from_double(-text_cy),
      )
    }
    let line : Array[PptxLineItem] = []
    let mut line_width = 0.0
    let mut line_height = 21.6
    let left_inset = pptx_body_inset(body, "lIns")
    let top_inset = pptx_body_inset(body, "tIns")
    let mut y = shape_y + top_inset + line_height
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
      let mut x = shape_x + left_inset
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
            "right" => offset = Double::max(0.0, draw_width - total)
            "center" => offset = Double::max(0.0, (draw_width - total) / 2.0)
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
            if x + advance > shape_x + draw_width && !line.is_empty() {
              flush()
              y += line_height
              x = shape_x
            }
            if y > shape_y + draw_height {
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
    if text_rotated {
      object.restore()
    }
  }
  let encoded = object.encode()
  let hash = writer.add_part("obj", encoded)
  let content = @render.extract_text_with_budget(
    @core.decode_object_resources(encoded),
    fn(_) { None },
    index_budget,
  ) catch {
    _ => { runs: [], links: [], nodes: [], }
  }
  for i, run in content.runs {
    index_runs.push({
      a: page_index,
      b: 0,
      ordinal: run.ordinal,
      separator: if i == 0 {
        2
      } else {
        run.separator
      },
      text: run.text,
    })
  }
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
  let index_runs : Array[@core.IndexRun] = []
  let index_budget = @render.TextExtractionBudget::new()
  for slide in presentation.slides {
    if slide.hidden {
      continue
    }
    let page_index = pages.length()
    pages.push(
      pptx_render_slide(
        pkg,
        slide.part,
        presentation.width,
        presentation.height,
        writer,
        theme,
        theme_fonts,
        page_index,
        index_runs,
        index_budget,
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
  if !index_runs.is_empty() {
    let encoded = @core.encode_text_index(index_runs) catch { _ => b"" }
    if encoded.length() > 0 {
      view["textIndex"] = Json::string(writer.add_part("idx", encoded))
    }
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
