///|
#export_name("musicxml_convert")
pub fn musicxml_convert(data : Bytes, guitar_tab : Bool) -> String {
  let result = @musicxml.convert(data, @fontdb.Database::new(), guitar_tab~) catch {
    @musicxml.MusicXmlInvalid(message) =>
      return Json::object({ "error": Json::string(message) }).stringify()
    error =>
      return Json::object({ "error": Json::string(error.to_string()) }).stringify()
  }
  Json::object({
    "bdf": Json::string(@base64.encode(result.bdf)),
    "pages": Json::number(result.pages.to_double()),
    "warnings": Json::array(result.warnings.map(Json::string)),
  }).stringify()
}

///|
#export_name("musicxml_convert_font")
pub fn musicxml_convert_font(
  data : Bytes,
  font : Bytes,
  guitar_tab : Bool,
) -> String {
  let db = @fontdb.Database::new()
  let _ = db.add_file("stix.ttf", font)
  let result = @musicxml.convert(data, db, guitar_tab~) catch {
    @musicxml.MusicXmlInvalid(message) =>
      return Json::object({ "error": Json::string(message) }).stringify()
    error =>
      return Json::object({ "error": Json::string(error.to_string()) }).stringify()
  }
  Json::object({
    "bdf": Json::string(@base64.encode(result.bdf)),
    "pages": Json::number(result.pages.to_double()),
    "warnings": Json::array(result.warnings.map(Json::string)),
  }).stringify()
}
