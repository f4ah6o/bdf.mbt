///|
fn hash_byte(c : Byte) -> Int32 {
  let v = c.to_int()
  if v <= 57 {
    v - 48
  } else {
    v - 87
  }
}

///|
fn write_hash(out : @buffer.Buffer, hash : String) -> Unit {
  let bytes = @utf8.encode(hash)
  for i in 0..<16 {
    out.write_byte(
      (hash_byte(bytes[i * 2]) * 16 + hash_byte(bytes[i * 2 + 1])).to_byte(),
    )
  }
}

///|
fn image_object(
  hash : String,
  width : Float,
  height : Float,
  alt : String,
) -> Bytes {
  let original = @utf8.encode(alt)
  // The upstream object's string table strips leading Unicode BOMs.
  let mut start = 0
  while start + 3 <= original.length() &&
        original[start] == 0xef &&
        original[start + 1] == 0xbb &&
        original[start + 2] == 0xbf {
    start += 3
  }
  let text = original[start:]
  let ops = @buffer.Buffer()
  ops.write_bytes(b"\x71\x0a\x00\x42\x01\x02\x40\x00")
  ops.write_float_le(0.0F)
  ops.write_float_le(0.0F)
  ops.write_float_le(width)
  ops.write_float_le(height)
  ops.write_bytes(
    if text.length() == 0 {
      b"\x71\x0b\x00"
    } else {
      b"\x71\x0b\x01"
    },
  )
  let out = @buffer.Buffer()
  out.write_bytes(b"BOBJ\x01\x00\x00\x00")
  out.write_float_le(0.0F)
  out.write_float_le(0.0F)
  out.write_float_le(width)
  out.write_float_le(height)
  out.write_leb128(if text.length() == 0 { 1U } else { 2U })
  out.write_leb128(text.length().to_uint())
  out.write_bytes(text)
  if text.length() != 0 {
    out.write_byte(0)
  }
  out.write_bytes(b"\x00\x00\x00\x01") // paths, paints, fonts, image count
  write_hash(out, hash)
  out.write_byte(0) // child object count
  out.write_leb128(ops.length().to_uint())
  out.write_bytes(ops.to_bytes())
  out.to_bytes()
}
