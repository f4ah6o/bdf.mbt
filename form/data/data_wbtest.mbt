///|
fn json_source(name : String, file_name : String, text : String) -> Source {
  { name, file_name, data: @utf8.encode(text) }
}

///|
fn array_of(value : Json) -> Array[Json] {
  match value {
    Json::Array(values) => values
    _ => []
  }
}

///|
fn object_of(value : Json) -> Map[String, Json] {
  match value {
    Json::Object(object) => object
    _ => Map([])
  }
}

///|
fn data_error(sources : Array[Source]) -> String {
  try {
    ignore(load_data(sources))
    ""
  } catch {
    DataError(message) => message
  }
}

///|
test "form data reads and merges JSON" {
  let first = load_data([
    json_source("", "data.json", "{\"name\":\"ACME\",\"n\":3,\"customer\":{\"zip\":null}}"),
  ])
  assert_eq(first["name"], Json::string("ACME"))
  assert_eq(first["n"], Json::number(3.0))
  assert_eq(first["customer"], Json::object({ "zip": Json::null() }))
  let merged = load_data([
    json_source("", "a.json", "{\"name\":\"A\",\"keep\":1}"),
    json_source("", "b.json", "{\"name\":\"B\",\"extra\":true}"),
  ])
  assert_eq(merged["name"], Json::string("B"))
  assert_eq(merged["keep"], Json::number(1.0))
  assert_eq(merged["extra"], Json::boolean(true))
  let named = load_data([
    json_source("items", "items.json", "[{\"name\":\"a\"},{\"name\":\"b\"}]"),
    json_source("party.address", "address.json", "{\"city\":\"Tokyo\"}"),
  ])
  assert_eq(array_of(named["items"]).length(), 2)
  assert_eq(
    object_of(object_of(named["party"])["address"])["city"],
    Json::string("Tokyo"),
  )
}

///|
test "form data reads CSV as objects" {
  let csv = "name,qty,ok,empty,code\nA,2,true,,001\nB,,false,x,3.5\n"
  let data = load_data([json_source("", "lines.csv", csv)])
  let rows = array_of(data["lines"])
  assert_eq(rows.length(), 2)
  let first = object_of(rows[0])
  assert_eq(first["name"], Json::string("A"))
  assert_eq(first["qty"], Json::number(2.0))
  assert_eq(first["ok"], Json::boolean(true))
  assert_eq(first["empty"], Json::null())
  assert_eq(first["code"], Json::string("001"))
  let second = object_of(rows[1])
  assert_eq(second["qty"], Json::null())
  assert_eq(second["ok"], Json::boolean(false))
  assert_eq(second["code"], Json::number(3.5))
  let named = load_data([json_source("rows", "lines.csv", "a,b\n1,2\n")])
  assert_eq(array_of(named["rows"]).length(), 1)
  assert_eq(object_of(array_of(named["rows"])[0])["b"], Json::number(2.0))
}

///|
test "form data rejects bad sources" {
  assert_true(
    data_error([json_source("", "data.json", "[1,2]")]).contains("object"),
    msg="a list without a name",
  )
  assert_true(
    data_error([json_source("a..b", "data.json", "{}")]).contains("empty part"),
    msg="an empty name part",
  )
  assert_true(
    data_error([json_source("", "data.json", "{} {}")]).contains("data.json"),
    msg="more than one JSON value",
  )
  assert_true(
    data_error([json_source("", "lines.csv", "a,a\n1,2\n")]).contains("two columns"),
    msg="duplicate columns",
  )
  assert_true(
    data_error([json_source("", "data.yaml", "a: [")]).contains("YAML"),
    msg="broken YAML",
  )
  assert_true(
    data_error([json_source("", "data.xlsx", "x")]).contains("workbook"),
    msg="a workbook",
  )
  assert_true(
    data_error([json_source("", "data.bin", "x")]).contains("JSON"),
    msg="an unknown extension",
  )
  let numbers = load_data([json_source("rows", "n.csv", "v\n01\n1\n1.\n-0.5\n1e3\n")])
  let rows = array_of(numbers["rows"])
  assert_eq(object_of(rows[0])["v"], Json::string("01"))
  assert_eq(object_of(rows[1])["v"], Json::number(1.0))
  assert_eq(object_of(rows[2])["v"], Json::string("1."))
  assert_eq(object_of(rows[3])["v"], Json::number(-0.5))
  assert_eq(object_of(rows[4])["v"], Json::string("1e3"))
}
///|
test "form data reads YAML" {
  let yaml = "name: Alice\nitems:\n  - one\n  - two\nenabled: true\nn: 3\nnested:\n  city: Tokyo\n"
  let data = load_data([json_source("", "data.yaml", yaml)])
  assert_eq(data["name"], Json::string("Alice"))
  assert_eq(data["enabled"], Json::boolean(true))
  assert_eq(data["n"], Json::number(3.0))
  assert_eq(array_of(data["items"]).length(), 2)
  assert_eq(object_of(data["nested"])["city"], Json::string("Tokyo"))
  let named = load_data([json_source("rows", "rows.yml", "- name: a\n- name: b\n")])
  assert_eq(array_of(named["rows"]).length(), 2)
  let bad = data_error([json_source("", "bad.yaml", "name: [")])
  assert_true(bad != "")
}

