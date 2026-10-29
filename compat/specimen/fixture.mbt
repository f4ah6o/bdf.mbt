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
      return (try! face.sample_pruned_truetype(glyphs)).unwrap_or(b"")
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
      return (try! face.sample_truetype(text)).unwrap_or(b"")
    }
  }
  abort("missing font face")
}
