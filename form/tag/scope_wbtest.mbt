///|
fn tag_scope_data() -> Json {
  Json::object({
    "name": Json::string("root"),
    "customer": Json::object({
      "name": Json::string("ACME"),
      "zip": Json::null(),
    }),
    "items": Json::array([
      Json::object({ "name": Json::string("a"), "qty": Json::number(2.0) }),
      Json::object({ "qty": Json::number(0.0) }),
    ]),
    "n": Json::number(3.0),
  })
}

///|
fn tag_lookup(scope : Scope, name : String) -> Json {
  let path = if name == "." {
    ["."]
  } else {
    name.split(".").map(fn(part) { part.to_owned() }).to_array()
  }
  match scope.lookup(path) {
    Some(value) => value
    None => Json::string("<none>")
  }
}

///|
test "form scopes look names up from the innermost item" {
  let root = Scope::new(tag_scope_data())
  let items = items(tag_lookup(root, "items"))
  let first = root.item(items[0], Map([("_index", Json::number(1.0)), ("_first", Json::boolean(true))]))
  let second = first.item(items[1], Map([("_index", Json::number(2.0))]))
  let blank = root.item(items[0], Map([("_page", Json::number(7.0))])).blank_scope(Map([("_blank", Json::boolean(true))]))
  let cases : Array[(Scope, String, Json)] = [
    (root, "name", Json::string("root")),
    (root, "customer.name", Json::string("ACME")),
    (root, "customer.zip", Json::null()),
    (root, "customer.none", Json::string("<none>")),
    (root, "name.x", Json::string("<none>")),
    (root, "none", Json::string("<none>")),
    (root, "n", Json::number(3.0)),
    (first, "name", Json::string("a")),
    (first, "qty", Json::number(2.0)),
    (first, "n", Json::number(3.0)),
    (first, "_index", Json::number(1.0)),
    (first, "_first", Json::boolean(true)),
    (second, "name", Json::string("a")),
    (second, "qty", Json::number(0.0)),
    (second, "_index", Json::number(2.0)),
    (second, "_first", Json::boolean(true)),
    (second, ".", items[1]),
    (blank, "name", Json::string("<none>")),
    (blank, "n", Json::string("<none>")),
    (blank, "_blank", Json::boolean(true)),
    (blank, "_page", Json::number(7.0)),
    (blank, ".", Json::string("<none>")),
  ]
  for entry in cases {
    assert_eq(tag_lookup(entry.0, entry.1), entry.2, msg=entry.1)
  }
}

///|
test "form truthy and items follow JSON values" {
  let cases : Array[(Json, Bool)] = [
    (Json::null(), false),
    (Json::boolean(false), false),
    (Json::boolean(true), true),
    (Json::number(0.0), false),
    (Json::number(0.5), true),
    (Json::string(""), false),
    (Json::string("x"), true),
  ]
  for entry in cases {
    assert_eq(truthy(entry.0), entry.1)
  }
  assert_false(truthy(Json::array([])), msg="an empty list is false")
  assert_true(truthy(Json::array([Json::null()])), msg="a list is true")
  assert_true(truthy(Json::object({})), msg="an object is true")
  assert_eq(items(Json::null()).length(), 0)
  assert_eq(items(Json::boolean(false)).length(), 0)
  assert_eq(items(Json::array([Json::number(1.0), Json::number(2.0)])).length(), 2)
  assert_eq(items(Json::object({})).length(), 1)
  assert_eq(items(Json::string("x")).length(), 1)
}

///|
test "form dates keep the clock on the wall" {
  let cases : Array[(String, String)] = [
    ("2026-10-13", "2026-10-13T00:00:00Z"),
    ("2026/1/2", "2026-01-02T00:00:00Z"),
    ("2026-10-13T09:30:00", "2026-10-13T09:30:00Z"),
    ("2026-10-13T09:30:00+09:00", "2026-10-13T09:30:00Z"),
    ("2026-10-13 09:30", "2026-10-13T09:30:00Z"),
  ]
  for entry in cases {
    assert_eq(parse_date(entry.0), Some(entry.1), msg=entry.0)
  }
  for value in ["20261013", "October 13", "2026-13-40", "12345"] {
    assert_eq(parse_date(value), None, msg=value)
  }
}
