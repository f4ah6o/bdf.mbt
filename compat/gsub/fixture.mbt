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

///|
fn class_json(classes : Map[Int32, Int32]) -> Json {
  let keys = classes.keys().collect()
  keys.sort()
  Json::array(
    keys.map(g => {
      Json::array([
        Json::number(g.to_double()),
        Json::number(classes[g].to_double()),
      ])
    }),
  )
}

///|
#export_name("inspect_gdef")
pub fn inspect_gdef(data : Bytes) -> String {
  match @otlayout.parse_gdef(data[:]) {
    None => Json::object({ "valid": Json::boolean(false) }).stringify()
    Some(g) =>
      Json::object({
        "valid": Json::boolean(true),
        "classes": class_json(g.classes),
        "attach": class_json(g.mark_attach),
        "sets": Json::array(
          g.mark_sets.map(s => {
            Json::array(s.map(n => Json::number(n.to_double())))
          }),
        ),
      }).stringify()
  }
}

///|
#export_name("inspect_gpos_pairs")
pub fn inspect_gpos_pairs(data : Bytes, queries : Array[Int32]) -> String {
  match @otlayout.parse_gpos(data[:]) {
    None => Json::object({ "valid": Json::boolean(false) }).stringify()
    Some(table) => {
      let counts : Array[Json] = []
      let truncated : Array[Json] = []
      for index in queries {
        counts.push(Json::number(table.pair_count(index).to_double()))
        truncated.push(Json::boolean(table.truncated()))
      }
      Json::object({
        "valid": Json::boolean(true),
        "counts": Json::array(counts),
        "truncated": Json::array(truncated),
      }).stringify()
    }
  }
}

///|
#export_name("tag_names")
pub fn tag_names(tag : String) -> String {
  Json::object({
    "feature": Json::string(@otlayout.feature_name(tag)),
    "default": Json::number(@otlayout.feature_default(tag).to_double()),
    "script": Json::string(@otlayout.script_name(tag)),
    "language": Json::string(@otlayout.language_name(tag)),
  }).stringify()
}

///|
#export_name("type_name")
pub fn type_name(typ : Int32, gpos : Bool) -> String {
  @otlayout.lookup_type_name(typ, gpos~)
}

///|
#export_name("list_substitutions")
pub fn list_substitutions(data : Bytes, index : Int32, limit : Int32) -> String {
  let table = @otlayout.parse_gsub(data[:]).unwrap()
  let items : Array[Json] = []
  table.each_substitution(index, subst => {
    items.push(
      Json::object({
        "input": Json::array(subst.input.map(g => Json::number(g.to_double()))),
        "output": Json::array(
          subst.output.map(g => Json::number(g.to_double())),
        ),
      }),
    )
    items.length() < limit
  })
  Json::object({
    "items": Json::array(items),
    "truncated": Json::boolean(table.truncated()),
  }).stringify()
}

///|
fn context_json(context : @otlayout.LookupContext?) -> Json {
  match context {
    Some(c) =>
      Json::object({
        "rules": Json::number(c.rules.to_double()),
        "nested": Json::array(c.nested.map(n => Json::number(n.to_double()))),
      })
    None => Json::null()
  }
}

///|
#export_name("lookup_contexts")
pub fn lookup_contexts(data : Bytes, gpos : Bool) -> String {
  let count = @otlayout.parse_layout(data[:], gpos~).unwrap().lookups.length()
  let result : Array[Json] = []
  let truncated = if gpos {
    let table = @otlayout.parse_gpos(data[:]).unwrap()
    for i in -1..<=count {
      result.push(context_json(table.context(i)))
    }
    table.truncated()
  } else {
    let table = @otlayout.parse_gsub(data[:]).unwrap()
    for i in -1..<=count {
      result.push(context_json(table.context(i)))
    }
    table.truncated()
  }
  Json::object({
    "contexts": Json::array(result),
    "truncated": Json::boolean(truncated),
  }).stringify()
}

///|
fn position_json(value : @otlayout.PositionValue) -> Json {
  Json::object({
    "xPlacement": Json::number(value.x_placement.to_double()),
    "yPlacement": Json::number(value.y_placement.to_double()),
    "xAdvance": Json::number(value.x_advance.to_double()),
    "yAdvance": Json::number(value.y_advance.to_double()),
  })
}

///|
#export_name("open_gpos")
pub fn open_gpos(data : Bytes) -> @otlayout.Gpos {
  @otlayout.parse_gpos(data[:]).unwrap()
}

///|
#export_name("position_singles")
pub fn position_singles(table : @otlayout.Gpos, index : Int32) -> String {
  let values : Array[Json] = []
  table.each_single(index, (glyph, value) => {
    values.push(
      Json::object({
        "glyph": Json::number(glyph.to_double()),
        "value": position_json(value),
      }),
    )
    values.length() < 100
  })
  Json::array(values).stringify()
}

///|
#export_name("position_pair")
pub fn position_pair(
  table : @otlayout.Gpos,
  index : Int32,
  first : Int32,
  second : Int32,
) -> String {
  let (v1, v2) = match table.pair_value(index, first, second) {
    Some((a, b)) => (position_json(a), position_json(b))
    None => (Json::null(), Json::null())
  }
  Json::object({
    "first": Json::number(first.to_double()),
    "second": Json::number(second.to_double()),
    "v1": v1,
    "v2": v2,
  }).stringify()
}

///|
#export_name("gpos_truncated")
pub fn gpos_truncated(table : @otlayout.Gpos) -> Bool {
  table.truncated()
}
