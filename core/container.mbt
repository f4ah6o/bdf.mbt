///|
pub(all) struct Header {
  version : Int32
  flags : Int32
  manifest_offset : Int32
  manifest_length : Int32
  manifest_encoding : Int32
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
  if manifest_offset < 32 ||
    manifest_offset > data.length() ||
    manifest_length > data.length() - manifest_offset {
    raise BadFormat("manifest outside BDF file")
  }
  { version, flags, manifest_offset, manifest_length, manifest_encoding, }
}

///|
/// Open an unencrypted single-file BDF, including deflate-raw manifests.
pub fn open_single(data : Bytes) -> Document raise {
  let header = parse_header(data)
  if header.flags != 0 {
    raise Unsupported("encrypted BDF requires a crypto host")
  }
  let r = Reader::new(data)
  r.skip(header.manifest_offset)
  let stored_manifest = r.take(header.manifest_length)
  let manifest_bytes = if header.manifest_encoding == 1 {
    inflate_bounded(stored_manifest, 268435456)
  } else {
    stored_manifest
  }
  let json = @utf8.decode(manifest_bytes) catch {
    _ => raise BadFormat("invalid UTF-8 manifest")
  }
  let manifest = parse_manifest(json)
  let part_start = header.manifest_offset + header.manifest_length
  for part in manifest.parts {
    if part.offset < 0 ||
      part.length < 0 ||
      part_start > data.length() ||
      part.offset > data.length() - part_start ||
      part.length > data.length() - part_start - part.offset {
      raise BadFormat("part outside BDF file")
    }
  }
  { manifest, header, data, }
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
      let off = start + part.offset
      let r = Reader::new(self.data)
      r.skip(off)
      let stored = r.take(part.length)
      if part.encoding == "identity" {
        return stored
      } else if part.encoding == "deflate-raw" {
        return inflate_bounded(stored, part.size)
      } else {
        raise BadFormat("unknown part encoding")
      }
    }
  }
  raise BadFormat("unknown part")
}
