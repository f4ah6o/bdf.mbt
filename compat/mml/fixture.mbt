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

///|
#export_name("mml_source")
pub fn mml_source(text : String, dialect : String) -> String {
  let source = @mml.split_mml_source(text, dialect)
  let tracks = source.tracks.map(fn(track) {
    Json::array([
      Json::string(track.name),
      Json::string(track.text),
      Json::number(track.kind.to_double()),
    ])
  })
  Json::array([
    Json::string(source.title),
    Json::string(source.composer),
    Json::string(source.arranger),
    Json::string(source.lyricist),
    Json::string(source.copyright),
    Json::boolean(source.reverse),
    Json::array(tracks),
    Json::array(source.warnings.map(fn(w) { Json::string(w) })),
    Json::string(@mml.strip_mml_comments(text, false)),
    Json::string(@mml.strip_mml_comments(text, true)),
  ]).stringify()
}
