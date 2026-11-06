///|
test "requested attributes and filter" {
  let request = new_request(OP_GET_PRINTER_ATTRIBUTES, 4, "", "")
  request.add(TAG_OPERATION, [
    attr("requested-attributes", [keyword("copies"), keyword("printer-name")]),
  ])
  let message = decode(request.encode())
  let operation = match message.group(TAG_OPERATION) {
    Some(group) => group
    None => {
      fail("missing operation group")
      { tag: TAG_OPERATION, attrs: [] }
    }
  }
  assert_eq(requested(operation, ["all"]), ["copies", "printer-name"])
  let attrs = [
    attr("copies", [integer(1)]),
    attr("printer-name", [name("office")]),
    attr("sides", [keyword("one-sided")]),
  ]
  let filtered = filter(attrs, ["copies"], Map([]))
  assert_eq(filtered.length(), 1)
  assert_eq(filtered[0].name, "copies")
  let groups : Map[String, Array[String]] = Map([])
  groups["job-template"] = ["copies", "sides"]
  let by_group = filter(attrs, ["job-template"], groups)
  assert_eq(by_group.length(), 2)
  assert_eq(filter(attrs, ["all"], Map([])).length(), 3)
}

///|
test "printer groups and value helpers" {
  let attrs = [
    attr("copies-default", [integer(1)]),
    attr("copies-supported", [range(1, 99)]),
    attr("media-col-default", [collection([])]),
    attr("printer-name", [name("office")]),
    attr("printer-state", [enum_value(3)]),
  ]
  let groups = printer_groups(attrs)
  assert_eq(groups["job-template"].length(), 3)
  assert_eq(groups["printer-description"].length(), 2)
  assert_eq(keywords(["one-sided", "two-sided"]).length(), 2)
  assert_eq(keywords(["one-sided"])[0].tag, TAG_KEYWORD)
  assert_eq(mime_types(["application/pdf"])[0].tag, TAG_MIME_TYPE)
  assert_eq(enums([3, 4])[1].int, 4)
}
