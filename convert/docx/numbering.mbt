///|
priv struct DocxNumberingLevel {
  format : String
  text : String
  start : Int32
  left : Double
  rpr : DocxXmlNode?
}

///|
priv struct DocxNumbering {
  nums : Map[String, String]
  levels : Map[String, Array[DocxNumberingLevel]]
  num_levels : Map[String, Array[DocxNumberingLevel]]
}

///|
fn docx_numbering_empty() -> DocxNumbering {
  { nums: Map([]), levels: Map([]), num_levels: Map([]), }
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
  { format, text, start: start.to_int(), left, rpr: node.child("rPr"), }
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
            levels.push({
              format: "decimal",
              text: "",
              start: 1,
              left: 0.0,
              rpr: None,
            })
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
  // A numbering instance can override the start and the definition of its
  // abstract levels; resolve them once so that the counters use them.
  for node in root.children {
    if node.name() != "num" {
      continue
    }
    let id = docx_attribute(node.element, "numId", "")
    let abstract_id = match numbering.nums.get(id) {
      Some(value) => value
      None => continue
    }
    let base = match numbering.levels.get(abstract_id) {
      Some(value) => value
      None => continue
    }
    let levels : Array[DocxNumberingLevel] = []
    for level in base {
      levels.push(level)
    }
    for child in node.children {
      if child.name() != "lvlOverride" {
        continue
      }
      let index = @string.parse_int(docx_attribute(child.element, "ilvl", "0")) catch {
        _ => 0
      }
      while levels.length() <= index {
        levels.push({
          format: "decimal",
          text: "",
          start: 1,
          left: 0.0,
          rpr: None,
        })
      }
      let mut level = levels[index]
      match child.child("lvl") {
        Some(definition) => level = docx_numbering_level(definition)
        None => ()
      }
      match child.child("startOverride") {
        Some(start) =>
          level = {
            ..level,
            start: @string.parse_int(docx_attribute(start.element, "val", "1")) catch {
              _ => 1
            },
          }
        None => ()
      }
      levels[index] = level
    }
    numbering.num_levels[id] = levels
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
/// The run properties of a list label: the paragraph mark's formatting
/// followed by the level's properties, with decorations cleared
/// underline, shading and highlight never carry into a number or bullet.
fn docx_numbering_label_props(
  mark : DocxRunProps,
  level : DocxNumberingLevel,
  theme_fonts : @ooxml.OoxmlThemeFonts,
  warnings : Array[String],
) -> DocxRunProps raise {
  let props = mark.copy()
  // These decorations are cleared below, so do not reject an otherwise
  // harmless colored underline while resolving the invisible formatting.
  match level.rpr {
    Some(rpr) =>
      for child in rpr.children {
        if child.name() == "eastAsianLayout" &&
          docx_bool(child.element, "combine", false) {
          let warning = "DOCX list label eastAsianLayout combine is not supported"
          if !warnings.contains(warning) {
            warnings.push(warning)
          }
          if !child.children.is_empty() {
            docx_text_unsupported("eastAsianLayout")
          }
          props.tcy = docx_bool(child.element, "vert", false)
          props.tcy_fit = docx_bool(child.element, "vertCompress", false)
        } else if child.name() != "u" &&
          child.name() != "shd" &&
          child.name() != "highlight" {
          docx_style_apply_rpr(props, Some({ ..rpr, children: [child], }))
        }
      }
    None => ()
  }
  props.resolve_theme_fonts(theme_fonts)
  { ..props, underline: "none", has_shading: false, highlight: "", }
}

///|
fn docx_number_paragraph(
  paragraph : DocxTextParagraph,
  numbering : DocxNumbering,
  counters : Map[String, Array[Int32]],
  theme_fonts : @ooxml.OoxmlThemeFonts,
  warnings : Array[String],
) -> Unit raise {
  let number_id = paragraph.props.number_id
  if number_id == "" {
    return
  }
  let levels = match numbering.num_levels.get(number_id) {
    Some(value) => value
    None =>
      match numbering.nums.get(number_id) {
        Some(abstract_id) =>
          match numbering.levels.get(abstract_id) {
            Some(value) => value
            None => return
          }
        None => return
      }
  }
  if levels.is_empty() {
    return
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
  if counts[level_index] == 0 {
    counts[level_index] = level.start - 1
  }
  counts[level_index] = counts[level_index] + 1
  for index in (level_index + 1)..<counts.length() {
    counts[index] = 0
  }
  let mut prefix = docx_numbering_text(level, counts)
  if prefix == "" {
    return
  }
  let label = docx_numbering_label_props(
    paragraph.mark,
    level,
    theme_fonts,
    warnings,
  )
  let font_node = docx_style_child(level.rpr, "rFonts")
  let font_name = match font_node {
    Some(value) => docx_attribute(value.element, "ascii", "")
    None => ""
  }
  if docx_numbering_is_symbol_font(font_name) {
    prefix = docx_numbering_map_symbol(font_name, prefix)
    for i in 0..<label.fonts.length() {
      label.fonts[i] = paragraph.mark.fonts[i]
      label.themes[i] = paragraph.mark.themes[i]
    }
  }
  if (label.toggles & 4) != 0 {
    prefix = prefix.to_upper()
  }
  paragraph.items.insert(0, {
    kind: "char",
    text: prefix,
    clear: false,
    props: label,
    width: 0.0,
    height: 0.0,
    draw_width: 0.0,
    draw_height: 0.0,
    effect_left: 0.0,
    effect_top: 0.0,
    effect_right: 0.0,
    effect_bottom: 0.0,
    anchored: false,
    anchor: None,
    x: 0.0,
    y: 0.0,
    crop_left: 0.0,
    crop_top: 0.0,
    crop_right: 0.0,
    crop_bottom: 0.0,
    rotation: 0.0,
    flip_h: false,
    flip_v: false,
    link: "",
    small_caps: (label.toggles & 8) != 0 && (label.toggles & 4) == 0,
    field_format: "",
    shade: None,
    border_width: 0.0,
    border_color: None,
  })
  paragraph.items.insert(1, {
    kind: "tab",
    text: "\t",
    clear: false,
    props: label,
    width: 0.0,
    height: 0.0,
    draw_width: 0.0,
    draw_height: 0.0,
    effect_left: 0.0,
    effect_top: 0.0,
    effect_right: 0.0,
    effect_bottom: 0.0,
    anchored: false,
    anchor: None,
    x: 0.0,
    y: 0.0,
    crop_left: 0.0,
    crop_top: 0.0,
    crop_right: 0.0,
    crop_bottom: 0.0,
    rotation: 0.0,
    flip_h: false,
    flip_v: false,
    link: "",
    small_caps: false,
    field_format: "",
    shade: None,
    border_width: 0.0,
    border_color: None,
  })
  paragraph.props.left += level.left
}

///|
fn docx_number_blocks(
  blocks : Array[DocxBlock],
  numbering : DocxNumbering,
  counters : Map[String, Array[Int32]],
  theme_fonts : @ooxml.OoxmlThemeFonts,
  warnings : Array[String],
) -> Unit raise {
  for block in blocks {
    match block {
      DocxParaBlock(paragraph) =>
        docx_number_paragraph(
          paragraph, numbering, counters, theme_fonts, warnings,
        )
      DocxTableBlock(table) =>
        for row in table.rows {
          for cell in row.cells {
            docx_number_blocks(
              cell.blocks,
              numbering,
              counters,
              theme_fonts,
              warnings,
            )
          }
        }
    }
  }
}

///|
fn docx_apply_numbering(
  blocks : Array[DocxBlock],
  numbering : DocxNumbering,
  theme_fonts~ : @ooxml.OoxmlThemeFonts = @ooxml.default_theme_fonts(),
  warnings~ : Array[String] = [],
) -> Unit raise {
  let counters : Map[String, Array[Int32]] = Map([])
  docx_number_blocks(blocks, numbering, counters, theme_fonts, warnings)
}
