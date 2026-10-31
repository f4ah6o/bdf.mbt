///|
test "SHA-256 known vectors and padding boundaries" {
  assert_eq(
    sha256(b""),
    "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
  )
  assert_eq(
    sha256(b"abc"),
    "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
  )
  assert_eq(
    sha256(Bytes::make(55, b'a')),
    "9f4390f8d30c2dd92ec9f095b65e2b9ae9b0a925a5258e241c9f1e910f734318",
  )
  assert_eq(
    sha256(Bytes::make(56, b'a')),
    "b35439a4ac6f0948b6d6f9e3c6af0f5f590ce20f1bde7090ef7970686ec6738a",
  )
  assert_eq(
    sha256(Bytes::make(63, b'a')),
    "7d3e74a05d7db15bce4ad9ec0658ea98e3f06eeecf16b4c6fff2da457ddc2f34",
  )
  assert_eq(
    sha256(Bytes::make(64, b'a')),
    "ffe054fe7ae0cb6dc65c3af9b61d5209f439851db43d0ba5997337df154668eb",
  )
  assert_eq(
    sha256(Bytes::make(65, b'a')),
    "635361c48bb9eab14198e76ea8ab7f1a41685d6ad62aa9146d301d4f17eb0ae0",
  )
  assert_eq(
    sha256(Bytes::make(1000, b'a')),
    "41edece42d63e8d9bf515a9ba6932e1c20cbc9f5a5d134645adb5db1b9737ea3",
  )
}

///|
test "single-file writer stores and deduplicates parts" {
  let writer = DocumentWriter::new(
    meta=Json::object({ "source": Json::string("test") }),
  )
  let first = writer.add_part("img", b"abc")
  assert_eq(first, "ba7816bf8f01cfea414140de5dae2223")
  assert_eq(writer.add_part("obj", b"abc"), first)
  let large = Bytes::make(1000, b'a')
  let second = writer.add_part("obj", large)
  let image = writer.add_part("img", large)
  assert_eq(image, second)
  let bitmap = Bytes::from_array(
    [b'B', b'M', ..Bytes::make(1000, 0).to_array()],
  )
  let third = writer.add_part("img", bitmap)
  let file = writer.write_single()
  let doc = open_single(file)
  assert_eq(doc.manifest.parts.length(), 3)
  assert_eq(doc.manifest.parts[0].kind, "img")
  assert_eq(doc.manifest.parts[0].encoding, "identity")
  assert_eq(doc.manifest.parts[1].encoding, "deflate-raw")
  assert_eq(doc.manifest.parts[2].encoding, "deflate-raw")
  assert_eq(doc.part(first), b"abc")
  assert_eq(doc.part(second), large)
  assert_eq(doc.part(third), bitmap)
}

///|
test "single-file writer compresses large manifests" {
  let writer = DocumentWriter::new()
  for i in 0..<30 {
    writer.add_view(
      Json::object({
        "id": Json::string("view\{i}"),
        "kind": Json::string("fixed"),
      }),
    )
  }
  let doc = open_single(writer.write_single())
  assert_eq(doc.header.manifest_encoding, 1)
  assert_eq(doc.manifest.views.length(), 30)
  assert_eq(doc.manifest.views[29].id, "view29")
}

///|
test "writer sets the upstream default generator without mutating metadata" {
  let fields : Map[String, Json] = { "source": Json::string("test") }
  let writer = DocumentWriter::new(meta=Json::object(fields))
  let split = writer.write_split()
  let parsed = @json.parse(@utf8.decode_lossy(split.manifest))
  assert_eq(required_string(field(parsed, "meta"), "generator"), "bdf-go/0.1")
  assert_false(fields.contains("generator"))
  let custom = DocumentWriter::new(
    meta=Json::object({ "generator": Json::string("custom/2") }),
  )
  let manifest = @json.parse(@utf8.decode_lossy(custom.write_split().manifest))
  assert_eq(required_string(field(manifest, "meta"), "generator"), "custom/2")
}

///|
test "writer preserves already compressed media but compresses plain image and font data" {
  let writer = DocumentWriter::new()
  let png = Bytes::from_array(
    [0x89, b'P', b'N', b'G', ..Bytes::make(1000, 0).to_array()],
  )
  let svg = Bytes::from_array(
    [0xef, 0xbb, 0xbf, b' ', b'<', ..Bytes::make(1000, b'a').to_array()],
  )
  let font = Bytes::from_array(
    [b'w', b'O', b'F', b'2', ..Bytes::make(1000, 0).to_array()],
  )
  let audio = Bytes::make(1001, 0)
  let hashes = [
    writer.add_part("img", png),
    writer.add_part("img", svg),
    writer.add_part("font", font),
    writer.add_part("audio", audio),
  ]
  let doc = open_single(writer.write_single())
  for i, encoding in ["identity", "deflate-raw", "identity", "identity"] {
    assert_eq(doc.manifest.parts[i].encoding, encoding)
  }
  assert_eq(doc.part(hashes[0]), png)
  assert_eq(doc.part(hashes[1]), svg)
  assert_eq(doc.part(hashes[2]), font)
  assert_eq(doc.part(hashes[3]), audio)
}

///|
test "empty table collection is omitted" {
  let writer = DocumentWriter::new()
  let split = writer.write_split()
  let json = @utf8.decode(split.manifest)
  assert_true(json.contains("\"views\":[]"))
  assert_false(json.contains("\"tables\""))
  assert_true(json.contains("\"parts\":[]"))
}
