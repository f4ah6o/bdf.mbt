///|
/// A ZIP entry's central-directory metadata.
pub(all) struct ZipEntry {
  name : String
  method : Int32
  flags : Int32
  crc32 : UInt32
  compressed_size : Int32
  size : Int32
  offset : Int32
}

///|
/// A ZIP archive stored in memory.
pub(all) struct ZipArchive {
  data : Bytes
  entries : Array[ZipEntry]
}

///|
pub suberror ZipError {
  InvalidZip(String)
}

///|
fn zip_u16(b : Bytes, p : Int32) -> Int32 {
  b[p].to_int() | (b[p + 1].to_int() << 8)
}

///|
fn zip_u32(b : Bytes, p : Int32) -> UInt32 {
  b[p].to_uint() |
  (b[p + 1].to_uint() << 8) |
  (b[p + 2].to_uint() << 16) |
  (b[p + 3].to_uint() << 24)
}

///|
fn zip_small_u64(b : Bytes, p : Int32) -> Int32 raise ZipError {
  if zip_u32(b, p + 4) != 0U || zip_u32(b, p) > 2147483647U {
    raise InvalidZip("zip: invalid archive")
  }
  zip_u32(b, p).to_int()
}

///|
/// Open a ZIP archive and enumerate its central directory without decompressing.
pub fn open_zip(data : Bytes) -> ZipArchive raise ZipError {
  let len = data.length()
  if len < 22 {
    raise InvalidZip("zip: not a valid zip file")
  }
  let mut end = -1
  let mut i = len - 22
  let lower = Int32::max(0, len - 65557)
  while i >= lower {
    if zip_u32(data, i) == 0x06054b50U {
      if i + 22 + zip_u16(data, i + 20) > len {
        raise InvalidZip("zip: not a valid zip file")
      }
      end = i
      break
    }
    i -= 1
  }
  if end < 0 {
    raise InvalidZip("zip: not a valid zip file")
  }
  let mut directory_end = end
  let mut size = zip_u32(data, end + 12).to_int64()
  let mut offset = zip_u32(data, end + 16).to_int64()
  let mut count = zip_u16(data, end + 10)
  if (count == 65535 || size == 4294967295L || offset == 4294967295L) &&
    end >= 20 &&
    zip_u32(data, end - 20) == 0x07064b50U &&
    zip_u32(data, end - 16) == 0U &&
    zip_u32(data, end - 4) == 1U {
    let pos = zip_small_u64(data, end - 12)
    if pos < 0 || pos > len - 56 || zip_u32(data, pos) != 0x06064b50U {
      raise InvalidZip("zip: not a valid zip file")
    }
    count = zip_small_u64(data, pos + 32)
    size = zip_small_u64(data, pos + 40).to_int64()
    offset = zip_small_u64(data, pos + 48).to_int64()
    directory_end = pos
  }
  let mut base = directory_end.to_int64() - size - offset
  let dir_at = base + offset
  if dir_at < 0L || dir_at >= len.to_int64() {
    raise InvalidZip("zip: not a valid zip file")
  }
  if base > 0L &&
    offset >= 0L &&
    offset <= (len - 4).to_int64() &&
    zip_u32(data, offset.to_int()) == 0x02014b50U {
    base = 0L
  }
  let mut pos64 = base + offset
  let entries : Array[ZipEntry] = []
  while pos64 >= 0L && pos64 <= (len - 46).to_int64() {
    let pos = pos64.to_int()
    if zip_u32(data, pos) != 0x02014b50U {
      break
    }
    let flags = zip_u16(data, pos + 8)
    let method = zip_u16(data, pos + 10)
    let crc32 = zip_u32(data, pos + 16)
    let mut compressed = zip_u32(data, pos + 20).to_int64()
    let mut uncompressed = zip_u32(data, pos + 24).to_int64()
    let name_len = zip_u16(data, pos + 28)
    let extra_len = zip_u16(data, pos + 30)
    let comment_len = zip_u16(data, pos + 32)
    let mut local = zip_u32(data, pos + 42).to_int64()
    let next = pos.to_int64() +
      46L +
      name_len.to_int64() +
      extra_len.to_int64() +
      comment_len.to_int64()
    if next > len.to_int64() {
      raise InvalidZip("zip: not a valid zip file")
    }
    let name = @utf8.decode_lossy(data[pos + 46:pos + 46 + name_len])
    let extra_end = pos + 46 + name_len + extra_len
    let mut extra = pos + 46 + name_len
    while extra + 4 <= extra_end {
      let tag = zip_u16(data, extra)
      let n = zip_u16(data, extra + 2)
      extra += 4
      if n > extra_end - extra {
        break
      }
      if tag == 1 {
        let mut cursor = extra
        if uncompressed == 4294967295L {
          if cursor + 8 > extra + n {
            raise InvalidZip("zip: not a valid zip file")
          }
          uncompressed = zip_small_u64(data, cursor).to_int64()
          cursor += 8
        }
        if compressed == 4294967295L {
          if cursor + 8 > extra + n {
            raise InvalidZip("zip: not a valid zip file")
          }
          compressed = zip_small_u64(data, cursor).to_int64()
          cursor += 8
        }
        if local == 4294967295L {
          if cursor + 8 > extra + n {
            raise InvalidZip("zip: not a valid zip file")
          }
          local = zip_small_u64(data, cursor).to_int64()
        }
        break
      }
      extra += n
    }
    let local_offset = local + base
    if local_offset < 0L ||
      local_offset > 2147483647L ||
      uncompressed > 2147483647L ||
      compressed > 2147483647L {
      raise InvalidZip("zip: not a valid zip file")
    }
    entries.push({
      name,
      method,
      flags,
      crc32,
      compressed_size: compressed.to_int(),
      size: uncompressed.to_int(),
      offset: local_offset.to_int(),
    })
    pos64 = next
  }
  if entries.length() % 65536 != count % 65536 {
    raise InvalidZip("zip: not a valid zip file")
  }
  { data, entries, }
}

///|
fn zip_crc32(data : Bytes) -> UInt32 {
  let mut crc = 0xffffffffU
  for b in data {
    crc = crc ^ b.to_uint()
    for _ in 0..<8 {
      crc = if (crc & 1U) != 0U { (crc >> 1) ^ 0xedb88320U } else { crc >> 1 }
    }
  }
  crc ^ 0xffffffffU
}

///|
/// Read and verify an archive entry, rejecting output above `limit` bytes.
pub fn ZipArchive::read(
  self : ZipArchive,
  entry : ZipEntry,
  limit : Int32,
) -> Bytes raise ZipError {
  let data = self.data
  let pos = entry.offset
  if limit < 0 || entry.size > limit {
    raise InvalidZip("zip: entry exceeds limit")
  }
  if pos < 0 || pos > data.length() - 30 || zip_u32(data, pos) != 0x04034b50U {
    raise InvalidZip("zip: not a valid zip file")
  }
  if entry.name.has_suffix("/") {
    if entry.size != 0 {
      raise InvalidZip("zip: not a valid zip file")
    }
    return b""
  }
  let start = pos.to_int64() +
    30L +
    zip_u16(data, pos + 26).to_int64() +
    zip_u16(data, pos + 28).to_int64()
  let end = start + entry.compressed_size.to_int64()
  if start < 0L || end > data.length().to_int64() {
    raise InvalidZip("zip: not a valid zip file")
  }
  let result = match entry.method {
    0 => data[start.to_int():end.to_int()].to_owned()
    8 => {
      let decoder = @deflate.Decoder(until=EndOfMember)
      let chunk : FixedArray[Byte] = FixedArray::make(16384, 0)
      let output = @buffer.Buffer()
      let mut pos = start.to_int()
      while true {
        let state = decoder.step_into(data[pos:end.to_int()], chunk, end=true) catch {
          _ => raise InvalidZip("zip: invalid compressed data")
        }
        let used = decoder.last_consumed()
        let written = decoder.last_produced()
        if written > limit - output.length() {
          raise InvalidZip("zip: entry exceeds limit")
        }
        output.write_bytes(Bytes::from_array(chunk[:written]))
        pos += used
        if state is Done {
          break
        }
        if used == 0 && written == 0 {
          raise InvalidZip("zip: incomplete compressed data")
        }
      }
      output.to_bytes()
    }
    _ => raise InvalidZip("zip: unsupported compression algorithm")
  }
  if result.length() != entry.size {
    raise InvalidZip("zip: invalid uncompressed size")
  }
  if (entry.flags & 8) != 0 {
    let mut descriptor = end.to_int()
    if descriptor > data.length() - 12 {
      raise InvalidZip("zip: missing data descriptor")
    }
    if zip_u32(data, descriptor) == 0x08074b50U {
      descriptor += 4
    }
    if descriptor > data.length() - 12 ||
      zip_u32(data, descriptor) != entry.crc32 {
      raise InvalidZip("zip: checksum error")
    }
  }
  if ((entry.flags & 8) != 0 || entry.crc32 != 0U) &&
    zip_crc32(result) != entry.crc32 {
    raise InvalidZip("zip: checksum error")
  }
  result
}
