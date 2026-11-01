///|
test "select_pages keeps only the requested pages" {
  let writer = DocumentWriter::new()
  writer.add_view(
    Json::object({
      "id": Json::string("view"),
      "kind": Json::string("fixed"),
      "pages": Json::array([
        Json::object({
          "w": Json::number(100.0),
          "h": Json::number(200.0),
          "layers": Json::array([]),
        }),
        Json::object({
          "w": Json::number(300.0),
          "h": Json::number(400.0),
          "layers": Json::array([]),
        }),
      ]),
    }),
  )
  let selected = select_pages(writer.write_single(), [2L])
  let document = open_single(selected)
  assert_eq(document.manifest.views.length(), 1)
  assert_eq(document.manifest.views[0].pages.length(), 1)
  assert_eq(document.manifest.views[0].pages[0].width, 300.0)
}
