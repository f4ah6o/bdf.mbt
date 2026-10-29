///|
struct IsoBox {
  kind : Bytes
  data : BytesView
}

///|
fn iso_u32(data : BytesView, offset : Int32) -> UInt64 {
  (data[offset].to_uint64() << 24) |
  (data[offset + 1].to_uint64() << 16) |
  (data[offset + 2].to_uint64() << 8) |
  data[offset + 3].to_uint64()
}

///|
// Boxes that extend beyond their enclosing bytes stop the list, as upstream.
fn iso_boxes(data : BytesView) -> Array[IsoBox] {
  let boxes : Array[IsoBox] = []
  let mut offset = 0
  while offset <= data.length() - 8 {
    let mut size = iso_u32(data, offset)
    let mut header = 8
    if size == 0 {
      size = (data.length() - offset).to_uint64()
    } else if size == 1 {
      if data.length() - offset < 16 {
        break
      }
      let high = iso_u32(data, offset + 8)
      let low = iso_u32(data, offset + 12)
      size = (high << 32) | low
      header = 16
    }
    if size < header.to_uint64() || size > (data.length() - offset).to_uint64() {
      break
    }
    let end = offset + size.to_int()
    boxes.push({
      kind: data[offset + 4:offset + 8].to_bytes(),
      data: data[offset + header:end],
    })
    offset = end
  }
  boxes
}

///|
fn iso_find(boxes : Array[IsoBox], kind : Bytes) -> BytesView {
  for box in boxes {
    if box.kind == kind {
      return box.data
    }
  }
  b""[:]
}

///|
struct IsoReader {
  data : BytesView
  mut pos : Int32
  mut bad : Bool
}

///|
fn IsoReader::take(self : IsoReader, length : Int32) -> BytesView {
  if self.bad || length < 0 || length > self.data.length() - self.pos {
    self.bad = true
    return b""[:]
  }
  let start = self.pos
  self.pos += length
  self.data[start:self.pos]
}

///|
fn IsoReader::uint(self : IsoReader, size : Int32) -> UInt64 {
  if size != 0 && size != 1 && size != 2 && size != 4 && size != 8 {
    self.bad = true
    return 0
  }
  let bytes = self.take(size)
  if self.bad {
    return 0
  }
  let mut value = 0UL
  for byte in bytes {
    value = (value << 8) | byte.to_uint64()
  }
  value
}

///|
fn IsoReader::variable(self : IsoReader, size : Int32) -> UInt64 {
  if size != 0 && size != 4 && size != 8 {
    self.bad = true
    return 0
  }
  self.uint(size)
}

///|
fn IsoReader::cstring(self : IsoReader) -> Bytes {
  let start = self.pos
  while self.pos < self.data.length() && self.data[self.pos] != 0 {
    self.pos += 1
  }
  if self.bad || self.pos >= self.data.length() {
    self.bad = true
    return b""
  }
  let value = self.data[start:self.pos].to_bytes()
  self.pos += 1
  value
}
