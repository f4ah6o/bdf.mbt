///|
// This is an internal, deliberately limited model. A rejected element is not
// silently converted into plain text: later stages must add its semantics.
priv struct DocxTextItem {
  kind : String
  text : String
  clear : Bool
  props : DocxRunProps
  width : Double
  height : Double
  anchored : Bool
  x : Double
  y : Double
  crop_left : Double
  crop_top : Double
  crop_right : Double
  crop_bottom : Double
  rotation : Double
  flip_h : Bool
  flip_v : Bool
  mut shade : UInt32?
  mut border_width : Double
  mut border_color : UInt32?
} derive(Debug, Eq)

///|
priv struct DocxTextParagraph {
  props : DocxParagraphProps
  mark : DocxRunProps
  items : Array[DocxTextItem]
  section_index : Int32
} derive(Debug, Eq)

///|
priv struct DocxTextDocument {
  part : String
  sections : Array[DocxSection]
  paragraphs : Array[DocxTextParagraph]
}

///|
priv struct DocxTextWalker {
  styles : DocxStyles
  paragraphs : Array[DocxTextParagraph]
  mut section_index : Int32
}

///|
priv struct DocxXmlNode {
  element : @xml.NamespaceElement
  children : Array[DocxXmlNode]
  text : StringBuilder
}

///|
fn DocxXmlNode::name(self : DocxXmlNode) -> String {
  self.element.name.local_name
}

///|
fn DocxXmlNode::child(self : DocxXmlNode, name : String) -> DocxXmlNode? {
  for child in self.children {
    if child.name() == name {
      return Some(child)
    }
  }
  None
}

///|
fn docx_text_xml(content : String) -> DocxXmlNode raise {
  if content.contains("<!ENTITY") {
    raise InvalidDocx("OOXML part declares entities")
  }
  let reader = @xml.NamespaceReader::from_string(content)
  let stack : Array[DocxXmlNode] = []
  let mut root : DocxXmlNode? = None
  let mut count = 0
  while true {
    let event = reader.read_event()
    match event.kind {
      Start(element) | Empty(element) => {
        count += 1
        if count > 1048576 || stack.length() >= 256 {
          raise InvalidDocx("DOCX XML exceeds supported limits")
        }
        let node : DocxXmlNode = {
          element,
          children: [],
          text: StringBuilder(),
        }
        if stack.is_empty() {
          if root is Some(_) {
            raise InvalidDocx("multiple XML roots")
          }
          root = Some(node)
        } else {
          stack[stack.length() - 1].children.push(node)
        }
        if event.kind is Start(_) {
          stack.push(node)
        }
      }
      Text(value) | CData(value) =>
        if !stack.is_empty() {
          stack[stack.length() - 1].text.write_string(value)
        }
      End(_) => ignore(stack.pop())
      Decl(encoding~, ..) =>
        match encoding {
          Some(value) if value.to_lower() != "utf-8" =>
            docx_text_unsupported("XML encoding")
          _ => ()
        }
      Eof => break
      _ => ()
    }
  }
  match root {
    Some(node) if stack.is_empty() => node
    _ => raise InvalidDocx("invalid or empty document XML")
  }
}

///|
fn docx_text_unsupported(name : String) -> Unit raise {
  raise InvalidDocx("unsupported DOCX content: " + name)
}

///|
fn docx_text_section_check(section : DocxXmlNode) -> Unit raise {
  for child in section.children {
    match child.name() {
      "pgSz"
      | "pgMar"
      | "type"
      | "titlePg"
      | "pgNumType"
      | "docGrid"
      | "textDirection"
      | "headerReference"
      | "footerReference" =>
        if !child.children.is_empty() {
          docx_text_unsupported(child.name())
        }
      "cols" =>
        for col in child.children {
          if col.name() != "col" || !col.children.is_empty() {
            docx_text_unsupported(child.name())
          }
        }
      other => docx_text_unsupported(other)
    }
  }
}

///|
fn docx_text_ppr(props : DocxParagraphProps, node : DocxXmlNode) -> Bool raise {
  let mut has_section = false
  for child in node.children {
    let name = child.name()
    match name {
      "numPr" =>
        for sub in child.children {
          match sub.name() {
            "numId" => props.number_id = docx_attribute(sub.element, "val", "")
            "ilvl" =>
              props.level = docx_props_number(sub.element, "val", 0.0).to_int()
            other => docx_text_unsupported("numPr " + other)
          }
        }
      "pBdr" => ()
      "sectPr" =>
        if !has_section {
          docx_text_section_check(child)
          has_section = true
        }
      "tabs" => {
        for tab in child.children {
          if tab.name() != "tab" || !tab.children.is_empty() {
            docx_text_unsupported("tabs")
          }
          if props.tabs.length() >= 200 {
            props.tabs_truncated = true
            break
          }
          props.apply_tab(tab.element)
        }
        props.sort_tabs()
      }
      "keepNext"
      | "keepLines"
      | "pageBreakBefore"
      | "widowControl"
      | "contextualSpacing"
      | "snapToGrid"
      | "kinsoku"
      | "overflowPunct"
      | "autoSpaceDE"
      | "autoSpaceDN"
      | "bidi"
      | "suppressLineNumbers"
      | "framePr"
      | "outlineLvl"
      | "jc"
      | "spacing"
      | "ind"
      | "shd" => {
        if !child.children.is_empty() {
          docx_text_unsupported(name)
        }
        props.apply_element(child.element)
      }
      other => docx_text_unsupported(other)
    }
  }
  has_section
}

///|
fn docx_text_push(
  items : Array[DocxTextItem],
  kind : String,
  text : String,
  props : DocxRunProps,
  clear~ : Bool = false,
) -> Unit {
  items.push({
    kind,
    text,
    clear,
    props,
    width: 0.0,
    height: 0.0,
    anchored: false,
    x: 0.0,
    y: 0.0,
    crop_left: 0.0,
    crop_top: 0.0,
    crop_right: 0.0,
    crop_bottom: 0.0,
    rotation: 0.0,
    flip_h: false,
    flip_v: false,
    shade: None,
    border_width: 0.0,
    border_color: None,
  })
}

///|
fn docx_text_chars(
  items : Array[DocxTextItem],
  text : String,
  props : DocxRunProps,
) -> Unit {
  for c in text {
    match c {
      '\r' | '\n' => docx_text_push(items, "break", "\n", props)
      '\t' => docx_text_push(items, "tab", "\t", props)
      '\u00ad' => ()
      _ => {
        let s = StringBuilder()
        s.write_char(c)
        docx_text_push(items, "char", s.to_string(), props)
      }
    }
  }
}

///|
fn docx_attribute_any(
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
fn docx_emu(value : String) -> Double {
  (@string.parse_double(value.trim()) catch { _ => 0.0 }) / 12700.0
}

///|
fn docx_picture_transform(node : DocxXmlNode) -> (Double, Bool, Bool) {
  let pending : Array[DocxXmlNode] = [node]
  while !pending.is_empty() {
    let value = pending.pop().unwrap()
    if value.name() == "xfrm" {
      let rotation = (@string.parse_double(
          docx_attribute(value.element, "rot", "0"),
        ) catch {
          _ => 0.0
        }) /
        60000.0
      let flip_h = docx_attribute(value.element, "flipH", "") == "1"
      let flip_v = docx_attribute(value.element, "flipV", "") == "1"
      return (rotation, flip_h, flip_v)
    }
    for sub in value.children {
      pending.push(sub)
    }
  }
  (0.0, false, false)
}

///|
fn docx_crop(node : DocxXmlNode, name : String) -> Double {
  (@string.parse_double(docx_attribute(node.element, name, "0")) catch {
    _ => 0.0
  }) /
  100000.0
}

///|
fn docx_anchor_offset(anchor : DocxXmlNode, name : String) -> Double? {
  match anchor.child(name) {
    Some(position) =>
      match position.child("posOffset") {
        Some(offset) => Some(docx_emu(offset.text.to_string()))
        None => None
      }
    None => None
  }
}

///|
fn docx_text_drawing(
  node : DocxXmlNode,
  items : Array[DocxTextItem],
  props : DocxRunProps,
) -> Unit raise {
  let container = match node.child("inline") {
    Some(value) => Some(value)
    None => node.child("anchor")
  }
  let container = match container {
    Some(value) => value
    None => return docx_text_unsupported("drawing")
  }
  let (width, height) = match container.child("extent") {
    Some(value) =>
      (
        docx_emu(docx_attribute_any(value.element, "cx", "")),
        docx_emu(docx_attribute_any(value.element, "cy", "")),
      )
    None => (0.0, 0.0)
  }
  let mut embed = ""
  fn find_blip(value : DocxXmlNode) -> Unit {
    if value.name() == "blip" {
      embed = docx_attribute_any(value.element, "embed", "")
    }
    for child in value.children {
      find_blip(child)
    }
  }
  find_blip(container)
  if embed == "" {
    let mut box_text = ""
    fn find_text_box(value : DocxXmlNode) -> Unit {
      if value.name() == "txbxContent" {
        let text = StringBuilder()
        let mut first = true
        fn collect(value : DocxXmlNode) -> Unit {
          if value.name() == "t" {
            if !first {
              text.write_string(" ")
            }
            first = false
            text.write_string(value.text.to_string())
          }
          for child in value.children {
            collect(child)
          }
        }
        collect(value)
        box_text = text.to_string()
      }
      for child in value.children {
        find_text_box(child)
      }
    }
    find_text_box(container)
    if box_text != "" {
      docx_text_push(items, "text", box_text, props)
      return
    }
    docx_text_unsupported("drawing without an embedded image")
  }
  let (rotation, flip_h, flip_v) = docx_picture_transform(container)
  let anchored = node.child("inline") is None
  let mut crop_left = 0.0
  let mut crop_top = 0.0
  let mut crop_right = 0.0
  let mut crop_bottom = 0.0
  let pending : Array[DocxXmlNode] = [container]
  while !pending.is_empty() {
    let value = pending.pop().unwrap()
    if value.name() == "srcRect" {
      crop_left = docx_crop(value, "l")
      crop_top = docx_crop(value, "t")
      crop_right = docx_crop(value, "r")
      crop_bottom = docx_crop(value, "b")
    }
    for sub in value.children {
      pending.push(sub)
    }
  }
  let mut x = 0.0
  let mut y = 0.0
  if anchored {
    x = docx_anchor_offset(container, "positionH").unwrap_or(0.0)
    y = docx_anchor_offset(container, "positionV").unwrap_or(0.0)
  }
  items.push({
    kind: "image",
    text: embed,
    clear: false,
    props,
    width,
    height,
    anchored,
    x,
    y,
    crop_left,
    crop_top,
    crop_right,
    crop_bottom,
    rotation,
    flip_h,
    flip_v,
    shade: None,
    border_width: 0.0,
    border_color: None,
  })
}

///|
fn docx_text_run(
  node : DocxXmlNode,
  items : Array[DocxTextItem],
  styles : DocxStyles,
  paragraph_style : String,
) -> Unit raise {
  let mut found_rpr = false
  for child in node.children {
    if child.name() == "rPr" {
      if found_rpr {
        docx_text_unsupported("duplicate rPr")
      }
      found_rpr = true
    }
  }
  let props = styles.resolve_run(paragraph_style, node.child("rPr"))
  if (props.toggles & (4 | 8 | 64)) != 0 {
    docx_text_unsupported("run text case conversion or hidden text")
  }
  if props.tcy {
    docx_text_unsupported("vertical combined text")
  }
  for child in node.children {
    let name = child.name()
    if name != "rPr" &&
      name != "t" &&
      name != "drawing" &&
      !child.children.is_empty() {
      docx_text_unsupported(name)
    }
    match name {
      "rPr" => ()
      "t" => {
        if !child.children.is_empty() {
          docx_text_unsupported(name)
        }
        docx_text_chars(items, child.text.to_string(), props)
      }
      "tab" | "ptab" => docx_text_push(items, "tab", "\t", props)
      "br" => {
        let typ = docx_attribute(child.element, "type", "textWrapping")
        match typ {
          "page" => docx_text_push(items, "page", "", props)
          "column" => docx_text_push(items, "column", "", props)
          _ =>
            docx_text_push(
              items,
              "break",
              "\n",
              props,
              clear=docx_attribute(child.element, "clear", "none") != "none",
            )
        }
      }
      "cr" => docx_text_push(items, "break", "\n", props)
      "noBreakHyphen" => docx_text_chars(items, "\u2011", props)
      "softHyphen" | "lastRenderedPageBreak" => ()
      "drawing" => docx_text_drawing(child, items, props)
      other => docx_text_unsupported(other)
    }
  }
}

///|
fn docx_text_inlines(
  node : DocxXmlNode,
  items : Array[DocxTextItem],
  styles : DocxStyles,
  paragraph_style : String,
) -> Unit raise {
  for child in node.children {
    match child.name() {
      "pPr" => ()
      "r" => docx_text_run(child, items, styles, paragraph_style)
      "smartTag" | "customXml" | "ins" | "moveTo" =>
        docx_text_inlines(child, items, styles, paragraph_style)
      "sdt" => {
        let mut seen_content = false
        for sub in child.children {
          if sub.name() == "sdtContent" && !seen_content {
            seen_content = true
            docx_text_inlines(sub, items, styles, paragraph_style)
          } else {
            docx_text_unsupported(sub.name())
          }
        }
      }
      other => docx_text_unsupported(other)
    }
  }
}

///|
fn DocxTextWalker::blocks(
  self : DocxTextWalker,
  node : DocxXmlNode,
  wrapped : Bool,
) -> Unit raise {
  let mut seen_final_section = false
  for child in node.children {
    if seen_final_section {
      docx_text_unsupported("content after final section")
    }
    match child.name() {
      "p" => {
        let items : Array[DocxTextItem] = []
        let mut seen_ppr = false
        for node in child.children {
          if node.name() == "pPr" {
            if seen_ppr {
              docx_text_unsupported("duplicate pPr")
            }
            seen_ppr = true
          }
        }
        let direct = child.child("pPr")
        let (paragraph_style, props) = self.styles.resolve_paragraph(direct)
        let mark = self.styles.resolve_run(paragraph_style, None)
        let ends_section = docx_style_child(direct, "sectPr") is Some(_)
        if ends_section && wrapped {
          docx_text_unsupported("wrapped paragraph section")
        }
        docx_text_inlines(child, items, self.styles, paragraph_style)
        match docx_paragraph_shade(direct) {
          Some(color) =>
            for item in items {
              item.shade = Some(color)
            }
          None => ()
        }
        let (border_width, border_color) = docx_paragraph_border(direct)
        if border_width > 0.0 {
          for item in items {
            item.border_width = border_width
            item.border_color = border_color
          }
        }
        self.paragraphs.push({
          props,
          mark,
          items,
          section_index: self.section_index,
        })
        if ends_section {
          self.section_index += 1
        }
      }
      "tbl" => {
        let grid : Array[Double] = []
        match child.child("tblGrid") {
          Some(value) =>
            for column in value.children {
              if column.name() == "gridCol" {
                grid.push(
                  docx_measure(docx_attribute(column.element, "w", ""), 0.0),
                )
              }
            }
          None => ()
        }
        for row in child.children {
          if row.name() != "tr" {
            continue
          }
          let items : Array[DocxTextItem] = []
          let mut first = true
          let mut cell_index = 0
          for cell in row.children {
            if cell.name() != "tc" {
              continue
            }
            if !first {
              docx_text_push(items, "tab", "\t", docx_default_run_props())
            }
            first = false
            let span = docx_table_cell_grid_span(cell)
            let mut width = 0.0
            if cell_index < grid.length() {
              width = 0.0
              let mut k = 0
              while k < span && cell_index + k < grid.length() {
                width += grid[cell_index + k]
                k += 1
              }
            }
            let shade = docx_table_cell_shade(cell)
            let (border_width, border_color) = docx_table_cell_border(cell)
            if width > 0.0 && (shade is Some(_) || border_width > 0.0) {
              items.push({
                kind: "cell",
                text: "",
                clear: false,
                props: docx_default_run_props(),
                width,
                height: 0.0,
                anchored: false,
                x: 0.0,
                y: 0.0,
                crop_left: 0.0,
                crop_top: 0.0,
                crop_right: 0.0,
                crop_bottom: 0.0,
                rotation: 0.0,
                flip_h: false,
                flip_v: false,
                shade,
                border_width,
                border_color,
              })
            }
            cell_index += span
            for part in cell.children {
              if part.name() == "p" {
                docx_text_inlines(part, items, self.styles, "")
              } else if part.name() == "tbl" {
                docx_text_unsupported("nested table")
              }
            }
            for _ in 1..<span {
              docx_text_push(items, "tab", "\t", docx_default_run_props())
            }
          }
          docx_text_push(items, "break", "\n", docx_default_run_props())
          let props = docx_default_paragraph_props()
          let mut position = 0.0
          for width in grid {
            position += width
            props.tabs.push({ position, alignment: "left", leader: "none", })
          }
          self.paragraphs.push({
            props,
            mark: docx_default_run_props(),
            items,
            section_index: self.section_index,
          })
        }
      }
      "sdt" => {
        let mut seen_content = false
        for sub in child.children {
          if sub.name() == "sdtContent" && !seen_content {
            seen_content = true
            self.blocks(sub, true)
          } else {
            docx_text_unsupported(sub.name())
          }
        }
      }
      "customXml" | "ins" | "moveTo" => self.blocks(child, true)
      "sectPr" => {
        if wrapped {
          docx_text_unsupported("wrapped section")
        }
        seen_final_section = true
        docx_text_section_check(child)
      }
      other => docx_text_unsupported(other)
    }
  }
}

///|
fn docx_table_cell_border(cell : DocxXmlNode) -> (Double, UInt32?) {
  let props = cell.child("tcPr")
  let borders = match props {
    Some(value) => value.child("tcBorders")
    None => None
  }
  for name in ["top", "left", "bottom", "right"] {
    match borders {
      Some(value) =>
        match value.child(name) {
          Some(border) => {
            let size = docx_attribute(border.element, "sz", "")
            let width = (@string.parse_double(size) catch { _ => 0.0 }) / 8.0
            if width > 0.0 {
              let color = docx_attribute(border.element, "color", "")
              let parsed = if color.length() == 6 {
                @string.parse_int(color, base=16) catch {
                  _ => -1
                }
              } else {
                -1
              }
              return (
                width,
                if parsed >= 0 {
                  Some((parsed.to_uint() << 8) | 0xffU)
                } else {
                  Some(0x000000ffU)
                },
              )
            }
          }
          None => ()
        }
      None => ()
    }
  }
  (0.0, None)
}

///|
fn docx_paragraph_shade(props : DocxXmlNode?) -> UInt32? {
  let shd = match props {
    Some(value) => value.child("shd")
    None => None
  }
  match shd {
    Some(value) => {
      let fill = docx_attribute(value.element, "fill", "")
      if fill.length() == 6 {
        let number = @string.parse_int(fill, base=16) catch { _ => -1 }
        if number >= 0 {
          Some((number.to_uint() << 8) | 0xffU)
        } else {
          None
        }
      } else {
        None
      }
    }
    None => None
  }
}

///|
fn docx_paragraph_border(props : DocxXmlNode?) -> (Double, UInt32?) {
  let borders = match props {
    Some(value) => value.child("pBdr")
    None => None
  }
  for name in ["top", "left", "bottom", "right"] {
    match borders {
      Some(value) =>
        match value.child(name) {
          Some(border) => {
            let width = (@string.parse_double(
                docx_attribute(border.element, "sz", ""),
              ) catch {
                _ => 0.0
              }) /
              8.0
            if width > 0.0 {
              let color = docx_attribute(border.element, "color", "")
              let parsed = if color.length() == 6 {
                @string.parse_int(color, base=16) catch {
                  _ => -1
                }
              } else {
                -1
              }
              return (
                width,
                if parsed >= 0 {
                  Some((parsed.to_uint() << 8) | 0xffU)
                } else {
                  Some(0x000000ffU)
                },
              )
            }
          }
          None => ()
        }
      None => ()
    }
  }
  (0.0, None)
}

///|
fn docx_table_cell_grid_span(cell : DocxXmlNode) -> Int32 {
  let props = cell.child("tcPr")
  let span = match props {
    Some(value) =>
      match value.child("gridSpan") {
        Some(grid) => docx_attribute(grid.element, "val", "1")
        None => "1"
      }
    None => "1"
  }
  let value = @string.parse_int(span) catch { _ => 1 }
  if value < 1 {
    1
  } else {
    value
  }
}

///|
fn docx_table_cell_shade(cell : DocxXmlNode) -> UInt32? {
  let props = cell.child("tcPr")
  match props {
    Some(value) =>
      match value.child("shd") {
        Some(shade) => {
          let fill = docx_attribute(shade.element, "fill", "")
          if fill.length() == 6 {
            let number = @string.parse_int(fill, base=16) catch { _ => -1 }
            if number >= 0 {
              Some((number.to_uint() << 8) | 0xffU)
            } else {
              None
            }
          } else {
            None
          }
        }
        None => None
      }
    None => None
  }
}

///|
fn docx_document_text(data : Bytes) -> DocxTextDocument raise {
  let package = @ooxml.open_ooxml(data)
  let part = match package.relationship_of_type("", "/officeDocument") {
    Some(rel) => rel.target
    None => "word/document.xml"
  }
  for typ in ["/settings", "/footnotes", "/endnotes"] {
    if package.relationship_of_type(part, typ) is Some(_) {
      docx_text_unsupported(typ)
    }
  }
  let styles = match package.relationship_of_type(part, "/styles") {
    Some(rel) => {
      if rel.external {
        docx_text_unsupported("external styles")
      }
      let data = package.read(rel.target)
      docx_styles_from_xml(@utf8.decode(data[:], ignore_bom=true))
    }
    None => docx_styles_from_xml("<styles/>")
  }
  let bytes = package.read(part)
  let xml = @utf8.decode(bytes[:], ignore_bom=true)
  let root = docx_text_xml(xml)
  if root.name() != "document" {
    raise InvalidDocx("not a Word document")
  }
  let body = match root.child("body") {
    Some(body) => body
    None => raise InvalidDocx("missing document body")
  }
  let mut seen_body = false
  for child in root.children {
    if child.name() != "body" || seen_body {
      docx_text_unsupported(child.name())
    }
    seen_body = true
  }
  let walker : DocxTextWalker = { styles, paragraphs: [], section_index: 0, }
  walker.blocks(body, false)
  let (section_part, sections) = docx_sections(data)
  if part != section_part || walker.section_index >= sections.length() {
    raise InvalidDocx("inconsistent DOCX sections")
  }
  let numbering = match package.relationship_of_type(part, "/numbering") {
    Some(rel) => {
      if rel.external {
        docx_text_unsupported("external numbering")
      }
      docx_numbering_from_xml(
        @utf8.decode_lossy(package.read(rel.target)[:], ignore_bom=true),
      )
    }
    None => docx_numbering_empty()
  }
  docx_apply_numbering(walker.paragraphs, numbering)
  { part, sections, paragraphs: walker.paragraphs, }
}
