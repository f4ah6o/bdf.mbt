///|
pub(all) struct Header {
  version : Int
  flags : Int
  manifest_offset : Int
  manifest_length : Int
  manifest_encoding : Int
}

///|
pub fn parse_header(data : Bytes) -> Header raise {
  let r = Reader::new(data)
  if r.take(4) != b"bdf\x00" {
    raise BadFormat("bad magic")
  }
  let version = r.u16()
  if version != 1 {
    raise BadFormat("unsupported BDF version")
  }
  let flags = r.u16()
  if (flags & 0xfffe) != 0 {
    raise BadFormat("unsupported header flags")
  }
  let manifest_offset = r.u64_size()
  let manifest_length = r.u64_size()
  let manifest_encoding = r.u8()
  if manifest_encoding > 1 {
    raise BadFormat("unknown manifest encoding")
  }
  for _ in 0..<7 {
    if r.u8() != 0 {
      raise BadFormat("nonzero reserved bytes")
    }
  }
  if manifest_length > 268435456 {
    raise BadFormat("manifest exceeds 256 MiB")
  }
  if manifest_offset < 32 || manifest_offset > data.length() ||
    manifest_length > data.length() - manifest_offset {
    raise BadFormat("manifest outside BDF file")
  }
  { version, flags, manifest_offset, manifest_length, manifest_encoding }
}

///|
/// Open an uncompressed, unencrypted single-file BDF. The caller may decode
/// deflate-raw with a bounded host decompressor before invoking parse_manifest.
pub fn open_single(data : Bytes) -> Document raise {
  let header = parse_header(data)
  if header.flags != 0 {
    raise Unsupported("encrypted BDF requires a crypto host")
  }
  if header.manifest_encoding != 0 {
    raise Unsupported("deflate-raw manifest requires a decompression host")
  }
  let r = Reader::new(data)
  r.skip(header.manifest_offset)
  let json = @utf8.decode(r.take(header.manifest_length)) catch {
    _ => raise BadFormat("invalid UTF-8 manifest")
  }
  let manifest = parse_manifest(json)
  let part_start = header.manifest_offset + header.manifest_length
  for part in manifest.parts {
    if part.offset < 0 || part.length < 0 ||
      part_start > data.length() ||
      part.offset > data.length() - part_start ||
      part.length > data.length() - part_start - part.offset {
      raise BadFormat("part outside BDF file")
    }
  }
  { manifest, header, data }
}

///|
pub(all) struct Document {
  manifest : Manifest
  header : Header
  data : Bytes
}

///|
pub fn Document::part(self : Document, hash : String) -> Bytes raise {
  let start = self.header.manifest_offset + self.header.manifest_length
  for part in self.manifest.parts {
    if part.hash == hash {
      if part.encoding != "identity" {
        raise Unsupported("compressed part requires a decompression host")
      }
      let off = start + part.offset
      let r = Reader::new(self.data)
      r.skip(off)
      return r.take(part.length)
    }
  }
  raise BadFormat("unknown part")
}
