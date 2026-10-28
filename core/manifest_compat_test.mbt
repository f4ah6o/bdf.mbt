///|
test "manifests accept omitted views and null page layers" {
  let empty = @core.parse_manifest("{\"bdf\":1,\"parts\":[]}")
  assert_eq(empty.views.length(), 0)
  let nil_parts = @core.parse_manifest(
    "{\"bdf\":1,\"parts\":null,\"encryption\":null}",
  )
  assert_eq(nil_parts.parts.length(), 0)
  let doc = @core.parse_manifest(
    "{\"bdf\":1,\"parts\":[],\"views\":[{\"id\":\"pages\",\"kind\":\"fixed\",\"pages\":[{\"w\":1,\"h\":2,\"layers\":null}]}]}",
  )
  assert_eq(doc.views[0].pages[0].layers.length(), 0)
}

///|
test "manifest rejects malformed and out of range part integers" {
  for number in ["-0.1", "1.5", "2147483648", "1e100"] {
    let json = "{\"bdf\":1,\"parts\":[{\"h\":\"0123456789abcdef0123456789abcdef\",\"t\":\"obj\",\"len\":" +
      number +
      ",\"size\":0}]}"
    let rejected = try {
      ignore(@core.parse_manifest(json))
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
  }
}

///|
test "manifest rejects wrong collection and opset types" {
  for
    json in [
      "{\"bdf\":1,\"parts\":[],\"views\":{}}", "{\"bdf\":1,\"parts\":[],\"opset\":0.5}",
      "{\"bdf\":1,\"parts\":[],\"opset\":\"1\"}", "{\"bdf\":1,\"parts\":[],\"views\":[{\"id\":\"p\",\"kind\":\"fixed\",\"pages\":{}}]}",
    ] {
    let rejected = try {
      ignore(@core.parse_manifest(json))
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
  }
}
