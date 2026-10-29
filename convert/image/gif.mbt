///|
fn gif_blocks(data : Bytes, start : Int32, keep : Bool) -> (Bytes?, Int32) {
  let mut offset = start
  let out = @buffer.Buffer()
  while offset < data.length() {
    let size = data[offset].to_int()
    offset += 1
    if size == 0 {
      break
    }
    if keep {
      let end = if size > data.length() - offset {
        data.length()
      } else {
        offset + size
      }
      out.write_bytes(data[offset:end])
    }
    offset += size
  }
  (if out.is_empty() { None } else { Some(out.to_bytes()) }, offset)
}

///|
fn gif_find(
  data : Bytes,
  pattern : Bytes,
  start : Int32,
  end : Int32,
) -> Int32? {
  let mut at = start
  while at <= end - pattern.length() {
    if data[at:at + pattern.length()] == pattern[:] {
      return Some(at)
    }
    at += 1
  }
  None
}

///|
fn read_gif(data : Bytes) -> Picture raise {
  if data.length() < 13 {
    raise ImageFailure("image: GIF: the image is truncated")
  }
  let width = u16(data, 6).to_int64()
  let height = u16(data, 8).to_int64()
  let mut offset = 13
  if (data[10].to_int() & 0x80) != 0 {
    offset += 3 << ((data[10].to_int() & 7) + 1)
  }
  let mut frames = 0
  let mut comment = ""
  let packets : Array[Bytes] = []
  while offset < data.length() {
    let marker = data[offset].to_int()
    if marker == 0x21 {
      if offset > data.length() - 2 {
        break
      }
      let label = data[offset + 1].to_int()
      offset += 2
      let start = offset
      let (content, next) = gif_blocks(
        data,
        offset,
        label == 0xfe && comment == "",
      )
      offset = next
      if content is Some(bytes) {
        comment = xmp_clean(metadata_latin1(bytes))
      }
      if label == 0xff &&
        start <= data.length() - 12 &&
        data[start:start + 12] == b"\x0bXMP DataXMP"[:] {
        let end = if offset < data.length() { offset } else { data.length() }
        if gif_find(data, b"<?xpacket end=", start + 12, end)
          is Some(packet_end) {
          if gif_find(data, b"?>", packet_end, end) is Some(terminator) {
            packets.push(data[start + 12:terminator + 2].to_bytes())
          }
        }
      }
    } else if marker == 0x2c {
      frames += 1
      if offset > data.length() - 10 {
        break
      }
      let flags = data[offset + 9].to_int()
      offset += 10
      if (flags & 0x80) != 0 {
        offset += 3 << ((flags & 7) + 1)
      }
      let (_, next) = gif_blocks(data, offset + 1, false)
      offset = next
    } else {
      break
    }
  }
  let dc : Map[String, Array[String]] = Map([])
  for packet in packets {
    metadata_merge(dc, metadata_xmp(packet))
  }
  if !xmp_placeholder(comment) {
    let native : Map[String, Array[String]] = Map([])
    xmp_add(native, "description", [comment])
    metadata_merge(dc, native)
  }
  { format: "gif", width, height, dc, animated: frames > 1, warnings: [], }
}
