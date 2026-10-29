///|
#export_name("mml_detection")
pub fn mml_detection(value : String) -> String {
  let (ok, tokens, notes) = @mml.mml_like(value)
  Json::array([
    Json::boolean(@mml.detect_mml(@utf8.encode(value))),
    Json::string(@mml.detect_mml_dialect(value)),
    Json::boolean(ok),
    Json::number(tokens.to_double()),
    Json::number(notes.to_double()),
  ]).stringify()
}

///|
#export_name("mml_decode")
pub fn mml_decode(data : Bytes) -> String {
  @mml.decode_mml(data)
}
