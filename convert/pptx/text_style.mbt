///|
// Paragraph and run property inheritance for DrawingML text.
//
// The chain is the paragraph's own pPr, the shape's list style, the list
// styles of the layout and master placeholders it inherits from, and the
// master text style of its placeholder type (or the presentation's default
// text style). Each entry contributes its level style and default
// paragraph properties; the first value found wins.

///|
fn pptx_level_style_name(level : Int32) -> String {
  match level {
    0 => "lvl1pPr"
    1 => "lvl2pPr"
    2 => "lvl3pPr"
    3 => "lvl4pPr"
    4 => "lvl5pPr"
    5 => "lvl6pPr"
    6 => "lvl7pPr"
    7 => "lvl8pPr"
    _ => "lvl9pPr"
  }
}

///|
fn pptx_paragraph_level(paragraph : PptxXmlNode) -> Int32 {
  match pptx_child(Some(paragraph), "pPr") {
    Some(props) =>
      match
        (@string.parse_int(pptx_attribute(props.element, "lvl", "0")) catch {
          _ => 0
        }) {
        value => if value < 0 || value > 8 { 0 } else { value }
      }
    None => 0
  }
}

///|
fn pptx_append_list_style(
  chain : Array[PptxXmlNode],
  style : PptxXmlNode?,
  level : Int32,
) -> Unit {
  match style {
    Some(value) => {
      match pptx_child(Some(value), pptx_level_style_name(level)) {
        Some(entry) => chain.push(entry)
        None => ()
      }
      match pptx_child(Some(value), "defPPr") {
        Some(entry) => chain.push(entry)
        None => ()
      }
    }
    None => ()
  }
}

///|
fn pptx_master_text_style(
  master : PptxXmlNode?,
  placeholder_type : String,
) -> PptxXmlNode? {
  let master = match master {
    Some(value) => value
    None => return None
  }
  let styles = pptx_child(Some(master), "txStyles")
  let name = match pptx_master_placeholder_type(placeholder_type) {
    "title" => "titleStyle"
    "body" => "bodyStyle"
    _ => "otherStyle"
  }
  pptx_child(styles, name)
}

///|
// A layout or master placeholder also gives the run properties of the
// paragraph it was authored with (its pPr defRPr).
fn pptx_append_placeholder_paragraph(
  chain : Array[PptxXmlNode],
  body : PptxXmlNode,
) -> Unit {
  match pptx_child(pptx_child(Some(body), "p"), "pPr") {
    Some(props) => chain.push(props)
    None => ()
  }
}

///|
// The paragraph property chain of a paragraph in a text body.
fn pptx_text_chain(
  shape : PptxXmlNode,
  body : PptxXmlNode,
  paragraph : PptxXmlNode,
  layout_placeholders : Array[PptxXmlNode],
  master_placeholders : Array[PptxXmlNode],
  master : PptxXmlNode?,
  default_text_style : PptxXmlNode?,
  inherited : Bool,
) -> Array[PptxXmlNode] {
  let chain : Array[PptxXmlNode] = []
  let level = pptx_paragraph_level(paragraph)
  match pptx_child(Some(paragraph), "pPr") {
    Some(props) => chain.push(props)
    None => ()
  }
  pptx_append_list_style(chain, pptx_child(Some(body), "lstStyle"), level)
  let mut placeholder_type = ""
  if inherited {
    match pptx_placeholder_info(shape) {
      Some(info) => {
        let mut master_info = info
        match pptx_find_placeholder_shape(layout_placeholders, info, false) {
          Some(layout_shape) => {
            match pptx_child(Some(layout_shape), "txBody") {
              Some(layout_body) => {
                pptx_append_list_style(
                  chain,
                  pptx_child(Some(layout_body), "lstStyle"),
                  level,
                )
                pptx_append_placeholder_paragraph(chain, layout_body)
              }
              None => ()
            }
            match pptx_placeholder_info(layout_shape) {
              Some(value) => master_info = value
              None => ()
            }
          }
          None => ()
        }
        match
          pptx_find_placeholder_shape(master_placeholders, master_info, true) {
          Some(master_shape) =>
            match pptx_child(Some(master_shape), "txBody") {
              Some(master_body) => {
                pptx_append_list_style(
                  chain,
                  pptx_child(Some(master_body), "lstStyle"),
                  level,
                )
                pptx_append_placeholder_paragraph(chain, master_body)
              }
              None => ()
            }
          None => ()
        }
        placeholder_type = master_info.kind
      }
      None => ()
    }
  }
  let host = if placeholder_type == "" {
    default_text_style
  } else {
    pptx_master_text_style(master, placeholder_type)
  }
  pptx_append_list_style(chain, host, level)
  chain
}

///|
fn pptx_chain_attribute(
  chain : Array[PptxXmlNode],
  name : String,
  default : String,
) -> String {
  for node in chain {
    let value = pptx_attribute(node.element, name, "")
    if value != "" {
      return value
    }
  }
  default
}

///|
fn pptx_chain_child(chain : Array[PptxXmlNode], name : String) -> PptxXmlNode? {
  for node in chain {
    match pptx_child(Some(node), name) {
      Some(value) => return Some(value)
      None => ()
    }
  }
  None
}

///|
fn pptx_chain_first_child(
  chain : Array[PptxXmlNode],
  names : Array[String],
) -> PptxXmlNode? {
  for node in chain {
    for name in names {
      match pptx_child(Some(node), name) {
        Some(value) => return Some(value)
        None => ()
      }
    }
  }
  None
}

///|
fn pptx_chain_run_child(
  chain : Array[PptxXmlNode],
  run_properties : PptxXmlNode?,
  name : String,
) -> PptxXmlNode? {
  match run_properties {
    Some(props) =>
      match pptx_child(Some(props), name) {
        Some(value) => return Some(value)
        None => ()
      }
    None => ()
  }
  for node in chain {
    match pptx_child(pptx_child(Some(node), "defRPr"), name) {
      Some(value) => return Some(value)
      None => ()
    }
  }
  None
}

///|
fn pptx_chain_run_attribute(
  chain : Array[PptxXmlNode],
  run_properties : PptxXmlNode?,
  name : String,
  default : String,
) -> String {
  match run_properties {
    Some(props) => {
      let value = pptx_attribute(props.element, name, "")
      if value != "" {
        return value
      }
    }
    None => ()
  }
  for node in chain {
    match pptx_child(Some(node), "defRPr") {
      Some(props) => {
        let value = pptx_attribute(props.element, name, "")
        if value != "" {
          return value
        }
      }
      None => ()
    }
  }
  default
}

///|
fn pptx_chain_run_bool(
  chain : Array[PptxXmlNode],
  run_properties : PptxXmlNode?,
  name : String,
) -> Bool {
  let value = pptx_chain_run_attribute(chain, run_properties, name, "")
  if value == "" {
    false
  } else {
    ["1", "true", "on"].contains(pptx_trim(value))
  }
}

///|
priv struct PptxParagraphProps {
  level : Int32
  align : Int32
  mar_l : Double
  indent : Double
  ln_pct : Double
  ln_pts : Double
  bef_pct : Double
  bef_pts : Double
  aft_pct : Double
  aft_pts : Double
}

///|
fn pptx_paragraph_props(chain : Array[PptxXmlNode]) -> PptxParagraphProps {
  let level = pptx_chain_attribute(chain, "lvl", "0")
  let level = match (@string.parse_int(level) catch { _ => 0 }) {
    value => if value < 0 || value > 8 { 0 } else { value }
  }
  let align = match pptx_chain_attribute(chain, "algn", "") {
    "ctr" => 1
    "r" => 2
    "just" | "dist" => 3
    _ => 0
  }
  let mar_l = pptx_measure(pptx_chain_attribute(chain, "marL", "0"), 0.0)
  let indent = pptx_measure(pptx_chain_attribute(chain, "indent", "0"), 0.0)
  let mut ln_pct = 1.0
  let mut ln_pts = 0.0
  match pptx_chain_child(chain, "lnSpc") {
    Some(spacing) =>
      match pptx_child(Some(spacing), "spcPct") {
        Some(value) =>
          ln_pct = (@string.parse_double(
              pptx_attribute(value.element, "val", "100000"),
            ) catch {
              _ => 100000.0
            }) /
            100000.0
        None =>
          match pptx_child(Some(spacing), "spcPts") {
            Some(value) => {
              ln_pct = 0.0
              ln_pts = (@string.parse_double(
                  pptx_attribute(value.element, "val", "0"),
                ) catch {
                  _ => 0.0
                }) /
                100.0
            }
            None => ()
          }
      }
    None => ()
  }
  let mut bef_pct = 0.0
  let mut bef_pts = 0.0
  match pptx_chain_child(chain, "spcBef") {
    Some(spacing) =>
      match pptx_child(Some(spacing), "spcPct") {
        Some(value) =>
          bef_pct = (@string.parse_double(
              pptx_attribute(value.element, "val", "0"),
            ) catch {
              _ => 0.0
            }) /
            100000.0
        None =>
          match pptx_child(Some(spacing), "spcPts") {
            Some(value) =>
              bef_pts = (@string.parse_double(
                  pptx_attribute(value.element, "val", "0"),
                ) catch {
                  _ => 0.0
                }) /
                100.0
            None => ()
          }
      }
    None => ()
  }
  let mut aft_pct = 0.0
  let mut aft_pts = 0.0
  match pptx_chain_child(chain, "spcAft") {
    Some(spacing) =>
      match pptx_child(Some(spacing), "spcPct") {
        Some(value) =>
          aft_pct = (@string.parse_double(
              pptx_attribute(value.element, "val", "0"),
            ) catch {
              _ => 0.0
            }) /
            100000.0
        None =>
          match pptx_child(Some(spacing), "spcPts") {
            Some(value) =>
              aft_pts = (@string.parse_double(
                  pptx_attribute(value.element, "val", "0"),
                ) catch {
                  _ => 0.0
                }) /
                100.0
            None => ()
          }
      }
    None => ()
  }
  {
    level,
    align,
    mar_l,
    indent,
    ln_pct,
    ln_pts,
    bef_pct,
    bef_pts,
    aft_pct,
    aft_pts,
  }
}

///|
priv struct PptxBullet {
  kind : String // "none", "char" or "auto"
  text : String
  start : Int32
  font : String
}

///|
fn pptx_paragraph_bullet(chain : Array[PptxXmlNode]) -> PptxBullet {
  let node = pptx_chain_first_child(chain, [
    "buNone", "buAutoNum", "buChar", "buBlip",
  ])
  match node {
    Some(value) => {
      let kind = value.element.name.local_name
      if kind == "buNone" {
        { kind: "none", text: "", start: 1, font: "", }
      } else if kind == "buAutoNum" {
        {
          kind: "auto",
          text: "",
          start: @string.parse_int(
            pptx_attribute(value.element, "startAt", "1"),
          ) catch {
            _ => 1
          },
          font: "",
        }
      } else {
        let text = if kind == "buChar" {
          pptx_attribute(value.element, "char", "\u{2022}")
        } else {
          "\u{2022}"
        }
        let font = match pptx_chain_first_child(chain, ["buFont"]) {
          Some(value) => pptx_attribute(value.element, "typeface", "")
          None => ""
        }
        { kind: "char", text, start: 1, font, }
      }
    }
    None => { kind: "none", text: "", start: 1, font: "", }
  }
}

///|
// The text of an automatic list number (1., a., i., …).
fn pptx_auto_number(scheme : String, value : Int32) -> String {
  let number = match scheme {
    "arabicParenR" => value.to_string() + ")"
    "arabicParenBoth" => "(" + value.to_string() + ")"
    "arabicPlain" => value.to_string()
    "lowerLetter" | "lowerLetterParenR" | "lowerLetterParenBoth" =>
      String::from_array([Char::from_int('a'.to_int() + (value - 1) % 26)])
    "upperLetter" | "upperLetterParenR" | "upperLetterParenBoth" =>
      String::from_array([Char::from_int('A'.to_int() + (value - 1) % 26)])
    _ => value.to_string() + "."
  }
  match scheme {
    "lowerLetterParenR" | "upperLetterParenR" => number + ")"
    _ => number
  }
}
