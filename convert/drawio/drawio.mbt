///|
/// A draw.io conversion failure.
pub suberror DrawioError {
  DrawioInvalid(String)
}

///|
pub(all) struct DrawioResult {
  bdf : Bytes
  pages : Int32
  summary : String
  warnings : Array[String]
}

///|
/// Detect a draw.io XML document.
pub fn detect(data : Bytes) -> Bool {
  if data.has_prefix(b"\x89PNG\r\n\x1a\n") {
    let text = @utf8.decode_lossy(data[:Int::min(data.length(), 262144)].to_owned())
    return text.contains("mxGraphModel") || text.contains("mxfile")
  }
  let head = @utf8.decode_lossy(data[:Int::min(data.length(), 65536)].to_owned())
  head.contains("<mxfile") || head.contains("<mxGraphModel") ||
    ((head.contains("<svg") || head.contains("<?xml")) &&
      (head.contains("&lt;mxfile") || head.contains("&lt;mxGraphModel")))
}

///|
priv struct DrawioNode {
  name : String
  attrs : Map[String, String]
  children : Array[DrawioNode]
  text : StringBuilder
}

///|
fn drawio_attr(node : DrawioNode, name : String, default : String) -> String {
  match node.attrs.get(name) {
    Some(value) => value
    None => default
  }
}

///|
fn drawio_num(node : DrawioNode, name : String, default : Double) -> Double {
  let text = drawio_attr(node, name, "")
  if text == "" {
    return default
  }
  @string.parse_double(text) catch { _ => default }
}

///|
fn drawio_parse(content : String) -> DrawioNode raise {
  let reader = @xml.NamespaceReader::from_string(content)
  let stack : Array[DrawioNode] = []
  let mut root : DrawioNode? = None
  while true {
    let event = reader.read_event()
    match event.kind {
      Start(element) | Empty(element) => {
        let attrs : Map[String, String] = Map([])
        for attr in element.attributes {
          attrs[attr.name.local_name] = attr.value
        }
        let node : DrawioNode = {
          name: element.name.local_name,
          attrs,
          children: [],
          text: StringBuilder(),
        }
        if stack.is_empty() {
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
      End(_) =>
        if !stack.is_empty() {
          stack.pop() |> ignore
        }
      Eof => break
      _ => ()
    }
  }
  match root {
    Some(value) => value
    None => raise Failure("drawio: empty XML")
  }
}

///|
fn drawio_find(node : DrawioNode, name : String) -> DrawioNode? {
  for child in node.children {
    if child.name == name {
      return Some(child)
    }
  }
  None
}

///|
fn drawio_all(node : DrawioNode, name : String, output : Array[DrawioNode]) -> Unit {
  for child in node.children {
    if child.name == name {
      output.push(child)
    }
    drawio_all(child, name, output)
  }
}

///|
fn drawio_style(style : String, key : String, default : String) -> String {
  for part in style.split(";") {
    let item = sfc_drawio_trim(part)
    let eq = item.find("=")
    match eq {
      Some(value) =>
        if item[:value] == key {
          return item[value + 1:].to_owned()
        }
      None =>
        if item == key {
          return "1"
        }
    }
  }
  default
}

///|
fn sfc_drawio_trim(value : StringView) -> String {
  let mut start = 0
  let mut end = value.length()
  while start < end && (value[start] == ' ' || value[start] == '\t' || value[start] == '\r' || value[start] == '\n') {
    start += 1
  }
  while end > start && (value[end - 1] == ' ' || value[end - 1] == '\t' || value[end - 1] == '\r' || value[end - 1] == '\n') {
    end -= 1
  }
  value[start:end].to_owned()
}

///|
fn drawio_color(value : String, default : UInt32) -> UInt32 {
  if value == "" || value == "none" {
    return default
  }
  let mut text = value
  if text.has_prefix("#") {
    text = text[1:].to_owned()
  }
  if text.length() != 6 {
    return default
  }
  let mut number = 0
  for character in text {
    let digit = if character >= '0' && character <= '9' {
      character.to_int() - 48
    } else if character >= 'a' && character <= 'f' {
      character.to_int() - 87
    } else if character >= 'A' && character <= 'F' {
      character.to_int() - 55
    } else {
      return default
    }
    number = (number << 4) | digit
  }
  ((number << 8) | 255).to_uint()
}

///|
fn drawio_plain(value : String) -> String {
  let output = StringBuilder()
  let mut index = 0
  while index < value.length() {
    let c = value[index].unsafe_to_char()
    if c == '<' {
      let close = value[index:].find(">")
      match close {
        Some(offset) => {
          let tag = value[index + 1:index + offset].to_lower()
          if tag.has_prefix("br") || tag == "/p" || tag == "/li" {
            output.write_char('\n')
          }
          index += offset + 1
        }
        None => index = value.length()
      }
    } else {
      output.write_char(c)
      index += 1
    }
  }
  output.to_string()
}

///|
/// Convert a draw.io document into fixed-view BDF views, one per diagram.
pub fn convert(
  data : Bytes,
  title~ : String = "",
  db~ : @fontdb.Database? = None,
) -> DrawioResult raise DrawioError {
  if data.length() > 268435456 {
    raise DrawioInvalid("drawio: the file is larger than 268435456 bytes")
  }
  let diagrams = drawio_read_file(data) catch {
    Failure(message) => raise DrawioInvalid(message)
    _ => raise DrawioInvalid("drawio: invalid draw.io file")
  }
  if diagrams.is_empty() {
    raise DrawioInvalid("drawio: the file has no diagrams")
  }
  let fonts = @canvas.Fonts::new(db)
  let warnings : Array[String] = []
  let warn = DrawioWarn::new()
  let meta = @cad.document_meta("drawio", title=title)
  let writer = @core.DocumentWriter::new(meta=Json::object(meta))
  let mut views = 0
  let used_ids : Map[String, Bool] = Map([])
  for page_info in diagrams {
    let rendered = drawio_render_page(writer, page_info, fonts, warnings, warn)
    match rendered {
      Some((view, view_id, _page_title, labels)) => {
        let mut id = if view_id == "" { "page" + (views + 1).to_string() } else { view_id }
        while used_ids.contains(id) {
          id = id + "_"
        }
        used_ids[id] = true
        let view_map = match view {
          Json::Object(value) => value
          _ => Map([])
        }
        view_map["id"] = Json::string(id)
        if !labels.is_empty() {
          let runs : Array[@core.IndexRun] = []
          for label in labels {
            runs.push({
              a: 0,
              b: 0,
              ordinal: runs.length(),
              separator: 2,
              text: label,
            })
          }
          let index_hash = writer.add_part("idx", @core.encode_text_index(runs)) catch {
            error => raise DrawioInvalid("drawio: " + error.to_string())
          }
          view_map["textIndex"] = Json::string(index_hash)
        }
        writer.add_view(Json::object(view_map))
        views += 1
      }
      None => ()
    }
  }
  if views == 0 {
    raise DrawioInvalid("drawio: no pages could be drawn")
  }
  for warning in fonts.warnings() {
    warnings.push(warning)
  }
  for warning in warn.items {
    warnings.push(warning)
  }
  let bdf = writer.write_single() catch {
    error => raise DrawioInvalid("drawio: " + error.to_string())
  }
  {
    bdf,
    pages: views,
    summary: "\{views} page(s)",
    warnings,
  }
}
