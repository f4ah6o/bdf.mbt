///|
/// CFF format or execution error.
pub suberror CffError {
  InvalidCff(String)
  TooLong
}

///|
fn be16(data : BytesView, offset : Int32) -> Int32 {
  if offset < 0 || offset >= data.length() - 1 {
    return 0
  }
  (data[offset].to_int() << 8) | data[offset + 1].to_int()
}

///|
fn be32(data : BytesView, offset : Int32) -> UInt32 {
  if offset < 0 || offset >= data.length() - 3 {
    return 0U
  }
  (data[offset].to_uint() << 24) |
  (data[offset + 1].to_uint() << 16) |
  (data[offset + 2].to_uint() << 8) |
  data[offset + 3].to_uint()
}

///|
fn emit16(data : Array[Byte], n : Int32) -> Unit {
  data.push(((n >> 8) & 255).to_byte())
  data.push((n & 255).to_byte())
}

///|
fn emit32(data : Array[Byte], n : Int32) -> Unit {
  data.push(((n >> 24) & 255).to_byte())
  data.push(((n >> 16) & 255).to_byte())
  data.push(((n >> 8) & 255).to_byte())
  data.push((n & 255).to_byte())
}

///|
fn read_index(data : BytesView, start : Int32) -> (Array[Bytes], Int32) raise {
  if start < 0 || start > data.length() - 2 {
    raise InvalidCff("truncated index")
  }
  let count = be16(data, start)
  let pos = start + 2
  if count == 0 {
    return ([], pos)
  }
  if pos >= data.length() {
    raise InvalidCff("truncated index")
  }
  let size = data[pos].to_int()
  if size < 1 || size > 4 {
    raise InvalidCff("bad offSize")
  }
  let table = pos + 1
  let table_len = (count + 1) * size
  if table_len > data.length() - table {
    raise InvalidCff("truncated index offsets")
  }
  let base = table + table_len - 1
  let read_offset = (index : Int32) => {
    let mut offset = 0U
    for k in 0..<size {
      offset = (offset << 8) | data[table + index * size + k].to_uint()
    }
    offset
  }
  let result : Array[Bytes] = []
  for i in 0..<count {
    let begin = read_offset(i)
    let end = read_offset(i + 1)
    if begin > end || end > (data.length() - base).reinterpret_as_uint() {
      raise InvalidCff("bad index offsets")
    }
    result.push(
      data[base + begin.reinterpret_as_int():base + end.reinterpret_as_int()].to_owned(),
    )
  }
  let last = read_offset(count)
  if last > (data.length() - base).reinterpret_as_uint() {
    raise InvalidCff("bad index offsets")
  }
  (result, base + last.reinterpret_as_int())
}

///|
fn write_index(items : Array[Bytes]) -> Bytes {
  let out : Array[Byte] = []
  emit16(out, items.length())
  if items.length() == 0 {
    return Bytes::from_array(out)
  }
  let mut total = 1
  for item in items {
    total += item.length()
  }
  let mut size = 1
  while size < 4 && total >= 1 << (8 * size) {
    size += 1
  }
  out.push(size.to_byte())
  let append_offset = (n : Int32) => {
    for i in 0..<size {
      out.push(((n >> (8 * (size - i - 1))) & 255).to_byte())
    }
  }
  let mut offset = 1
  append_offset(offset)
  for item in items {
    offset += item.length()
    append_offset(offset)
  }
  for item in items {
    for byte in item {
      out.push(byte)
    }
  }
  Bytes::from_array(out)
}
