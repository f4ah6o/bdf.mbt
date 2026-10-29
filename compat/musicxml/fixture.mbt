///|
#export_name("musicxml_detect_text")
pub fn musicxml_detect_text(data : Bytes) -> String {
  let (little, utf16) = @musicxml.musicxml_utf16_order(data)
  Json::array([
    Json::boolean(little),
    Json::boolean(utf16),
    Json::string(@musicxml.musicxml_head_text(data)),
    Json::boolean(@musicxml.detect_musicxml_text(data)),
  ]).stringify()
}

///|
#export_name("musicxml_text")
pub fn musicxml_text(data : Bytes) -> String {
  let (bytes, warning) = @musicxml.musicxml_to_utf8(data)
  Json::array([
    Json::string(@musicxml.musicxml_declared_encoding(data)),
    Json::array([ for b in bytes => Json::number(b.to_int().to_double()) ]),
    Json::string(warning),
  ]).stringify()
}

///|
#export_name("musicxml_mxl")
pub fn musicxml_mxl(data : Bytes) -> String {
  let head = data[:Int32::min(data.length(), 1024)].to_owned()
  let detect = @musicxml.detect_musicxml(head, data)
  let (bytes, error) = (Some(@musicxml.read_musicxml_input(data)), "") catch {
    @musicxml.InvalidMusicXmlInput(message) => (None, message)
  }
  Json::array([
    Json::boolean(detect),
    match bytes {
      None => Json::null()
      Some(b) =>
        Json::array([ for v in b => Json::number(v.to_int().to_double()) ])
    },
    Json::string(error),
  ]).stringify()
}

///|
#export_name("musicxml_values")
pub fn musicxml_values(text : String) -> String {
  let (n, nok) = @musicxml.musicxml_integer(text)
  let (f, fok) = @musicxml.musicxml_float(text)
  let (endings, more) = @musicxml.musicxml_ending_numbers(text)
  Json::array([
    Json::number(n.to_double()),
    Json::boolean(nok),
    Json::number(f),
    Json::boolean(fok),
    Json::array(endings.map(n => Json::number(n.to_double()))),
    Json::boolean(more),
  ]).stringify()
}

///|
#export_name("musicxml_numbers")
pub fn musicxml_numbers(max : Int32, names_json : String) -> String {
  let names = @json.parse(names_json) catch { _ => return "[]" }
  let numbered = @musicxml.MusicXmlNumbers::new(max)
  let out : Array[Json] = []
  match names {
    Array(items) =>
      for item in items {
        match item {
          String(name) => out.push(Json::number(numbered.get(name).to_double()))
          _ => ()
        }
      }
    _ => ()
  }
  Json::array(out).stringify()
}

///|
fn musicxml_tree_json(node : @musicxml.MusicXmlNode) -> Json {
  Json::array([
    Json::string(node.name),
    Json::array(
      node.attributes.map(a => {
        Json::array([Json::string(a.name), Json::string(a.value)])
      }),
    ),
    Json::string(node.text),
    Json::array(node.children.map(musicxml_tree_json)),
  ])
}

///|
#export_name("musicxml_tree")
pub fn musicxml_tree(data : Bytes) -> String {
  musicxml_tree_json(@musicxml.musicxml_read_tree(data)).stringify() catch {
    _ => "null"
  }
}
