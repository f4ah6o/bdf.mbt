///|
/// Expand one raw DEFLATE stream with an upper bound on decoded bytes.
/// Bytes after the stream are accepted, matching the upstream BDF reader.
fn inflate_bounded(data : Bytes, limit : Int32) -> Bytes raise {
  if limit < 0 {
    raise BadFormat("negative deflate limit")
  }
  let decoder = @deflate.Decoder(until=EndOfMember)
  let chunk : FixedArray[Byte] = FixedArray::make(16384, 0)
  let output = @buffer.Buffer()
  let mut offset = 0
  while true {
    let status = decoder.step_into(data[offset:], chunk, end=true) catch {
      _ => raise BadFormat("invalid deflate stream")
    }
    let consumed = decoder.last_consumed()
    let produced = decoder.last_produced()
    if produced > limit - output.length() {
      raise BadFormat("deflate output exceeds limit")
    }
    output.write_bytes(Bytes::from_array(chunk[:produced]))
    offset += consumed
    if status is Done {
      return output.to_bytes()
    }
    if consumed == 0 && produced == 0 {
      raise BadFormat("incomplete deflate stream")
    }
  }
  output.to_bytes()
}
