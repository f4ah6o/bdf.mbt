///|
// PDF RunLengthDecode. As upstream does, a complete run can extend past the
// requested maximum; incomplete literal runs retain their available bytes.
fn pdf_decode_run_length(data : Bytes, max : Int64) -> Bytes {
  let result = @buffer.Buffer()
  let mut pos = 0
  while pos < data.length() && result.length().to_int64() <= max {
    let header = data[pos].to_int()
    pos += 1
    if header == 128 {
      break
    }
    if header < 128 {
      let count = Int32::min(header + 1, data.length() - pos)
      for i in 0..<count {
        result.write_byte(data[pos + i])
      }
      pos += count
    } else if pos < data.length() {
      let value = data[pos]
      pos += 1
      for _ in 0..<(257 - header) {
        result.write_byte(value)
      }
    }
  }
  result.to_bytes()
}
