///|
/// One encrypted BDF key slot. Unknown slot types are ignored when unlocking.
pub(all) enum KeySlot {
  Password(String, Int32, String, String)
  Ecdh(String, String, String, String)
  Other
}

///|
/// The public outer manifest and the information needed to unlock it.
pub(all) struct EncryptedManifest {
  outer : Manifest
  cipher : String
  keys : Array[KeySlot]
  manifest_hash : String
  manifest_encoding : String
}

///|
/// Parse the outer manifest of an encrypted BDF document.
pub fn parse_encrypted_manifest(input : String) -> EncryptedManifest raise {
  let root = @json.parse(input) catch {
    _ => raise BadFormat("invalid manifest JSON")
  }
  let outer = parse_manifest_internal(input, true)
  let encryption = field(root, "encryption")
  let cipher = required_string(encryption, "cipher")
  if cipher != "A256GCM" {
    raise BadFormat("unknown cipher")
  }
  let manifest = field(encryption, "manifest")
  let manifest_hash = required_string(manifest, "part")
  if !valid_hash(manifest_hash) {
    raise BadFormat("invalid sealed manifest hash")
  }
  let manifest_encoding = optional_string(manifest, "enc", "identity")
  if manifest_encoding != "identity" && manifest_encoding != "deflate-raw" {
    raise BadFormat("unknown manifest encoding")
  }
  let keys : Array[KeySlot] = []
  for slot in required_array(encryption, "keys") {
    match optional_string(slot, "type", "") {
      "password" => {
        let iterations = if slot is Object(fields) {
          match fields.get("iter") {
            Some(Number(value, ..)) =>
              if value >= 0.0 && value <= 2147483647.0 && value.floor() == value {
                value.to_int()
              } else {
                -1
              }
            _ => -1
          }
        } else {
          -1
        }
        keys.push(
          Password(
            optional_string(slot, "kdf", ""),
            iterations,
            optional_string(slot, "salt", ""),
            optional_string(slot, "key", ""),
          ),
        )
      }
      "ecdh" =>
        keys.push(
          Ecdh(
            optional_string(slot, "kdf", ""),
            optional_string(slot, "crv", ""),
            optional_string(slot, "epk", ""),
            optional_string(slot, "key", ""),
          ),
        )
      _ => keys.push(Other)
    }
  }
  let mut found = false
  for part in outer.parts {
    if part.hash == manifest_hash {
      found = true
      if part.length > 268435484 {
        raise BadFormat("sealed manifest exceeds limit")
      }
    }
  }
  if !found {
    raise BadFormat("sealed manifest part missing")
  }
  { outer, cipher, keys, manifest_hash, manifest_encoding, }
}

///|
/// Decode a stored manifest or part using the given maximum output size.
pub fn decode_encoded(
  data : Bytes,
  encoding : String,
  limit : Int32,
) -> Bytes raise {
  if limit < 0 {
    raise BadFormat("negative decoded size limit")
  }
  match encoding {
    "identity" => {
      if data.length() > limit {
        raise BadFormat("decoded data exceeds limit")
      }
      data
    }
    "deflate-raw" => inflate_bounded(data, limit)
    _ => raise BadFormat("unknown part encoding")
  }
}

///|
/// An encrypted single-file document before unlocking its inner manifest.
pub(all) struct EncryptedSingle {
  metadata : EncryptedManifest
  document : Document
}

///|
pub fn open_encrypted_single(data : Bytes) -> EncryptedSingle raise {
  let header = parse_header(data)
  if header.flags != 1 {
    raise BadFormat("document is not encrypted")
  }
  let reader = Reader::new(data)
  reader.skip(header.manifest_offset)
  let stored = reader.take(header.manifest_length)
  let decoded = decode_encoded(
    stored,
    if header.manifest_encoding == 1 {
      "deflate-raw"
    } else {
      "identity"
    },
    268435456,
  )
  let text = @utf8.decode(decoded) catch {
    _ => raise BadFormat("invalid UTF-8 manifest")
  }
  let metadata = parse_encrypted_manifest(text)
  let start = header.manifest_offset + header.manifest_length
  for part in metadata.outer.parts {
    if part.offset > data.length() - start ||
      part.length > data.length() - start - part.offset {
      raise BadFormat("part outside BDF file")
    }
  }
  { metadata, document: { manifest: metadata.outer, header, data, }, }
}

///|
/// Return the stored, still-encrypted bytes of a declared single-file part.
pub fn EncryptedSingle::stored_part(
  self : EncryptedSingle,
  hash : String,
) -> Bytes raise {
  for part in self.metadata.outer.parts {
    if part.hash == hash {
      let reader = Reader::new(self.document.data)
      reader.skip(
        self.document.header.manifest_offset +
        self.document.header.manifest_length +
        part.offset,
      )
      return reader.take(part.length)
    }
  }
  raise BadFormat("unknown part")
}

///|
/// Validate the decrypted inner manifest and map each plaintext hash to its
/// declared ciphertext hash. Nested encryption is rejected.
pub fn sealed_references(
  input : String,
  outer : Manifest,
) -> Map[String, String] raise {
  let inner = parse_manifest(input)
  let root = @json.parse(input) catch {
    _ => raise BadFormat("invalid manifest JSON")
  }
  let refs : Map[String, String] = Map([])
  for entry in required_array(root, "parts") {
    let hash = required_string(entry, "h")
    let sealed_hash = required_string(entry, "sealed")
    if !valid_hash(sealed_hash) {
      raise BadFormat("invalid sealed part hash")
    }
    let mut found = false
    for part in outer.parts {
      if part.hash == sealed_hash {
        found = true
      }
    }
    if !found {
      raise BadFormat("sealed part missing")
    }
    refs[hash] = sealed_hash
  }
  if refs.length() != inner.parts.length() {
    raise BadFormat("invalid sealed references")
  }
  refs
}
