///|
struct WriterPart {
  hash : String
  kind : String
  data : Bytes
}

///|
/// Builds an unencrypted BDF document. Views and metadata use the BDF
/// manifest's JSON representation so every view kind can be written.
pub struct DocumentWriter {
  parts : Array[WriterPart]
  views : Array[Json]
  tables : Array[Json]
  meta : Json
}

///|
pub fn DocumentWriter::new(
  meta~ : Json = Json::empty_object(),
) -> DocumentWriter {
  { parts: [], views: [], tables: [], meta, }
}

///|
/// Add a part, deduplicating by the first 128 bits of its SHA-256, as BDF does.
pub fn DocumentWriter::add_part(
  self : DocumentWriter,
  kind : String,
  data : Bytes,
) -> String raise {
  // The SHA-256 padding calculation and the in-memory writer use Int offsets.
  if data.length() > 2147483575 {
    raise BadFormat("part too large")
  }
  let hash = sha256(data).unsafe_substring(start=0, end=32)
  for part in self.parts {
    if part.hash == hash {
      return hash
    }
  }
  self.parts.push({ hash, kind, data, })
  hash
}

///|
pub fn DocumentWriter::add_view(self : DocumentWriter, view : Json) -> Unit {
  self.views.push(view)
}

///|
/// Add a table entry in the BDF manifest representation.
pub fn DocumentWriter::add_table(self : DocumentWriter, table : Json) -> Unit {
  self.tables.push(table)
}

///|
fn writer_image_uncompressed(data : Bytes) -> Bool {
  if data.length() >= 2 && data[0] == b'B' && data[1] == b'M' {
    return true
  }
  if data.length() >= 4 &&
    data[0] == 0 &&
    data[1] == 0 &&
    data[2] == 1 &&
    data[3] == 0 {
    return true
  }
  let mut i = 0
  if data.length() >= 3 && data[0] == 0xef && data[1] == 0xbb && data[2] == 0xbf {
    i = 3
  }
  while i < data.length() &&
        (
          data[i] == b' ' ||
          data[i] == b'\t' ||
          data[i] == b'\r' ||
          data[i] == b'\n'
        ) {
    i += 1
  }
  i < data.length() && data[i] == b'<'
}

///|
fn writer_should_compress(part : WriterPart) -> Bool {
  if part.data.length() < 512 || part.kind == "audio" {
    return false
  }
  if part.kind == "img" && !writer_image_uncompressed(part.data) {
    return false
  }
  if part.kind == "font" &&
    part.data.length() >= 4 &&
    (part.data[:4] == b"wOFF"[:] || part.data[:4] == b"wOF2"[:]) {
    return false
  }
  true
}

///|
fn writer_encode_part(part : WriterPart) -> (Bytes, String) {
  if writer_should_compress(part) {
    let compressed = @deflate.compress(part.data)
    if compressed.length() < part.data.length() {
      return (compressed, "deflate-raw")
    }
  }
  (part.data, "identity")
}

///|
fn DocumentWriter::manifest(self : DocumentWriter, entries : Array[Json]) -> Json {
  let meta = if self.meta is Object(fields) {
    let copy : Map[String, Json] = Map([])
    for key, value in fields { copy[key] = value }
    match copy.get("generator") {
      None | Some(String("")) | Some(Null) => copy["generator"] = Json::string("bdf-go/0.1")
      _ => ()
    }
    Json::object(copy)
  } else { self.meta }
  Json::object({
    "bdf": Json::number(1.0),
    "opset": Json::number(1.0),
    "unit": Json::string("pt"),
    "meta": meta,
    "views": Json::array(self.views),
    "tables": Json::array(self.tables),
    "parts": Json::array(entries),
  })
}

///|
/// Encode the accumulated document using identity or raw DEFLATE parts.
pub fn DocumentWriter::write_single(self : DocumentWriter) -> Bytes raise {
  let entries : Array[Json] = []
  let stored : Array[Bytes] = []
  let mut offset = 0
  for part in self.parts {
    let (encoded, encoding) = writer_encode_part(part)
    if encoded.length() > 2147483647 - offset {
      raise BadFormat("document too large")
    }
    entries.push(
      Json::object({
        "h": Json::string(part.hash),
        "t": Json::string(part.kind),
        "enc": Json::string(encoding),
        "len": Json::number(encoded.length().to_double()),
        "size": Json::number(part.data.length().to_double()),
        "off": Json::number(offset.to_double()),
      }),
    )
    stored.push(encoded)
    offset += encoded.length()
  }
  let manifest = self.manifest(entries)
  let plain = @utf8.encode(manifest.stringify())
  if plain.length() > 268435456 {
    raise BadFormat("manifest exceeds 256 MiB")
  }
  let mut encoded_manifest = plain
  let mut manifest_encoding = 0
  if plain.length() >= 512 {
    let compressed = @deflate.compress(plain)
    if compressed.length() < plain.length() {
      encoded_manifest = compressed
      manifest_encoding = 1
    }
  }
  if encoded_manifest.length() > 2147483615 - offset {
    raise BadFormat("document too large")
  }
  let out = @buffer.Buffer()
  out.write_bytes(b"bdf\x00")
  out.write_uint16_le(1)
  out.write_uint16_le(0)
  out.write_uint64_le(32)
  out.write_uint64_le(encoded_manifest.length().to_uint64())
  out.write_byte(manifest_encoding.to_byte())
  out.write_bytes(b"\x00\x00\x00\x00\x00\x00\x00")
  out.write_bytes(encoded_manifest)
  for part in stored {
    out.write_bytes(part)
  }
  out.to_bytes()
}
