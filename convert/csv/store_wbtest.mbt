///|
test "CSV values survive a BDF table round trip" {
  let parsed = parse(
    @utf8.encode("name,amount\nAlice,1\nBob,2.5\n"),
    header=HeaderYes,
  )
  let table = values_table(parsed).unwrap()
  let writer = @core.DocumentWriter::new()
  assert_eq(store_table(writer, table, title="Names", view="sheet1"), None)
  let doc = @core.open_single(writer.write_single())
  assert_eq(doc.manifest.tables.length(), 1)
  let stored = doc.manifest.tables[0]
  assert_eq(stored.id, "data")
  assert_eq(stored.rows, 2L)
  assert_eq(stored.title, "Names")
  assert_eq(stored.view, "sheet1")
  assert_eq(stored.columns, [
    { name: "name", kind: "string", },
    { name: "amount", kind: "number", },
  ])
  assert_eq(doc.part(stored.part), encode_table(table))
}
