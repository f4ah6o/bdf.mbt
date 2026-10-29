///|
test "CSV conversion writes a sheet, text index and typed data table" {
  let input = @utf8.encode("name,amount\nAlice,1\nBob,2.5\n")
  let result = convert_no_fonts(input, name="People", header=HeaderYes)
  let doc = @core.open_single(result.bdf)
  assert_eq(doc.manifest.views.length(), 1)
  let view = doc.manifest.views[0]
  assert_eq(view.kind, "sheet")
  assert_eq(view.title, "People")
  assert_eq(view.frozen_rows, 1)
  assert_eq(view.tiles.length(), 1)
  let index = @core.decode_text_index(doc.part(view.text_index.unwrap()))
  assert_eq(@core.index_plain_text(index), "name\namount\nAlice\n1\nBob\n2.5")
  assert_eq(doc.manifest.tables.length(), 1)
  let table = doc.manifest.tables[0]
  assert_eq(table.rows, 2L)
  assert_eq(table.view, "sheet1")
  assert_true(doc.part(table.part).has_prefix(b"PAR1"))
}

///|
test "CSV no-index and no-data options omit both optional parts" {
  let result = convert_no_fonts(
    @utf8.encode("a,b\n1,2"),
    no_text_index=true,
    data_mode=DataNone,
  )
  let doc = @core.open_single(result.bdf)
  assert_eq(doc.manifest.views[0].text_index, None)
  assert_eq(doc.manifest.tables.length(), 0)
}

///|
test "CSV parameter aliases and sheet filenames follow upstream" {
  let options = parse_params({
    "delimiter": "TAB",
    "quote": "single",
    "header": "T",
    "data": "ALL",
  })
  assert_eq(options.delimiter, b'\t')
  assert_eq(options.quote, 39)
  assert_eq(options.header, HeaderYes)
  assert_eq(options.data_mode, DataAll)
  assert_eq(sheet_name("/dir/example.csv"), "example")
  assert_eq(sheet_name("/dir/example.csv/"), "example")
  assert_eq(sheet_name(""), ".")
}

///|
test "CSV content detection excludes binary and plotter files" {
  assert_true(detect(b"name,value\nAlice,1\nBob,2\n"))
  assert_true(!detect(b"IN;SP1;PA0,0;PD100,200;"))
  assert_true(!detect(b"%PDF-1.7\nname,value\nAlice,1\n"))
  assert_true(!detect(b"name,value\nAlice,\x001\n"))
  assert_true(detect(b"\xff\xfeA\x00,\x00B\x00\n\x001\x00,\x002\x00\n\x00"))
}
