///|
test "split output and stored-part round trips" {
  let writer = DocumentWriter::new(meta=Json::object({ "source": Json::string("test") }))
  let small = writer.add_part("img", b"small image")
  let large = writer.add_part("obj", Bytes::make(4096, b'x'))
  assert_eq(writer.add_part("other", b"small image"), small)
  writer.add_view(Json::object({ "id": Json::string("sheet"), "kind": Json::string("sheet") }))
  let direct = writer.write_split()
  let converted = single_to_split(writer.write_single())
  assert_eq(direct.manifest, converted.manifest)
  assert_eq(direct.parts.length(), 2)
  let stored : Map[String, Bytes] = Map([])
  for i, part in direct.parts {
    assert_eq(part.hash, converted.parts[i].hash)
    assert_eq(part.data, converted.parts[i].data)
    stored[part.hash] = part.data
  }
  let load : (String, Int32) -> Bytes raise = (hash, limit) => {
    let bytes = stored[hash]
    if bytes.length() > limit { raise BadFormat("stored part exceeds limit") }
    bytes
  }
  let split = open_split(direct.manifest, load)
  assert_eq(split.manifest.parts[0].offset, 0)
  assert_eq(split.manifest.parts[1].offset, 0)
  assert_eq(split.manifest.parts[1].encoding, "deflate-raw")
  assert_eq(split.part(small), b"small image")
  assert_eq(split.part(large), Bytes::make(4096, b'x'))
  let single = open_single(split_to_single(direct.manifest, load))
  assert_eq(single.manifest.views[0].id, "sheet")
  assert_eq(single.part(small), b"small image")
  assert_eq(single.part(large), Bytes::make(4096, b'x'))
  assert_eq(single.manifest.parts[1].offset, direct.parts[0].data.length())
}

///|
test "relocation rejects corrupted and missing stored parts" {
  let writer = DocumentWriter::new()
  let hash = writer.add_part("obj", b"content")
  let split = writer.write_split()
  let wrong_hash = try {
    ignore(split_to_single(split.manifest, (_, _) => b"changed"))
    false
  } catch { BadFormat(_) => true; _ => false }
  assert_true(wrong_hash)
  let wrong_size = try {
    ignore(split_to_single(split.manifest, (_, _) => b"short"))
    false
  } catch { BadFormat(_) => true; _ => false }
  assert_true(wrong_size)
  let single = writer.write_single()
  let opened = open_single(single)
  let bytes = single.to_array()
  bytes[opened.header.manifest_offset + opened.header.manifest_length] = b'X'
  let rejected = try {
    ignore(single_to_split(Bytes::from_array(bytes)))
    false
  } catch { BadFormat(_) => true; _ => false }
  assert_true(rejected)
  assert_eq(hash, split.parts[0].hash)
}
