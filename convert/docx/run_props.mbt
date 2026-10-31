///|
// Run properties are retained independently of the text reader until style
// inheritance and rendering can consume them. Colors and shading are rejected
// here until theme color resolution is available.
priv struct DocxRunProps {
  fonts : Array[String]
  themes : Array[String]
  mut hint : String
  mut toggles : Int32
  mut specified : Int32
  mut size : Double
  color : UInt32
  auto_color : Bool
  shading : UInt32
  has_shading : Bool
  underline_color : UInt32
  has_underline_color : Bool
  mut highlight : String
  mut underline : String
  mut vertical_align : String
  mut position : Double
  mut spacing : Double
  mut scale : Double
  mut emphasis : String
  languages : Array[String]
  mut web_hidden : Bool
  mut rtl : Bool
  mut tcy : Bool
  mut tcy_fit : Bool
} derive(Debug, Eq)

///|
fn docx_default_run_props() -> DocxRunProps {
  {
    fonts: ["Times New Roman", "Times New Roman", "", "Times New Roman"],
    themes: ["", "", "", ""],
    hint: "",
    toggles: 0,
    specified: 0,
    size: 10.0,
    color: 255U,
    auto_color: true,
    shading: 0U,
    has_shading: false,
    underline_color: 0U,
    has_underline_color: false,
    highlight: "",
    underline: "none",
    vertical_align: "",
    position: 0.0,
    spacing: 0.0,
    scale: 1.0,
    emphasis: "",
    languages: ["", "", ""],
    web_hidden: false,
    rtl: false,
    tcy: false,
    tcy_fit: false,
  }
}

///|
fn docx_run_toggle(name : String) -> Int32 {
  match name {
    "b" => 1
    "i" => 2
    "caps" => 4
    "smallCaps" => 8
    "strike" => 16
    "dstrike" => 32
    "vanish" => 64
    "outline" => 128
    "shadow" => 256
    "emboss" => 512
    "imprint" => 1024
    _ => 0
  }
}

///|
fn DocxRunProps::apply_node(
  self : DocxRunProps,
  node : DocxXmlNode,
) -> Unit raise {
  for child in node.children {
    let element = child.element
    let name = child.name()
    if !child.children.is_empty() {
      docx_text_unsupported(name)
    }
    let bit = docx_run_toggle(name)
    if bit != 0 {
      self.specified = self.specified | bit
      if docx_bool(element, "val", true) {
        self.toggles = self.toggles | bit
      } else {
        self.toggles = self.toggles & (bit ^ -1)
      }
      continue
    }
    match name {
      "rFonts" => {
        let keys = ["ascii", "hAnsi", "eastAsia", "cs"]
        let theme_keys = [
          "asciiTheme", "hAnsiTheme", "eastAsiaTheme", "cstheme",
        ]
        for i in 0..<4 {
          if docx_has_attribute(element, keys[i]) {
            self.fonts[i] = docx_attribute(element, keys[i], "")
            self.themes[i] = ""
          }
        }
        for i in 0..<4 {
          if docx_has_attribute(element, theme_keys[i]) {
            self.themes[i] = docx_attribute(element, theme_keys[i], "")
          }
        }
        if docx_has_attribute(element, "hint") {
          self.hint = docx_attribute(element, "hint", "")
        }
      }
      "sz" => {
        let v = docx_props_number(element, "val", 0.0)
        if v > 0.0 {
          self.size = v / 2.0
        }
      }
      "highlight" => self.highlight = docx_attribute(element, "val", "")
      "u" => {
        if docx_has_attribute(element, "color") ||
          docx_has_attribute(element, "themeColor") ||
          docx_has_attribute(element, "themeTint") ||
          docx_has_attribute(element, "themeShade") {
          docx_text_unsupported("underline color")
        }
        self.underline = docx_attribute(element, "val", "single")
      }
      "vertAlign" => self.vertical_align = docx_attribute(element, "val", "")
      "position" => self.position = docx_props_number(element, "val", 0.0) / 2.0
      "spacing" => self.spacing = docx_props_measure(element, "val")
      "w" => {
        let v = docx_props_number(element, "val", 100.0)
        if v > 0.0 {
          self.scale = v / 100.0
        }
      }
      "em" => self.emphasis = docx_attribute(element, "val", "")
      "lang" => {
        let keys = ["val", "eastAsia", "bidi"]
        for i in 0..<3 {
          if docx_has_attribute(element, keys[i]) {
            self.languages[i] = docx_attribute(element, keys[i], "")
          }
        }
      }
      "webHidden" => self.web_hidden = docx_bool(element, "val", true)
      "rtl" => self.rtl = docx_bool(element, "val", true)
      "eastAsianLayout" => {
        if docx_bool(element, "combine", false) {
          docx_text_unsupported("eastAsianLayout combine")
        }
        self.tcy = docx_bool(element, "vert", false)
        self.tcy_fit = docx_bool(element, "vertCompress", false)
      }
      other => docx_text_unsupported(other)
    }
  }
}

///|
fn DocxRunProps::apply_xml(self : DocxRunProps, xml : String) -> Unit raise {
  let node = docx_text_xml(xml)
  if node.name() != "rPr" {
    raise InvalidDocx("expected run properties")
  }
  self.apply_node(node)
}
