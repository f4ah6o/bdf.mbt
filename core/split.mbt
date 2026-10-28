///|
/// A split document loads stored part bytes on demand through its host.
/// The loader receives a validated hash and the maximum stored byte count.
pub struct SplitDocument {
  pub manifest : Manifest
  priv load : (String, Int32) -> Bytes raise
}

///|
/// Open an unencrypted split document from manifest.json and a part loader.
/// The loader is invoked only when a caller requests a declared part. It should
/// enforce the supplied stored byte limit before allocating or downloading.
pub fn open_split(
  manifest_data : Bytes,
  load : (String, Int32) -> Bytes raise,
) -> SplitDocument raise {
  if manifest_data.length() > 268435456 {
    raise BadFormat("manifest exceeds 256 MiB")
  }
  let text = @utf8.decode(manifest_data) catch {
    _ => raise BadFormat("invalid UTF-8 manifest")
  }
  { manifest: parse_manifest(text), load, }
}

///|
fn SplitDocument::load_entry(self : SplitDocument, entry : Part) -> Bytes raise {
  if !valid_hash(entry.hash) || entry.length < 0 || entry.size < 0 {
    raise BadFormat("invalid split part entry")
  }
  let data = (self.load)(entry.hash, entry.length)
  if data.length() != entry.length {
    raise BadFormat("stored part size does not match manifest")
  }
  data
}

///|
/// Load the stored bytes for a declared part, checking its exact stored size.
pub fn SplitDocument::stored_part(
  self : SplitDocument,
  hash : String,
) -> Bytes raise {
  for entry in self.manifest.parts {
    if entry.hash == hash {
      return self.load_entry(entry)
    }
  }
  raise BadFormat("unknown part")
}

///|
/// Load and decode a declared part. Deflate output is bounded by its size.
pub fn SplitDocument::part(self : SplitDocument, hash : String) -> Bytes raise {
  for entry in self.manifest.parts {
    if entry.hash == hash {
      return decode_stored_part(entry, self.load_entry(entry))
    }
  }
  raise BadFormat("unknown part")
}

///|
fn decode_stored_part(entry : Part, stored : Bytes) -> Bytes raise {
  if entry.encoding == "identity" {
    stored
  } else if entry.encoding == "deflate-raw" {
    inflate_bounded(stored, entry.size)
  } else {
    raise BadFormat("unknown part encoding")
  }
}
