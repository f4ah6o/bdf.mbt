///|
test "textform fills from data sources" {
  let source : @data.Source = {
    name: "",
    file_name: "data.json",
    data: @utf8.encode("{\"name\":\"Alice\"}"),
  }
  let result = fill_sources("Hello {{name}}", [source])
  assert_eq(result.image.pages[0].lines[0].text, "Hello Alice")
}

///|
test "textform fills from YAML data" {
  let source : @data.Source = {
    name: "",
    file_name: "data.yaml",
    data: @utf8.encode("name: Alice\nitems:\n  - one\n  - two\n"),
  }
  let result = fill_sources("Hello {{name}} {{items}}", [source])
  assert_true(result.image.pages[0].lines[0].text.contains("Alice"))
}

