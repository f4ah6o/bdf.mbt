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
