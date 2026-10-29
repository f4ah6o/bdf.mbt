///|
#export_name("decode")
pub fn decode(data : Bytes) -> Bytes {
  try! @sfnt.decode_woff(data)
}

///|
#export_name("error")
pub fn error(data : Bytes) -> String {
  try {
    ignore(@sfnt.decode_woff(data))
    ""
  } catch {
    @sfnt.InvalidFont(message) => "font: " + message
    error => error.to_string()
  }
}
