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
  face : String
  choice : @fontdb.Choice?
  record_family : String
  record_weight : Int32
  record_style : Int32
  asc : Double
  desc : Double
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
  // The names a color scheme maps to (bg1 …) are the ones the parts use.
  for
    (alias, source) in [
      ("bg1", "lt1"),
      ("tx1", "dk1"),
      ("bg2", "lt2"),
      ("tx2", "dk2"),
      ("accent1", "accent1"),
      ("accent2", "accent2"),
      ("accent3", "accent3"),
      ("accent4", "accent4"),
      ("accent5", "accent5"),
      ("accent6", "accent6"),
    ] {
    if !colors.contains(alias) {
      match colors.get(source) {
        Some(value) => colors[alias] = value
        None => ()
      }
    }
  }
  colors
}

///|
fn pptx_theme_fonts(package : @ooxml.OoxmlPackage) -> PptxThemeFonts {
  let default : PptxThemeFonts = {
    major: "sans-serif",
    minor: "sans-serif",
    major_ea: "",
    minor_ea: "",
  }
  let part = match package.relationship_of_type("", "/theme") {
    Some(rel) => rel.target
    None => "ppt/theme/theme1.xml"
  }
  if !package.has(part) {
    return default
  }
  let root = pptx_read_xml(package, part) catch { _ => return default }
  let scheme = pptx_child(pptx_child(Some(root), "themeElements"), "fontScheme")
  let typeface = fn(node : PptxXmlNode?, key : String) -> String {
    match pptx_child(node, key) {
      Some(value) =>
        match pptx_attribute(value.element, "typeface", "") {
          "" => "sans-serif"
          name => name
        }
      None => "sans-serif"
    }
  }
  let ea_typeface = fn(node : PptxXmlNode?, key : String) -> String {
    match pptx_child(node, key) {
      Some(value) => pptx_attribute(value.element, "typeface", "")
      None => ""
    }
  }
  let major = pptx_child(scheme, "majorFont")
  let minor = pptx_child(scheme, "minorFont")
  {
    major: typeface(major, "latin"),
    minor: typeface(minor, "latin"),
    major_ea: ea_typeface(major, "ea"),
    minor_ea: ea_typeface(minor, "ea"),
  }
}

///|
/// The theme's fill and line style matrices: a p:style fillRef or lnRef
/// names an entry (1-based) of one of these lists.
fn pptx_theme_style_lists(
  package : @ooxml.OoxmlPackage,
) -> (Array[PptxXmlNode], Array[PptxXmlNode], Array[PptxXmlNode]) {
  let empty : (Array[PptxXmlNode], Array[PptxXmlNode], Array[PptxXmlNode]) = (
    [],
    [],
    [],
  )
  let part = match package.relationship_of_type("", "/theme") {
    Some(rel) => rel.target
    None => "ppt/theme/theme1.xml"
  }
  if !package.has(part) {
    return empty
  }
  let root = pptx_read_xml(package, part) catch { _ => return empty }
  let fmt = pptx_child(pptx_child(Some(root), "themeElements"), "fmtScheme")
  (
    pptx_children(pptx_child(fmt, "fillStyleLst")),
    pptx_children(pptx_child(fmt, "bgFillStyleLst")),
    pptx_children(pptx_child(fmt, "lnStyleLst")),
  )
}

///|
fn pptx_run_family(
  run : PptxXmlNode,
  fonts : PptxThemeFonts,
  inherited : PptxPlaceholderDefaults?,
) -> String {
  let major = fonts.major
  let minor = fonts.minor
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
fn pptx_char_width_code(code : Int32, size : Double) -> Double {
  if code == 0x20 || code == 0xa0 {
    size * 0.25
  } else if code >= 0x2e80 {
    size
  } else if code < 0x20 || code == 0x200b || code == 0xfeff {
    0.0
  } else {
    size * 0.5
  }
}

///|
fn pptx_char_width(c : Char, size : Double) -> Double {
  pptx_char_width_code(c.to_int(), size)
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
  // Without chOff/chExt the child rectangle is the group's own box.
  let ch_x = match ch_off {
    Some(value) => pptx_measure(pptx_attribute(value.element, "x", ""), off_x)
    None => off_x
  }
  let ch_y = match ch_off {
    Some(value) => pptx_measure(pptx_attribute(value.element, "y", ""), off_y)
    None => off_y
  }
  let ch_w = match ch_ext {
    Some(value) => pptx_measure(pptx_attribute(value.element, "cx", ""), ext_x)
    None => ext_x
  }
  let ch_h = match ch_ext {
    Some(value) => pptx_measure(pptx_attribute(value.element, "cy", ""), ext_y)
    None => ext_y
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
fn pptx_line_spacing(paragraph : PptxXmlNode) -> Double {
  let spacing = pptx_child(pptx_child(Some(paragraph), "pPr"), "lnSpc")
  match pptx_child(spacing, "spcPct") {
    Some(value) =>
      (@string.parse_double(pptx_attribute(value.element, "val", "100000")) catch {
        _ => 100000.0
      }) /
      100000.0
    None =>
      match pptx_child(spacing, "spcPts") {
        Some(value) =>
          (@string.parse_double(pptx_attribute(value.element, "val", "0")) catch {
            _ => 0.0
          }) /
          100.0
        None => 0.0
      }
  }
}

///|
fn pptx_paragraph_spacing(paragraph : PptxXmlNode, name : String) -> Double {
  let spacing = pptx_child(pptx_child(Some(paragraph), "pPr"), name)
  match pptx_child(spacing, "spcPts") {
    Some(value) =>
      (@string.parse_double(pptx_attribute(value.element, "val", "0")) catch {
        _ => 0.0
      }) /
      100.0
    None => 0.0
  }
}

///|
fn pptx_body_anchor(body : PptxXmlNode) -> String {
  match pptx_child(Some(body), "bodyPr") {
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
  18.0
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
fn pptx_cell_is_vmerge(cell : PptxXmlNode) -> Bool {
  pptx_attribute(cell.element, "vMerge", "0") == "1"
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
fn pptx_gradient_node(
  gradient : PptxXmlNode?,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  theme : Map[String, UInt32],
) -> @core.Paint? {
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
fn pptx_gradient_paint(
  shape : PptxXmlNode,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  theme : Map[String, UInt32],
) -> @core.Paint? {
  pptx_gradient_node(
    pptx_child(pptx_child(Some(shape), "spPr"), "gradFill"),
    x,
    y,
    width,
    height,
    theme,
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
fn pptx_tint_color(color : UInt32, fraction : Double) -> UInt32 {
  let channel = fn(shift : Int32) -> Double {
    let value = pptx_color_channel(color, shift)
    value + (255.0 - value) * fraction
  }
  pptx_pack_color(channel(24), channel(16), channel(8))
}

fn pptx_some_or(first : UInt32?, second : UInt32?) -> UInt32? {
  match first {
    Some(value) => Some(value)
    None => second
  }
}

///|
fn pptx_table_style_accent(
  theme : Map[String, UInt32],
  accent : Int32,
) -> UInt32 {
  if accent == 0 {
    return match theme.get("dk1") {
      Some(value) => value
      None => 0x000000ffU
    }
  }
  let key = "accent" + accent.to_string()
  match theme.get(key) {
    Some(value) => value
    None => 0x4472c4ffU
  }
}

///|
fn pptx_shade_color(color : UInt32, fraction : Double) -> UInt32 {
  let channel = fn(shift : Int32) -> Double {
    pptx_color_channel(color, shift) * fraction
  }
  pptx_pack_color(channel(24), channel(16), channel(8))
}

///|
/// A cell fill from a synthesized built-in table style, or None for an
/// unknown style ID.
fn pptx_table_style_fill(
  theme : Map[String, UInt32],
  style_id : String,
  first_row : Bool,
  band_row : Bool,
  last_row : Bool,
  first_col : Bool,
  last_col : Bool,
  row_index : Int,
  col_index : Int,
  row_count : Int,
  col_count : Int,
) -> UInt32? {
  let info = match pptx_table_style_family(style_id) {
    Some(value) => value
    None => return None
  }
  let (family, accent_index) = info
  let accent = pptx_table_style_accent(theme, accent_index)
  let lt1 = match theme.get("lt1") {
    Some(value) => value
    None => 0xffffffffU
  }
  let dk1 = match theme.get("dk1") {
    Some(value) => value
    None => 0x000000ffU
  }
  let pair = if accent_index > 0 {
    pptx_table_style_accent(theme, accent_index % 6 + 1)
  } else {
    dk1
  }
  let whole = match family {
    "Themed-Style-1" | "Light-Style-1" | "Light-Style-2" | "Light-Style-3" => None
    "Themed-Style-2" => Some(accent)
    "Medium-Style-1" | "Medium-Style-3" => Some(lt1)
    "Medium-Style-2" | "Medium-Style-4" => Some(pptx_tint_color(accent, 0.2))
    "Dark-Style-1" =>
      Some(if accent_index == 0 {
        pptx_tint_color(dk1, 0.75)
      } else {
        pptx_shade_color(accent, 0.2)
      })
    "Dark-Style-2" => Some(pptx_tint_color(accent, 0.2))
    _ => None
  }
  let header = match family {
    "Themed-Style-1" | "Light-Style-2" | "Medium-Style-1" |
      "Medium-Style-2" | "Medium-Style-3" =>
      Some(accent)
    "Medium-Style-4" => Some(pptx_tint_color(accent, 0.2))
    "Dark-Style-1" => Some(dk1)
    "Dark-Style-2" => Some(pair)
    _ => None
  }
  let band = match family {
    "Themed-Style-1" => Some(pptx_tint_color(accent, 0.4))
    "Themed-Style-2" => Some(pptx_tint_color(accent, 0.8))
    "Light-Style-1" | "Light-Style-3" | "Medium-Style-1" =>
      Some(pptx_tint_color(accent, 0.2))
    "Medium-Style-2" | "Medium-Style-4" | "Dark-Style-2" =>
      Some(pptx_tint_color(accent, 0.4))
    "Medium-Style-3" => Some(pptx_tint_color(dk1, 0.2))
    "Dark-Style-1" => Some(pptx_shade_color(accent, 0.4))
    _ => None
  }
  if (last_row && row_index == row_count - 1) ||
    (first_col && col_index == 0) ||
    (last_col && col_index == col_count - 1) {
    return Some(match family {
      "Dark-Style-1" => if last_row && row_index == row_count - 1 {
        pptx_shade_color(accent, 0.5)
      } else {
        pptx_shade_color(accent, 0.6)
      }
      "Medium-Style-4" => if last_row && row_index == row_count - 1 {
        pptx_tint_color(accent, 0.2)
      } else {
        accent
      }
      _ => match header {
        Some(value) => value
        None => match whole {
          Some(value) => value
          None => lt1
        }
      }
    })
  }
  if first_row && row_index == 0 {
    return pptx_some_or(header, whole)
  }
  let first = if first_row { 1 } else { 0 }
  if band_row && row_index >= first && (row_index - first) % 2 == 0 {
    return pptx_some_or(band, whole)
  }
  whole
}

///|
fn pptx_table_style_text(
  theme : Map[String, UInt32],
  style_id : String,
  first_row : Bool,
  last_row : Bool,
  first_col : Bool,
  last_col : Bool,
  row_index : Int,
  col_index : Int,
  row_count : Int,
  col_count : Int,
) -> (UInt32, Bool)? {
  let info = match pptx_table_style_family(style_id) {
    Some(value) => value
    None => return None
  }
  let (family, accent_index) = info
  let accent = pptx_table_style_accent(theme, accent_index)
  let lt1 = match theme.get("lt1") {
    Some(value) => value
    None => 0xffffffffU
  }
  let dk1 = match theme.get("dk1") {
    Some(value) => value
    None => 0x000000ffU
  }
  let header_text = match family {
    "Light-Style-3" | "Medium-Style-4" => accent
    "Dark-Style-1" => lt1
    _ => lt1
  }
  let body_text = match family {
    "Themed-Style-2" | "Dark-Style-1" => lt1
    _ => dk1
  }
  let special = (first_row && row_index == 0) ||
    (last_row && row_index == row_count - 1) ||
    (first_col && col_index == 0) ||
    (last_col && col_index == col_count - 1)
  if special {
    Some((header_text, true))
  } else {
    Some((body_text, false))
  }
}

///|
/// Table-style borders for a synthesized built-in style. The sides follow
/// the same family definitions as the fills.
fn pptx_table_style_borders(
  theme : Map[String, UInt32],
  style_id : String,
  first_row : Bool,
  last_row : Bool,
  first_col : Bool,
  last_col : Bool,
  row_index : Int,
  row_count : Int,
  col_index : Int,
  col_count : Int,
) -> Array[(Int32, Double, UInt32)] {
  let borders : Array[(Int32, Double, UInt32)] = []
  let info = match pptx_table_style_family(style_id) {
    Some(value) => value
    None => return borders
  }
  let (family, accent_index) = info
  let accent = pptx_table_style_accent(theme, accent_index)
  let lt1 = match theme.get("lt1") {
    Some(value) => value
    None => 0xffffffffU
  }
  let dk1 = match theme.get("dk1") {
    Some(value) => value
    None => 0x000000ffU
  }
  let add = fn(side : Int32, width : Double, color : UInt32) -> Unit {
    borders.push((side, width, color))
  }
  let all = fn(width : Double, color : UInt32) -> Unit {
    for side in 0..<4 {
      add(side, width, color)
    }
  }
  let header = first_row && row_index == 0
  let final = last_row && row_index == row_count - 1
  match family {
    "Themed-Style-1" => {
      all(1.0, accent)
      if header {
        add(2, 2.0, accent)
      }
      if final {
        add(0, 2.0, accent)
      }
    }
    "Themed-Style-2" => {
      all(1.0, lt1)
      if header {
        add(2, 2.0, lt1)
      }
      if final {
        add(0, 2.0, lt1)
      }
    }
    "Light-Style-1" => {
      if row_index == 0 {
        add(0, 1.0, accent)
      }
      if row_index == row_count - 1 {
        add(2, 1.0, accent)
      }
      if header {
        add(2, 1.0, accent)
      }
    }
    "Light-Style-2" => all(1.0, accent)
    "Light-Style-3" => {
      all(1.0, accent)
      if header {
        add(2, 2.0, accent)
      }
    }
    "Medium-Style-1" => {
      all(1.0, accent)
      if header {
        add(2, 2.0, accent)
      }
      if final {
        add(0, 2.0, accent)
      }
    }
    "Medium-Style-2" => {
      all(1.0, lt1)
      if header {
        add(2, 3.0, lt1)
      }
      if final {
        add(0, 3.0, lt1)
      }
    }
    "Medium-Style-3" => {
      if row_index == 0 {
        add(0, 2.0, dk1)
      }
      if row_index == row_count - 1 {
        add(2, 2.0, dk1)
      }
      if header {
        add(2, 2.0, dk1)
      }
      if final {
        add(0, 2.0, dk1)
      }
    }
    "Medium-Style-4" => {
      all(1.0, accent)
      if final {
        add(0, 2.0, accent)
      }
    }
    "Dark-Style-1" => {
      if header {
        add(2, 2.0, lt1)
      }
      if final {
        add(0, 2.0, lt1)
      }
      if first_col && col_index == 0 {
        add(1, 2.0, lt1)
      }
      if last_col && col_index == col_count - 1 {
        add(3, 2.0, lt1)
      }
    }
    "Dark-Style-2" =>
      if final {
        add(0, 2.0, dk1)
      }
    _ => ()
  }
  borders
}

///|
fn pptx_emit_table(
  shape : PptxXmlNode,
  object : @core.ObjectBuilder,
  x : Double,
  y : Double,
  width : Double,
  theme : Map[String, UInt32],
  fonts : PptxThemeFonts,
  font_ctx : PptxFontContext,
) -> Unit raise {
  let lines = pptx_table_lines(shape)
  if lines.is_empty() {
    return
  }
  let table = pptx_child(
    pptx_child(pptx_child(Some(shape), "graphic"), "graphicData"),
    "tbl",
  )
  let table_props = pptx_child(table, "tblPr")
  let style_id = match pptx_child(table_props, "tableStyleId") {
    Some(value) => value.text.to_string()
    None => ""
  }
  let first_row = pptx_attribute(
    match table_props { Some(value) => value.element; None => shape.element },
    "firstRow",
    "0",
  ) == "1"
  let band_row = pptx_attribute(
    match table_props { Some(value) => value.element; None => shape.element },
    "bandRow",
    "0",
  ) == "1"
  let last_row = pptx_attribute(
    match table_props { Some(value) => value.element; None => shape.element },
    "lastRow",
    "0",
  ) == "1"
  let first_col = pptx_attribute(
    match table_props { Some(value) => value.element; None => shape.element },
    "firstCol",
    "0",
  ) == "1"
  let last_col = pptx_attribute(
    match table_props { Some(value) => value.element; None => shape.element },
    "lastCol",
    "0",
  ) == "1"
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
  let row_count = row_heights.length()
  let col_count = if grid.length() > 0 { grid.length() } else { 1 }
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
      if cell.element.name.local_name != "tc" || pptx_cell_is_vmerge(cell) {
        continue
      }
      let span = pptx_cell_grid_span(cell)
      let grid_index = cell_index.to_int()
      let mut column_width = if grid_index >= 0 && grid_index < grid.length() {
        grid[grid_index]
      } else {
        cell_width
      }
      if span > 1 && grid_index >= 0 && grid_index + span <= grid.length() {
        column_width = 0.0
        for k in 0..<span {
          column_width += grid[grid_index + k]
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
      let explicit_fill = pptx_node_color(
        pptx_child(Some(cell), "tcPr"), "solidFill", theme,
      )
      let style_fill = pptx_table_style_fill(
        theme, style_id, first_row, band_row, last_row, first_col, last_col,
        row_index, grid_index, row_count, col_count,
      )
      match explicit_fill {
        Some(color) => {
          object.fill_color(color)
          object.fill_rect(
            Float::from_double(cell_x),
            Float::from_double(row_top),
            Float::from_double(column_width),
            Float::from_double(cell_height),
          )
        }
        None =>
          match style_fill {
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
      }
      let explicit_borders = pptx_cell_borders(cell, theme)
      let borders = if explicit_borders.is_empty() {
        pptx_table_style_borders(
          theme, style_id, first_row, last_row, first_col, last_col,
          row_index, row_count, grid_index, col_count,
        )
      } else {
        explicit_borders
      }
      for border in borders {
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
  let minor = fonts.minor
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
      if cell.element.name.local_name != "tc" || pptx_cell_is_vmerge(cell) {
        continue
      }
      let span = pptx_cell_grid_span(cell)
      let grid_index = cell_index.to_int()
      let mut column_width = if grid_index >= 0 && grid_index < grid.length() {
        grid[grid_index]
      } else {
        cell_width
      }
      if span > 1 && grid_index >= 0 && grid_index + span <= grid.length() {
        column_width = 0.0
        for k in 0..<span {
          column_width += grid[grid_index + k]
        }
      }
      let text = pptx_cell_text(cell)
      if text != "" {
        let size = pptx_cell_text_size(cell)
        let italic = pptx_cell_italic(cell)
        let style_text = pptx_table_style_text(
          theme, style_id, first_row, last_row, first_col, last_col,
          text_row, grid_index, row_count, col_count,
        )
        let (bold, color) = match style_text {
          Some((value, is_bold)) => (
            if is_bold { 700 } else { pptx_cell_bold(cell) },
            value,
          )
          None => (pptx_cell_bold(cell), pptx_cell_color(cell, theme))
        }
        let margin_left = pptx_cell_margin(cell, "marL", 7.2)
        let margin_right = pptx_cell_margin(cell, "marR", 7.2)
        let margin_top = pptx_cell_margin(cell, "marT", 3.6)
        let margin_bottom = pptx_cell_margin(cell, "marB", 3.6)
        let inner = Double::max(1.0, column_width - margin_left - margin_right)
        let align = match pptx_cell_alignment(cell) {
          "center" => 1
          "right" => 2
          _ => 0
        }
        let props : PptxParagraphProps = {
          level: 0,
          align,
          mar_l: 0.0,
          indent: 0.0,
          ln_pct: 1.0,
          ln_pts: 0.0,
          bef_pct: 0.0,
          bef_pts: 0.0,
          aft_pct: 0.0,
          aft_pts: 0.0,
        }
        let chars = pptx_char_to_styled(
          font_ctx,
          text,
          minor,
          fonts.minor_ea,
          bold,
          italic,
          size,
          color,
        )
        let layout = pptx_layout_paragraph(
          chars, props, "", 0.0, minor, bold, italic, color, inner, font_ctx,
        )
        let mut total = 0.0
        for line in layout.lines {
          total += line.height
        }
        let mut text_y = match pptx_cell_vertical_anchor(cell) {
          "center" => text_top + (row_height - total) / 2.0
          "bottom" => text_top + row_height - margin_bottom - total
          _ => text_top + margin_top
        }
        object.mark(0, "")
        let mut previous_wrap : Byte = 1
        for i, line in layout.lines {
          if i > 0 {
            object.mark(previous_wrap, "")
          }
          previous_wrap = line.wrap
          let mut offset = 0.0
          match align {
            1 => offset = Double::max(0.0, (inner - line.width) / 2.0)
            2 => offset = Double::max(0.0, inner - line.width)
            _ => ()
          }
          let baseline = text_y + line.height - line.desc
          for item in line.items {
            let font = pptx_font_ref(
              font_ctx,
              object,
              item.face,
              item.choice,
              item.record_family,
              item.record_weight,
              item.record_style,
              item.text,
            )
            object.font(font, Float::from_double(item.size))
            object.fill_color(item.color)
            object.fill_text(
              item.text,
              Float::from_double(
                cell_x + margin_left + offset + line.start + item.x,
              ),
              Float::from_double(baseline),
              Float::from_double(item.advance),
            )
          }
          text_y += line.height
        }
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
priv struct PptxChartSeries {
  name : String
  categories : Array[String]
  values : Array[Double]
  color : UInt32
}

///|
fn pptx_chart_series_name(series : PptxXmlNode) -> String {
  let names = pptx_chart_values(Some(series), "tx")
  if names.is_empty() {
    ""
  } else {
    names[0]
  }
}

///|
fn pptx_chart_nice_axis(
  maximum : Double,
  axis_length : Double,
) -> (Double, Double) {
  if maximum <= 0.0 {
    return (1.0, 1.0)
  }
  let mut max_steps = (axis_length / 40.0 + 0.5).to_int()
  if max_steps < 2 {
    max_steps = 2
  }
  if max_steps > 10 {
    max_steps = 10
  }
  let mut hi = maximum * 1.05
  let mut step = 1.0
  let magnitude = @math.pow(
    10.0,
    @math.log10(hi / max_steps.to_double()).floor(),
  )
  for multiplier in [1.0, 2.0, 5.0, 10.0, 20.0, 50.0] {
    step = multiplier * magnitude
    if @math.ceil(hi / step - 1.0e-9) <= max_steps.to_double() {
      break
    }
  }
  hi = @math.ceil(hi / step - 1.0e-9) * step
  (step, hi)
}

///|
fn pptx_chart_tick_text(value : Double) -> String {
  if (value - value.round()).abs() < 1.0e-9 {
    value.to_int().to_string()
  } else {
    let rounded = (value * 10.0 + 0.5).to_int().to_double() / 10.0
    rounded.to_string()
  }
}

///|
fn pptx_chart_collect_text(node : PptxXmlNode, out : StringBuilder) -> Unit {
  let name = node.element.name.local_name
  if name == "t" || name == "v" {
    out.write_string(node.text.to_string())
  }
  for child in node.children {
    pptx_chart_collect_text(child, out)
  }
}

///|
fn pptx_chart_title_text(chart_space : PptxXmlNode?) -> String {
  match pptx_child(chart_space, "title") {
    Some(value) => {
      let out = StringBuilder()
      pptx_chart_collect_text(value, out)
      out.to_string().trim().to_owned()
    }
    None => ""
  }
}

///|
fn pptx_chart_label(
  object : @core.ObjectBuilder,
  font : Int32,
  size : Double,
  color : UInt32,
  text : String,
  x : Double,
  y : Double,
) -> Unit raise {
  object.mark(0, "")
  object.font(font, Float::from_double(size))
  object.fill_color(color)
  object.fill_text(
    text,
    Float::from_double(x),
    Float::from_double(y),
    Float::from_double(pptx_text_width(text, size)),
  )
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
  fonts : PptxThemeFonts,
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
  let chart_space = pptx_child(Some(root), "chart")
  let plot_area = pptx_child(chart_space, "plotArea")
  let bar = pptx_child(plot_area, "barChart")
  let line_chart = pptx_child(plot_area, "lineChart")
  let pie_chart = pptx_child(plot_area, "pieChart")
  let chart = match bar {
    Some(value) => value
    None =>
      match line_chart {
        Some(value) => value
        None =>
          match pie_chart {
            Some(value) => value
            None => return
          }
      }
  }
  let kind = chart.element.name.local_name
  let is_bar = kind == "barChart"
  let is_pie = kind == "pieChart"
  let horizontal = is_bar &&
    (match pptx_child(Some(chart), "barDir") {
      Some(value) => pptx_attribute(value.element, "val", "col") == "bar"
      None => false
    })
  let stacked = is_bar &&
    (match pptx_child(Some(chart), "grouping") {
      Some(value) =>
        pptx_attribute(value.element, "val", "clustered") == "stacked"
      None => false
    })
  let palette = [
    0x4472c4ffU, 0xed7d31ffU, 0xa5a5a5ffU, 0xffc000ffU, 0x5b9bd5ffU, 0x70ad47ffU,
  ]
  let series : Array[PptxChartSeries] = []
  for item in pptx_children(Some(chart)) {
    if item.element.name.local_name != "ser" {
      continue
    }
    let values : Array[Double] = []
    for value in pptx_chart_values(Some(item), "val") {
      values.push(@string.parse_double(value) catch { _ => 0.0 })
    }
    let categories = pptx_chart_values(Some(item), "cat")
    let color = match
      pptx_node_color(pptx_child(Some(item), "spPr"), "solidFill", theme) {
      Some(value) => value
      None => palette[series.length() % palette.length()]
    }
    series.push({
      name: pptx_chart_series_name(item),
      categories,
      values,
      color,
    })
  }
  if series.is_empty() {
    return
  }
  let minor = fonts.minor
  let label_font = object.add_font({
    hash: None,
    family: minor,
    weight: 400,
    style: 0,
  })
  let label_size = 8.0
  let black = 0x000000ffU
  // An explicit c:title wins; Office titles a one-series chart with its
  // series name when the chart has no title of its own.
  let explicit_title = pptx_chart_title_text(chart_space)
  let title = if explicit_title != "" {
    explicit_title
  } else if series.length() == 1 && series[0].name != "" {
    series[0].name
  } else {
    ""
  }
  let plot_x = x + 20.0
  let mut plot_y = y + 20.0
  let mut plot_width = Double::max(1.0, width - 40.0)
  let mut plot_height = Double::max(1.0, height - 40.0)
  if title != "" {
    pptx_chart_label(
      object,
      label_font,
      10.0,
      black,
      title,
      x + width / 2.0 - pptx_text_width(title, 10.0) / 2.0,
      y + 12.0,
    )
    plot_y += 16.0
    plot_height = Double::max(1.0, plot_height - 16.0)
  }
  // legend
  let legend = pptx_child(chart_space, "legend")
  if legend is Some(_) {
    let entries : Array[String] = []
    if is_pie {
      for category in series[0].categories {
        entries.push(category)
      }
    } else {
      for item in series {
        entries.push(item.name)
      }
    }
    let position = match pptx_child(legend, "legendPos") {
      Some(value) => pptx_attribute(value.element, "val", "r")
      None => "r"
    }
    if ["b", "t"].contains(position) {
      let width_sum = entries.fold(init=0.0, (sum, value) => {
        sum + pptx_text_width(value, label_size) + 18.0
      })
      let mut legend_x = x + (width - width_sum) / 2.0
      let legend_y = if position == "b" { y + height - 8.0 } else { y + 12.0 }
      for entry in entries {
        pptx_chart_label(
          object, label_font, label_size, black, entry, legend_x, legend_y,
        )
        legend_x += pptx_text_width(entry, label_size) + 18.0
      }
      if position == "b" {
        plot_height = Double::max(1.0, plot_height - 12.0)
      }
    } else {
      let mut legend_y = plot_y + 4.0
      for entry in entries {
        pptx_chart_label(
          object,
          label_font,
          label_size,
          black,
          entry,
          x + width - 60.0,
          legend_y,
        )
        legend_y += 12.0
      }
      plot_width = Double::max(1.0, plot_width - 64.0)
    }
  }
  if is_pie {
    let values = series[0].values
    let total = values.fold(init=0.0, (sum, value) => sum + value)
    if total <= 0.0 {
      return
    }
    let cx = x + width / 2.0
    let cy = y + height / 2.0 + 8.0
    let radius = Double::min(width, height) / 2.0 - 24.0
    let mut start = -3.141592653589793 / 2.0
    for index, value in values {
      let sweep = 2.0 * 3.141592653589793 * value / total
      let path = object.add_path(
        @core.Inline(pptx_pie_path(cx, cy, radius, start, sweep)),
      )
      object.fill_color(palette[index % palette.length()])
      object.fill_path(path, 0)
      let mid = start + sweep / 2.0
      let label = (value / total * 100.0 + 0.5).to_int().to_string() + "%"
      let label_width = pptx_text_width(label, label_size)
      pptx_chart_label(
        object,
        label_font,
        label_size,
        black,
        label,
        cx + @math.cos(mid) * radius * 0.7 - label_width / 2.0,
        cy + @math.sin(mid) * radius * 0.7,
      )
      start += sweep
    }
    return
  }
  let categories = series[0].categories
  let count = Double::max(1.0, categories.length().to_double())
  let slot = if horizontal { plot_height / count } else { plot_width / count }
  let mut maximum = 0.0
  if stacked {
    for index in 0..<categories.length() {
      let mut sum = 0.0
      for item in series {
        if index < item.values.length() {
          sum += item.values[index]
        }
      }
      maximum = Double::max(maximum, sum)
    }
  } else {
    for item in series {
      for value in item.values {
        maximum = Double::max(maximum, value)
      }
    }
  }
  let (step, axis_high) = pptx_chart_nice_axis(
    maximum,
    if horizontal {
      plot_width
    } else {
      plot_height
    },
  )
  // value axis labels
  let value_axis_visible = match pptx_child(plot_area, "valAx") {
    Some(value) =>
      pptx_attribute(value.element, "delete", "0") != "1" &&
      (match pptx_child(Some(value), "tickLblPos") {
        Some(position) =>
          pptx_attribute(position.element, "val", "nextTo") != "none"
        None => true
      })
    None => false
  }
  let mut tick = 0.0
  while value_axis_visible && tick <= axis_high + step * 1.0e-6 {
    let text = pptx_chart_tick_text(tick)
    if horizontal {
      pptx_chart_label(
        object,
        label_font,
        label_size,
        black,
        text,
        plot_x + plot_width * tick / axis_high - 6.0,
        y + height - 6.0,
      )
    } else {
      let label_width = pptx_text_width(text, label_size)
      pptx_chart_label(
        object,
        label_font,
        label_size,
        black,
        text,
        plot_x - label_width - 4.0,
        plot_y + plot_height - plot_height * tick / axis_high,
      )
    }
    tick += step
  }
  // category labels
  for index, category in categories {
    if horizontal {
      let label_width = pptx_text_width(category, label_size)
      pptx_chart_label(
        object,
        label_font,
        label_size,
        black,
        category,
        plot_x - label_width - 4.0,
        plot_y + slot * index.to_double() + slot / 2.0,
      )
    } else {
      let label_width = pptx_text_width(category, label_size)
      pptx_chart_label(
        object,
        label_font,
        label_size,
        black,
        category,
        plot_x + slot * index.to_double() + (slot - label_width) / 2.0,
        y + height - 4.0,
      )
    }
  }
  object.line(1.0F, 0, 0, 8.0F)
  object.stroke_color(0xbfbfbffFU)
  object.stroke_rect(
    Float::from_double(plot_x),
    Float::from_double(plot_y),
    Float::from_double(plot_width),
    Float::from_double(plot_height),
  )
  let series_count = series.length().to_double()
  if horizontal {
    if stacked {
      for index in 0..<categories.length() {
        let mut used = 0.0
        for item in series {
          if index < item.values.length() {
            let bar_width = plot_width * item.values[index] / axis_high
            object.fill_color(item.color)
            object.fill_rect(
              Float::from_double(plot_x + plot_width * used / axis_high),
              Float::from_double(plot_y + slot * index.to_double() + slot * 0.1),
              Float::from_double(bar_width),
              Float::from_double(slot * 0.8),
            )
            used += item.values[index]
          }
        }
      }
    } else {
      for index in 0..<categories.length() {
        let sub_slot = slot / series_count
        for s, item in series {
          if index < item.values.length() {
            object.fill_color(item.color)
            object.fill_rect(
              Float::from_double(plot_x),
              Float::from_double(
                plot_y +
                slot * index.to_double() +
                sub_slot * s.to_double() +
                sub_slot * 0.1,
              ),
              Float::from_double(plot_width * item.values[index] / axis_high),
              Float::from_double(sub_slot * 0.8),
            )
          }
        }
      }
    }
  } else if stacked {
    for index in 0..<categories.length() {
      let mut used = 0.0
      for item in series {
        if index < item.values.length() {
          let bar_height = plot_height * item.values[index] / axis_high
          object.fill_color(item.color)
          object.fill_rect(
            Float::from_double(plot_x + slot * index.to_double() + slot * 0.1),
            Float::from_double(
              plot_y + plot_height - plot_height * used / axis_high - bar_height,
            ),
            Float::from_double(slot * 0.8),
            Float::from_double(bar_height),
          )
          used += item.values[index]
        }
      }
    }
  } else if line_chart is Some(_) {
    for item in series {
      if item.values.is_empty() {
        continue
      }
      let path = object.add_path(
        @core.Inline(
          pptx_line_path(
            item.values,
            axis_high,
            plot_x,
            plot_y,
            plot_width,
            plot_height,
          ),
        ),
      )
      object.line(2.0F, 0, 0, 8.0F)
      object.stroke_color(item.color)
      object.stroke_path(path)
      object.fill_color(item.color)
      let value_count = item.values.length().to_double()
      for index, value in item.values {
        let px = if value_count <= 1.0 {
          plot_x + plot_width / 2.0
        } else {
          plot_x + plot_width * index.to_double() / (value_count - 1.0)
        }
        let py = plot_y + plot_height - plot_height * value / axis_high
        object.fill_rect(
          Float::from_double(px - 2.0),
          Float::from_double(py - 2.0),
          4.0,
          4.0,
        )
      }
    }
  } else {
    let sub_slot = slot / series_count
    for index in 0..<categories.length() {
      for s, item in series {
        if index < item.values.length() {
          let bar_height = plot_height * item.values[index] / axis_high
          object.fill_color(item.color)
          object.fill_rect(
            Float::from_double(
              plot_x +
              slot * index.to_double() +
              sub_slot * s.to_double() +
              sub_slot * 0.1,
            ),
            Float::from_double(plot_y + plot_height - bar_height),
            Float::from_double(sub_slot * 0.8),
            Float::from_double(bar_height),
          )
        }
      }
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
///
/// The host supplies the fonts it found (a PowerPoint font directory, for
/// example) as `db`; with faces, text measures real glyphs and the faces it
/// uses are embedded as subsets. With no database text keeps upstream's
/// estimated metrics, no font parts are written, and one warning says so.
pub fn convert(
  data : Bytes,
  title~ : String = "",
  db~ : @fontdb.Database? = None,
) -> PptxResult raise {
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
  let core = pkg.core_properties()
  let dc : Map[String, Json] = Map([])
  let put = (key : String, values : Array[String]) => {
    if values.is_empty() {
      return
    }
    if key == "subject" {
      dc[key] = Json::array(values.map(Json::string))
    } else {
      dc[key] = Json::string(values[0])
    }
  }
  put("title", core.title)
  put("creator", core.creator)
  put("subject", core.subject)
  put("description", core.description)
  put("identifier", core.identifier)
  put("language", core.language)
  put("created", core.created)
  put("modified", core.modified)
  if core.language.is_empty() {
    let language = pptx_default_language(presentation)
    if language != "" {
      put("language", [language])
    }
  }
  if title != "" {
    dc["title"] = Json::string(title)
  }
  if !dc.is_empty() {
    meta["dc"] = Json::object(dc)
  }
  let writer = @core.DocumentWriter::new(meta=Json::object(meta))
  let theme = pptx_theme_colors(pkg)
  let theme_fonts = pptx_theme_fonts(pkg)
  let (theme_fills, theme_bg_fills, theme_lines) = pptx_theme_style_lists(pkg)
  let warnings : Array[String] = []
  let warned : Map[String, Bool] = Map([])
  let fonts = @canvas.Fonts::new(db)
  let has_fonts = fonts.has_fonts()
  let missing : Map[Int32, Bool] = Map([])
  if !has_fonts {
    warnings.push(
      "no fonts found; text is laid out with estimated metrics and not embedded",
    )
  }
  let pages : Array[Json] = []
  let index_runs : Array[@core.IndexRun] = []
  let index_budget = @render.TextExtractionBudget::new()
  let cache = pptx_new_render_cache()
  for slide in presentation.slides {
    if slide.hidden {
      continue
    }
    let page_index = pages.length()
    let root = pptx_read_xml(pkg, slide.part)
    pages.push(
      pptx_render_page(
        pkg,
        writer,
        theme,
        theme_fonts,
        theme_fills,
        theme_bg_fills,
        theme_lines,
        presentation.default_text_style,
        slide.part,
        root,
        presentation.width,
        presentation.height,
        page_index,
        index_runs,
        index_budget,
        cache,
        warnings,
        warned,
        fonts,
        missing,
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
    "id": Json::string("slides"),
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
  let embedded_fonts = cache.embedded_fonts
  if has_fonts {
    match pptx_missing_glyph_warning(missing) {
      Some(message) => warnings.push(message)
      None => ()
    }
  }
  {
    bdf: writer.write_single(),
    pages: count,
    summary: "\{count} slide(s), \{embedded_fonts} embedded font(s)",
    warnings,
  }
}
