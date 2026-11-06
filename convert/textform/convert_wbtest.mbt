///|
test "textform convert fills and renders" {
  let data : Map[String, Json] = { "name": Json::string("Alice") }
  let result = convert("Hello {{name}}", data, "Greeting")
  let document = @core.open_single(result.bdf)
  assert_eq(document.manifest.views[0].title, "Greeting")
  let back = @textpart.from_document(result.bdf)
  assert_eq(back.pages[0].lines[0].text, "Hello Alice")
  let source : @data.Source = {
    name: "",
    file_name: "data.json",
    data: b"{\"name\":\"Bob\"}",
  }
  let from_sources = convert_sources("Hello {{name}}", [source], "")
  let back = @textpart.from_document(from_sources.bdf)
  assert_eq(back.pages[0].lines[0].text, "Hello Bob")
}
