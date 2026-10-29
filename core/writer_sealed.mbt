///|
/// An unencrypted document prepared for independent part sealing.
/// The host must use one AES-256-GCM content key and a fresh 12-byte nonce
/// for every part. Associated data is the part's 16-byte decoded hash.
pub struct SealingPlan {
  manifest : Bytes
  parts : Array[SplitPart]
}

///|
/// The compressed or uncompressed manifest to seal with associated data
/// equal to the UTF-8 bytes of `manifest`.
pub(all) struct SealingManifest {
  data : Bytes
  encoding : String
}

///|
/// Prepare an unencrypted single-file BDF for encryption. Stored parts are
/// checked and retained as-is, so their compression does not change.
pub fn prepare_sealing(data : Bytes) -> SealingPlan raise {
  let split = single_to_split(data)
  let (_, _, encrypted) = writer_manifest(split.manifest)
  if encrypted { raise BadFormat("document is already encrypted") }
  { manifest: split.manifest, parts: split.parts, }
}

///|
/// Return the stored plaintext parts to seal, in manifest order.
pub fn SealingPlan::parts(self : SealingPlan) -> Array[SplitPart] {
  [ for part in self.parts => part ]
}

///|
fn sealing_nonce(data : Bytes) -> String {
  let hex = "0123456789abcdef"
  let out = StringBuilder()
  for i in 0..<12 {
    out.write_char(hex.get_char((data[i].to_int() >> 4)).unwrap())
    out.write_char(hex.get_char(data[i].to_int() & 15).unwrap())
  }
  out.to_string()
}

///|
fn sealing_check_parts(plan : SealingPlan, sealed : Array[Bytes]) -> Unit raise {
  if sealed.length() != plan.parts.length() {
    raise BadFormat("sealed part count mismatch")
  }
  let nonces : Map[String, Bool] = Map([])
  for i, data in sealed {
    let length = plan.parts[i].data.length()
    if length > 2147483547 || data.length() != length + 28 {
      raise BadFormat("invalid sealed part length")
    }
    let nonce = sealing_nonce(data)
    if nonces.contains(nonce) { raise BadFormat("reused sealing nonce") }
    nonces[nonce] = true
  }
}

///|
/// Build the inner manifest after the stored parts have been sealed. Each
/// item must contain a 12-byte nonce, ciphertext, and a 16-byte GCM tag.
pub fn SealingPlan::inner_manifest(
  self : SealingPlan,
  sealed : Array[Bytes],
) -> SealingManifest raise {
  sealing_check_parts(self, sealed)
  let (root, manifest, encrypted) = writer_manifest(self.manifest)
  if encrypted || manifest.parts.length() != self.parts.length() {
    raise BadFormat("invalid sealing plan")
  }
  let entries = required_array(root, "parts")
  for i, entry in entries {
    guard entry is Object(fields) else { raise BadFormat("expected part object") }
    writer_check_stored(manifest.parts[i], self.parts[i].data)
    fields["off"] = Json::number(0.0)
    fields["sealed"] = Json::string(sha256(sealed[i]).unsafe_substring(start=0, end=32))
  }
  let plain = @utf8.encode(root.stringify())
  if plain.length() > 268435456 { raise BadFormat("manifest exceeds 256 MiB") }
  let compressed = @deflate.compress(plain)
  if compressed.length() < plain.length() {
    { data: compressed, encoding: "deflate-raw", }
  } else {
    { data: plain, encoding: "identity", }
  }
}

///|
/// Assemble a split encrypted document after sealing the inner manifest.
/// `keys` contains the BDF key-slot objects created by the crypto host.
pub fn SealingPlan::finish(
  self : SealingPlan,
  sealed : Array[Bytes],
  inner : SealingManifest,
  sealed_manifest : Bytes,
  keys : Array[Json],
) -> SplitOutput raise {
  let expected = self.inner_manifest(sealed)
  if expected.data != inner.data || expected.encoding != inner.encoding {
    raise BadFormat("sealing manifest does not match parts")
  }
  if inner.data.length() > 2147483547 ||
    sealed_manifest.length() != inner.data.length() + 28 {
    raise BadFormat("invalid sealed manifest length")
  }
  if keys.length() == 0 { raise BadFormat("encrypted document needs a key") }
  let nonce = sealing_nonce(sealed_manifest)
  for part in sealed {
    if sealing_nonce(part) == nonce { raise BadFormat("reused sealing nonce") }
  }
  let stored : Array[SplitPart] = []
  for data in [sealed_manifest, ..sealed] {
    stored.push({ hash: sha256(data).unsafe_substring(start=0, end=32), data, })
  }
  let entries = stored.map(part => Json::object({
    "h": Json::string(part.hash), "t": Json::string("sealed"),
    "enc": Json::string("identity"), "len": Json::number(part.data.length().to_double()),
    "size": Json::number(part.data.length().to_double()), "off": Json::number(0.0),
  }))
  let manifest = Json::object({
    "bdf": Json::number(1.0),
    "encryption": Json::object({
      "cipher": Json::string("A256GCM"),
      "keys": Json::array(keys),
      "manifest": Json::object({ "part": Json::string(stored[0].hash), "enc": Json::string(inner.encoding) }),
    }),
    "parts": Json::array(entries),
  })
  let bytes = @utf8.encode(manifest.stringify())
  if bytes.length() > 268435456 { raise BadFormat("manifest exceeds 256 MiB") }
  ignore(parse_encrypted_manifest(@utf8.decode_lossy(bytes)))
  { manifest: bytes, parts: stored, }
}
