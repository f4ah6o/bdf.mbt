///|
test "textform selects pages" {
  let data : Map[String, Json] = {
    "items": Json::array([
      Json::object({ "v": Json::string("1") }),
      Json::object({ "v": Json::string("2") }),
      Json::object({ "v": Json::string("3") }),
    ]),
  }
  let template = "---\nlines: 2\n---\n{{#items | rows}}\n{{v}}\n{{/items}}\n"
  let result = @textform.fill_result(data, template)
  assert_eq(result.image.pages.length(), 2)
  let bytes = render_with_tables(result.image, result.tables, "", pages="2")
  let document = @core.open_single(bytes)
  assert_eq(document.manifest.views[0].pages.length(), 1)
  let back = @textpart.from_document(bytes)
  assert_eq(back.pages.length(), 1)
  assert_eq(back.pages[0].lines[0].text, "3")
}
