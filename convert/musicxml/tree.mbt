///|
/// A MusicXML element attribute, with its namespace prefix removed.
pub(all) struct MusicXmlAttribute {
  name : String
  value : String
}

///|
/// A MusicXML element and its direct text and descendants.
pub(all) struct MusicXmlNode {
  name : String
  attributes : Array[MusicXmlAttribute]
  children : Array[MusicXmlNode]
  mut text : String
}

///|
/// Look up the first matching attribute, trimming its value.
pub fn MusicXmlNode::attr(self : MusicXmlNode, name : String) -> String? {
  for attr in self.attributes {
    if attr.name == name {
      return Some(musicxml_trim(attr.value))
    }
  }
  None
}

///|
/// Find the first child of an element with the given local name.
pub fn MusicXmlNode::child(self : MusicXmlNode, name : String) -> MusicXmlNode? {
  for child in self.children {
    if child.name == name {
      return Some(child)
    }
  }
  None
}

///|
fn musicxml_local(name : String) -> String {
  let mut local = ""
  for part in name.split(":") {
    local = part.to_owned()
  }
  local
}

///|
fn musicxml_node(element : @xml.XmlElement) -> MusicXmlNode {
  let attrs : Array[MusicXmlAttribute] = [
    for attr in element.attributes => {
      { name: musicxml_local(attr.name), value: attr.value, }
    }
  ]
  {
    name: musicxml_local(element.name),
    attributes: attrs,
    children: [],
    text: "",
  }
}

///|
fn musicxml_node_text(
  text : StringBuilder,
  children : Array[MusicXmlNode],
) -> String {
  let value = text.to_string()
  if !children.is_empty() && musicxml_trim(value) == "" {
    ""
  } else {
    value
  }
}

///|
/// Read a MusicXML element tree, with at most one million elements.
pub fn musicxml_read_tree(
  data : Bytes,
) -> MusicXmlNode raise MusicXmlInputError {
  let bytes = read_musicxml_input(data)
  let (prepared, _) = musicxml_to_utf8(bytes)
  let label = musicxml_declared_encoding(prepared)
  let latin = [
    "iso-8859-1", "iso8859-1", "latin1", "latin-1", "l1", "iso_8859-1",
  ].contains(label)
  let text = if latin {
    let out = StringBuilder()
    for b in prepared {
      out.write_char(b.to_int().unsafe_to_char())
    }
    out.to_string()
  } else if label != "" &&
    ![
      "utf-8", "utf8", "utf-16", "utf16", "utf-16le", "utf-16be", "ucs-2", "iso-10646-ucs-2",
      "unicode", "us-ascii", "ascii",
    ].contains(label) {
    @csv.decode_charset(prepared, label) catch {
      _ => @utf8.decode_lossy(prepared[:])
    }
  } else {
    @utf8.decode_lossy(prepared[:])
  }
  let reader = @xml.Reader::from_string(musicxml_repair_entities(text))
  let nodes : Array[MusicXmlNode] = []
  let texts : Array[StringBuilder] = []
  let text_sizes : Array[Int32] = []
  let mut count = 0
  while true {
    let event = reader.read_event() catch {
      _ => raise InvalidMusicXmlInput("musicxml: invalid XML")
    }
    match event.kind {
      Start(element) | Empty(element) => {
        count += 1
        if count > 1048576 {
          raise InvalidMusicXmlInput(
            "musicxml: an element holds too many elements",
          )
        }
        let node = musicxml_node(element)
        if !nodes.is_empty() {
          nodes[nodes.length() - 1].children.push(node)
        }
        if event.kind is Empty(_) {
          if nodes.is_empty() {
            return node
          }
        } else {
          nodes.push(node)
          texts.push(StringBuilder())
          text_sizes.push(0)
        }
      }
      Text(value) | CData(value) =>
        if !texts.is_empty() && text_sizes[text_sizes.length() - 1] < 65536 {
          texts[texts.length() - 1].write_string(value)
          text_sizes[text_sizes.length() - 1] += @utf8.encode(value).length()
        }
      End(_) => {
        if nodes.is_empty() {
          raise InvalidMusicXmlInput("musicxml: invalid XML")
        }
        let node = nodes.pop().unwrap()
        let content = texts.pop().unwrap()
        ignore(text_sizes.pop())
        node.text = musicxml_node_text(content, node.children)
        if nodes.is_empty() {
          return node
        }
      }
      Eof => raise InvalidMusicXmlInput("musicxml: no score in the file")
      _ => ()
    }
  }
  raise InvalidMusicXmlInput("musicxml: no score in the file")
}
