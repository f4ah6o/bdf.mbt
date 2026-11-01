///|
priv struct VisioXmlNode {
  element : @xml.NamespaceElement
  children : Array[VisioXmlNode]
  text : StringBuilder
}

///|
fn visio_parse_xml(content : String) -> VisioXmlNode raise VisioError {
  if content.contains("<!ENTITY") {
    raise VisioInvalid("Visio part declares entities")
  }
  let reader = @xml.NamespaceReader::from_string(content)
  let stack : Array[VisioXmlNode] = []
  let mut root : VisioXmlNode? = None
  let mut count = 0
  while true {
    let event = reader.read_event() catch {
      _ => raise VisioInvalid("invalid Visio XML")
    }
    match event.kind {
      Start(element) | Empty(element) => {
        count += 1
        if count > 8388608 || stack.length() > 20000 {
          raise VisioInvalid("Visio part exceeds XML limits")
        }
        let node : VisioXmlNode = {
          element,
          children: [],
          text: StringBuilder(),
        }
        if stack.is_empty() {
          if root is Some(_) {
            raise VisioInvalid("multiple XML roots")
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
    _ => raise VisioInvalid("invalid or empty Visio XML")
  }
}

///|
fn visio_children(node : VisioXmlNode?) -> Array[VisioXmlNode] {
  match node {
    Some(value) => value.children
    None => []
  }
}

///|
fn visio_child(node : VisioXmlNode?, name : String) -> VisioXmlNode? {
  for child in visio_children(node) {
    if child.element.name.local_name == name {
      return Some(child)
    }
  }
  None
}

///|
fn visio_attr(node : VisioXmlNode?, name : String, default : String) -> String {
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
fn visio_text(node : VisioXmlNode?) -> String {
  match node {
    Some(value) => {
      let out = StringBuilder()
      out.write_string(value.text.to_string())
      for child in value.children {
        out.write_string(visio_text(Some(child)))
      }
      out.to_string()
    }
    None => ""
  }
}

///|
fn visio_read_xml(
  package : @ooxml.OoxmlPackage,
  part : String,
) -> VisioXmlNode raise VisioError {
  let data = package.read(part) catch {
    @ooxml.InvalidOoxml(message) => raise VisioInvalid(message)
  }
  visio_parse_xml(@utf8.decode_lossy(data[:], ignore_bom=true))
}

///|
fn visio_cells(shape : VisioXmlNode?) -> Map[String, String] {
  let cells : Map[String, String] = Map([])
  for child in visio_children(shape) {
    if child.element.name.local_name == "Cell" {
      let name = visio_attr(Some(child), "N", "")
      if name != "" {
        cells[name] = visio_attr(Some(child), "V", visio_attr(Some(child), "F", ""))
      }
    }
  }
  cells
}

///|
fn visio_cell(cells : Map[String, String], name : String, default : String) -> String {
  match cells.get(name) {
    Some(value) => value
    None => default
  }
}

///|
fn visio_number(cells : Map[String, String], name : String, default : Double) -> Double {
  @string.parse_double(visio_cell(cells, name, "")) catch { _ => default }
}
