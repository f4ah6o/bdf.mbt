///|
/// An unresolved spreadsheet color (none, RGB, theme, indexed or automatic).
pub(all) struct XlsxColor {
  kind : Int32
  rgb : UInt32
  index : Int32
  tint : Double
}

///|
/// A spreadsheet font definition.
pub(all) struct XlsxFont {
  mut name : String
  mut size : Double
  mut bold : Bool
  mut italic : Bool
  mut underline : String
  mut strike : Bool
  mut color : XlsxColor
  mut vertical : String
  mut scheme : String
  mut family : Int32
}

///|
/// Cell alignment and text layout settings.
pub(all) struct XlsxAlignment {
  horizontal : String
  vertical : String
  wrap : Bool
  shrink : Bool
  indent : Int32
  rotation : Int32
  justify_last : Bool
}

///|
/// Indices and alignment for a cell format.
pub(all) struct XlsxCellFormat {
  number_format : Int32
  font : Int32
  fill : Int32
  border : Int32
  alignment : XlsxAlignment
}

///|
/// The workbook's fonts, custom number formats and cell formats.
pub(all) struct XlsxStyles {
  fonts : Array[XlsxFont]
  number_formats : Map[Int32, String]
  cell_formats : Array[XlsxCellFormat]
  palette : Array[UInt32]
}

///|
priv struct XlsxFormatBuilder {
  number_format : Int32
  font : Int32
  fill : Int32
  border : Int32
  base : Int32
  apply_alignment : Bool
  mut alignment : XlsxAlignment?
}

///|
fn xlsx_default_color() -> XlsxColor {
  { kind: 0, rgb: 0U, index: 0, tint: 0.0, }
}

///|
fn xlsx_default_font() -> XlsxFont {
  {
    name: "Calibri",
    size: 11.0,
    bold: false,
    italic: false,
    underline: "",
    strike: false,
    color: xlsx_default_color(),
    vertical: "",
    scheme: "",
    family: 0,
  }
}

///|
fn xlsx_default_alignment() -> XlsxAlignment {
  {
    horizontal: "general",
    vertical: "bottom",
    wrap: false,
    shrink: false,
    indent: 0,
    rotation: 0,
    justify_last: false,
  }
}

///|
fn xlsx_alignment(element : @xml.NamespaceElement) -> XlsxAlignment {
  let rotation = xlsx_node_int(element, "textRotation", 0)
  {
    horizontal: xlsx_attr(element, "horizontal", "general"),
    vertical: xlsx_attr(element, "vertical", "bottom"),
    wrap: xlsx_bool_or(element, "wrapText", false),
    shrink: xlsx_bool_or(element, "shrinkToFit", false),
    indent: xlsx_node_int(element, "indent", 0),
    rotation: if rotation < 0 || (rotation > 180 && rotation != 255) {
      0
    } else {
      rotation
    },
    justify_last: xlsx_bool_or(element, "justifyLastLine", false),
  }
}

///|
fn xlsx_color(element : @xml.NamespaceElement) -> XlsxColor {
  let tint = xlsx_float_or(element, "tint", 0.0)
  let mut kind = 0
  let mut rgb = 0U
  let mut index = 0
  if xlsx_bool_or(element, "auto", false) {
    kind = 4
  } else if xlsx_has_attr(element, "rgb") {
    let data = @utf8.encode(xlsx_trim(xlsx_attr(element, "rgb", "")))
    let start = if data.length() == 8 { 2 } else { 0 }
    if data.length() - start == 6 {
      let mut valid = true
      for i in start..<data.length() {
        let n = xlsx_hex(data[i])
        if n < 0 {
          valid = false
          break
        }
        rgb = rgb * 16U + n.to_uint()
      }
      if valid {
        kind = 1
      } else {
        rgb = 0U
      }
    }
  } else if xlsx_has_attr(element, "theme") {
    kind = 2
    index = xlsx_node_int(element, "theme", 0)
  } else if xlsx_has_attr(element, "indexed") {
    kind = 3
    index = xlsx_node_int(element, "indexed", 0)
  }
  { kind, rgb, index, tint, }
}

///|
fn XlsxFont::apply(self : XlsxFont, element : @xml.NamespaceElement) -> Unit {
  let name = element.name.local_name
  let value = xlsx_attr(element, "val", "")
  match name {
    "name" | "rFont" => if value != "" { self.name = value }
    "sz" => {
      let size = xlsx_float_or(element, "val", 0.0)
      if size > 0.0 && size < 1000.0 {
        self.size = size
      }
    }
    "b" => self.bold = xlsx_bool_or(element, "val", true)
    "i" => self.italic = xlsx_bool_or(element, "val", true)
    "u" => {
      let v = xlsx_attr(element, "val", "single")
      self.underline = if v == "none" { "" } else { v }
    }
    "strike" => self.strike = xlsx_bool_or(element, "val", true)
    "color" => self.color = xlsx_color(element)
    "vertAlign" => self.vertical = if value == "baseline" { "" } else { value }
    "scheme" => self.scheme = if value == "none" { "" } else { value }
    "family" => self.family = xlsx_node_int(element, "val", 0)
    _ => ()
  }
}

///|
fn xlsx_format(element : @xml.NamespaceElement) -> XlsxFormatBuilder {
  {
    number_format: xlsx_node_int(element, "numFmtId", 0),
    font: xlsx_node_int(element, "fontId", 0),
    fill: xlsx_node_int(element, "fillId", 0),
    border: xlsx_node_int(element, "borderId", 0),
    base: xlsx_node_int(element, "xfId", 0),
    apply_alignment: xlsx_bool_or(element, "applyAlignment", false),
    alignment: None,
  }
}

///|
fn xlsx_styles_default() -> XlsxStyles {
  let font = xlsx_default_font()
  font.scheme = "minor"
  {
    fonts: [font],
    number_formats: Map([]),
    palette: xlsx_default_palette(),
    cell_formats: [
      {
        number_format: 0,
        font: 0,
        fill: 0,
        border: 0,
        alignment: xlsx_default_alignment(),
      },
    ],
  }
}

///|
fn xlsx_parse_styles(data : Bytes) -> XlsxStyles raise {
  let text = @utf8.decode_lossy(data[:], ignore_bom=true)
  if text.contains("<!ENTITY") {
    raise InvalidXlsxInput("ooxml: the part declares entities")
  }
  let reader = @xml.NamespaceReader::from_string(text)
  let formats : Map[Int32, String] = Map([])
  let fonts : Array[XlsxFont] = []
  let base_formats : Array[XlsxFormatBuilder] = []
  let cell_formats : Array[XlsxFormatBuilder] = []
  let seen : Map[String, Bool] = Map([])
  let palette = xlsx_default_palette()
  let mut colors_depth = -1
  let mut indexed_depth = -1
  let mut palette_index = 0
  let mut depth = 0
  let mut block = ""
  let mut block_depth = -1
  let mut font_depth = -1
  let mut xf_depth = -1
  let mut current_font : XlsxFont? = None
  let mut current_xf : XlsxFormatBuilder? = None
  while true {
    let event = reader.read_event()
    match event.kind {
      Start(element) | Empty(element) => {
        let name = element.name.local_name
        if depth == 1 && name == "colors" && !seen.contains("colors") {
          seen["colors"] = true
          if event.kind is Start(_) {
            colors_depth = depth + 1
          }
        } else if depth == colors_depth &&
          name == "indexedColors" &&
          !seen.contains("indexedColors") {
          seen["indexedColors"] = true
          if event.kind is Start(_) {
            indexed_depth = depth + 1
          }
        } else if depth == indexed_depth && name == "rgbColor" {
          if palette_index < palette.length() {
            let color = xlsx_color(element)
            if color.kind == 1 {
              palette[palette_index] = color.rgb
            }
          }
          palette_index += 1
        } else if depth == 1 &&
          ["numFmts", "fonts", "cellStyleXfs", "cellXfs"].contains(name) &&
          !seen.contains(name) {
          seen[name] = true
          if event.kind is Start(_) {
            block = name
            block_depth = depth + 1
          }
        } else if depth == block_depth {
          match block {
            "numFmts" =>
              if name == "numFmt" {
                formats[xlsx_node_int(element, "numFmtId", -1)] = xlsx_attr(
                  element, "formatCode", "General",
                )
              }
            "fonts" =>
              if name == "font" {
                let font = xlsx_default_font()
                fonts.push(font)
                if event.kind is Start(_) {
                  current_font = Some(font)
                  font_depth = depth + 1
                }
              }
            "cellStyleXfs" | "cellXfs" =>
              if name == "xf" {
                let xf = xlsx_format(element)
                if block == "cellXfs" {
                  cell_formats.push(xf)
                } else {
                  base_formats.push(xf)
                }
                if event.kind is Start(_) {
                  current_xf = Some(xf)
                  xf_depth = depth + 1
                }
              }
            _ => ()
          }
        } else if depth == font_depth {
          if current_font is Some(font) {
            font.apply(element)
          }
        } else if depth == xf_depth && name == "alignment" {
          if current_xf is Some(xf) && xf.alignment is None {
            xf.alignment = Some(xlsx_alignment(element))
          }
        }
        if event.kind is Start(_) {
          depth += 1
        } else if depth == 0 {
          break
        }
      }
      End(_) => {
        depth -= 1
        if depth + 1 == colors_depth {
          colors_depth = -1
        }
        if depth + 1 == indexed_depth {
          indexed_depth = -1
        }
        if depth + 1 == font_depth {
          font_depth = -1
          current_font = None
        }
        if depth + 1 == xf_depth {
          xf_depth = -1
          current_xf = None
        }
        if depth + 1 == block_depth {
          block_depth = -1
          block = ""
        }
        if depth == 0 {
          break
        }
      }
      Eof =>
        if depth == 0 {
          break
        } else {
          raise InvalidXlsxInput("xlsx: unexpected EOF")
        }
      _ => ()
    }
  }
  if fonts.is_empty() {
    let font = xlsx_default_font()
    font.scheme = "minor"
    fonts.push(font)
  }
  let result : Array[XlsxCellFormat] = []
  for xf in cell_formats {
    let alignment = match xf.alignment {
      Some(value) => value
      None =>
        if !xf.apply_alignment &&
          xf.base >= 0 &&
          xf.base < base_formats.length() {
          base_formats[xf.base].alignment.unwrap_or(xlsx_default_alignment())
        } else {
          xlsx_default_alignment()
        }
    }
    result.push({
      number_format: xf.number_format,
      font: xf.font,
      fill: xf.fill,
      border: xf.border,
      alignment,
    })
  }
  if result.is_empty() {
    result.push({
      number_format: 0,
      font: 0,
      fill: 0,
      border: 0,
      alignment: xlsx_default_alignment(),
    })
  }
  { fonts, number_formats: formats, cell_formats: result, palette, }
}

///|
/// Load the workbook's fonts, custom number formats and cell formats.
pub fn XlsxWorkbook::styles(self : XlsxWorkbook) -> XlsxStyles {
  let rel = match self.package.relationship_of_type(self.part, "/styles") {
    Some(rel) => rel
    None => return xlsx_styles_default()
  }
  let data = self.package.read(rel.target) catch {
    _ => return xlsx_styles_default()
  }
  xlsx_parse_styles(data) catch {
    _ => xlsx_styles_default()
  }
}
