///|
// Inflate a PDF FlateDecode stream, matching upstream's allowance for raw
// DEFLATE, truncated streams, and an unchecked zlib checksum. The caller's
// limit is exceeded by at most one byte, as in inflateUpTo.
fn pdf_inflate_up_to(
  data : Bytes,
  predictor : Int32,
  colors : Int32,
  bits : Int32,
  columns : Int32,
  max : Int64,
) -> Bytes raise PdfStreamError {
  if max < 0L {
    return b""
  }
  let p = pdf_predictor(predictor, colors, bits, columns, data.length())
  if data.is_empty() {
    raise InvalidStream("empty deflate stream")
  }
  let limit = if max >= 2147483646L { 2147483647L } else { max + 1L }
  let raw_limit = if p.kind == 0 {
    limit
  } else {
    let rows = (limit + p.row_size.to_int64() - 1L) / p.row_size.to_int64()
    Int64::min(rows * p.row_length.to_int64(), 2147483647L)
  }
  let mut start = 0
  if data.length() >= 2 {
    let a = data[0].to_int()
    let b = data[1].to_int()
    if (a & 15) == 8 && a >> 4 <= 7 && (a * 256 + b) % 31 == 0 {
      if (b & 32) != 0 {
        raise InvalidStream("preset deflate dictionary")
      }
      start = 2
    }
  }
  let decoder = @deflate.Decoder(until=EndOfMember)
  let result = @buffer.Buffer()
  let mut cursor = start
  while result.length().to_int64() < raw_limit {
    let available = Int64::min(raw_limit - result.length().to_int64(), 65536L).to_int()
    let chunk = FixedArray::make(available, b'\x00')
    let state = decoder.step_into(data[cursor:], chunk, end=false) catch {
      _ => raise InvalidStream("invalid deflate stream")
    }
    cursor += decoder.last_consumed()
    result.write_bytesview(
      Bytes::from_array(chunk[:decoder.last_produced()])[:],
    )
    if state is Done || state is NeedMoreInput {
      break
    }
  }
  let raw = result.to_bytes()
  let decoded = p.undo(raw)
  if decoded.length().to_int64() > limit {
    decoded[:limit.to_int()].to_owned()
  } else {
    decoded
  }
}
