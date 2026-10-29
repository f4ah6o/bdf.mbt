///|
#export_name("convert_fixture")
pub fn convert_fixture(data : Bytes, name : String, title : String) -> Bytes {
  (try! @image.convert(data, name~, title~)).bdf
}

///|
#export_name("convert_summary")
pub fn convert_summary(data : Bytes, name : String, title : String) -> String {
  (try! @image.convert(data, name~, title~)).summary
}

///|
#export_name("convert_animated")
pub fn convert_animated(data : Bytes) -> Bool {
  (try! @image.convert(data)).animated
}

///|
#export_name("convert_warnings")
pub fn convert_warnings(data : Bytes) -> Array[String] {
  (try! @image.convert(data)).warnings
}

///|
#export_name("accepts")
pub fn accepts(data : Bytes) -> Bool {
  try {
    ignore(@image.convert(data))
    true
  } catch {
    _ => false
  }
}
