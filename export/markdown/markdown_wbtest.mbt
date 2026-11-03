///|
fn sample_document() -> Bytes raise {
  let writer = @core.DocumentWriter::new(
    meta=Json::object({
      "dc": Json::object({
        "title": Json::string("Demo document"),
        "creator": Json::string("Example"),
      }),
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
  builder.mark(6, "1")
  builder.fill_text("Title", 10.0F, 20.0F, 30.0F)
  builder.mark(11, "")
  builder.mark(0, "")
  builder.fill_text("Body text", 10.0F, 40.0F, 60.0F)
  builder.mark(11, "")
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
  writer.write_single()
}

///|
test "markdown writes front matter, headings and paragraphs" {
  let result = write_bytes(sample_document(), MarkdownOptions::new())
  assert_true(result.markdown.has_prefix("---\n"))
  assert_true(result.markdown.contains("title: Demo document"))
  assert_true(result.markdown.contains("# Title"))
  assert_true(result.markdown.contains("Body text"))
}

///|
test "markdown omits metadata when absent" {
  let result = write_bytes(sample_document(), MarkdownOptions::new())
  assert_eq(result.views, 1)
  assert_eq(result.images, 0)
}

///|
test "markdown writes images as zip files or data urls" {
  let writer = @core.DocumentWriter::new()
  let object_builder = @core.ObjectBuilder::new()
  let font = object_builder.add_font({
    hash: None,
    family: "Example",
    weight: 400,
    style: 0,
  })
  object_builder.font(font, 12.0F)
  object_builder.fill_text("Picture", 10.0F, 20.0F, 30.0F)
  let png = b"\x89PNG\r\n\x1a\n"
  let image_hash = writer.add_part("img", png)
  let image = object_builder.add_image(image_hash)
  object_builder.image(image, 10.0F, 10.0F, 20.0F, 20.0F)
  let object_hash = writer.add_part("obj", object_builder.encode())
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
  let bytes = writer.write_single()
  let zip = write_bytes(bytes, MarkdownOptions::new())
  assert_eq(zip.images, 1)
  assert_eq(zip.files.length(), 1)
  assert_eq(zip.files[0].name, "images/image-1.png")
  assert_true(zip.markdown.contains("![image](images/image-1.png)"))
  let embed = write_bytes(bytes, { ..MarkdownOptions::new(), images: "embed", })
  assert_eq(embed.files.length(), 0)
  assert_true(embed.markdown.contains("data:image/png;base64,"))
}
