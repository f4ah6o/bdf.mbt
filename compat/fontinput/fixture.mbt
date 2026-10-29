///|
#export_name("detect")
pub fn detect(data : Bytes) -> Bool {
  @font.detect(data)
}

///|
#export_name("inspect_file")
pub fn inspect_file(data : Bytes) -> String {
  try {
    let file = @font.load(data)
    let faces : Array[Json] = []
    for face in file.faces() {
      faces.push(
        Json::object({
          "index": Json::number(face.index.to_double()),
          "size": Json::number(face.size.to_double()),
          "glyphs": Json::number(face.font.metrics.glyph_count.to_double()),
        }),
      )
    }
    Json::object({
      "error": Json::string(""),
      "container": Json::string(file.container),
      "collection": Json::boolean(file.collection),
      "size": Json::number(file.size.to_double()),
      "faces": Json::array(faces),
    }).stringify()
  } catch {
    @font.InvalidFontInput(message) =>
      Json::object({ "error": Json::string(message) }).stringify()
    error =>
      Json::object({ "error": Json::string(error.to_string()) }).stringify()
  }
}

///|
#export_name("select")
pub fn select(data : Bytes, spec : String) -> String {
  try {
    let file = @font.load(data)
    let (selected, warnings) = file.select(spec)
    Json::object({
      "error": Json::string(""),
      "indexes": Json::array(
        selected.map(face => Json::number(face.index.to_double())),
      ),
      "warnings": Json::array(warnings.map(w => Json::string(w))),
    }).stringify()
  } catch {
    @font.InvalidFontInput(message) =>
      Json::object({
        "error": Json::string(message),
        "indexes": Json::array([]),
        "warnings": Json::array([]),
      }).stringify()
    error =>
      Json::object({ "error": Json::string(error.to_string()) }).stringify()
  }
}
