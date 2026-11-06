///|
fn schema_field(name : String, kind : String, in_sections : Array[String]) -> @tag.Field {
  {
    name,
    kind,
    in_sections,
    format: "",
    mode: "",
    slots: 0,
    inverted: false,
    code: "",
    input: "",
    at: [],
    value_type: "",
    options: [],
    labels: [],
    label: "",
    default: Json::null(),
    max_len: 0,
    multiline: false,
  }
}

///|
fn j_obj(value : Json) -> Map[String, Json] {
  match value {
    Json::Object(object) => object
    _ => Map([])
  }
}

///|
fn j_str(value : Json) -> String {
  match value {
    Json::String(text) => text
    _ => ""
  }
}

///|
fn schema_props(value : Json) -> Map[String, Json] {
  match value {
    Json::Object(object) =>
      match object.get("properties") {
        Some(Json::Object(properties)) => properties
        _ => Map([])
      }
    _ => Map([])
  }
}

///|
fn schema_info_json(value : Json) -> Map[String, Json] {
  match value {
    Json::Object(object) =>
      match object.get("x-bdf") {
        Some(Json::Object(info)) => info
        _ => Map([])
      }
    _ => Map([])
  }
}

///|
test "form schema writes properties in template order" {
  let fields : Array[@tag.Field] = [
    { ..schema_field("items", @tag.FIELD_SECTION, []), mode: @tag.MODE_ROWS },
    schema_field("name", @tag.FIELD_VALUE, ["items"]),
    { ..schema_field("paid", @tag.FIELD_SECTION, []), inverted: true },
    schema_field("photo", @tag.FIELD_IMAGE, []),
    { ..schema_field("url", @tag.FIELD_IMAGE, []), code: "qr" },
    { ..schema_field("total", @tag.FIELD_VALUE, []), format: "#,##0" },
    { ..schema_field("date", @tag.FIELD_VALUE, []), format: "yyyy-mm-dd" },
  ]
  let sample = Json::object({
    "items": Json::array([Json::object({ "name": Json::string("a") })]),
    "paid": Json::boolean(true),
    "photo": Json::string("photo.png"),
  })
  let result = schema(fields, Some(sample))
  let props = schema_props(result)
  let items = props["items"]
  assert_eq(j_obj(items)["type"], Json::string("array"))
  let item_props = schema_props(j_obj(items)["items"])
  assert_eq(j_obj(item_props["name"])["type"], Json::string("string"))
  assert_eq(schema_info_json(items)["kind"], Json::string(@tag.FIELD_SECTION))
  assert_eq(schema_info_json(items)["mode"], Json::string(@tag.MODE_ROWS))
  let paid = props["paid"]
  assert_eq(j_obj(paid)["type"], Json::string("boolean"))
  assert_true(
    j_str(j_obj(paid)["description"]).contains("false"),
    msg="an inverted condition",
  )
  assert_eq(schema_info_json(paid)["inverted"], Json::boolean(true))
  let photo = props["photo"]
  assert_eq(j_obj(photo)["type"], Json::string("string"))
  assert_eq(j_obj(photo)["format"], Json::string("uri-reference"))
  assert_eq(schema_info_json(photo)["kind"], Json::string(@tag.FIELD_IMAGE))
  let url = props["url"]
  assert_eq(schema_info_json(url)["code"], Json::string("qr"))
  assert_true(
    j_str(j_obj(url)["description"]).contains("QR code"),
    msg="a QR code",
  )
  assert_eq(j_obj(props["total"])["type"], Json::string("number"))
  assert_eq(j_obj(props["date"])["type"], Json::string("string"))
  assert_eq(j_obj(props["date"])["format"], Json::string("date"))
  assert_eq(schema_info_json(props["date"])["format"], Json::string("yyyy-mm-dd"))
  assert_eq(schema_info_json(props["date"])["kind"], Json::string(@tag.FIELD_VALUE))
}

///|
test "form schema reads sample lists and scalar items" {
  let fields : Array[@tag.Field] = [
    { ..schema_field("tags", @tag.FIELD_SECTION, []), mode: @tag.MODE_SLOTS, slots: 3 },
    schema_field(".", @tag.FIELD_VALUE, ["tags"]),
    schema_field("n", @tag.FIELD_VALUE, []),
    schema_field("label", @tag.FIELD_VALUE, []),
  ]
  let sample = Json::object({
    "tags": Json::array([Json::string("a"), Json::string("b")]),
    "n": Json::number(2.0),
    "label": Json::string("Name"),
  })
  let props = schema_props(schema(fields, Some(sample)))
  let tags = props["tags"]
  assert_eq(j_obj(tags)["type"], Json::string("array"))
  assert_eq(j_obj(j_obj(tags)["items"])["type"], Json::string("string"))
  assert_eq(j_obj(tags)["maxItems"], Json::number(3.0))
  assert_eq(schema_info_json(tags)["slots"], Json::number(3.0))
  assert_eq(j_obj(props["n"])["type"], Json::string("number"))
  assert_eq(j_obj(props["label"])["type"], Json::string("string"))
  assert_false(schema_props(schema(fields, None)).is_empty(), msg="without a sample")
}

///|
test "form schema number formats" {
  let cases : Array[(String, String)] = [
    ("#,##0", "number"),
    ("0.00", "number"),
    ("yyyy-mm-dd", "date"),
    ("yyyy-mm-dd hh:mm", "date-time"),
    ("hh:mm", ""),
    ("@", ""),
    ("General", ""),
    ("\"kg\" #,##0", "number"),
    ("[$-409]mmmm d, yyyy", "date"),
  ]
  for entry in cases {
    let fields = [
      { ..schema_field("v", @tag.FIELD_VALUE, []), format: entry.0 },
    ]
    let props = schema_props(schema(fields, None))
    let expected = if entry.1 == "" {
      Json::array([Json::string("string"), Json::string("number")])
    } else if entry.1 == "date" || entry.1 == "date-time" {
      Json::string("string")
    } else {
      Json::string(entry.1)
    }
    assert_eq(j_obj(props["v"])["type"], expected, msg=entry.0)
  }
}
