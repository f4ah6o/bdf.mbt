///|
// Regression tests of what a compiled template shows and of the fields that a
// fill reports, adapted from form/form_test.go of upstream: a template
// compiled without a sample shows its tags, and a fill reports the names that
// its tags look up.

///|
test "form compiles a workbook without a sample and keeps its tags" {
  let compiled = compile(form_test_small_xlsx(), "form", Options::new())
  assert_true(compiled.template.sample is None, msg="no sample")
  let text = form_test_text(compiled.bdf)
  assert_true(text.contains("{{no}}"), msg=text)
  assert_true(text.contains("{{customer.name}}"), msg=text)
}

///|
test "form compiles a Word document without a sample and keeps its tags" {
  let compiled = compile(
    form_test_docx(["{{no}}", "{{customer.name}}"]),
    "form",
    Options::new(),
  )
  assert_true(compiled.template.sample is None, msg="no sample")
  let text = form_test_text(compiled.bdf)
  assert_true(text.contains("{{no}}"), msg=text)
  assert_true(text.contains("{{customer.name}}"), msg=text)
}

///|
test "form compiles a text template without a sample and keeps its tags" {
  let compiled = compile(
    @utf8.encode("No: {{no}}\nName: {{customer.name}}\n"),
    "form",
    Options::new(),
  )
  assert_eq(compiled.template.format, FORMAT_TEXT)
  let text = form_test_text(compiled.bdf)
  assert_true(text.contains("{{no}}"), msg=text)
  assert_true(text.contains("{{customer.name}}"), msg=text)
}

///|
test "form compiles a template with a sample and shows the sample" {
  let compiled = compile(
    form_test_small_xlsx(),
    "form",
    Options::new(data=form_test_json("{\"no\":\"A-1\",\"customer\":{\"name\":\"ACME\"}}")),
  )
  let text = form_test_text(compiled.bdf)
  assert_true(text.contains("A-1"), msg=text)
  assert_true(text.contains("ACME"), msg=text)
  assert_true(!text.contains("{{"), msg=text)
}

///|
test "form fill returns the fields of the template" {
  let result = fill(
    form_test_small_xlsx(),
    Options::new(
      data=form_test_json("{\"no\":\"A-1\",\"customer\":{\"name\":\"ACME\"}}"),
    ),
  )
  let names = result.fields.map(fn(field) { field.name }).join(",")
  assert_true(names.contains("no"), msg=names)
  assert_true(names.contains("customer.name"), msg=names)
}

///|
test "form fill of a compiled template returns its fields" {
  let compiled = compile(form_test_small_xlsx(), "form", Options::new())
  let result = fill(
    compiled.bdf,
    Options::new(
      data=form_test_json("{\"no\":\"A-1\",\"customer\":{\"name\":\"ACME\"}}"),
    ),
  )
  assert_eq(result.fields.length(), compiled.template.fields.length())
  assert_eq(
    result.fields.map(fn(field) { field.name }).join(","),
    compiled.template.fields.map(fn(field) { field.name }).join(","),
  )
}

///|
test "form fill of a partly filled form returns its fields" {
  let compiled = compile(form_test_small_xlsx(), "form", Options::new())
  let first = fill(
    compiled.bdf,
    Options::new(data=form_test_json("{\"no\":\"A-1\"}"), open=["customer.name"]),
  )
  let names = first.fields.map(fn(field) { field.name }).join(",")
  assert_true(names.contains("customer.name"), msg=names)
  let done = fill(
    first.bdf,
    Options::new(data=form_test_json("{\"customer\":{\"name\":\"ACME\"}}")),
  )
  assert_eq(done.fields.length(), first.fields.length())
}

///|
test "form fill of a text template returns its fields" {
  let result = fill(
    @utf8.encode("No: {{no}}\n"),
    Options::new(data=form_test_json("{\"no\":\"A-1\"}")),
  )
  let names = result.fields.map(fn(field) { field.name }).join(",")
  assert_true(names.contains("no"), msg=names)
}

///|
test "form reads the fields of a template of pdfme without its shapes" {
  let tpl = @utf8.encode(
    "{\"basePdf\":{\"width\":100,\"height\":50},\"schemas\":[[{\"name\":\"rule\",\"type\":\"line\",\"position\":{\"x\":0,\"y\":0},\"width\":50,\"height\":0},{\"name\":\"box\",\"type\":\"rectangle\",\"position\":{\"x\":0,\"y\":0},\"width\":10,\"height\":10},{\"name\":\"plan\",\"type\":\"select\",\"options\":[\"basic\",\"pro\"],\"position\":{\"x\":10,\"y\":10},\"width\":50,\"height\":10}]]}",
  )
  let fields = @pdfme.inspect(tpl)
  let names = fields.map(fn(field) { field.name }).join(",")
  assert_eq(names, "plan")
  assert_eq(fields[0].options.join(","), "basic,pro")
  assert_eq(fields[0].value_type, "string")
}
