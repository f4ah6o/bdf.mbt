///|
fn map_byte_result(
  result : Result[Array[Int], String],
) -> Result[Bytes, String] {
  match result {
    Ok(data) => Ok(@bytes.int_array_to_bytes(data))
    Err(msg) => Err(msg)
  }
}

///|
fn parse_codestream(data : Array[Int]) -> Result[@core.Codestream, String] {
  @core.parse_codestream(@bytes.int_array_to_bytes(data))
}

///|
fn parse_codestream_bytes(data : Bytes) -> Result[@core.Codestream, String] {
  @core.parse_codestream_bytes(data)
}

///|
fn parse_codestream_strict(data : Array[Int]) -> Result[@core.Codestream, String] {
  @core.parse_codestream_strict(@bytes.int_array_to_bytes(data))
}

///|
fn parse_codestream_strict_bytes(
  data : Bytes,
) -> Result[@core.Codestream, String] {
  @core.parse_codestream_strict(data)
}

///|
fn encode_codestream(stream : @core.Codestream) -> Result[Array[Int], String] {
  @core.encode_codestream(stream)
}

///|
fn encode_codestream_bytes(stream : @core.Codestream) -> Result[Bytes, String] {
  map_byte_result(@core.encode_codestream(stream))
}

///|
fn roundtrip_bytes(data : Array[Int]) -> Result[Array[Int], String] {
  @core.roundtrip_bytes(@bytes.int_array_to_bytes(data))
}

///|
fn roundtrip_codestream_bytes(data : Bytes) -> Result[Bytes, String] {
  map_byte_result(@core.roundtrip_bytes(data))
}
