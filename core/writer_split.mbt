///|
/// A stored part of a split document. Hosts save `data` under `parts/<hash>`.
pub(all) struct SplitPart {
  hash : String
  data : Bytes
}

///|
/// The manifest.json and stored parts of a split BDF document.
pub(all) struct SplitOutput {
  manifest : Bytes
  parts : Array[SplitPart]
}

///|
/// Encode a document as manifest.json and content-addressed stored parts.
pub fn DocumentWriter::write_split(self : DocumentWriter) -> SplitOutput raise {
  let entries : Array[Json] = []
  let parts : Array[SplitPart] = []
  for part in self.parts {
    let (data, encoding) = writer_encode_part(part)
    entries.push(Json::object({
      "h": Json::string(part.hash),
      "t": Json::string(part.kind),
      "enc": Json::string(encoding),
      "len": Json::number(data.length().to_double()),
      "size": Json::number(part.data.length().to_double()),
      "off": Json::number(0.0),
    }))
    parts.push({ hash: part.hash, data, })
  }
  let manifest = @utf8.encode(self.manifest(entries).stringify())
  if manifest.length() > 268435456 {
    raise BadFormat("manifest exceeds 256 MiB")
  }
  { manifest, parts, }
}

///|
fn writer_manifest(data : Bytes) -> (Json, Manifest, Bool) raise {
  if data.length() > 268435456 {
    raise BadFormat("manifest exceeds 256 MiB")
  }
  let text = @utf8.decode(data) catch {
    _ => raise BadFormat("invalid UTF-8 manifest")
  }
  let root = @json.parse(text) catch {
    _ => raise BadFormat("invalid manifest JSON")
  }
  let encrypted = if root is Object(fields) {
    match fields.get("encryption") {
      None | Some(Null) => false
      Some(_) => true
    }
  } else {
    false
  }
  let manifest = if encrypted {
    parse_encrypted_manifest(text).outer
  } else {
    parse_manifest(text)
  }
  (root, manifest, encrypted)
}

///|
fn writer_offsets(root : Json, offsets : Array[Int32]) -> Bytes raise {
  let parts = required_array(root, "parts")
  if parts.length() != offsets.length() {
    raise BadFormat("part count mismatch")
  }
  for i, part in parts {
    guard part is Object(fields) else { raise BadFormat("expected part object") }
    fields["off"] = Json::number(offsets[i].to_double())
  }
  let data = @utf8.encode(root.stringify())
  if data.length() > 268435456 {
    raise BadFormat("manifest exceeds 256 MiB")
  }
  data
}

///|
fn writer_check_stored(part : Part, stored : Bytes) -> Unit raise {
  if stored.length() != part.length {
    raise BadFormat("stored part size does not match manifest")
  }
  let checked = if part.kind == "sealed" {
    stored
  } else {
    decode_stored_part(part, stored)
  }
  if checked.length() > 2147483575 {
    raise BadFormat("part too large")
  }
  if sha256(checked).unsafe_substring(start=0, end=32) != part.hash {
    raise BadFormat("part hash mismatch: " + part.hash)
  }
}

///|
/// Convert a single-file BDF to its split form without recompressing parts.
/// Encrypted documents can be copied without a password; sealed part hashes
/// are checked against the stored ciphertext.
pub fn single_to_split(data : Bytes) -> SplitOutput raise {
  let header = parse_header(data)
  let source = Reader::new(data)
  source.skip(header.manifest_offset)
  let stored_manifest = source.take(header.manifest_length)
  let manifest_data = if header.manifest_encoding == 1 {
    inflate_bounded(stored_manifest, 268435456)
  } else {
    stored_manifest
  }
  let (root, manifest, encrypted) = writer_manifest(manifest_data)
  if encrypted != (header.flags == 1) {
    raise BadFormat("encryption flag does not match manifest")
  }
  let base = header.manifest_offset + header.manifest_length
  let parts : Array[SplitPart] = []
  for part in manifest.parts {
    if part.offset > data.length() - base ||
      part.length > data.length() - base - part.offset {
      raise BadFormat("part outside BDF file")
    }
    let reader = Reader::new(data)
    reader.skip(base + part.offset)
    let stored = reader.take(part.length)
    writer_check_stored(part, stored)
    parts.push({ hash: part.hash, data: stored, })
  }
  { manifest: writer_offsets(root, [ for _ in parts => 0 ]), parts, }
}

///|
/// Convert split BDF data to a single file, preserving the stored parts.
/// The loader receives the part hash and the maximum stored byte count.
pub fn split_to_single(
  manifest_data : Bytes,
  load : (String, Int32) -> Bytes raise,
) -> Bytes raise {
  let (root, manifest, encrypted) = writer_manifest(manifest_data)
  let parts : Array[Bytes] = []
  let offsets : Array[Int32] = []
  let mut total = 0
  for part in manifest.parts {
    let stored = load(part.hash, part.length)
    writer_check_stored(part, stored)
    if stored.length() > 2147483647 - total {
      raise BadFormat("document too large")
    }
    offsets.push(total)
    total += stored.length()
    parts.push(stored)
  }
  let plain = writer_offsets(root, offsets)
  let mut encoded = plain
  let mut encoding = 0
  if plain.length() >= 512 {
    let compressed = @deflate.compress(plain)
    if compressed.length() < plain.length() {
      encoded = compressed
      encoding = 1
    }
  }
  if encoded.length() > 2147483615 - total {
    raise BadFormat("document too large")
  }
  let output = @buffer.Buffer()
  output.write_bytes(b"bdf\x00")
  output.write_uint16_le(1)
  output.write_uint16_le(if encrypted { 1 } else { 0 })
  output.write_uint64_le(32)
  output.write_uint64_le(encoded.length().to_uint64())
  output.write_byte(encoding.to_byte())
  output.write_bytes(b"\x00\x00\x00\x00\x00\x00\x00")
  output.write_bytes(encoded)
  for part in parts { output.write_bytes(part) }
  output.to_bytes()
}
