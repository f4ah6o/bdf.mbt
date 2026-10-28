///|
test "sheet manifest retains sorted tiles and the default tile size" {
  let manifest = @core.parse_manifest(
    "{\"bdf\":1,\"parts\":[],\"views\":[{\"id\":\"s\",\"kind\":\"sheet\",\"tile\":0,\"tiles\":{\"2,0\":\"11111111111111111111111111111111\",\"0,1\":\"22222222222222222222222222222222\",\"1,0\":\"33333333333333333333333333333333\"},\"tilesRef\":\"index\"}]}",
  )
  let view = manifest.views[0]
  assert_eq(view.tile_size, 2048.0)
  assert_eq(view.tiles.map(fn(t) { (t.x, t.y) }), [(1, 0), (2, 0), (0, 1)])
  assert_eq(view.tiles_ref, Some("index"))
}

///|
test "tile index rejects truncated, unordered and out-of-range records" {
  let valid = b"\x01\x00\x00\x00\x02\x00\x00\x00\x00\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0a\x0b\x0c\x0d\x0e\x0f"
  let decoded = @core.decode_tile_index(valid)
  assert_eq(decoded.length(), 1)
  assert_eq(
    (decoded[0].x, decoded[0].y, decoded[0].object),
    (1, 2, "000102030405060708090a0b0c0d0e0f"),
  )
  for
    invalid in [
      b"\x01",
      valid + valid,
      b"\xff\xff\xff\xff\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00",
    ] {
    let mut rejected = false
    ignore(@core.decode_tile_index(invalid)) catch {
      _ => rejected = true
    }
    assert_true(rejected)
  }
}

///|
test "sheet manifest rejects invalid tile data" {
  for
    suffix in [
      "\"tile\":0.5", "\"tile\":16777217", "\"tiles\":[]", "\"tiles\":{\"-1,0\":\"11111111111111111111111111111111\"}",
      "\"tiles\":{\"0,0\":\"invalid\"}",
    ] {
    let source = "{\"bdf\":1,\"parts\":[],\"views\":[{\"id\":\"s\",\"kind\":\"sheet\"," +
      suffix +
      "}]}"
    let mut rejected = false
    ignore(@core.parse_manifest(source)) catch {
      _ => rejected = true
    }
    assert_true(rejected)
  }
}
