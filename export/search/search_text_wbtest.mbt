///|
test "search text groups pages and keeps metadata" {
  let writer = @core.DocumentWriter::new(
    meta=Json::object({
      "dc": Json::object({ "title": Json::string("Demo document") }),
    }),
  )
  let builder = @core.ObjectBuilder::new()
  let font = builder.add_font({
    hash: None,
    family: "Example",
    weight: 400,
    style: 0,
  })
  builder.font(font, 12.0F)
  builder.fill_text("Hello world", 10.0F, 20.0F, 30.0F)
  let object_hash = writer.add_part("obj", builder.encode())
  writer.add_view(
    Json::object({
      "id": Json::string("page1"),
      "kind": Json::string("fixed"),
      "pages": Json::array([
        Json::object({
          "w": Json::number(200.0),
          "h": Json::number(200.0),
          "layers": Json::array([
            Json::object({
              "role": Json::string(""),
              "obj": Json::string(object_hash),
            }),
          ]),
        }),
      ]),
    }),
  )
  let result = search_text_bytes(writer.write_single())
  assert_eq(result.views, 1)
  assert_eq(result.pages, 1)
  assert_true(result.json.contains("\"views\""))
  assert_true(result.json.contains("Demo document"))
  assert_true(result.plain.contains("Hello world"))
  let parsed = @json.parse(result.json)
  assert_eq(parsed.value("views").unwrap().as_array().unwrap().length(), 1)
}

///|
test "search text rejects an invalid manifest" {
  let rejected = try {
    ignore(search_text_bytes(b"not a bdf"))
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
}
