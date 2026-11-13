///|
// A drawing anchored in a paragraph (wp:anchor). The object floats on the
// page: wrap keeps the text out of its area and behind places it under the
// text of the page. The offsets are the parsed wp:posOffset values; the
// layout resolves them against the page, the margins, the column or the
// paragraph.
priv struct DocxAnchor {
  h_rel : String
  v_rel : String
  h_align : String
  v_align : String
  wrap : String
  side : String
  dist_top : Double
  dist_bottom : Double
  dist_left : Double
  dist_right : Double
  effect_top : Double
  effect_bottom : Double
  effect_left : Double
  effect_right : Double
  behind : Bool
  z : Int32
} derive(Debug, Eq)

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
  draw_width : Double
  draw_height : Double
  effect_left : Double
  effect_top : Double
  effect_right : Double
  effect_bottom : Double
  anchored : Bool
  anchor : DocxAnchor?
  x : Double
  y : Double
  crop_left : Double
  crop_top : Double
  crop_right : Double
  crop_bottom : Double
  rotation : Double
  flip_h : Bool
  flip_v : Bool
  mut link : String
  mut small_caps : Bool
  field_format : String
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
// A border width of zero means that the side is not drawn.
priv struct DocxLineBorder {
  width : Double
  color : UInt32
  space : Double
  style : String
} derive(Debug, Eq)

///|
priv struct DocxMargins {
  top : Double?
  left : Double?
  bottom : Double?
  right : Double?
} derive(Debug, Eq)

///|
priv struct DocxTableCell {
  col : Int32
  span : Int32
  vmerge : String
  mut row_span : Int32
  borders : Array[DocxLineBorder?]
  tl2br : DocxLineBorder?
  tr2bl : DocxLineBorder?
  shade : UInt32?
  mar : DocxMargins
  valign : String
  blocks : Array[DocxBlock]
}

///|
priv struct DocxTableRow {
  cells : Array[DocxTableCell]
  height : Double
  exact : Bool
  cant_split : Bool
  header : Bool
  grid_before : Int32
}

///|
priv struct DocxTable {
  grid : Array[Double]
  width_type : String
  width : Double
  layout_type : String
  jc : String
  ind : Double
  cell_spacing : Double
  borders : Array[DocxLineBorder?]
  cell_mar : DocxMargins
  shade : UInt32?
  rows : Array[DocxTableRow]
  section_index : Int32
}

///|
priv enum DocxBlock {
  DocxParaBlock(DocxTextParagraph)
  DocxTableBlock(DocxTable)
}

///|
priv struct DocxTextDocument {
  part : String
  sections : Array[DocxSection]
  blocks : Array[DocxBlock]
  paragraphs : Array[DocxTextParagraph]
  stories : Map[String, Array[DocxTextParagraph]]
  story_tables : Map[String, Array[DocxTable]]
  bookmark_text : Map[String, String]
  footnotes : Map[String, Array[String]]
  endnotes : Map[String, Array[String]]
  even_odd : Bool
  language : String
  background : UInt32?
  has_math : Bool
  warnings : Array[String]
}

///|
priv struct DocxFieldState {
  mut instr : String
  mut result : Bool
  mut typ : String
  mut format : String
  mut arg : String
  mut emitted : Bool
}

///|
priv struct DocxTextWalker {
  styles : DocxStyles
  blocks : Array[DocxBlock]
  paragraphs : Array[DocxTextParagraph]
  mut section_index : Int32
  fields : Array[DocxFieldState]
  bookmarks : Map[String, StringBuilder]
  open_bookmarks : Array[String]
  mut current_link : String
  // Set when this walker parses an OMML formula, so the converter can report
  // that no font with a MATH table was available to lay it out.
  mut has_math : Bool
  // Degrade notes, such as drawings whose visual content is not supported.
  // The converter surfaces them in its result instead of failing the part.
  warnings : Array[String]
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
/// Note content the converter degrades instead of drawing or extracting it.
/// The note is reported once per walker; the converter merges the notes of
/// every walker into the warnings of its result.
fn docx_text_warn(walker : DocxTextWalker, message : String) -> Unit {
  if !walker.warnings.contains(message) {
    walker.warnings.push(message)
  }
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
      "pgBorders" =>
        for border in child.children {
          if !["top", "left", "bottom", "right"].contains(border.name()) ||
            !border.children.is_empty() {
            docx_text_unsupported(child.name())
          }
        }
      other => docx_text_unsupported(other)
    }
  }
}

///|
/// The paragraph mark's direct run properties: w:pPr/w:rPr without its
/// w:rStyle selector. Upstream resolves the mark with the default
/// character style (wordproc/model.go paragraph() passes rStyle ""), so a
/// character style named inside the mark's rPr is not consulted there.
fn docx_mark_rpr(direct : DocxXmlNode?) -> DocxXmlNode? raise {
  match docx_style_child(direct, "rPr") {
    Some(value) => Some(docx_style_without_selector(value, "rStyle"))
    None => None
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
      "pBdr" => props.apply_node(child)
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
        props.apply_node(child)
      }
      // The paragraph mark's own run properties. Upstream's applyPPr has
      // no default case: this child belongs to the mark resolved like a
      // run in blocks() (wordproc/model.go paragraph()).
      "rPr" => ()
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
}

///|
fn docx_text_chars(
  walker : DocxTextWalker,
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
        let text = s.to_string()
        docx_text_push(items, "char", text, props)
        for name in walker.open_bookmarks {
          match walker.bookmarks.get(name) {
            Some(buffer) => buffer.write_string(text)
            None => ()
          }
        }
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
fn docx_anchor_align(node : DocxXmlNode, name : String) -> String {
  match node.child(name) {
    Some(value) => value.text.to_string().trim().to_string()
    None => ""
  }
}

///|
fn docx_anchor_position(
  anchor : DocxXmlNode,
  name : String,
  default_rel : String,
) -> (String, String, Double) {
  match anchor.child(name) {
    Some(value) => {
      let rel = docx_attribute(value.element, "relativeFrom", default_rel)
      let align = docx_anchor_align(value, "align")
      let offset = match value.child("posOffset") {
        Some(offset) => docx_emu(offset.text.to_string())
        None => 0.0
      }
      (rel, align, offset)
    }
    None => (default_rel, "", 0.0)
  }
}

///|
// docx_text_anchor reads a wp:anchor: where it is positioned (a page, a
// margin, the column or the paragraph) and the area its wrap keeps the text
// out of. A simple position (wp:simplePos) is relative to the page.
fn docx_text_anchor(container : DocxXmlNode) -> (Double, Double, DocxAnchor) {
  let mut x = 0.0
  let mut y = 0.0
  let mut h_rel = "column"
  let mut v_rel = "paragraph"
  let mut h_align = ""
  let mut v_align = ""
  if docx_attribute(container.element, "simplePos", "0") == "1" {
    h_rel = "page"
    v_rel = "page"
    match container.child("simplePos") {
      Some(value) => {
        x = docx_emu(docx_attribute(value.element, "x", "0"))
        y = docx_emu(docx_attribute(value.element, "y", "0"))
      }
      None => ()
    }
  } else {
    let (h_relative, h_alignment, h_offset) = docx_anchor_position(
      container, "positionH", "column",
    )
    h_rel = h_relative
    h_align = h_alignment
    x = h_offset
    let (v_relative, v_alignment, v_offset) = docx_anchor_position(
      container, "positionV", "paragraph",
    )
    v_rel = v_relative
    v_align = v_alignment
    y = v_offset
  }
  let mut wrap = "none"
  let mut side = "bothSides"
  for child in container.children {
    match child.name() {
      "wrapSquare" | "wrapTight" | "wrapThrough" => {
        // Tight and through wrapping keep the text out of the object's
        // box, as square wrapping does.
        wrap = "square"
        side = docx_attribute(child.element, "wrapText", "bothSides")
      }
      "wrapTopAndBottom" => wrap = "topAndBottom"
      _ => ()
    }
  }
  let effect = container.child("effectExtent")
  let mut effect_left = 0.0
  let mut effect_top = 0.0
  let mut effect_right = 0.0
  let mut effect_bottom = 0.0
  match effect {
    Some(value) => {
      effect_left = docx_emu(docx_attribute(value.element, "l", "0"))
      effect_top = docx_emu(docx_attribute(value.element, "t", "0"))
      effect_right = docx_emu(docx_attribute(value.element, "r", "0"))
      effect_bottom = docx_emu(docx_attribute(value.element, "b", "0"))
    }
    None => ()
  }
  let anchor : DocxAnchor = {
    h_rel: h_rel,
    v_rel: v_rel,
    h_align: h_align,
    v_align: v_align,
    wrap: wrap,
    side: side,
    dist_top: docx_emu(docx_attribute(container.element, "distT", "0")),
    dist_bottom: docx_emu(docx_attribute(container.element, "distB", "0")),
    dist_left: docx_emu(docx_attribute(container.element, "distL", "0")),
    dist_right: docx_emu(docx_attribute(container.element, "distR", "0")),
    effect_top,
    effect_bottom,
    effect_left,
    effect_right,
    behind: docx_attribute(container.element, "behindDoc", "0") == "1",
    z: @string.parse_int(docx_attribute(container.element, "relativeHeight", "0")) catch {
      _ => 0
    },
  }
  (x, y, anchor)
}

///|
fn docx_text_drawing(
  walker : DocxTextWalker,
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
  let mut blip = false
  fn find_blip(value : DocxXmlNode) -> Unit {
    if value.name() == "blip" {
      blip = true
      embed = docx_attribute_any(value.element, "embed", "")
    }
    for child in value.children {
      find_blip(child)
    }
  }
  find_blip(container)
  if blip && embed == "" {
    // A picture drawing with a blip that names no image part keeps failing
    // the part: the file it points at is lost, and the degrade below is for
    // drawings without any embedded image at all. A blip with an embed that
    // no relationship resolves to fails when the image is laid out.
    docx_text_unsupported("picture drawing with a missing image reference")
  }
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
    // The drawing is a shape, a group, a chart or SmartArt: visual content
    // this converter does not draw. Upstream renders it, so the document is
    // degraded, not failed: the drawing is skipped, one warning is surfaced,
    // and docPr/@descr survives as the FIGURE mark of the skipped content,
    // the way upstream marks the alternative text of a drawing.
    docx_text_warn(
      walker,
      "DOCX: a drawing without an embedded image or text box (shape, group, chart or SmartArt) was skipped",
    )
    let descr = match container.child("docPr") {
      Some(pr) => docx_attribute(pr.element, "descr", "").trim()
      None => ""
    }
    if descr == "" {
      return
    }
    let anchored = node.child("inline") is None
    let mut x = 0.0
    let mut y = 0.0
    let mut anchor : DocxAnchor? = None
    if anchored {
      let (anchor_x, anchor_y, parsed) = docx_text_anchor(container)
      x = anchor_x
      y = anchor_y
      anchor = Some(parsed)
    }
    items.push({
      kind: "figure",
      text: descr.to_string(),
      clear: false,
      props,
      width,
      height,
      draw_width: 0.0,
      draw_height: 0.0,
      effect_left: 0.0,
      effect_top: 0.0,
      effect_right: 0.0,
      effect_bottom: 0.0,
      anchored,
      anchor,
      x,
      y,
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
    return
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
  let effect = container.child("effectExtent")
  let mut effect_left = 0.0
  let mut effect_top = 0.0
  let mut effect_right = 0.0
  let mut effect_bottom = 0.0
  match effect {
    Some(value) => {
      effect_left = docx_emu(docx_attribute(value.element, "l", "0"))
      effect_top = docx_emu(docx_attribute(value.element, "t", "0"))
      effect_right = docx_emu(docx_attribute(value.element, "r", "0"))
      effect_bottom = docx_emu(docx_attribute(value.element, "b", "0"))
    }
    None => ()
  }
  let mut x = 0.0
  let mut y = 0.0
  let mut anchor : DocxAnchor? = None
  if anchored {
    let (anchor_x, anchor_y, parsed) = docx_text_anchor(container)
    x = anchor_x
    y = anchor_y
    anchor = Some(parsed)
  }
  let (picture_border_width, picture_border_color) = docx_picture_border(
    container,
  )
  items.push({
    kind: "image",
    text: embed,
    clear: false,
    props,
    width,
    height,
    draw_width: width,
    draw_height: height,
    effect_left,
    effect_top,
    effect_right,
    effect_bottom,
    anchored,
    anchor,
    x,
    y,
    crop_left,
    crop_top,
    crop_right,
    crop_bottom,
    rotation,
    flip_h,
    flip_v,
    link: "",
    small_caps: false,
    field_format: "",
    shade: None,
    border_width: picture_border_width,
    border_color: picture_border_color,
  })
}

///|
fn docx_picture_border(node : DocxXmlNode) -> (Double, UInt32?) {
  let pending : Array[DocxXmlNode] = [node]
  while !pending.is_empty() {
    let value = pending.pop().unwrap()
    if value.name() == "spPr" {
      match value.child("ln") {
        Some(line) => {
          let width = docx_emu(docx_attribute(line.element, "w", "0"))
          let color = match line.child("solidFill") {
            Some(fill) => docx_fill_color(fill.element)
            None => None
          }
          return (width, color)
        }
        None => ()
      }
    }
    for child in value.children {
      pending.push(child)
    }
  }
  (0.0, None)
}

///|
fn docx_omml_attr(
  node : DocxXmlNode,
  name : String,
  default : String,
) -> String {
  docx_attribute(node.element, name, default)
}

///|
fn docx_omml_join(node : DocxXmlNode) -> String {
  let out = StringBuilder()
  for child in node.children {
    let name = child.name()
    if name == "rPr" ||
      name == "ctrlPr" ||
      name == "sdtPr" ||
      name == "bookmarkStart" ||
      name == "bookmarkEnd" {
      continue
    }
    out.write_string(docx_omml_linear(child))
  }
  out.to_string()
}

///|
fn docx_omml_wrap(text : String) -> String {
  if text == "" {
    return text
  }
  let mut simple = text.length() == 1
  if text.length() > 1 {
    simple = true
    for c in text {
      if c == ' ' ||
        c == '+' ||
        c == '-' ||
        c == '=' ||
        c == ',' ||
        c == ';' ||
        c == '/' ||
        c == '*' ||
        c == '<' ||
        c == '>' ||
        c == '\u2212' ||
        c == '\u00b1' ||
        c == '\u00d7' ||
        c == '\u00f7' ||
        c == '\u2211' ||
        c == '\u222b' ||
        c == '\u221a' ||
        c == '\u00b7' ||
        c == '\u2264' ||
        c == '\u2265' ||
        c == '\u2260' ||
        c == '\u221e' ||
        c == '\u03c0' {
        simple = false
        break
      }
    }
  }
  if simple {
    text
  } else if text.length() >= 2 &&
    text[0] == '(' &&
    text[text.length() - 1] == ')' {
    text
  } else {
    "(" + text + ")"
  }
}

///|
fn docx_omml_paren(text : String) -> String {
  if text.length() >= 2 && text[0] == '(' && text[text.length() - 1] == ')' {
    text
  } else {
    "(" + text + ")"
  }
}

///|
fn docx_omml_node_text(node : DocxXmlNode?) -> String {
  match node {
    Some(value) => docx_omml_join(value)
    None => ""
  }
}

///|
fn docx_omml_linear(node : DocxXmlNode) -> String {
  let name = node.name()
  match name {
    "t" => node.text.to_string()
    "r"
    | "e"
    | "num"
    | "den"
    | "sub"
    | "sup"
    | "deg"
    | "lim"
    | "fName"
    | "oMath" => docx_omml_join(node)
    "f" => {
      let num = docx_omml_node_text(node.child("num"))
      let den = docx_omml_node_text(node.child("den"))
      docx_omml_paren(num) + "/" + docx_omml_paren(den)
    }
    "rad" => {
      let body = docx_omml_node_text(node.child("e"))
      let degree = docx_omml_node_text(node.child("deg"))
      if degree == "" {
        "√(" + body + ")"
      } else {
        degree + "√(" + body + ")"
      }
    }
    "sSup" => {
      let base = docx_omml_node_text(node.child("e"))
      let sup = docx_omml_node_text(node.child("sup"))
      docx_omml_wrap(base) + "^" + docx_omml_wrap(sup)
    }
    "sSub" => {
      let base = docx_omml_node_text(node.child("e"))
      let sub = docx_omml_node_text(node.child("sub"))
      docx_omml_wrap(base) + "_" + docx_omml_wrap(sub)
    }
    "sSubSup" => {
      let base = docx_omml_node_text(node.child("e"))
      let sub = docx_omml_node_text(node.child("sub"))
      let sup = docx_omml_node_text(node.child("sup"))
      docx_omml_wrap(base) +
      "_" +
      docx_omml_wrap(sub) +
      "^" +
      docx_omml_wrap(sup)
    }
    "sPre" => {
      let base = docx_omml_node_text(node.child("e"))
      let sub = docx_omml_node_text(node.child("sub"))
      let sup = docx_omml_node_text(node.child("sup"))
      "_" +
      docx_omml_wrap(sub) +
      "^" +
      docx_omml_wrap(sup) +
      docx_omml_wrap(base)
    }
    "nary" => {
      let chr = match node.child("naryPr") {
        Some(pr) => {
          let value = docx_omml_attr(pr, "chr", "")
          if value == "" {
            "∫"
          } else {
            value
          }
        }
        None => "∫"
      }
      let sub = docx_omml_node_text(node.child("sub"))
      let sup = docx_omml_node_text(node.child("sup"))
      let body = docx_omml_node_text(node.child("e"))
      let mut out = chr
      if sub != "" {
        out += "_" + docx_omml_wrap(sub)
      }
      if sup != "" {
        out += "^" + docx_omml_wrap(sup)
      }
      out + " " + body
    }
    "func" => {
      let fname = docx_omml_node_text(node.child("fName"))
      let body = docx_omml_node_text(node.child("e"))
      fname + " " + body
    }
    "limLow" => {
      let base = docx_omml_node_text(node.child("e"))
      let lim = docx_omml_node_text(node.child("lim"))
      docx_omml_wrap(base) + "_" + docx_omml_wrap(lim)
    }
    "limUpp" => {
      let base = docx_omml_node_text(node.child("e"))
      let lim = docx_omml_node_text(node.child("lim"))
      docx_omml_wrap(base) + "^" + docx_omml_wrap(lim)
    }
    "d" => {
      let pr = node.child("dPr")
      let beg = match pr {
        Some(value) => {
          let attr = docx_omml_attr(value, "begChr", "")
          if attr == "" {
            "("
          } else {
            attr
          }
        }
        None => "("
      }
      let end = match pr {
        Some(value) => {
          let attr = docx_omml_attr(value, "endChr", "")
          if attr == "" {
            ")"
          } else {
            attr
          }
        }
        None => ")"
      }
      beg + docx_omml_node_text(node.child("e")) + end
    }
    "m" => {
      let rows : Array[String] = []
      for row in node.children {
        if row.name() != "mr" {
          continue
        }
        let cells : Array[String] = []
        for cell in row.children {
          if cell.name() == "e" {
            cells.push(docx_omml_join(cell))
          }
        }
        rows.push(cells.join(", "))
      }
      "(" + rows.join("; ") + ")"
    }
    "acc" | "bar" | "groupChr" | "box" | "borderBox" | "phant" =>
      docx_omml_node_text(node.child("e"))
    "eqArr" => {
      let rows : Array[String] = []
      for child in node.children {
        if child.name() == "e" {
          rows.push(docx_omml_join(child))
        }
      }
      rows.join("; ")
    }
    _ => docx_omml_join(node)
  }
}

///|
// The markup-compatibility namespace prefixes whose mc:Choice content the
// walker draws instead of the Fallback. A copy of upstream wordproc/docx.go.
fn docx_alternate_content_prefix_supported(prefix : String) -> Bool {
  match prefix {
    "wps" | "wpg" | "wpc" | "wp14" | "w14" | "w15" | "a14" | "pic14" => true
    _ => false
  }
}

///|
// A Choice qualifies when its Requires attribute names at least one prefix
// and every prefix is supported, as upstream requiresAll does: a Choice
// without Requires defers to the Fallback.
fn docx_alternate_content_choice_supported(choice : DocxXmlNode) -> Bool {
  let requires = docx_attribute(choice.element, "Requires", "")
  let prefix = StringBuilder()
  let mut count = 0
  let mut supported = true
  fn check(word : String) -> Bool {
    count += 1
    docx_alternate_content_prefix_supported(word)
  }
  for ch in requires {
    if ch.is_whitespace() {
      if prefix.to_string() != "" {
        if !check(prefix.to_string()) {
          supported = false
        }
        prefix.reset()
      }
    } else {
      prefix.write_char(ch)
    }
  }
  if prefix.to_string() != "" {
    if !check(prefix.to_string()) {
      supported = false
    }
  }
  supported && count > 0
}

///|
fn docx_alternate_content(node : DocxXmlNode) -> DocxXmlNode? {
  for child in node.children {
    if child.name() == "Choice" && docx_alternate_content_choice_supported(child) {
      return Some(child)
    }
  }
  for child in node.children {
    if child.name() == "Fallback" {
      return Some(child)
    }
  }
  for child in node.children {
    if child.name() == "Choice" {
      return Some(child)
    }
  }
  None
}

///|
fn docx_text_omml(
  walker : DocxTextWalker,
  node : DocxXmlNode,
  items : Array[DocxTextItem],
  props : DocxRunProps,
) -> Unit {
  walker.has_math = true
  let text = docx_omml_linear(node)
  if text != "" {
    docx_text_chars(walker, items, text, props)
  }
}

///|

///|
fn docx_field_info(instr : String) -> (String, String, String) {
  let tokens : Array[String] = []
  let current = StringBuilder()
  for c in instr {
    if c == ' ' || c == '\t' || c == '\n' || c == '\r' {
      if current.to_string() != "" {
        tokens.push(current.to_string())
        current.reset()
      }
    } else {
      current.write_char(c)
    }
  }
  if current.to_string() != "" {
    tokens.push(current.to_string())
  }
  if tokens.is_empty() {
    return ("", "", "")
  }
  let typ = tokens[0].to_upper()
  let mut format = ""
  let mut target = ""
  let mut i = 1
  while i < tokens.length() {
    if tokens[i] == "\\*" && i + 1 < tokens.length() {
      format = tokens[i + 1]
    } else if target == "" && i == 1 {
      target = tokens[i]
    }
    i += 1
  }
  (typ, format, target)
}

///|
fn docx_field_dynamic(typ : String) -> Bool {
  typ == "PAGE" ||
  typ == "NUMPAGES" ||
  typ == "SECTIONPAGES" ||
  typ == "PAGEREF" ||
  typ == "REF"
}

///|
fn docx_text_field(
  items : Array[DocxTextItem],
  props : DocxRunProps,
  typ : String,
  format : String,
  arg : String,
) -> Unit {
  items.push({
    kind: "field",
    text: if typ == "PAGEREF" || typ == "REF" {
      typ + "\u{0001}" + arg
    } else {
      typ
    },
    clear: false,
    props,
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
    field_format: format,
    shade: None,
    border_width: 0.0,
    border_color: None,
  })
}

///|
fn docx_dynamic_field(walker : DocxTextWalker) -> DocxFieldState? {
  if walker.fields.is_empty() {
    return None
  }
  let field = walker.fields[walker.fields.length() - 1]
  if field.result && docx_field_dynamic(field.typ) {
    Some(field)
  } else {
    None
  }
}

///|
fn docx_theme_color(name : String) -> UInt32? {
  match name {
    "dark1" | "text1" => Some(0x000000ffU)
    "light1" | "background1" => Some(0xffffffffU)
    "dark2" | "text2" => Some(0x44546affU)
    "light2" | "background2" => Some(0xe7e6e6ffU)
    "accent1" => Some(0x4472c4ffU)
    "accent2" => Some(0xed7d31ffU)
    "accent3" => Some(0xa5a5a5ffU)
    "accent4" => Some(0xffc000ffU)
    "accent5" => Some(0x5b9bd5ffU)
    "accent6" => Some(0x70ad47ffU)
    "hyperlink" => Some(0x0563c1ffU)
    "followedHyperlink" => Some(0x954f72ffU)
    _ => None
  }
}

///|
fn docx_highlight_color(name : String) -> UInt32? {
  match name {
    "yellow" => Some(0xffff00ffU)
    "green" => Some(0x00ff00ffU)
    "cyan" => Some(0x00ffffffU)
    "magenta" => Some(0xff00ffffU)
    "blue" => Some(0x0000ffffU)
    "red" => Some(0xff0000ffU)
    "darkBlue" => Some(0x000080ffU)
    "darkCyan" => Some(0x008080ffU)
    "darkGreen" => Some(0x008000ffU)
    "darkMagenta" => Some(0x800080ffU)
    "darkRed" => Some(0x800000ffU)
    "darkYellow" => Some(0x808000ffU)
    "gray" => Some(0x808080ffU)
    "lightGray" => Some(0xc0c0c0ffU)
    "black" => Some(0x000000ffU)
    "white" => Some(0xffffffffU)
    _ => None
  }
}

///|
fn docx_text_run(
  walker : DocxTextWalker,
  node : DocxXmlNode,
  items : Array[DocxTextItem],
  paragraph_style : String,
) -> Unit raise {
  let styles = walker.styles
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
  // Hidden text is not part of the visible document.
  if (props.toggles & 64) != 0 {
    return
  }
  let first = items.length()
  docx_text_run_content(walker, node, items, props)
  let highlight = docx_highlight_color(props.highlight)
  for index in first..<items.length() {
    items[index].link = walker.current_link
    items[index].small_caps = (props.toggles & 8) != 0 &&
      (props.toggles & 4) == 0
    if props.has_shading {
      items[index].shade = Some(props.shading)
    } else if highlight is Some(color) {
      items[index].shade = Some(color)
    }
  }
}

///|
// The run content of one node, with resolved run properties. A chosen
// mc:AlternateContent branch is run content in place (upstream splices the
// chosen child into its parent), so it is dispatched back through here
// instead of the paragraph inline walker, which rejects a direct drawing.
fn docx_text_run_content(
  walker : DocxTextWalker,
  node : DocxXmlNode,
  items : Array[DocxTextItem],
  props : DocxRunProps,
) -> Unit raise {
  for child in node.children {
    let name = child.name()
    if name != "rPr" &&
      name != "t" &&
      name != "drawing" &&
      name != "AlternateContent" &&
      !child.children.is_empty() {
      docx_text_unsupported(name)
    }
    match name {
      "rPr" => ()
      "fldChar" => {
        let kind = docx_attribute(child.element, "fldCharType", "")
        match kind {
          "begin" =>
            walker.fields.push({
              instr: "",
              result: false,
              typ: "",
              format: "",
              arg: "",
              emitted: false,
            })
          "separate" =>
            if !walker.fields.is_empty() {
              let field = walker.fields[walker.fields.length() - 1]
              if !field.result {
                let (typ, format, arg) = docx_field_info(field.instr)
                field.typ = typ
                field.format = format
                field.arg = arg
                field.result = true
              }
            }
          "end" =>
            if !walker.fields.is_empty() {
              let field = walker.fields.pop().unwrap()
              if docx_field_dynamic(field.typ) && !field.emitted {
                docx_text_field(
                  items, props, field.typ, field.format, field.arg,
                )
              }
            }
          _ => ()
        }
      }
      "instrText" =>
        if !walker.fields.is_empty() {
          let field = walker.fields[walker.fields.length() - 1]
          if !field.result {
            field.instr += child.text.to_string()
          }
        }
      "t" => {
        if !child.children.is_empty() {
          docx_text_unsupported(name)
        }
        match docx_dynamic_field(walker) {
          Some(field) =>
            if !field.emitted {
              docx_text_field(
                items, props, field.typ, field.format, field.arg,
              )
              field.emitted = true
            }
          None => {
            let text = child.text.to_string()
            let text = if (props.toggles & 4) != 0 {
              text.to_upper()
            } else {
              text
            }
            docx_text_chars(walker, items, text, props)
          }
        }
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
      "noBreakHyphen" => docx_text_chars(walker, items, "\u2011", props)
      "softHyphen" | "lastRenderedPageBreak" => ()
      "drawing" => docx_text_drawing(walker, child, items, props)
      "footnoteReference" =>
        docx_text_push(
          items,
          "footnote",
          docx_attribute(child.element, "id", ""),
          props,
        )
      "endnoteReference" =>
        docx_text_push(
          items,
          "endnote",
          docx_attribute(child.element, "id", ""),
          props,
        )
      "commentReference" => ()
      "delText" => ()
      "sym" => {
        let code = docx_attribute(child.element, "char", "")
        let value = @string.parse_int(code, base=16) catch { _ => -1 }
        if value > 0 && value <= 0x10ffff {
          docx_text_chars(walker, items, Char::from_int(value).to_string(), props)
        }
      }
      "oMath" | "oMathPara" => docx_text_omml(walker, child, items, props)
      "AlternateContent" =>
        match docx_alternate_content(child) {
          Some(chosen) => docx_text_run_content(walker, chosen, items, props)
          None => ()
        }
      other => docx_text_unsupported(other)
    }
    if docx_dynamic_field(walker) is Some(field) {
      // The cached result of a page field is not drawn; the field item
      // stands in for it and the renderer substitutes the value.
      if !field.emitted {
        docx_text_field(items, props, field.typ, field.format, field.arg)
        field.emitted = true
      }
    }
  }
}

///|
fn docx_text_inlines(
  walker : DocxTextWalker,
  node : DocxXmlNode,
  items : Array[DocxTextItem],
  paragraph_style : String,
) -> Unit raise {
  for child in node.children {
    match child.name() {
      "pPr" => ()
      "r" => docx_text_run(walker, child, items, paragraph_style)
      "fldSimple" => {
        let (typ, format, arg) = docx_field_info(
          docx_attribute(child.element, "instr", ""),
        )
        if docx_field_dynamic(typ) {
          let props = walker.styles.resolve_run(paragraph_style, None)
          docx_text_field(items, props, typ, format, arg)
        } else {
          docx_text_inlines(walker, child, items, paragraph_style)
        }
      }
      "hyperlink" => {
        let mut link = docx_attribute_any(child.element, "id", "")
        if link == "" {
          let anchor = docx_attribute(child.element, "anchor", "")
          if anchor != "" {
            link = "#anchor:" + anchor
          }
        }
        let old = walker.current_link
        if link != "" {
          walker.current_link = link
        }
        docx_text_inlines(walker, child, items, paragraph_style)
        walker.current_link = old
      }
      "smartTag"
      | "customXml"
      | "ins"
      | "moveTo"
      | "dir"
      | "bdo" => docx_text_inlines(walker, child, items, paragraph_style)
      "oMath" | "oMathPara" => {
        let props = walker.styles.resolve_run(paragraph_style, None)
        docx_text_omml(walker, child, items, props)
      }
      "bookmarkStart" => {
        let name = docx_attribute(child.element, "name", "")
        if name != "" && name != "_GoBack" {
          let props = walker.styles.resolve_run(paragraph_style, None)
          docx_text_push(items, "bookmark", name, props)
          if !walker.bookmarks.contains(name) {
            walker.bookmarks[name] = StringBuilder()
          }
          walker.open_bookmarks.push(name)
        }
      }
      "bookmarkEnd" =>
        if !walker.open_bookmarks.is_empty() {
          ignore(walker.open_bookmarks.pop())
        }
      "proofErr"
      | "commentRangeStart"
      | "commentRangeEnd"
      | "permStart"
      | "permEnd"
      | "del"
      | "moveFrom" => ()
      "AlternateContent" =>
        match docx_alternate_content(child) {
          Some(chosen) =>
            docx_text_inlines(walker, chosen, items, paragraph_style)
          None => ()
        }
      "sdt" => {
        let mut seen_content = false
        for sub in child.children {
          if sub.name() == "sdtContent" && !seen_content {
            seen_content = true
            docx_text_inlines(walker, sub, items, paragraph_style)
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
fn docx_collect_children(
  node : DocxXmlNode,
  name : String,
  out : Array[DocxXmlNode],
) -> Unit {
  for child in node.children {
    let child_name = child.name()
    if child_name == name {
      out.push(child)
    } else if child_name == "sdt" {
      match child.child("sdtContent") {
        Some(content) => docx_collect_children(content, name, out)
        None => ()
      }
    } else if child_name == "customXml" ||
      child_name == "ins" ||
      child_name == "moveTo" {
      docx_collect_children(child, name, out)
    }
  }
}

///|
fn docx_child_shade(node : DocxXmlNode?) -> UInt32? {
  match node {
    Some(value) =>
      match value.child("shd") {
        Some(shade) => docx_fill_color(shade.element)
        None => None
      }
    None => None
  }
}

///|
fn docx_fill_color(element : @xml.NamespaceElement) -> UInt32? {
  let fill = docx_attribute(element, "fill", "")
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

///|
fn docx_line_border(node : DocxXmlNode?) -> DocxLineBorder? {
  match node {
    Some(value) => {
      let style = docx_attribute(value.element, "val", "single")
      if style == "nil" || style == "none" || style == "" {
        return None
      }
      let size = docx_attribute(value.element, "sz", "4")
      let width = Double::max(
        (@string.parse_double(size) catch { _ => 4.0 }) / 8.0,
        0.25,
      )
      let color = docx_attribute(value.element, "color", "auto")
      let parsed = if color.length() == 6 {
        @string.parse_int(color, base=16) catch {
          _ => -1
        }
      } else {
        -1
      }
      let space = docx_measure(docx_attribute(value.element, "space", "0"), 0.0)
      Some({
        width,
        color: if parsed >= 0 {
          (parsed.to_uint() << 8) | 0xffU
        } else {
          0x000000ffU
        },
        space,
        style,
      })
    }
    None => None
  }
}

///|
fn docx_border_sides(
  node : DocxXmlNode?,
  names : Array[String],
) -> Array[DocxLineBorder?] {
  let sides : Array[DocxLineBorder?] = []
  for name in names {
    let found = match node {
      Some(value) => value.child(name)
      None => None
    }
    sides.push(docx_line_border(found))
  }
  sides
}

///|
fn docx_margins(node : DocxXmlNode?) -> DocxMargins {
  let margin = match node {
    Some(value) => value
    None => return { top: None, left: None, bottom: None, right: None, }
  }
  let one = fn(names : Array[String]) -> Double? {
    for name in names {
      match margin.child(name) {
        Some(value) =>
          return Some(docx_measure(docx_attribute(value.element, "w", ""), 0.0))
        None => ()
      }
    }
    None
  }
  {
    top: one(["top"]),
    left: one(["left", "start"]),
    bottom: one(["bottom"]),
    right: one(["right", "end"]),
  }
}

///|
fn docx_look_bool(
  element : @xml.NamespaceElement,
  key : String,
  bit : Int,
  bits : Int,
  default : Bool,
) -> Bool {
  if docx_attribute(element, key, "") != "" {
    docx_bool(element, key, default)
  } else if bits >= 0 {
    (bits & bit) != 0
  } else {
    default
  }
}

///|
fn docx_table_conditions(
  first_row : Bool,
  last_row : Bool,
  first_col : Bool,
  last_col : Bool,
  no_hband : Bool,
  no_vband : Bool,
  row_band : Int,
  col_band : Int,
  row : Int,
  col : Int,
  rows : Int,
  cols : Int,
) -> Array[String] {
  let out : Array[String] = []
  if !no_hband && row_band > 0 && row > 0 {
    let band = ((row - 1) / row_band) % 2
    out.push(if band == 0 { "band1Horz" } else { "band2Horz" })
  }
  if !no_vband && col_band > 0 && col > 0 {
    let band = ((col - 1) / col_band) % 2
    out.push(if band == 0 { "band1Vert" } else { "band2Vert" })
  }
  if first_row && row == 0 {
    out.push("firstRow")
  }
  if last_row && row == rows - 1 {
    out.push("lastRow")
  }
  if first_col && col == 0 {
    out.push("firstColumn")
  }
  if last_col && col + 1 == cols {
    out.push("lastColumn")
  }
  if row == 0 && col == 0 {
    out.push("nwCell")
  }
  if row == 0 && col + 1 == cols {
    out.push("neCell")
  }
  if row == rows - 1 && col == 0 {
    out.push("swCell")
  }
  if row == rows - 1 && col + 1 == cols {
    out.push("seCell")
  }
  out
}

///|
fn docx_text_table(
  walker : DocxTextWalker,
  node : DocxXmlNode,
) -> DocxTable raise {
  let props = node.child("tblPr")
  let jc = match props {
    Some(value) =>
      match value.child("jc") {
        Some(align) => docx_attribute(align.element, "val", "left")
        None => "left"
      }
    None => "left"
  }
  let ind = match props {
    Some(value) =>
      match value.child("tblInd") {
        Some(indent) =>
          docx_measure(docx_attribute(indent.element, "w", ""), 0.0)
        None => 0.0
      }
    None => 0.0
  }
  let cell_spacing = match props {
    Some(value) =>
      match value.child("tblCellSpacing") {
        Some(spacing) =>
          docx_measure(docx_attribute(spacing.element, "w", ""), 0.0)
        None => 0.0
      }
    None => 0.0
  }
  let table_style_id = match props {
    Some(value) =>
      match value.child("tblStyle") {
        Some(style) => docx_attribute(style.element, "val", "")
        None => ""
      }
    None => ""
  }
  let table_style = table_style_id.to_lower()
  let layout_type = match props {
    Some(value) =>
      match value.child("tblLayout") {
        Some(layout) => docx_attribute(layout.element, "type", "fixed")
        None => "fixed"
      }
    None => "fixed"
  }
  let mut style_tbl_pr : DocxXmlNode? = None
  let mut style_tc_pr : DocxXmlNode? = None
  let cond_tc_prs : Map[String, Array[DocxXmlNode]] = {}
  let cond_rprs : Map[String, Array[DocxXmlNode]] = {}
  if table_style_id != "" {
    for style in walker.styles.chain(table_style_id) {
      if style.kind != "table" {
        continue
      }
      match style.tbl_pr {
        Some(value) => style_tbl_pr = Some(value)
        None => ()
      }
      match style.tc_pr {
        Some(value) => style_tc_pr = Some(value)
        None => ()
      }
      for key, cond in style.conds {
        match cond.tc_pr {
          Some(node) =>
            match cond_tc_prs.get(key) {
              Some(list) => list.push(node)
              None => cond_tc_prs[key] = [node]
            }
          None => ()
        }
        match cond.rpr {
          Some(node) =>
            match cond_rprs.get(key) {
              Some(list) => list.push(node)
              None => cond_rprs[key] = [node]
            }
          None => ()
        }
      }
    }
  }
  let mut look_first_row = true
  let mut look_last_row = false
  let mut look_first_col = true
  let mut look_last_col = false
  let mut look_no_hband = false
  let mut look_no_vband = false
  let mut row_band = 1
  let mut col_band = 1
  match props {
    Some(value) => {
      match value.child("tblLook") {
        Some(look) => {
          let raw = docx_attribute(look.element, "val", "").trim()
          let bits = if raw == "" {
            -1
          } else {
            @string.parse_int(raw, base=16) catch { _ => -1 }
          }
          look_first_row = docx_look_bool(
            look.element, "firstRow", 0x20, bits, true,
          )
          look_last_row = docx_look_bool(
            look.element, "lastRow", 0x40, bits, false,
          )
          look_first_col = docx_look_bool(
            look.element, "firstColumn", 0x80, bits, true,
          )
          look_last_col = docx_look_bool(
            look.element, "lastColumn", 0x100, bits, false,
          )
          look_no_hband = docx_look_bool(
            look.element, "noHBand", 0x200, bits, false,
          )
          look_no_vband = docx_look_bool(
            look.element, "noVBand", 0x400, bits, false,
          )
        }
        None => ()
      }
      match value.child("tblStyleRowBandSize") {
        Some(size) =>
          row_band = docx_number(
            docx_attribute(size.element, "val", "1"),
            1.0,
          ).to_int()
        None => ()
      }
      match value.child("tblStyleColBandSize") {
        Some(size) =>
          col_band = docx_number(
            docx_attribute(size.element, "val", "1"),
            1.0,
          ).to_int()
        None => ()
      }
    }
    None => ()
  }
  let base_borders = docx_border_sides(
    match props {
      Some(value) =>
        match value.child("tblBorders") {
          Some(node) => Some(node)
          None =>
            match style_tbl_pr {
              Some(style) => style.child("tblBorders")
              None => None
            }
        }
      None => None
    },
    ["top", "left", "bottom", "right", "insideH", "insideV"],
  )
  let borders = if table_style == "tablegrid" {
    base_borders.map(fn(border) {
      match border {
        Some(value) => Some(value)
        None => Some({ width: 0.5, color: 0x000000ffU, space: 0.0, style: "single" })
      }
    })
  } else {
    base_borders
  }
  let cell_mar = docx_margins(
    match props {
      Some(value) =>
        match value.child("tblCellMar") {
          Some(node) => Some(node)
          None =>
            match style_tbl_pr {
              Some(style) => style.child("tblCellMar")
              None => None
            }
        }
      None => None
    },
  )
  let mut shade = docx_child_shade(props)
  if shade is None {
    shade = docx_child_shade(style_tbl_pr)
  }
  let mut width_type = "auto"
  let mut width = 0.0
  match props {
    Some(value) =>
      match value.child("tblW") {
        Some(size) => {
          width_type = docx_attribute(size.element, "type", "auto")
          let raw = (@string.parse_double(
            docx_attribute(size.element, "w", "0"),
          ) catch {
            _ => 0.0
          })
          width = if width_type == "dxa" {
            raw / 20.0
          } else if width_type == "pct" {
            raw / 50.0
          } else if width_type == "nil" {
            0.0
          } else {
            raw
          }
        }
        None => ()
      }
    None => ()
  }
  let grid : Array[Double] = []
  match node.child("tblGrid") {
    Some(value) =>
      for column in value.children {
        if column.name() == "gridCol" {
          grid.push(docx_measure(docx_attribute(column.element, "w", ""), 0.0))
        }
      }
    None => ()
  }
  let row_nodes : Array[DocxXmlNode] = []
  docx_collect_children(node, "tr", row_nodes)
  let rows : Array[DocxTableRow] = []
  for row_index, row_node in row_nodes {
    let row_props = row_node.child("trPr")
    let mut height = 0.0
    let mut exact = false
    let mut cant_split = false
    let mut header = false
    let mut grid_before = 0
    match row_props {
      Some(value) => {
        match value.child("trHeight") {
          Some(size) => {
            height = docx_measure(docx_attribute(size.element, "val", ""), 0.0)
            exact = docx_attribute(size.element, "hRule", "atLeast") == "exact"
          }
          None => ()
        }
        match value.child("cantSplit") {
          Some(flag) => cant_split = docx_bool(flag.element, "val", true)
          None => ()
        }
        match value.child("tblHeader") {
          Some(flag) => header = docx_bool(flag.element, "val", true)
          None => ()
        }
        match value.child("gridBefore") {
          Some(count) =>
            grid_before = docx_number(
              docx_attribute(count.element, "val", "0"),
              0.0,
            ).to_int()
          None => ()
        }
      }
      None => ()
    }
    let cell_nodes : Array[DocxXmlNode] = []
    docx_collect_children(row_node, "tc", cell_nodes)
    let cells : Array[DocxTableCell] = []
    let mut col = grid_before
    for cell_node in cell_nodes {
      let cell_props = cell_node.child("tcPr")
      let span = match cell_props {
        Some(value) =>
          match value.child("gridSpan") {
            Some(grid_span) => {
              let number = @string.parse_int(
                docx_attribute(grid_span.element, "val", "1"),
              ) catch {
                _ => 1
              }
              if number < 1 {
                1
              } else {
                number
              }
            }
            None => 1
          }
        None => 1
      }
      let vmerge = match cell_props {
        Some(value) =>
          match value.child("vMerge") {
            Some(merge) => docx_attribute(merge.element, "val", "continue")
            None => ""
          }
        None => ""
      }
      let hmerge = match cell_props {
        Some(value) =>
          match value.child("hMerge") {
            Some(merge) => docx_attribute(merge.element, "val", "continue")
            None => ""
          }
        None => ""
      }
      if hmerge == "continue" && !cells.is_empty() {
        let previous = cells[cells.length() - 1]
        cells[cells.length() - 1] = { ..previous, span: previous.span + span, }
        col += span
        continue
      }
      let conditions = docx_table_conditions(
        look_first_row,
        look_last_row,
        look_first_col,
        look_last_col,
        look_no_hband,
        look_no_vband,
        row_band,
        col_band,
        row_index,
        col,
        row_nodes.length(),
        grid.length(),
      )
      let mut cond_tc_pr : DocxXmlNode? = None
      let mut cond_rpr : DocxXmlNode? = None
      for condition in conditions {
        match cond_tc_prs.get(condition) {
          Some(nodes) =>
            for node in nodes {
              cond_tc_pr = Some(node)
            }
          None => ()
        }
        match cond_rprs.get(condition) {
          Some(nodes) =>
            for node in nodes {
              cond_rpr = Some(node)
            }
          None => ()
        }
      }
      let all_borders = docx_border_sides(
        match cell_props {
          Some(value) =>
            match value.child("tcBorders") {
              Some(node) => Some(node)
              None =>
                match cond_tc_pr {
                  Some(cond) =>
                    match cond.child("tcBorders") {
                      Some(node) => Some(node)
                      None =>
                        match style_tc_pr {
                          Some(style) => style.child("tcBorders")
                          None => None
                        }
                    }
                  None =>
                    match style_tc_pr {
                      Some(style) => style.child("tcBorders")
                      None => None
                    }
                }
            }
          None =>
            match cond_tc_pr {
              Some(cond) =>
                match cond.child("tcBorders") {
                  Some(node) => Some(node)
                  None =>
                    match style_tc_pr {
                      Some(style) => style.child("tcBorders")
                      None => None
                    }
                }
              None =>
                match style_tc_pr {
                  Some(style) => style.child("tcBorders")
                  None => None
                }
            }
        },
        ["top", "left", "bottom", "right", "tl2br", "tr2bl"],
      )
      let side_borders : Array[DocxLineBorder?] = []
      for index in 0..<4 {
        side_borders.push(all_borders[index])
      }
      let mar = docx_margins(
        match cell_props {
          Some(value) =>
            match value.child("tcMar") {
              Some(node) => Some(node)
              None =>
                match cond_tc_pr {
                  Some(cond) =>
                    match cond.child("tcMar") {
                      Some(node) => Some(node)
                      None =>
                        match style_tc_pr {
                          Some(style) => style.child("tcMar")
                          None => None
                        }
                    }
                  None =>
                    match style_tc_pr {
                      Some(style) => style.child("tcMar")
                      None => None
                    }
                }
            }
          None =>
            match cond_tc_pr {
              Some(cond) =>
                match cond.child("tcMar") {
                  Some(node) => Some(node)
                  None =>
                    match style_tc_pr {
                      Some(style) => style.child("tcMar")
                      None => None
                    }
                }
              None =>
                match style_tc_pr {
                  Some(style) => style.child("tcMar")
                  None => None
                }
            }
        },
      )
      let valign = match cell_props {
        Some(value) =>
          match value.child("vAlign") {
            Some(align) => docx_attribute(align.element, "val", "top")
            None => "top"
          }
        None => "top"
      }
      let (blocks, cell_math) = docx_cell_blocks(
        cell_node,
        walker.styles,
        walker.warnings,
      )
      if cell_math {
        walker.has_math = true
      }
      match cond_rpr {
        Some(rpr) =>
          for block in blocks {
            match block {
              DocxParaBlock(paragraph) =>
                for item in paragraph.items {
                  item.props.apply_node(rpr)
                }
              DocxTableBlock(_) => ()
            }
          }
        None => ()
      }
      let mut cell_shade = docx_child_shade(cell_props)
      if cell_shade is None {
        cell_shade = docx_child_shade(cond_tc_pr)
      }
      if cell_shade is None {
        cell_shade = docx_child_shade(style_tc_pr)
      }
      cells.push({
        col,
        span,
        vmerge,
        row_span: 1,
        borders: side_borders,
        tl2br: all_borders[4],
        tr2bl: all_borders[5],
        shade: cell_shade,
        mar,
        valign,
        blocks,
      })
      col += span
    }
    rows.push({ cells, height, exact, cant_split, header, grid_before, })
  }
  // A vertical merge continues through the rows below it.
  for row_index, row in rows {
    for cell_index, cell in row.cells {
      if cell.vmerge != "restart" {
        continue
      }
      let mut span = 1
      let mut below = row_index + 1
      while below < rows.length() {
        let mut continued = false
        for candidate in rows[below].cells {
          if candidate.col == cell.col && candidate.vmerge == "continue" {
            continued = true
          }
        }
        if !continued {
          break
        }
        span += 1
        below += 1
      }
      rows[row_index].cells[cell_index].row_span = span
    }
  }
  {
    grid,
    width_type,
    width,
    layout_type,
    jc,
    ind,
    cell_spacing,
    borders,
    cell_mar,
    shade,
    rows,
    section_index: walker.section_index,
  }
}

///|
fn docx_cell_blocks(
  cell : DocxXmlNode,
  styles : DocxStyles,
  warnings : Array[String],
) -> (Array[DocxBlock], Bool) raise {
  let walker : DocxTextWalker = {
    styles,
    blocks: [],
    paragraphs: [],
    section_index: 0,
    fields: [],
    bookmarks: Map([]),
    open_bookmarks: [],
    current_link: "",
    has_math: false,
    warnings,
  }
  walker.blocks(cell, true)
  (walker.blocks, walker.has_math)
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
        // The paragraph mark (¶) resolves like a run: style chain plus the
        // direct w:pPr/w:rPr, which sizes empty paragraphs upstream
        // (wordproc/model.go paragraph()). Upstream binds the mark to the
        // document's default character style (runProps takes rStyle ""),
        // so an rStyle inside the mark's rPr selects nothing there; the
        // selector is stripped before the shared resolver.
        let mark = self.styles.resolve_run(
          paragraph_style,
          docx_mark_rpr(direct),
        )
        let ends_section = docx_style_child(direct, "sectPr") is Some(_)
        if ends_section && wrapped {
          docx_text_unsupported("wrapped paragraph section")
        }
        docx_text_inlines(self, child, items, paragraph_style)
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
        let paragraph : DocxTextParagraph = {
          props,
          mark,
          items,
          section_index: self.section_index,
        }
        self.paragraphs.push(paragraph)
        self.blocks.push(DocxParaBlock(paragraph))
        if ends_section {
          self.section_index += 1
        }
      }
      "tbl" => {
        let table = docx_text_table(self, child)
        self.blocks.push(DocxTableBlock(table))
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
      "tcPr" | "trPr" | "tblPr" | "tblGrid" | "bookmarkStart" | "bookmarkEnd" =>
        ()
      other => docx_text_unsupported(other)
    }
  }
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
fn docx_note_map(
  package : @ooxml.OoxmlPackage,
  part : String,
  rel_type : String,
  note_name : String,
) -> Map[String, Array[String]] raise {
  let notes : Map[String, Array[String]] = Map([])
  match package.relationship_of_type(part, rel_type) {
    Some(rel) => {
      if rel.external {
        docx_text_unsupported("external " + rel_type)
      }
      let root = docx_text_xml(
        @utf8.decode_lossy(package.read(rel.target)[:], ignore_bom=true),
      )
      for child in root.children {
        if child.name() != note_name {
          continue
        }
        let id = docx_attribute(child.element, "id", "")
        if id == "" || id == "-1" || id == "0" {
          continue
        }
        let lines : Array[String] = []
        for paragraph in child.children {
          if paragraph.name() != "p" {
            continue
          }
          let text = StringBuilder()
          fn collect(node : DocxXmlNode) -> Unit {
            if node.name() == "t" {
              text.write_string(node.text.to_string())
            }
            for sub in node.children {
              collect(sub)
            }
          }
          collect(paragraph)
          if text.to_string() != "" {
            lines.push(text.to_string())
          }
        }
        notes[id] = lines
      }
    }
    None => ()
  }
  notes
}

///|
fn docx_document_text(data : Bytes) -> DocxTextDocument raise {
  let package = @ooxml.open_ooxml(data)
  let part = match package.relationship_of_type("", "/officeDocument") {
    Some(rel) => rel.target
    None => "word/document.xml"
  }
  // Settings, footnotes and endnotes are read by later layout stages; a
  // document that has them is not rejected here.
  for typ in ["/footnotes", "/endnotes"] {
    match package.relationship_of_type(part, typ) {
      Some(rel) => if rel.external { docx_text_unsupported("external " + typ) }
      None => ()
    }
  }
  let theme_fonts = package.theme_fonts(part)
  let styles = match package.relationship_of_type(part, "/styles") {
    Some(rel) => {
      if rel.external {
        docx_text_unsupported("external styles")
      }
      let data = package.read(rel.target)
      docx_styles_from_xml(
        @utf8.decode(data[:], ignore_bom=true), theme_fonts~,
      )
    }
    None => docx_styles_from_xml("<styles/>", theme_fonts~)
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
  let background = match root.child("background") {
    Some(node) => {
      let color = docx_attribute(node.element, "color", "")
      if color.length() == 6 {
        let number = @string.parse_int(color, base=16) catch { _ => -1 }
        if number >= 0 {
          Some((number.to_uint() << 8) | 0xffU)
        } else {
          None
        }
      } else {
        let theme = docx_attribute(node.element, "themeColor", "")
        if theme != "" { docx_theme_color(theme) } else { None }
      }
    }
    None => None
  }
  let mut seen_body = false
  for child in root.children {
    if (child.name() != "body" && child.name() != "background") || seen_body {
      docx_text_unsupported(child.name())
    }
    if child.name() == "body" {
      seen_body = true
    }
  }
  let walker : DocxTextWalker = {
    styles,
    blocks: [],
    paragraphs: [],
    section_index: 0,
    fields: [],
    bookmarks: Map([]),
    open_bookmarks: [],
    current_link: "",
    has_math: false,
    warnings: [],
  }
  walker.blocks(body, false)
  let warnings : Array[String] = []
  for note in walker.warnings {
    if !warnings.contains(note) {
      warnings.push(note)
    }
  }
  // Formulas in table cells and in header or footer stories are parsed by
  // their own walkers, so the document holds a formula when any of them saw
  // one.
  let mut has_math = walker.has_math
  let (section_part, sections) = docx_sections(data)
  docx_inherit_section_stories(sections)
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
  docx_apply_numbering(
    walker.blocks, numbering, theme_fonts=styles.theme_fonts, warnings~,
  )
  let stories : Map[String, Array[DocxTextParagraph]] = Map([])
  let story_tables : Map[String, Array[DocxTable]] = Map([])
  for section in sections {
    for story in section.headers {
      let story_part = story.1
      if !stories.contains(story_part) {
        let (paragraphs, tables, story_math, story_notes) = docx_story_content(
          package, story_part, styles,
        )
        if story_math {
          has_math = true
        }
        for note in story_notes {
          if !warnings.contains(note) {
            warnings.push(note)
          }
        }
        stories[story_part] = paragraphs
        story_tables[story_part] = tables
      }
    }
    for story in section.footers {
      let story_part = story.1
      if !stories.contains(story_part) {
        let (paragraphs, tables, story_math, story_notes) = docx_story_content(
          package, story_part, styles,
        )
        if story_math {
          has_math = true
        }
        for note in story_notes {
          if !warnings.contains(note) {
            warnings.push(note)
          }
        }
        stories[story_part] = paragraphs
        story_tables[story_part] = tables
      }
    }
  }
  let footnotes = docx_note_map(package, part, "/footnotes", "footnote")
  let endnotes = docx_note_map(package, part, "/endnotes", "endnote")
  let bookmark_text : Map[String, String] = {}
  for name, text in walker.bookmarks {
    bookmark_text[name] = text.to_string()
  }
  {
    part,
    sections,
    blocks: walker.blocks,
    paragraphs: walker.paragraphs,
    stories,
    story_tables,
    bookmark_text,
    footnotes,
    endnotes,
    even_odd: docx_even_odd(package, part),
    language: docx_pick_language(styles, walker.paragraphs),
    background,
    has_math,
    warnings,
  }
}

///|
fn docx_story_content(
  package : @ooxml.OoxmlPackage,
  part : String,
  styles : DocxStyles,
) -> (Array[DocxTextParagraph], Array[DocxTable], Bool, Array[String]) {
  if part == "" || !package.has(part) {
    return ([], [], false, [])
  }
  try {
    let root = docx_text_xml(
      @utf8.decode_lossy(package.read(part)[:], ignore_bom=true),
    )
    let walker : DocxTextWalker = {
      styles,
      blocks: [],
      paragraphs: [],
      section_index: 0,
      fields: [],
      bookmarks: Map([]),
      open_bookmarks: [],
      current_link: "",
      has_math: false,
      warnings: [],
    }
    walker.blocks(root, true)
    let paragraphs : Array[DocxTextParagraph] = []
    let tables : Array[DocxTable] = []
    for block in walker.blocks {
      match block {
        DocxParaBlock(paragraph) => paragraphs.push(paragraph)
        DocxTableBlock(table) => tables.push(table)
      }
    }
    (paragraphs, tables, walker.has_math, walker.warnings)
  } catch {
    _ => ([], [], false, [])
  }
}

///|
fn docx_even_odd(package : @ooxml.OoxmlPackage, part : String) -> Bool {
  match package.relationship_of_type(part, "/settings") {
    Some(rel) =>
      if rel.external || !package.has(rel.target) {
        false
      } else {
        try {
          let root = docx_text_xml(
            @utf8.decode_lossy(package.read(rel.target)[:], ignore_bom=true),
          )
          let mut found = false
          for child in root.children {
            if child.name() == "evenAndOddHeaders" {
              found = docx_bool(child.element, "val", true)
            }
          }
          found
        } catch {
          _ => false
        }
      }
    None => false
  }
}

///|
/// The document language when the core properties name none: the default
/// run language, East Asian when most characters are CJK.
fn docx_pick_language(
  styles : DocxStyles,
  paragraphs : Array[DocxTextParagraph],
) -> String {
  let (latin, east_asian) = docx_style_language(styles)
  let mut cjk = 0
  let mut ascii = 0
  for paragraph in paragraphs {
    for item in paragraph.items {
      for character in item.text {
        let code = character.to_int()
        if (code >= 0x3040 && code <= 0x30ff) ||
          (code >= 0x3400 && code <= 0x4dbf) ||
          (code >= 0x4e00 && code <= 0x9fff) ||
          (code >= 0xac00 && code <= 0xd7af) ||
          (code >= 0xf900 && code <= 0xfaff) ||
          (code >= 0xff66 && code <= 0xff9d) {
          cjk += 1
        } else if (code >= 0x41 && code <= 0x5a) ||
          (code >= 0x61 && code <= 0x7a) {
          ascii += 1
        }
      }
    }
  }
  if east_asian != "" && cjk > ascii {
    east_asian
  } else if latin != "" {
    latin
  } else {
    east_asian
  }
}

///|

