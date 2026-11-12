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

///|
fn fontless_pdf_document(text : String) -> Bytes raise {
  let writer = @core.DocumentWriter::new()
  let builder = @core.ObjectBuilder::new()
  builder.fill_text(text, 20.0F, 40.0F, 60.0F)
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
/// The text of a run that the document gives no font of its own draws with
/// the PDF standard font, and a character beyond its codeset becomes a "?":
/// the writer warns about every such character instead of hiding the loss
/// behind a silent replacement. Text the standard font covers stays quiet.
test "pdf warns about the characters the standard font draws as ?" {
  let japanese = write_bytes(fontless_pdf_document("日本語"), PdfOptions::new())
  let mut warned = false
  for warning in japanese.warnings {
    if warning.starts_with(
        "text without a font of its own is drawn with the PDF standard font, which has no glyph for: 日本語",
      ) {
      warned = true
    }
  }
  assert_true(warned)
  // the "?" replaces the characters in the content stream
  assert_true(japanese.bytes.to_string().contains("(???"))
  // ASCII text the standard font covers draws without any warning
  let ascii = write_bytes(fontless_pdf_document("Hello PDF"), PdfOptions::new())
  assert_eq(ascii.warnings.length(), 0)
  // a fallback font (the writer embeds its subset) draws the same text
  // without any warning: the document is a real TrueType-less fixture, so
  // the subsetting path itself is covered by the site's form PDF tests
  let mixed = write_bytes(fontless_pdf_document("A B"), PdfOptions::new())
  assert_eq(mixed.warnings.length(), 0)
}

///|
/// The converters of forms write the source of a document at the top of its
/// metadata, the ones of documents under "dc": the writer reads both, so that
/// a filled text form is drawn on the cells of its grid.
test "pdf reads the source of a form from the top of the metadata" {
  let form = Json::object({
    "source": Json::string("text"),
    "ambiguousWide": Json::boolean(true),
  })
  assert_eq(meta_string(form, "source"), "text")
  assert_eq(meta_string(form, "ambiguousWide"), "")
  let document = Json::object({
    "dc": Json::object({ "title": Json::string("A document") }),
  })
  assert_eq(meta_string(document, "title"), "A document")
  assert_eq(meta_string(document, "source"), "")
  assert_eq(meta_string(Json::empty_object(), "source"), "")
}
