///|
let xmp_rdf = "http://www.w3.org/1999/02/22-rdf-syntax-ns#"

///|
let xmp_xml = "http://www.w3.org/XML/1998/namespace"

///|
let xmp_dc = "http://purl.org/dc/elements/1.1/"

///|
fn XmpNode::is_name(self : XmpNode, space : String, name : String) -> Bool {
  self.space == space && self.name == name
}

///|
fn xmp_collapse(value : String) -> String {
  let out = StringBuilder()
  let mut seen = false
  let mut spacing = false
  for ch in value {
    if ch.is_whitespace() {
      if seen {
        spacing = true
      }
    } else {
      if spacing {
        out.write_char(' ')
      }
      out.write_char(ch)
      seen = true
      spacing = false
    }
  }
  out.to_string()
}

///|
// The values of an RDF property can be a resource, an alternative, a list,
// a nested resource title, or text.
fn xmp_values(node : XmpNode) -> Array[String] {
  let resource = node.attribute(xmp_rdf, "resource")
  if resource != "" {
    return [resource]
  }
  let value = node.attribute(xmp_rdf, "value")
  if value != "" {
    return [value]
  }
  for child in node.children {
    if child.is_name(xmp_rdf, "Alt") ||
      child.is_name(xmp_rdf, "Seq") ||
      child.is_name(xmp_rdf, "Bag") {
      let defaults : Array[Array[String]] = []
      let others : Array[String] = []
      for item in child.children {
        if !item.is_name(xmp_rdf, "li") {
          continue
        }
        let values = xmp_values(item)
        if child.is_name(xmp_rdf, "Alt") &&
          item.attribute(xmp_xml, "lang") == "x-default" {
          defaults.push(values)
        } else {
          for item_value in values {
            others.push(item_value)
          }
        }
      }
      let out : Array[String] = []
      for i = defaults.length() - 1; i >= 0; i = i - 1 {
        for item_value in defaults[i] {
          out.push(item_value)
        }
      }
      for item_value in others {
        out.push(item_value)
      }
      return out
    }
    if child.is_name(xmp_rdf, "value") {
      return [xmp_collapse(child.text.to_string())]
    }
    for nested in child.children {
      if nested.is_name(xmp_dc, "title") || nested.is_name(xmp_rdf, "value") {
        return xmp_values(nested)
      }
    }
  }
  let text = xmp_collapse(node.text.to_string())
  if text == "" {
    []
  } else {
    [text]
  }
}
