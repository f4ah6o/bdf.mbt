///|
priv struct DocxNumberingLevel {
  format : String
  text : String
  start : Int32
  left : Double
}

///|
priv struct DocxNumbering {
  nums : Map[String, String]
  levels : Map[String, Array[DocxNumberingLevel]]
}

///|
fn docx_numbering_empty() -> DocxNumbering {
  { nums: Map([]), levels: Map([]), }
}

///|
fn docx_numbering_level(node : DocxXmlNode) -> DocxNumberingLevel {
  let mut format = "decimal"
  let mut text = ""
  let mut start = 1L
  let mut left = 0.0
  for child in node.children {
    match child.name() {
      "numFmt" => format = docx_attribute(child.element, "val", "decimal")
      "lvlText" => text = docx_attribute(child.element, "val", "")
      "start" =>
        start = @string.parse_int64(docx_attribute(child.element, "val", "1")) catch {
          _ => 1L
        }
      "pPr" =>
        match child.child("ind") {
          Some(indent) =>
            left = docx_measure(docx_attribute(indent.element, "left", ""), 0.0)
          None => ()
        }
      _ => ()
    }
  }
  { format, text, start: start.to_int(), left, }
}

///|
fn docx_numbering_from_xml(xml : String) -> DocxNumbering raise {
  let root = docx_text_xml(xml)
  if root.name() != "numbering" {
    raise InvalidDocx("expected DOCX numbering")
  }
  let numbering = docx_numbering_empty()
  for node in root.children {
    if node.name() == "abstractNum" {
      let id = docx_attribute(node.element, "abstractNumId", "")
      let levels : Array[DocxNumberingLevel] = []
      for child in node.children {
        if child.name() == "lvl" {
          let ilvl = @string.parse_int(
            docx_attribute(child.element, "ilvl", "0"),
          ) catch {
            _ => 0
          }
          while levels.length() <= ilvl {
            levels.push({ format: "decimal", text: "", start: 1, left: 0.0, })
          }
          levels[ilvl] = docx_numbering_level(child)
        }
      }
      if id != "" {
        numbering.levels[id] = levels
      }
    }
  }
  for node in root.children {
    if node.name() == "num" {
      let id = docx_attribute(node.element, "numId", "")
      if id == "" {
        continue
      }
      for child in node.children {
        if child.name() == "abstractNumId" {
          let target = docx_attribute(child.element, "val", "")
          if target != "" {
            numbering.nums[id] = target
          }
        }
      }
    }
  }
  numbering
}

///|
fn docx_numbering_text(
  level : DocxNumberingLevel,
  counters : Array[Int32],
) -> String {
  if level.format == "bullet" {
    return if level.text == "" { "•" } else { level.text }
  }
  let result = StringBuilder()
  let text = if level.text == "" { "%1." } else { level.text }
  let mut i = 0
  while i < text.length() {
    let c = text.get_char(i).unwrap()
    if c == '%' && i + 1 < text.length() {
      let digit = text.get_char(i + 1).unwrap()
      let index = digit.to_int() - '0'.to_int()
      if index >= 1 && index <= 9 {
        result.write_string(counters[index - 1].to_string())
        i += 2
        continue
      }
    }
    result.write_char(c)
    i += 1
  }
  result.to_string()
}

///|
fn docx_apply_numbering(
  paragraphs : Array[DocxTextParagraph],
  numbering : DocxNumbering,
) -> Unit {
  let counters : Map[String, Array[Int32]] = Map([])
  for paragraph in paragraphs {
    let number_id = paragraph.props.number_id
    if number_id == "" {
      continue
    }
    let abstract_id = match numbering.nums.get(number_id) {
      Some(value) => value
      None => continue
    }
    let levels = match numbering.levels.get(abstract_id) {
      Some(value) => value
      None => continue
    }
    if levels.is_empty() {
      continue
    }
    let level_index = if paragraph.props.level < 0 {
      0
    } else if paragraph.props.level >= levels.length() {
      levels.length() - 1
    } else {
      paragraph.props.level
    }
    let level = levels[level_index]
    let counts = match counters.get(number_id) {
      Some(value) => value
      None => {
        let value : Array[Int32] = Array::make(9, 0)
        counters[number_id] = value
        value
      }
    }
    counts[level_index] = counts[level_index] + 1
    for index in (level_index + 1)..<counts.length() {
      counts[index] = 0
    }
    let prefix = docx_numbering_text(level, counts)
    if prefix != "" {
      paragraph.items.insert(0, {
        kind: "char",
        text: prefix,
        clear: false,
        props: paragraph.mark,
        width: 0.0,
        height: 0.0,
        anchored: false,
        x: 0.0,
        y: 0.0,
        crop_left: 0.0,
        crop_top: 0.0,
        crop_right: 0.0,
        crop_bottom: 0.0,
      })
      paragraph.items.insert(1, {
        kind: "tab",
        text: "\t",
        clear: false,
        props: paragraph.mark,
        width: 0.0,
        height: 0.0,
        anchored: false,
        x: 0.0,
        y: 0.0,
        crop_left: 0.0,
        crop_top: 0.0,
        crop_right: 0.0,
        crop_bottom: 0.0,
      })
      paragraph.props.left += level.left
    }
  }
}
