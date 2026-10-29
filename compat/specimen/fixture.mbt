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
