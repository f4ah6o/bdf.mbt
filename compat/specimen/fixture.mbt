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
