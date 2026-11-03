///|
pub fn parse(data : Bytes) -> @core.Codestream raise DecodeError {
  match @core.parse_codestream_bytes(data) {
    Ok(stream) => stream
    Err(msg) => raise InvalidCodestream(msg)
  }
}
