///|
#export_name("glyph_program")
pub fn glyph_program(data : Bytes, index : Int32) -> Bytes {
  let file = try! @font.load(data)
  for face in file.faces() {
    if face.index == index {
      return try! face.font.glyph_program()
    }
  }
  abort("missing font face")
}

///|
#export_name("sample_program")
pub fn sample_program(data : Bytes, index : Int32) -> Bytes {
  let file = try! @font.load(data)
  for face in file.faces() {
    if face.index == index {
      return (try! face.sample_whole_program()).unwrap_or(b"")
    }
  }
  abort("missing font face")
}

///|
#export_name("pruned_program")
pub fn pruned_program(
  data : Bytes,
  index : Int32,
  glyphs : Array[Int32],
) -> Bytes {
  let file = try! @font.load(data)
  for face in file.faces() {
    if face.index == index {
      return (try! face.sample_pruned(glyphs)).unwrap_or(b"")
    }
  }
  abort("missing font face")
}

///|
#export_name("reachable")
pub fn reachable(data : Bytes, index : Int32, text : String) -> Array[Int32] {
  let file = try! @font.load(data)
  for face in file.faces() {
    if face.index == index {
      return face.font.specimen_reachable(text)
    }
  }
  abort("missing font face")
}

///|
#export_name("automatic_pruned")
pub fn automatic_pruned(data : Bytes, index : Int32, text : String) -> Bytes {
  let file = try! @font.load(data)
  for face in file.faces() {
    if face.index == index {
      return (try! face.sample_program(text)).unwrap_or(b"")
    }
  }
  abort("missing font face")
}

///|
#export_name("sample_plan")
pub fn sample_plan(data : Bytes, index : Int32, text : String) -> String {
  let file = try! @font.load(data)
  for face in file.faces() {
    if face.index == index {
      let plan = face.sample_plan(text)
      let primary = match plan.primary {
        Some(script) => script.code
        None => ""
      }
      return Json::object({
        "primary": Json::string(primary),
        "scripts": Json::array(
          plan.scripts.map(script => Json::string(script.code)),
        ),
        "specimen": Json::string(plan.specimen),
        "charset": Json::array(plan.charset.map(line => Json::string(line))),
        "waterfall": Json::string(plan.waterfall),
        "rtl": Json::boolean(plan.rtl),
        "lang": Json::string(plan.lang),
        "all": Json::string(plan.all()),
      }).stringify()
    }
  }
  abort("missing font face")
}

///|
#export_name("glyph_names")
pub fn glyph_names(data : Bytes, index : Int32) -> String {
  let file = try! @font.load(data)
  for face in file.faces() {
    if face.index == index {
      return Json::array(
        face.font.glyph_names().map(name => Json::string(name)),
      ).stringify()
    }
  }
  abort("missing font face")
}

///|
#export_name("coverage")
pub fn coverage(data : Bytes, index : Int32) -> String {
  let file = try! @font.load(data)
  for face in file.faces() {
    if face.index == index {
      return Json::array(
        face
        .coverage()
        .map(entry => {
          Json::object({
            "first": Json::number(entry.block.first.to_double()),
            "last": Json::number(entry.block.last.to_double()),
            "name": Json::string(entry.block.name),
            "assigned": Json::number(entry.block.assigned.to_double()),
            "mapped": Json::number(entry.mapped.to_double()),
          })
        }),
      ).stringify()
    }
  }
  abort("missing font face")
}

///|
fn name_json(name : @font.SpecimenName) -> Json {
  Json::object({
    "id": Json::number(name.id.to_double()),
    "lang": Json::string(name.lang),
    "english": Json::boolean(name.english),
    "text": Json::string(name.text),
    "rank": Json::number(name.rank.to_double()),
  })
}

///|
#export_name("specimen_names")
pub fn specimen_names(data : Bytes) -> String {
  let names = @font.parse_specimen_names(data)
  let best : Array[Json] = []
  let locals : Array[Json] = []
  for id in 0..<30 {
    best.push(Json::string(names.best(id)))
    locals.push(Json::array(names.local(id).map(name_json)))
  }
  Json::object({
    "records": Json::array(names.records.map(name_json)),
    "cut": Json::boolean(names.cut),
    "best": Json::array(best),
    "locals": Json::array(locals),
    "family": Json::string(names.family()),
    "full": Json::string(names.full()),
  }).stringify()
}

///|
#export_name("glyph_details")
pub fn glyph_details(data : Bytes, index : Int32) -> String {
  let file = try! @font.load(data)
  for face in file.faces() {
    if face.index == index {
      let glyphs = face
        .specimen_glyphs()
        .map(g => {
          Json::object({
            "name": Json::string(g.name),
            "characters": Json::array(
              g.characters.map(c => Json::number(c.to_double())),
            ),
            "label": Json::string(g.label),
            "alternative": Json::string(g.alternative),
          })
        })
      let counts = face
        .script_counts()
        .map(c => {
          Json::object({
            "name": Json::string(c.name),
            "count": Json::number(c.count.to_double()),
          })
        })
      return Json::object({
        "glyphs": Json::array(glyphs),
        "counts": Json::array(counts),
      }).stringify()
    }
  }
  abort("missing font face")
}

///|
#export_name("variations")
pub fn variations(data : Bytes, raw_names : Bytes) -> String {
  let v = @font.parse_variations(data, @font.parse_specimen_names(raw_names))
  Json::object({
    "axes": Json::array(
      v.axes.map(a => {
        Json::object({
          "tag": Json::string(a.tag),
          "name": Json::string(a.name),
          "min": Json::number(a.minimum),
          "default": Json::number(a.default_value),
          "max": Json::number(a.maximum),
          "hidden": Json::boolean(a.hidden),
        })
      }),
    ),
    "instances": Json::array(
      v.instances.map(i => {
        Json::object({
          "name": Json::string(i.name),
          "postscript": Json::string(i.postscript),
          "coordinates": Json::array(i.coordinates.map(c => Json::number(c))),
        })
      }),
    ),
  }).stringify()
}

///|
#export_name("info_tables")
pub fn info_tables(
  cmap : Bytes,
  meta : Bytes,
  colr : Bytes,
  cpal : Bytes,
  sbix : Bytes,
  cblc : Bytes,
  svg : Bytes,
) -> String {
  let (count, more) = @font.variation_sequences(cmap)
  let (design, supported) = @font.metadata_languages(meta)
  Json::object({
    "count": Json::number(count.to_double()),
    "more": Json::boolean(more),
    "design": Json::string(design),
    "supported": Json::string(supported),
    "color": Json::string(@font.color_formats(colr, cpal, sbix, cblc, svg)),
    "palettes": Json::array(
      @font.color_palettes(cpal).map(p => {
        Json::array(p.map(c => Json::number(c.to_double())))
      }),
    ),
  }).stringify()
}

///|
#export_name("kerning_description")
pub fn kerning_description(data : Bytes, index : Int32) -> String {
  let file = try! @font.load(data)
  for face in file.faces() {
    if face.index == index {
      return face.kerning()
    }
  }
  abort("missing font face")
}

///|
fn overview_row(row : @font.OverviewRow) -> Json {
  Json::object({
    "label": Json::string(row.label),
    "value": Json::string(row.value),
    "lang": Json::string(row.lang),
  })
}

///|
#export_name("overview")
pub fn overview(data : Bytes, index : Int32, outlines : Bool) -> String {
  let file = try! @font.load(data)
  for face in file.faces() {
    if face.index == index {
      let sections = file
        .overview(face, outlines~)
        .map(s => {
          Json::object({
            "title": Json::string(s.title),
            "rows": Json::array(s.rows.map(overview_row)),
          })
        })
      return Json::object({
        "sections": Json::array(sections),
        "tables": Json::array(face.table_list().map(overview_row)),
      }).stringify()
    }
  }
  abort("missing font face")
}

///|
#export_name("features")
pub fn features(data : Bytes, index : Int32) -> String {
  let file = try! @font.load(data)
  for face in file.faces() {
    if face.index == index {
      return Json::array(
        face
        .feature_groups()
        .map(g => {
          Json::object({
            "table": Json::string(g.table),
            "tag": Json::string(g.tag),
            "lookups": Json::array(
              g.lookups.map(x => Json::number(x.to_double())),
            ),
            "scripts": Json::array(g.scripts.map(Json::string)),
            "uiName": Json::string(g.ui_name),
            "characters": Json::array(
              g.characters.map(x => Json::number(x.to_double())),
            ),
          })
        }),
      ).stringify()
    }
  }
  abort("missing font face")
}
