///|
fn subset_result(
  font_data : Bytes,
  cff_data : Bytes,
  text : String,
) -> @engine.Subset raise {
  let font = @sfnt.parse(font_data)
  let glyphs : Array[Int32] = []
  for ch in text {
    match font.glyph(ch.to_int()) {
      Some(gid) => glyphs.push(gid)
      None => ()
    }
  }
  @engine.subset(cff_data, glyphs)
}

///|
#export_name("cff_program")
pub fn cff_program(font_data : Bytes, cff_data : Bytes, text : String) -> Bytes {
  (try! subset_result(font_data, cff_data, text)).data
}

///|
#export_name("cff_order")
pub fn cff_order(font_data : Bytes, cff_data : Bytes, text : String) -> String {
  Json::array(
    (try! subset_result(font_data, cff_data, text)).order.map(n => {
      Json::number(n.to_double())
    }),
  ).stringify()
}

///|
fn raw_result(data : Bytes, text : String) -> @engine.Subset raise {
  let glyphs : Array[Int32] = [ for ch in text => ch.to_int() ]
  @engine.subset(data, glyphs)
}

///|
#export_name("raw_program")
pub fn raw_program(data : Bytes, glyphs : String) -> Bytes {
  (try! raw_result(data, glyphs)).data
}

///|
#export_name("raw_order")
pub fn raw_order(data : Bytes, glyphs : String) -> String {
  Json::array(
    (try! raw_result(data, glyphs)).order.map(n => Json::number(n.to_double())),
  ).stringify()
}

///|
#export_name("sfnt_supported")
pub fn sfnt_supported(data : Bytes, text : String) -> Bool {
  let font = try! @sfnt.parse(data)
  let codes : Array[Int32] = [ for ch in text => ch.to_int() ]
  (try! font.subset_program(codes)) is Some(_)
}

///|
#export_name("sfnt_program")
pub fn sfnt_program(data : Bytes, text : String) -> Bytes {
  let font = try! @sfnt.parse(data)
  let codes : Array[Int32] = [ for ch in text => ch.to_int() ]
  match (try! font.subset_program(codes)) {
    Some(program) => program
    None => try! font.mapped_program(codes)
  }
}

///|
#export_name("raw_prune")
pub fn raw_prune(data : Bytes, glyphs : Array[Int32]) -> Bytes {
  try! @engine.prune(data, glyphs)
}
