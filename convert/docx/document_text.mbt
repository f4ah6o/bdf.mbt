///|
// This is an internal, deliberately limited model. A rejected element is not
// silently converted into plain text: later stages must add its semantics.
priv struct DocxTextItem {
  kind : String
  text : String
  clear : Bool
} derive(Debug, Eq)

///|
priv struct DocxTextParagraph {
  props : DocxParagraphProps
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
      | "textDirection" =>
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
      | "ind" => {
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
  clear~ : Bool = false,
) -> Unit {
  items.push({ kind, text, clear, })
}

///|
fn docx_text_chars(items : Array[DocxTextItem], text : String) -> Unit {
  for c in text {
    match c {
      '\r' | '\n' => docx_text_push(items, "break", "\n")
      '\t' => docx_text_push(items, "tab", "\t")
      '\u00ad' => ()
      _ => {
        let s = StringBuilder()
        s.write_char(c)
        docx_text_push(items, "char", s.to_string())
      }
    }
  }
}

///|
fn docx_text_run(node : DocxXmlNode, items : Array[DocxTextItem]) -> Unit raise {
  for child in node.children {
    let name = child.name()
    if name != "rPr" && name != "t" && !child.children.is_empty() {
      docx_text_unsupported(name)
    }
    match name {
      "rPr" => if !child.children.is_empty() { docx_text_unsupported(name) }
      "t" => {
        if !child.children.is_empty() {
          docx_text_unsupported(name)
        }
        docx_text_chars(items, child.text.to_string())
      }
      "tab" | "ptab" => docx_text_push(items, "tab", "\t")
      "br" => {
        let typ = docx_attribute(child.element, "type", "textWrapping")
        match typ {
          "page" => docx_text_push(items, "page", "")
          "column" => docx_text_push(items, "column", "")
          _ =>
            docx_text_push(
              items,
              "break",
              "\n",
              clear=docx_attribute(child.element, "clear", "none") != "none",
            )
        }
      }
      "cr" => docx_text_push(items, "break", "\n")
      "noBreakHyphen" => docx_text_chars(items, "\u2011")
      "softHyphen" | "lastRenderedPageBreak" => ()
      other => docx_text_unsupported(other)
    }
  }
}

///|
fn docx_text_inlines(
  node : DocxXmlNode,
  items : Array[DocxTextItem],
) -> Unit raise {
  for child in node.children {
    match child.name() {
      "pPr" => ()
      "r" => docx_text_run(child, items)
      "smartTag" | "customXml" | "ins" | "moveTo" =>
        docx_text_inlines(child, items)
      "sdt" => {
        let mut seen_content = false
        for sub in child.children {
          if sub.name() == "sdtContent" && !seen_content {
            seen_content = true
            docx_text_inlines(sub, items)
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
        let props = docx_default_paragraph_props()
        let items : Array[DocxTextItem] = []
        let mut ends_section = false
        let mut seen_ppr = false
        for node in child.children {
          if node.name() == "pPr" {
            if seen_ppr {
              docx_text_unsupported("duplicate pPr")
            }
            seen_ppr = true
          }
        }
        match child.child("pPr") {
          Some(ppr) => ends_section = docx_text_ppr(props, ppr)
          None => ()
        }
        if ends_section && wrapped {
          docx_text_unsupported("wrapped paragraph section")
        }
        docx_text_inlines(child, items)
        self.paragraphs.push({
          props,
          items,
          section_index: self.section_index,
        })
        if ends_section {
          self.section_index += 1
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
fn docx_document_text(data : Bytes) -> DocxTextDocument raise {
  let package = @ooxml.open_ooxml(data)
  let part = match package.relationship_of_type("", "/officeDocument") {
    Some(rel) => rel.target
    None => "word/document.xml"
  }
  for typ in ["/styles", "/numbering", "/settings", "/footnotes", "/endnotes"] {
    if package.relationship_of_type(part, typ) is Some(_) {
      docx_text_unsupported(typ)
    }
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
  let walker : DocxTextWalker = { paragraphs: [], section_index: 0, }
  walker.blocks(body, false)
  let (section_part, sections) = docx_sections(data)
  if part != section_part || walker.section_index >= sections.length() {
    raise InvalidDocx("inconsistent DOCX sections")
  }
  { part, sections, paragraphs: walker.paragraphs, }
}
