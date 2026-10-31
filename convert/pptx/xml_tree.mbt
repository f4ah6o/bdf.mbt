///|
// Minimal element tree for the PowerPoint parts needed by slide rendering.
priv struct PptxXmlNode {
  element : @xml.NamespaceElement
  children : Array[PptxXmlNode]
}

///|
fn pptx_parse_xml(content : String) -> PptxXmlNode raise {
  if content.contains("<!ENTITY") {
    raise InvalidPptx("OOXML part declares entities")
  }
  let reader = @xml.NamespaceReader::from_string(content)
  let stack : Array[PptxXmlNode] = []
  let mut root : PptxXmlNode? = None
  let mut count = 0
  while true {
    let event = reader.read_event()
    match event.kind {
      Start(element) | Empty(element) => {
        count += 1
        if count > 8388608 || stack.length() > 20000 {
          raise InvalidPptx("OOXML part exceeds XML limits")
        }
        let node : PptxXmlNode = { element, children: [], }
        if stack.is_empty() {
          if root is Some(_) {
            raise InvalidPptx("multiple XML roots")
          }
          root = Some(node)
        } else {
          stack[stack.length() - 1].children.push(node)
        }
        if event.kind is Start(_) {
          stack.push(node)
        }
      }
      End(_) => ignore(stack.pop())
      Eof => break
      _ => ()
    }
  }
  match root {
    Some(node) if stack.is_empty() => node
    _ => raise InvalidPptx("invalid or empty XML")
  }
}

///|
fn pptx_resolve_children(
  node : PptxXmlNode,
  output : Array[PptxXmlNode],
) -> Unit {
  let pending : Array[PptxXmlNode] = []
  let mut i = node.children.length()
  while i > 0 {
    i -= 1
    pending.push(node.children[i])
  }
  while !pending.is_empty() {
    let child = pending.pop().unwrap()
    if child.element.name.local_name == "AlternateContent" &&
      child.element.name.namespace_uri
      .unwrap_or("")
      .has_suffix("markup-compatibility/2006") {
      let mut fallback : PptxXmlNode? = None
      let mut choice : PptxXmlNode? = None
      for branch in child.children {
        if branch.element.name.local_name == "Fallback" && fallback is None {
          fallback = Some(branch)
        }
        if branch.element.name.local_name == "Choice" && choice is None {
          choice = Some(branch)
        }
      }
      let selected = match fallback {
        Some(value) => Some(value)
        None => choice
      }
      match selected {
        Some(value) => {
          let mut j = value.children.length()
          while j > 0 {
            j -= 1
            pending.push(value.children[j])
          }
        }
        None => ()
      }
    } else {
      output.push(child)
    }
  }
}

///|
fn pptx_children(node : PptxXmlNode?) -> Array[PptxXmlNode] {
  let output : Array[PptxXmlNode] = []
  match node {
    Some(value) => pptx_resolve_children(value, output)
    None => ()
  }
  output
}

///|
fn pptx_child(node : PptxXmlNode?, name : String) -> PptxXmlNode? {
  for child in pptx_children(node) {
    if child.element.name.local_name == name {
      return Some(child)
    }
  }
  None
}

///|
fn pptx_read_xml(
  package : @ooxml.OoxmlPackage,
  part : String,
) -> PptxXmlNode raise {
  let data = package.read(part)
  pptx_parse_xml(@utf8.decode_lossy(data[:], ignore_bom=true))
}
