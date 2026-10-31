///|
pub suberror DocxConvertError {
  DocxInvalid(String)
}

///|
pub(all) struct DocxResult {
  bdf : Bytes
  pages : Int32
  summary : String
  warnings : Array[String]
}

///|
priv struct DocxLineItem {
  text : String
  font : String
  weight : Int32
  style : Int32
  size : Double
  color : UInt32
  x : Double
  advance : Double
}

///|
fn docx_font_family(props : DocxRunProps) -> String {
  let name = if props.fonts.is_empty() { "" } else { props.fonts[0] }
  let lower = name.to_lower()
  if lower.contains("courier") || lower.contains("mono") {
    "monospace"
  } else if lower.contains("times") || lower.contains("serif") {
    "serif"
  } else {
    "sans-serif"
  }
}

///|
fn docx_font_weight(props : DocxRunProps) -> Int32 {
  if (props.toggles & 1) != 0 {
    700
  } else {
    400
  }
}

///|
fn docx_font_style(props : DocxRunProps) -> Int32 {
  if (props.toggles & 2) != 0 {
    1
  } else {
    0
  }
}

///|
fn docx_run_color(props : DocxRunProps) -> UInt32 {
  if props.auto_color {
    0x000000ffU
  } else {
    ((props.color & 0x00ffffffU) << 8) | 0xffU
  }
}

///|
fn docx_char_width(c : Char, size : Double) -> Double {
  let code = c.to_int()
  if c == ' ' {
    size * 0.25
  } else if code >= 0x2e80 || c == '\u3000' {
    size
  } else {
    size * 0.5
  }
}

///|
fn docx_text_width(text : String, size : Double) -> Double {
  let mut width = 0.0
  for c in text {
    width += docx_char_width(c, size)
  }
  width
}

///|
fn docx_round_up(value : Double) -> Double {
  let whole = value.to_int().to_double()
  if value > whole {
    whole + 1.0
  } else {
    whole
  }
}

///|
fn docx_section_at(document : DocxTextDocument, index : Int32) -> DocxSection {
  if document.sections.is_empty() {
    docx_new_section(None)
  } else if index < 0 || index >= document.sections.length() {
    document.sections[document.sections.length() - 1]
  } else {
    document.sections[index]
  }
}

///|
fn docx_story_part(section : DocxSection, header : Bool) -> String {
  let stories = if header { section.headers } else { section.footers }
  for entry in stories {
    if entry.0 == "default" {
      return entry.1
    }
  }
  if stories.is_empty() {
    ""
  } else {
    stories[0].1
  }
}

///|
fn docx_story_text(
  package : @ooxml.OoxmlPackage,
  part : String,
) -> Array[String] raise {
  if part == "" || !package.has(part) {
    return []
  }
  let root = docx_text_xml(
    @utf8.decode_lossy(package.read(part)[:], ignore_bom=true),
  )
  let lines : Array[String] = []
  fn collect(node : DocxXmlNode, text : StringBuilder) -> Unit {
    if node.name() == "t" {
      text.write_string(node.text.to_string())
    }
    for child in node.children {
      collect(child, text)
    }
  }
  for child in root.children {
    if child.name() == "p" {
      let text = StringBuilder()
      collect(child, text)
      if text.to_string() != "" {
        lines.push(text.to_string())
      }
    }
  }
  lines
}

///|
fn docx_emit_story(
  object : @core.ObjectBuilder,
  lines : Array[String],
  x : Double,
  y : Double,
  size : Double,
) -> Unit raise {
  if lines.is_empty() {
    return
  }
  let index = object.add_font({
    hash: None,
    family: "sans-serif",
    weight: 400,
    style: 0,
  })
  let mut baseline = y
  for line in lines {
    object.font(index, Float::from_double(size))
    object.fill_color(0x000000ffU)
    object.fill_text(
      line,
      Float::from_double(x),
      Float::from_double(baseline),
      Float::from_double(docx_text_width(line, size)),
    )
    baseline += size * 1.2
  }
}

///|
fn docx_render_document(
  document : DocxTextDocument,
  title : String,
  data : Bytes,
) -> DocxResult raise {
  let meta : Map[String, Json] = {
    "source": Json::string("docx"),
    "generator": Json::string("bdf-go/0.1"),
  }
  if title != "" {
    meta["title"] = Json::string(title)
  }
  let writer = @core.DocumentWriter::new(meta=Json::object(meta))
  let pkg = @ooxml.open_ooxml(data) catch {
    _ => raise DocxInvalid("invalid DOCX package")
  }
  let pages : Array[Json] = []
  let warnings : Array[String] = ["DOCX layout uses approximate text metrics"]
  let mut section = docx_section_at(document, 0)
  let mut object = @core.ObjectBuilder::new()
  let fonts : Map[String, Int32] = Map([])
  let stories : Map[String, Array[String]] = Map([])
  let mut section_index = 0
  let mut y = section.top
  let line : Array[DocxLineItem] = []
  let mut line_start = section.left
  let mut line_x = section.left
  let mut line_width = 0.0
  let mut line_height = 12.0
  let mut page_open = false

  fn ensure_font(builder : @core.ObjectBuilder, item : DocxLineItem) -> Int32 {
    let key = item.font +
      "|" +
      item.weight.to_string() +
      "|" +
      item.style.to_string()
    match fonts.get(key) {
      Some(index) => index
      None => {
        let index = builder.add_font({
          hash: None,
          family: item.font,
          weight: item.weight,
          style: item.style,
        })
        fonts[key] = index
        index
      }
    }
  }

  fn emit_line(
    items : Array[DocxLineItem],
    align : String,
    start : Double,
    end : Double,
  ) -> Unit raise {
    if items.is_empty() {
      return
    }
    let width = items[items.length() - 1].x +
      items[items.length() - 1].advance -
      start
    let offset = match align {
      "right" => Double::max(0.0, end - start - width)
      "center" => Double::max(0.0, (end - start - width) / 2.0)
      _ => 0.0
    }
    for item in items {
      let index = ensure_font(object, item)
      object.font(index, Float::from_double(item.size))
      object.fill_color(item.color)
      object.fill_text(
        item.text,
        Float::from_double(start + offset + item.x),
        Float::from_double(y),
        Float::from_double(item.advance),
      )
    }
  }

  fn flush_page() -> Unit raise {
    if !page_open {
      return
    }
    emit_line(line, "left", line_start, line_start + line_width)
    line.clear()
    let header_part = docx_story_part(section, true)
    let header_lines = if header_part == "" {
      []
    } else {
      match stories.get(header_part) {
        Some(value) => value
        None => {
          let value = docx_story_text(pkg, header_part) catch { _ => [] }
          stories[header_part] = value
          value
        }
      }
    }
    docx_emit_story(
      object,
      header_lines,
      section.left,
      section.header + 10.0,
      10.0,
    )
    let footer_part = docx_story_part(section, false)
    let footer_lines = if footer_part == "" {
      []
    } else {
      match stories.get(footer_part) {
        Some(value) => value
        None => {
          let value = docx_story_text(pkg, footer_part) catch { _ => [] }
          stories[footer_part] = value
          value
        }
      }
    }
    docx_emit_story(
      object,
      footer_lines,
      section.left,
      section.height - section.footer - footer_lines.length().to_double() * 12.0,
      10.0,
    )
    let encoded = object.encode()
    let hash = writer.add_part("obj", encoded)
    pages.push(
      Json::object({
        "w": Json::number(section.width, repr=section.width.to_string()),
        "h": Json::number(section.height, repr=section.height.to_string()),
        "layers": Json::array([
          Json::object({
            "role": Json::string("body"),
            "obj": Json::string(hash),
          }),
        ]),
      }),
    )
    page_open = false
  }

  fn new_page() -> Unit raise {
    flush_page()
    object = @core.ObjectBuilder::new()
    fonts.clear()
    y = section.top
    line_start = section.left
    line_x = section.left
    line_width = 0.0
    page_open = true
  }

  fn ensure_page(height : Double) -> Unit raise {
    if !page_open {
      new_page()
    } else if y + height > section.height - section.bottom {
      new_page()
    }
  }

  fn flush_line(align : String) -> Unit raise {
    if line.is_empty() {
      return
    }
    let start = line_start
    let end = section.width - section.right
    let width = line[line.length() - 1].x + line[line.length() - 1].advance
    emit_line(line, align, start, end)
    line.clear()
    line_x = start
    line_width = width
    y += line_height
  }

  for paragraph in document.paragraphs {
    if paragraph.section_index != section_index {
      flush_line(paragraph.props.alignment)
      flush_page()
      section_index = paragraph.section_index
      section = docx_section_at(document, section_index)
      new_page()
    }
    let props = paragraph.props
    let left = section.left + props.left + props.first
    let right = section.width - section.right - props.right
    line_start = left
    line_x = left
    line_width = 0.0
    if props.page_break_before {
      flush_page()
    }
    if page_open {
      y += props.before
    } else {
      new_page()
      y += props.before
    }
    let mut current_align = props.alignment
    for item in paragraph.items {
      match item.kind {
        "page" => {
          flush_line(current_align)
          flush_page()
        }
        "column" => {
          flush_line(current_align)
          line_x = left
        }
        "break" => {
          flush_line(current_align)
          current_align = "left"
        }
        "tab" => {
          let relative = line_x - left
          let mut next = 0.0
          for stop in props.tabs {
            if stop.position > relative {
              next = stop.position
              break
            }
          }
          if next == 0.0 {
            next = docx_round_up(relative / 36.0) * 36.0
            if next <= relative {
              next += 36.0
            }
          }
          line_x = left + next
        }
        "image" => {
          let mut target = ""
          let mut external = false
          for rel in pkg.relationships(document.part) {
            if rel.id == item.text {
              target = rel.target
              external = rel.external
            }
          }
          if target == "" || external {
            raise DocxInvalid("DOCX image relationship is missing")
          }
          let bytes = pkg.read(target) catch {
            _ => raise DocxInvalid("DOCX image part is missing")
          }
          let hash = writer.add_part("img", bytes)
          let mut width = if item.width > 0.0 { item.width } else { 72.0 }
          let mut height = if item.height > 0.0 { item.height } else { 72.0 }
          let available = right - line_x
          if available > 0.0 && width > available {
            height = height * available / width
            width = available
          }
          ensure_page(height)
          let index = object.add_image(hash)
          object.image(
            index,
            Float::from_double(line_x),
            Float::from_double(y - height),
            Float::from_double(width),
            Float::from_double(height),
          )
          line_x += width
          line_width = line_x - left
          line_height = Double::max(line_height, height)
        }
        _ => {
          let size = if item.props.size > 0.0 { item.props.size } else { 10.0 }
          let advance = docx_text_width(item.text, size)
          let height = size * 1.2
          if line.is_empty() {
            line_height = height
          }
          if line_x + advance > right && !line.is_empty() {
            flush_line(current_align)
            current_align = "left"
            line_height = height
          }
          ensure_page(line_height)
          let item_x = line_x - left
          line.push({
            text: item.text,
            font: docx_font_family(item.props),
            weight: docx_font_weight(item.props),
            style: docx_font_style(item.props),
            size,
            color: docx_run_color(item.props),
            x: item_x,
            advance,
          })
          line_x += advance
          line_width = line_x - left
        }
      }
    }
    flush_line(props.alignment)
    y += props.after
  }
  flush_line("left")
  flush_page()
  if pages.is_empty() {
    new_page()
    flush_page()
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
  let bdf = writer.write_single()
  let count = pages.length()
  {
    bdf,
    pages: count,
    summary: "\{count} page" + (if count == 1 { "" } else { "s" }),
    warnings,
  }
}

///|
/// Detect a WordprocessingML package.
pub fn detect(data : Bytes) -> Bool {
  if data.length() < 4 || data[0] != b'P' || data[1] != b'K' {
    return false
  }
  let pkg = @ooxml.open_ooxml(data) catch { _ => return false }
  match pkg.relationship_of_type("", "/officeDocument") {
    Some(rel) =>
      rel.target == "word/document.xml" || rel.target.has_prefix("word/")
    None => {
      ignore(pkg.read("word/document.xml")) catch {
        _ => return false
      }
      true
    }
  }
}

///|
/// Convert the supported WordprocessingML text subset to BDF.
pub fn convert(data : Bytes, title~ : String = "") -> DocxResult raise {
  let document = docx_document_text(data) catch {
    InvalidDocx(message) => raise DocxInvalid(message)
    error => raise DocxInvalid(error.to_string())
  }
  docx_render_document(document, title, data) catch {
    InvalidDocx(message) => raise DocxInvalid(message)
    error => raise DocxInvalid(error.to_string())
  }
}
