///|
fn fake_sealed(nonce : Byte, length : Int32) -> Bytes {
  let bytes = Bytes::make(length + 28, 0).to_array()
  bytes[0] = nonce
  Bytes::from_array(bytes)
}

///|
test "sealing plan builds an encrypted manifest and validates its references" {
  let writer = DocumentWriter::new()
  let one = writer.add_part("obj", b"first")
  let two = writer.add_part("img", b"second")
  let plan = prepare_sealing(writer.write_single())
  let parts = plan.parts()
  let sealed = [fake_sealed(1, parts[0].data.length()), fake_sealed(2, parts[1].data.length())]
  let inner = plan.inner_manifest(sealed)
  let slot = Json::object({
    "type": Json::string("password"), "kdf": Json::string("PBKDF2-SHA256"),
    "iter": Json::number(1000.0), "salt": Json::string("AA=="), "key": Json::string("AA=="),
  })
  let result = plan.finish(sealed, inner, fake_sealed(3, inner.data.length()), [slot])
  assert_eq(result.parts.length(), 3)
  let outer = parse_encrypted_manifest(@utf8.decode_lossy(result.manifest))
  assert_eq(outer.manifest_hash, result.parts[0].hash)
  let plain = decode_encoded(inner.data, inner.encoding, 268435456)
  let references = sealed_references(@utf8.decode_lossy(plain), outer.outer)
  assert_eq(references[one], result.parts[1].hash)
  assert_eq(references[two], result.parts[2].hash)
}

///|
test "sealing rejects nonce reuse, bad sizes and inconsistent manifests" {
  let writer = DocumentWriter::new()
  ignore(writer.add_part("obj", b"one"))
  ignore(writer.add_part("obj", b"two"))
  let plan = prepare_sealing(writer.write_single())
  let parts = plan.parts()
  let first = fake_sealed(1, parts[0].data.length())
  let second = fake_sealed(2, parts[1].data.length())
  let repeated = fake_sealed(1, parts[1].data.length())
  let rejected = try { ignore(plan.inner_manifest([first, repeated])); false } catch { _ => true }
  assert_true(rejected)
  let rejected = try { ignore(plan.inner_manifest([first])); false } catch { _ => true }
  assert_true(rejected)
  let rejected = try { ignore(plan.inner_manifest([first, b"short"])); false } catch { _ => true }
  assert_true(rejected)
  let inner = plan.inner_manifest([first, second])
  let slot = Json::object({ "type": Json::string("password"), "kdf": Json::string("PBKDF2-SHA256"), "iter": Json::number(1.0), "salt": Json::string("AA=="), "key": Json::string("AA==") })
  let rejected = try { ignore(plan.finish([first, second], inner, fake_sealed(1, inner.data.length()), [slot])); false } catch { _ => true }
  assert_true(rejected)
  let wrong : SealingManifest = { data: b"wrong", encoding: "identity" }
  let rejected = try { ignore(plan.finish([first, second], wrong, fake_sealed(3, 5), [slot])); false } catch { _ => true }
  assert_true(rejected)
}
