///|
fn fill_text(data : Map[String, Json], template : String) -> String raise {
  let image = fill_image(data, template)
  image.text({ margins: false, no_paper: false, crlf: false })
}

///|
test "textform fills values" {
  let data : Map[String, Json] = { "name": Json::string("Alice") }
  assert_eq(fill_text(data, "Hello {{name}}!"), "Hello Alice!\n")
  let image = fill_image(data, "Hello {{name}}!")
  assert_eq(image.pages.length(), 1)
  assert_eq(image.pages[0].lines[0].text, "Hello Alice!")
  assert_eq(fill_text(data, "{{missing}}"), "\n")
}

///|
test "textform fills sections of rows" {
  let data : Map[String, Json] = {
    "items": Json::array([
      Json::object({ "name": Json::string("a"), "qty": Json::number(2.0) }),
      Json::object({ "name": Json::string("b"), "qty": Json::number(3.0) }),
    ]),
  }
  let template = "{{#items | rows}}\n{{name}} {{qty}}\n{{/items}}\n"
  assert_eq(fill_text(data, template), "a 2\nb 3\n")
  let image = fill_image(data, template)
  assert_eq(image.pages.length(), 1)
  assert_eq(image.pages[0].lines.length(), 2)
}

///|
test "textform fills slots" {
  let data : Map[String, Json] = {
    "items": Json::array([
      Json::object({ "name": Json::string("a"), "qty": Json::number(2.0) }),
      Json::object({ "name": Json::string("b"), "qty": Json::number(3.0) }),
    ]),
  }
  let template = "{{#items}}\nname: {{name}}\nqty: {{qty}}\n{{/items}}\n"
  assert_eq(fill_text(data, template), "name: a\nqty: 3\n")
  let too_many = {
    "items": Json::array([
      Json::object({ "name": Json::string("a"), "qty": Json::number(1.0) }),
      Json::object({ "name": Json::string("b"), "qty": Json::number(2.0) }),
      Json::object({ "name": Json::string("c"), "qty": Json::number(3.0) }),
    ]),
  }
  let refused = try {
    ignore(fill_image(too_many, template))
    false
  } catch {
    TextFormError(message) => message.contains("slots")
  }
  assert_true(refused, msg="more items than slots")
}

///|
test "textform fills columns" {
  let data : Map[String, Json] = { "v": Json::string("ab") }
  assert_eq(fill_text(data, "[{{v | width:5}}]"), "[ab   ]\n")
  assert_eq(fill_text(data, "[{{v | right:5}}]"), "[   ab]\n")
  assert_eq(fill_text(data, "[{{v | center:6}}]"), "[  ab  ]\n")
  let long : Map[String, Json] = { "v": Json::string("abcd") }
  assert_eq(fill_text(long, "[{{v | width:2 | cut}}]"), "[ab]\n")
  assert_eq(fill_text(long, "[{{v | width:2 | wrap}}]"), "[ab]\n cd\n")
}

///|
test "textform paginates growing forms" {
  let data : Map[String, Json] = {
    "items": Json::array([
      Json::object({ "v": Json::string("1") }),
      Json::object({ "v": Json::string("2") }),
      Json::object({ "v": Json::string("3") }),
    ]),
  }
  let template = "---\nlines: 2\n---\n{{#items | rows}}\n{{v}}\n{{/items}}\n"
  let image = fill_image(data, template)
  assert_eq(image.pages.length(), 2)
  assert_eq(image.pages[0].lines.length(), 2)
  assert_eq(image.pages[1].lines.length(), 1)
}
