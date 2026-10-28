///|
test "parse encrypted metadata and validate sealed references" {
  let text = "{\"bdf\":1,\"encryption\":{\"cipher\":\"A256GCM\",\"keys\":[{\"type\":\"password\",\"kdf\":\"PBKDF2-SHA256\",\"iter\":1000,\"salt\":\"AA==\",\"key\":\"AA==\"}],\"manifest\":{\"part\":\"11111111111111111111111111111111\",\"enc\":\"identity\"}},\"parts\":[{\"h\":\"11111111111111111111111111111111\",\"t\":\"sealed\",\"len\":28,\"size\":28},{\"h\":\"22222222222222222222222222222222\",\"t\":\"sealed\",\"len\":30,\"size\":30}]}"
  let metadata = @core.parse_encrypted_manifest(text)
  assert_eq(metadata.manifest_hash, "11111111111111111111111111111111")
  guard metadata.keys[0] is Password("PBKDF2-SHA256", 1000, "AA==", "AA==") else {
    fail("password slot")
  }
  let inner = "{\"bdf\":1,\"parts\":[{\"h\":\"33333333333333333333333333333333\",\"t\":\"obj\",\"len\":2,\"size\":2,\"sealed\":\"22222222222222222222222222222222\"}]}"
  let refs = @core.sealed_references(inner, metadata.outer)
  assert_eq(
    refs.get("33333333333333333333333333333333"),
    Some("22222222222222222222222222222222"),
  )
  let missing = "{\"bdf\":1,\"parts\":[{\"h\":\"33333333333333333333333333333333\",\"t\":\"obj\",\"len\":2,\"size\":2,\"sealed\":\"44444444444444444444444444444444\"}]}"
  let rejected = try {
    ignore(@core.sealed_references(missing, metadata.outer))
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
}

///|
test "encrypted metadata rejects missing sealed manifest and unsupported cipher" {
  let missing = "{\"bdf\":1,\"encryption\":{\"cipher\":\"A256GCM\",\"keys\":[],\"manifest\":{\"part\":\"11111111111111111111111111111111\",\"enc\":\"identity\"}},\"parts\":[]}"
  let invalid_cipher = "{\"bdf\":1,\"encryption\":{\"cipher\":\"other\",\"keys\":[],\"manifest\":{\"part\":\"11111111111111111111111111111111\",\"enc\":\"identity\"}},\"parts\":[]}"
  for text in [missing, invalid_cipher] {
    let rejected = try {
      ignore(@core.parse_encrypted_manifest(text))
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
  }
}
