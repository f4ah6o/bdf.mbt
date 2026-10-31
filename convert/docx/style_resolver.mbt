///|
// A style retains its property nodes so unsupported formatting is checked only
// when that style is actually used. Style selection here does not render text.
priv struct DocxStyle {
  id : String
  kind : String
  based_on : String
  ppr : DocxXmlNode?
  rpr : DocxXmlNode?
}

///|
priv struct DocxStyles {
  by_id : Map[String, DocxStyle]
  mut default_paragraph : String
  mut default_character : String
  mut default_table : String
  doc_ppr : DocxXmlNode?
  doc_rpr : DocxXmlNode?
}

///|
fn docx_style_value(node : DocxXmlNode?) -> String {
  match node {
    Some(value) => docx_attribute(value.element, "val", "")
    None => ""
  }
}

///|
fn docx_style_child(node : DocxXmlNode?, name : String) -> DocxXmlNode? {
  match node {
    Some(value) => value.child(name)
    None => None
  }
}

///|
fn docx_styles_from_xml(xml : String) -> DocxStyles raise {
  let root = docx_text_xml(xml)
  if root.name() != "styles" {
    raise InvalidDocx("expected DOCX styles")
  }
  let defaults = root.child("docDefaults")
  let doc_ppr = docx_style_child(
    docx_style_child(defaults, "pPrDefault"),
    "pPr",
  )
  let doc_rpr = docx_style_child(
    docx_style_child(defaults, "rPrDefault"),
    "rPr",
  )
  let styles : DocxStyles = {
    by_id: {},
    default_paragraph: "",
    default_character: "",
    default_table: "",
    doc_ppr,
    doc_rpr,
  }
  for node in root.children {
    if node.name() != "style" {
      continue
    }
    let id = docx_attribute(node.element, "styleId", "")
    let kind = docx_attribute(node.element, "type", "paragraph")
    let style : DocxStyle = {
      id,
      kind,
      based_on: docx_style_value(node.child("basedOn")),
      ppr: node.child("pPr"),
      rpr: node.child("rPr"),
    }
    if !styles.by_id.contains(id) {
      styles.by_id[id] = style
    }
    if docx_bool(node.element, "default", false) {
      match kind {
        "paragraph" => styles.default_paragraph = id
        "character" => styles.default_character = id
        "table" => styles.default_table = id
        _ => ()
      }
    }
  }
  styles
}

///|
fn DocxStyles::chain(self : DocxStyles, id : String) -> Array[DocxStyle] {
  let found : Array[DocxStyle] = []
  let seen : Map[String, Bool] = {}
  let mut current = id
  while current != "" && !seen.contains(current) && found.length() < 32 {
    seen[current] = true
    match self.by_id.get(current) {
      Some(style) => {
        found.push(style)
        current = style.based_on
      }
      None => break
    }
  }
  let result : Array[DocxStyle] = []
  let mut i = found.length()
  while i > 0 {
    i -= 1
    result.push(found[i])
  }
  result
}

///|
fn DocxStyles::paragraph_style(self : DocxStyles, id : String) -> String {
  match self.by_id.get(id) {
    Some(style) if style.kind == "paragraph" => id
    _ => self.default_paragraph
  }
}

///|
// pStyle and rStyle select a style but are not applied by Go's applyPPr or
// applyRPr. The remaining properties are still validated by those parsers.
fn docx_style_without_selector(
  node : DocxXmlNode,
  selector : String,
) -> DocxXmlNode raise {
  let children : Array[DocxXmlNode] = []
  for child in node.children {
    if child.name() != selector {
      children.push(child)
    } else if !child.children.is_empty() {
      docx_text_unsupported(selector)
    }
  }
  { element: node.element, children, text: node.text, }
}

///|
fn docx_style_apply_ppr(
  props : DocxParagraphProps,
  node : DocxXmlNode?,
) -> Unit raise {
  match node {
    Some(value) => {
      let properties = docx_style_without_selector(value, "pStyle")
      ignore(docx_text_ppr(props, properties))
    }
    None => ()
  }
}

///|
fn docx_style_apply_rpr(
  props : DocxRunProps,
  node : DocxXmlNode?,
) -> Unit raise {
  match node {
    Some(value) =>
      props.apply_node(docx_style_without_selector(value, "rStyle"))
    None => ()
  }
}

///|
fn DocxStyles::resolve_paragraph(
  self : DocxStyles,
  direct : DocxXmlNode?,
) -> (String, DocxParagraphProps) raise {
  let id = self.paragraph_style(
    docx_style_value(docx_style_child(direct, "pStyle")),
  )
  let props = docx_default_paragraph_props()
  docx_style_apply_ppr(props, self.doc_ppr)
  for style in self.chain(self.paragraph_style(id)) {
    docx_style_apply_ppr(props, style.ppr)
  }
  docx_style_apply_ppr(props, direct)
  (id, props)
}

///|
fn DocxRunProps::copy(self : DocxRunProps) -> DocxRunProps {
  {
    fonts: self.fonts.copy(),
    themes: self.themes.copy(),
    hint: self.hint,
    toggles: self.toggles,
    specified: self.specified,
    size: self.size,
    color: self.color,
    auto_color: self.auto_color,
    shading: self.shading,
    has_shading: self.has_shading,
    underline_color: self.underline_color,
    has_underline_color: self.has_underline_color,
    highlight: self.highlight,
    underline: self.underline,
    vertical_align: self.vertical_align,
    position: self.position,
    spacing: self.spacing,
    scale: self.scale,
    emphasis: self.emphasis,
    languages: self.languages.copy(),
    web_hidden: self.web_hidden,
    rtl: self.rtl,
    tcy: self.tcy,
    tcy_fit: self.tcy_fit,
  }
}

///|
fn DocxStyles::resolve_run(
  self : DocxStyles,
  paragraph_style : String,
  direct : DocxXmlNode?,
) -> DocxRunProps raise {
  let paragraph = docx_default_run_props()
  docx_style_apply_rpr(paragraph, self.doc_rpr)
  for style in self.chain(self.paragraph_style(paragraph_style)) {
    docx_style_apply_rpr(paragraph, style.rpr)
  }
  let requested = docx_style_value(docx_style_child(direct, "rStyle"))
  let character_id = if requested == "" {
    self.default_character
  } else {
    requested
  }
  let character = self.chain(character_id)
  let props = if !character.is_empty() &&
    character[character.length() - 1].kind == "character" {
    let child = paragraph.copy()
    child.specified = 0
    for style in character {
      docx_style_apply_rpr(child, style.rpr)
    }
    child.toggles = paragraph.toggles ^ (child.toggles & child.specified)
    child
  } else {
    paragraph
  }
  docx_style_apply_rpr(props, direct)
  props.specified = 0
  props
}
