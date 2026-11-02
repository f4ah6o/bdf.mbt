///|
/// Decode one Parquet page payload. `expected` is the uncompressed page size.
fn parquet_decompress(data : Bytes, codec : Int, expected : Int) -> Bytes raise {
  let limit = if expected > 0 && expected < 268435456 {
    expected
  } else {
    268435456
  }
  if limit <= 0 {
    raise Failure("parquet: invalid page size")
  }
  match codec {
    0 => data
    1 => parquet_snappy(data, limit)
    2 => @gzip.decompress(data[:], max_output=limit) catch {
      _ => raise Failure("parquet: invalid GZIP page")
    }
    4 => @brotli.decompress(data[:], max_output=limit) catch {
      _ => raise Failure("parquet: invalid Brotli page")
    }
    5 => parquet_lz4(data, limit, true)
    6 => @zstd.decompress(data[:], max_output=limit) catch {
      _ => raise Failure("parquet: invalid Zstandard page")
    }
    7 => parquet_lz4(data, limit, false)
    _ => raise Failure("parquet: unsupported codec \{codec}")
  }
}

///|
fn parquet_varint_at(data : Bytes, pos : Int) -> (Int, Int) {
  let mut value = 0
  let mut shift = 0
  let mut index = pos
  while index < data.length() && shift < 35 {
    let byte = data[index].to_int()
    index += 1
    value = value | ((byte & 0x7f) << shift)
    if (byte & 0x80) == 0 {
      break
    }
    shift += 7
  }
  (value, index)
}

///|
fn parquet_snappy(data : Bytes, max : Int) -> Bytes raise {
  let header = parquet_varint_at(data, 0)
  let length = header.0
  let mut pos = header.1
  if length < 0 || length > max {
    raise Failure("parquet: Snappy page exceeds the size limit")
  }
  let out : Array[Byte] = []
  while pos < data.length() && out.length() < length {
    let tag = data[pos].to_int()
    pos += 1
    let kind = tag & 3
    if kind == 0 {
      let mut literal = tag >> 2
      if literal < 60 {
        literal += 1
      } else {
        let extra = literal - 59
        if pos + extra > data.length() {
          raise Failure("parquet: truncated Snappy literal")
        }
        let mut value = 0
        for index in 0..<extra {
          value = value | (data[pos + index].to_int() << (index * 8))
        }
        pos += extra
        literal = value + 1
      }
      if literal < 0 || pos + literal > data.length() {
        raise Failure("parquet: truncated Snappy literal")
      }
      for index in 0..<literal {
        out.push(data[pos + index])
      }
      pos += literal
    } else {
      let mut length = 0
      let mut offset = 0
      if kind == 1 {
        if pos >= data.length() {
          raise Failure("parquet: truncated Snappy copy")
        }
        length = ((tag >> 2) & 7) + 4
        offset = ((tag >> 5) << 8) | data[pos].to_int()
        pos += 1
      } else if kind == 2 {
        if pos + 2 > data.length() {
          raise Failure("parquet: truncated Snappy copy")
        }
        length = (tag >> 2) + 1
        offset = data[pos].to_int() | (data[pos + 1].to_int() << 8)
        pos += 2
      } else {
        if pos + 4 > data.length() {
          raise Failure("parquet: truncated Snappy copy")
        }
        length = (tag >> 2) + 1
        offset = data[pos].to_int() |
          (data[pos + 1].to_int() << 8) |
          (data[pos + 2].to_int() << 16) |
          (data[pos + 3].to_int() << 24)
        pos += 4
      }
      if offset <= 0 || offset > out.length() {
        raise Failure("parquet: invalid Snappy copy offset")
      }
      if out.length() + length > max {
        raise Failure("parquet: Snappy page exceeds the size limit")
      }
      let start = out.length() - offset
      for index in 0..<length {
        out.push(out[start + index])
      }
    }
  }
  if out.length() != length {
    raise Failure("parquet: truncated Snappy page")
  }
  Bytes::from_array(out)
}

///|
fn parquet_lz4_block(data : Bytes, max : Int) -> Bytes raise {
  let out : Array[Byte] = []
  let mut pos = 0
  while pos < data.length() {
    let token = data[pos].to_int()
    pos += 1
    let mut literal = token >> 4
    if literal == 15 {
      while true {
        if pos >= data.length() {
          raise Failure("parquet: truncated LZ4 literal")
        }
        let extra = data[pos].to_int()
        pos += 1
        literal += extra
        if extra != 255 {
          break
        }
      }
    }
    if literal > 0 {
      if pos + literal > data.length() || out.length() + literal > max {
        raise Failure("parquet: truncated LZ4 literal")
      }
      for index in 0..<literal {
        out.push(data[pos + index])
      }
      pos += literal
    }
    if pos >= data.length() {
      break
    }
    if pos + 2 > data.length() {
      raise Failure("parquet: truncated LZ4 offset")
    }
    let offset = data[pos].to_int() | (data[pos + 1].to_int() << 8)
    pos += 2
    if offset <= 0 || offset > out.length() {
      raise Failure("parquet: invalid LZ4 offset")
    }
    let mut length = token & 15
    if length == 15 {
      while true {
        if pos >= data.length() {
          raise Failure("parquet: truncated LZ4 match")
        }
        let extra = data[pos].to_int()
        pos += 1
        length += extra
        if extra != 255 {
          break
        }
      }
    }
    length += 4
    if out.length() + length > max {
      raise Failure("parquet: LZ4 page exceeds the size limit")
    }
    let start = out.length() - offset
    for index in 0..<length {
      out.push(out[start + index])
    }
  }
  Bytes::from_array(out)
}

///|
fn parquet_lz4(data : Bytes, max : Int, framed : Bool) -> Bytes raise {
  if !framed {
    return parquet_lz4_block(data, max)
  }
  // Hadoop LZ4 framing: big-endian uncompressed and compressed block sizes.
  let out : Array[Byte] = []
  let mut pos = 0
  while pos + 8 <= data.length() {
    let uncompressed = (data[pos].to_int() << 24) |
      (data[pos + 1].to_int() << 16) |
      (data[pos + 2].to_int() << 8) |
      data[pos + 3].to_int()
    let compressed = (data[pos + 4].to_int() << 24) |
      (data[pos + 5].to_int() << 16) |
      (data[pos + 6].to_int() << 8) |
      data[pos + 7].to_int()
    if uncompressed <= 0 || compressed <= 0 ||
      pos + 8 + compressed > data.length() || out.length() + uncompressed > max {
      break
    }
    let block = parquet_lz4_block(data[pos + 8:pos + 8 + compressed].to_owned(), uncompressed)
    if block.length() != uncompressed {
      break
    }
    for byte in block {
      out.push(byte)
    }
    pos += 8 + compressed
  }
  if out.is_empty() {
    // Some writers store a single raw LZ4 block under the LZ4 codec.
    return parquet_lz4_block(data, max)
  }
  Bytes::from_array(out)
}
