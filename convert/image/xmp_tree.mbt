///|
struct XmpAttribute {
  space : String
  name : String
  value : String
}

///|
struct XmpNode {
  space : String
  name : String
  attributes : Array[XmpAttribute]
  children : Array[XmpNode]
  text : StringBuilder
}

///|
fn xmp_node(element : @xml.NamespaceElement) -> XmpNode {
  let attrs : Array[XmpAttribute] = []
  for attribute in element.attributes {
    attrs.push({
      space: attribute.name.namespace_uri.unwrap_or(""),
      name: attribute.name.local_name,
      value: attribute.value,
    })
  }
  {
    space: element.name.namespace_uri.unwrap_or(""),
    name: element.name.local_name,
    attributes: attrs,
    children: [],
    text: StringBuilder(),
  }
}

///|
// Read what is available before a syntax error, as the upstream XMP reader
// does. Children beyond 512 levels are skipped while their siblings survive.
fn xmp_tree_checked(
  input : String,
  utf16~ : Bool = false,
  entire~ : Bool = false,
) -> (XmpNode?, Bool) {
  let reader = @xml.NamespaceReader::from_string(input)
  let stack : Array[XmpNode] = []
  let mut root : XmpNode? = None
  let mut skipped = 0
  let mut closed = false
  while true {
    let event = reader.read_event() catch { _ => return (root, false) }
    match event.kind {
      Start(element) => {
        if closed {
          return (root, false)
        }
        if skipped > 0 {
          skipped += 1
          continue
        }
        let node = xmp_node(element)
        if stack.length() > 0 {
          stack[stack.length() - 1].children.push(node)
        } else {
          root = Some(node)
        }
        if stack.length() == 512 {
          skipped = 1
        } else {
          stack.push(node)
        }
      }
      Empty(element) => {
        if closed {
          return (root, false)
        }
        if skipped > 0 {
          continue
        }
        let node = xmp_node(element)
        if stack.length() > 0 && stack.length() <= 512 {
          stack[stack.length() - 1].children.push(node)
        } else if stack.length() == 0 {
          root = Some(node)
          if !entire {
            return (root, true)
          }
          closed = true
        }
      }
      End(_) => {
        if skipped > 0 {
          skipped -= 1
          continue
        }
        ignore(stack.pop())
        if stack.length() == 0 {
          if !entire {
            return (root, true)
          }
          closed = true
        }
      }
      Text(value) | CData(value) =>
        if skipped == 0 && stack.length() > 0 {
          stack[stack.length() - 1].text.write_string(value)
        } else if closed && xmp_trim_space(value) != "" {
          return (root, false)
        }
      Decl(encoding~, ..) =>
        match encoding {
          Some(label) => {
            let name = label.to_lower()
            if name != "utf-8" &&
              !(utf16 &&
              (name == "utf-16" || name == "utf-16le" || name == "utf-16be")) {
              return (root, false)
            }
          }
          None => ()
        }
      Eof => break
      _ => ()
    }
  }
  (root, if entire { closed } else { true })
}

///|
fn xmp_tree(input : String) -> XmpNode? {
  xmp_tree_checked(input).0
}

///|
fn XmpNode::attribute(self : XmpNode, space : String, name : String) -> String {
  for attribute in self.attributes {
    if attribute.space == space && attribute.name == name {
      return attribute.value
    }
  }
  ""
}
