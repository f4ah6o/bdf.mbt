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
