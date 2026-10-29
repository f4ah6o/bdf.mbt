///|
#export_name("inspect_gsub")
pub fn inspect_gsub(data : Bytes, roots : Array[Int32]) -> String {
  let (valid, result, truncated) = match @otlayout.parse_gsub(data[:]) {
    Some(gsub) => (true, gsub.reachable(roots), gsub.truncated())
    None => {
      let unique : Map[Int32, Bool] = Map([])
      for root in roots {
        if root >= 0 && root <= 65535 {
          unique[root] = true
        }
      }
      let result = unique.keys().collect()
      result.sort()
      (false, result, false)
    }
  }
  Json::object({
    "valid": Json::boolean(valid),
    "result": Json::array(result.map(glyph => Json::number(glyph.to_double()))),
    "truncated": Json::boolean(truncated),
  }).stringify()
}

///|
fn language_json(lang : @otlayout.LanguageSystem) -> Json {
  Json::object({
    "tag": Json::string(lang.tag),
    "required": Json::number(lang.required.to_double()),
    "features": Json::array(lang.features.map(f => Json::number(f.to_double()))),
  })
}

///|
#export_name("layout_metadata")
pub fn layout_metadata(data : Bytes, gpos : Bool) -> String {
  match @otlayout.parse_layout(data[:], gpos~) {
    None => Json::object({ "valid": Json::boolean(false) }).stringify()
    Some(layout) => {
      let scripts = layout.scripts.map(s => {
        Json::object({
          "tag": Json::string(s.tag),
          "default": match s.default_language {
            Some(lang) => language_json(lang)
            None => Json::null()
          },
          "languages": Json::array(s.languages.map(language_json)),
        })
      })
      let features = layout.features.map(f => {
        Json::object({
          "tag": Json::string(f.tag),
          "lookups": Json::array(
            f.lookups.map(i => Json::number(i.to_double())),
          ),
          "uiName": Json::number(f.ui_name.to_double()),
          "characters": Json::array(
            f.characters.map(c => Json::number(c.to_double())),
          ),
        })
      })
      let lookups = layout.lookups.map(l => {
        Json::object({
          "type": Json::number(l.typ.to_double()),
          "flag": Json::number(l.flag.to_double()),
          "markSet": Json::number(l.mark_set.to_double()),
        })
      })
      Json::object({
        "valid": Json::boolean(true),
        "scripts": Json::array(scripts),
        "features": Json::array(features),
        "lookups": Json::array(lookups),
        "featureVariations": Json::number(layout.feature_variations.to_double()),
        "scriptFeatures": Json::array(
          layout
          .script_features()
          .map(row => Json::array(row.map(v => Json::string(v)))),
        ),
      }).stringify()
    }
  }
}
