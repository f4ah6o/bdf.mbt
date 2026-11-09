///|
fn sample_pdf_document() -> Bytes raise {
  let writer = @core.DocumentWriter::new()
  let builder = @core.ObjectBuilder::new()
  let font = builder.add_font({
    hash: None,
    family: "Example",
    weight: 400,
    style: 0,
  })
  builder.font(font, 12.0F)
  builder.fill_text("Hello PDF", 20.0F, 40.0F, 60.0F)
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
test "pdf writes a readable one-page document" {
  let result = write_bytes(sample_pdf_document(), PdfOptions::new())
  assert_eq(result.pages, 1)
  assert_true(result.bytes.has_prefix(b"%PDF-1.7"))
  assert_true(result.bytes.to_string().contains("%%EOF"))
  assert_true(result.bytes.to_string().contains("1 0 0 -1 0 200 cm"))
  let parsed = @pdf.convert(result.bytes) catch {
    _ => {
      assert_true(false)
      return
    }
  }
  assert_eq(parsed.pages, 1)
}
