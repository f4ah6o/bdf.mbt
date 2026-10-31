///|
// The supported paragraph properties. Border and shading require the Office
// theme, so applying either is rejected until that resolver is implemented.
priv struct DocxParagraphProps {
  mut alignment : String
  mut left : Double
  mut right : Double
  mut first : Double
  mut left_chars : Double
  mut right_chars : Double
  mut first_chars : Double
  mut before : Double
  mut after : Double
  mut before_lines : Double
  mut after_lines : Double
  mut before_auto : Bool
  mut after_auto : Bool
  mut line : Double
  mut line_rule : String
  mut contextual : Bool
  mut keep_next : Bool
  mut keep_lines : Bool
  mut page_break_before : Bool
  mut widow_control : Bool
  mut snap_to_grid : Bool
  mut kinsoku : Bool
  mut overflow_punct : Bool
  mut auto_space_de : Bool
  mut auto_space_dn : Bool
  mut bidi : Bool
  mut suppress_line_numbers : Bool
  mut frame : Bool
  mut number_id : String
  mut level : Int32
  mut outline : Int32
  mut tabs : Array[DocxTab]
  mut tabs_truncated : Bool
} derive(Debug, Eq)

///|
priv struct DocxTab {
  position : Double
  alignment : String
  leader : String
} derive(Debug, Eq)

///|
fn docx_default_paragraph_props() -> DocxParagraphProps {
  {
    alignment: "left",
    left: 0.0,
    right: 0.0,
    first: 0.0,
    left_chars: 0.0,
    right_chars: 0.0,
    first_chars: 0.0,
    before: 0.0,
    after: 0.0,
    before_lines: 0.0,
    after_lines: 0.0,
    before_auto: false,
    after_auto: false,
    line: 240.0,
    line_rule: "auto",
    contextual: false,
    keep_next: false,
    keep_lines: false,
    page_break_before: false,
    widow_control: false,
    snap_to_grid: true,
    kinsoku: true,
    overflow_punct: true,
    auto_space_de: true,
    auto_space_dn: true,
    bidi: false,
    suppress_line_numbers: false,
    frame: false,
    number_id: "",
    level: 0,
    outline: -1,
    tabs: [],
    tabs_truncated: false,
  }
}

///|
fn docx_paragraph_alignment(value : String) -> String {
  match value {
    "start" | "left" => "left"
    "end" | "right" => "right"
    "center" => "center"
    "both" | "mediumKashida" | "highKashida" | "lowKashida" => "both"
    "distribute" | "thaiDistribute" => "distribute"
    _ => "left"
  }
}

///|
fn docx_props_measure(element : @xml.NamespaceElement, key : String) -> Double {
  docx_measure(docx_attribute(element, key, ""), 0.0)
}

///|
fn docx_props_number(
  element : @xml.NamespaceElement,
  key : String,
  default : Double,
) -> Double {
  docx_number(docx_attribute(element, key, ""), default)
}

///|
fn DocxParagraphProps::apply_element(
  self : DocxParagraphProps,
  element : @xml.NamespaceElement,
) -> Unit raise {
  let value = docx_attribute(element, "val", "")
  match element.name.local_name {
    "keepNext" => self.keep_next = docx_bool(element, "val", true)
    "keepLines" => self.keep_lines = docx_bool(element, "val", true)
    "pageBreakBefore" =>
      self.page_break_before = docx_bool(element, "val", true)
    "widowControl" => self.widow_control = docx_bool(element, "val", true)
    "contextualSpacing" => self.contextual = docx_bool(element, "val", true)
    "snapToGrid" => self.snap_to_grid = docx_bool(element, "val", true)
    "kinsoku" => self.kinsoku = docx_bool(element, "val", true)
    "overflowPunct" => self.overflow_punct = docx_bool(element, "val", true)
    "autoSpaceDE" => self.auto_space_de = docx_bool(element, "val", true)
    "autoSpaceDN" => self.auto_space_dn = docx_bool(element, "val", true)
    "bidi" => self.bidi = docx_bool(element, "val", true)
    "suppressLineNumbers" =>
      self.suppress_line_numbers = docx_bool(element, "val", true)
    "framePr" => self.frame = true
    "outlineLvl" => {
      self.outline = docx_props_number(element, "val", 9.0).to_int()
      if self.outline > 8 {
        self.outline = -1
      }
    }
    "jc" => self.alignment = docx_paragraph_alignment(value)
    "pBdr" | "shd" =>
      raise InvalidDocx("paragraph border and shading are not supported yet")
    "spacing" => {
      if docx_has_attribute(element, "before") {
        self.before = docx_props_measure(element, "before")
      }
      if docx_has_attribute(element, "after") {
        self.after = docx_props_measure(element, "after")
      }
      if docx_has_attribute(element, "beforeLines") {
        self.before_lines = docx_props_number(element, "beforeLines", 0.0)
      }
      if docx_has_attribute(element, "afterLines") {
        self.after_lines = docx_props_number(element, "afterLines", 0.0)
      }
      if docx_has_attribute(element, "beforeAutospacing") {
        self.before_auto = docx_bool(element, "beforeAutospacing", false)
      }
      if docx_has_attribute(element, "afterAutospacing") {
        self.after_auto = docx_bool(element, "afterAutospacing", false)
      }
      if docx_has_attribute(element, "line") {
        self.line = docx_props_number(element, "line", 240.0)
        self.line_rule = docx_attribute(element, "lineRule", "auto")
      } else if docx_has_attribute(element, "lineRule") {
        self.line_rule = docx_attribute(element, "lineRule", "")
      }
    }
    "ind" => {
      if docx_has_attribute(element, "left") {
        self.left = docx_props_measure(element, "left")
      }
      if docx_has_attribute(element, "start") {
        self.left = docx_props_measure(element, "start")
      }
      if docx_has_attribute(element, "right") {
        self.right = docx_props_measure(element, "right")
      }
      if docx_has_attribute(element, "end") {
        self.right = docx_props_measure(element, "end")
      }
      if docx_has_attribute(element, "firstLine") {
        self.first = docx_props_measure(element, "firstLine")
      }
      if docx_has_attribute(element, "hanging") {
        self.first = -docx_props_measure(element, "hanging")
      }
      if docx_has_attribute(element, "leftChars") {
        self.left_chars = docx_props_number(element, "leftChars", 0.0)
      }
      if docx_has_attribute(element, "startChars") {
        self.left_chars = docx_props_number(element, "startChars", 0.0)
      }
      if docx_has_attribute(element, "rightChars") {
        self.right_chars = docx_props_number(element, "rightChars", 0.0)
      }
      if docx_has_attribute(element, "endChars") {
        self.right_chars = docx_props_number(element, "endChars", 0.0)
      }
      if docx_has_attribute(element, "firstLineChars") {
        self.first_chars = docx_props_number(element, "firstLineChars", 0.0)
      }
      if docx_has_attribute(element, "hangingChars") {
        self.first_chars = -docx_props_number(element, "hangingChars", 0.0)
      }
    }
    _ => ()
  }
}

///|
fn DocxParagraphProps::apply_tab(
  self : DocxParagraphProps,
  element : @xml.NamespaceElement,
) -> Unit {
  if self.tabs.length() >= 200 {
    self.tabs_truncated = true
    return
  }
  let position = docx_props_measure(element, "pos")
  let retained : Array[DocxTab] = []
  for tab in self.tabs {
    if (tab.position - position).abs() > 0.05 {
      retained.push(tab)
    }
  }
  self.tabs = retained
  let alignment = match docx_attribute(element, "val", "") {
    "clear" => return
    "start" | "num" => "left"
    "end" => "right"
    value => value
  }
  self.tabs.push({
    position,
    alignment,
    leader: docx_attribute(element, "leader", "none"),
  })
}

///|
fn DocxParagraphProps::sort_tabs(self : DocxParagraphProps) -> Unit {
  for i in 1..<self.tabs.length() {
    let mut j = i
    while j > 0 && self.tabs[j].position < self.tabs[j - 1].position {
      let tmp = self.tabs[j]
      self.tabs[j] = self.tabs[j - 1]
      self.tabs[j - 1] = tmp
      j -= 1
    }
  }
}

///|
// Apply one w:pPr layer; repeatedly calling this implements style inheritance.
fn DocxParagraphProps::apply_xml(
  self : DocxParagraphProps,
  xml : String,
) -> Unit raise {
  if xml.contains("<!ENTITY") {
    raise InvalidDocx("OOXML part declares entities")
  }
  let reader = @xml.NamespaceReader::from_string(xml)
  let path : Array[String] = []
  let mut number_seen = false
  let mut level_seen = false
  let mut tabs_full = false
  while true {
    let event = reader.read_event()
    match event.kind {
      Start(element) | Empty(element) => {
        let name = element.name.local_name
        let depth = path.length()
        if depth == 1 {
          self.apply_element(element)
          if name == "numPr" {
            number_seen = false
            level_seen = false
          }
          if name == "tabs" {
            tabs_full = false
          }
        } else if depth == 2 && path[1] == "numPr" {
          if name == "numId" && !number_seen {
            number_seen = true
            self.number_id = docx_attribute(element, "val", "")
          } else if name == "ilvl" && !level_seen {
            level_seen = true
            self.level = docx_props_number(element, "val", 0.0).to_int()
          }
        } else if depth == 2 && path[1] == "tabs" && name == "tab" && !tabs_full {
          self.apply_tab(element)
          if self.tabs_truncated {
            tabs_full = true
          }
        }
        if event.kind is Start(_) {
          path.push(name)
        } else if depth == 1 && name == "tabs" {
          self.sort_tabs()
        }
      }
      End(_) => {
        if path.length() == 2 && path[1] == "tabs" {
          self.sort_tabs()
        }
        ignore(path.pop())
      }
      Eof => break
      _ => ()
    }
  }
}
