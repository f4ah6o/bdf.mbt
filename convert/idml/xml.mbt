///|
priv struct IdmlXmlNode {
  element : @xml.NamespaceElement
  children : Array[IdmlXmlNode]
  text : StringBuilder
}

///|
fn idml_parse_xml(content : String) -> IdmlXmlNode raise IdmlError {
  if content.contains("<!ENTITY") {
    raise IdmlInvalid("IDML part declares entities")
  }
  let reader = @xml.NamespaceReader::from_string(content)
  let stack : Array[IdmlXmlNode] = []
  let mut root : IdmlXmlNode? = None
  let mut count = 0
  while true {
    let event = reader.read_event() catch { _ => raise IdmlInvalid("invalid IDML XML") }
    match event.kind {
      Start(element) | Empty(element) => {
        count += 1
        if count > 8388608 || stack.length() > 20000 {
          raise IdmlInvalid("IDML part exceeds XML limits")
        }
        let node : IdmlXmlNode = {
          element,
          children: [],
          text: StringBuilder(),
        }
        if stack.is_empty() {
          if root is Some(_) {
            raise IdmlInvalid("multiple XML roots")
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
      Eof => break
      _ => ()
    }
  }
  match root {
    Some(node) if stack.is_empty() => node
    _ => raise IdmlInvalid("invalid or empty XML")
  }
}

///|
fn idml_children(node : IdmlXmlNode?) -> Array[IdmlXmlNode] {
  match node {
    Some(value) => value.children
    None => []
  }
}

///|
fn idml_child(node : IdmlXmlNode?, name : String) -> IdmlXmlNode? {
  for child in idml_children(node) {
    if child.element.name.local_name == name {
      return Some(child)
    }
  }
  None
}

///|
fn idml_attr(node : IdmlXmlNode?, name : String, default : String) -> String {
  match node {
    Some(value) =>
      for attr in value.element.attributes {
        if attr.name.local_name == name {
          return attr.value
        }
      }
    None => ()
  }
  default
}

///|
fn idml_has_attr(node : IdmlXmlNode?, name : String) -> Bool {
  match node {
    Some(value) =>
      for attr in value.element.attributes {
        if attr.name.local_name == name {
          return true
        }
      }
    None => ()
  }
  false
}

///|
fn idml_text(node : IdmlXmlNode?) -> String {
  match node {
    Some(value) => {
      let text = value.text.to_string()
      if text != "" {
        text
      } else {
        let out = StringBuilder()
        for child in value.children {
          out.write_string(idml_text(Some(child)))
        }
        out.to_string()
      }
    }
    None => ""
  }
}

///|
fn idml_read_xml(
  package : @ooxml.OoxmlPackage,
  part : String,
) -> IdmlXmlNode raise IdmlError {
  let data = package.read(part) catch {
    @ooxml.InvalidOoxml(message) => raise IdmlInvalid(message)
  }
  idml_parse_xml(@utf8.decode_lossy(data[:], ignore_bom=true))
}

///|
fn idml_numbers(text : String) -> Array[Double] {
  let out : Array[Double] = []
  for part in text.split(" ") {
    if part == "" {
      continue
    }
    let value = @string.parse_double(part.to_owned()) catch { _ => continue }
    out.push(value)
  }
  out
}
