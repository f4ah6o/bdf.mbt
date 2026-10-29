///|
fn rejected(table : Table) -> Bool {
  try {
    ignore(encode(table))
    false
  } catch {
    _ => true
  }
}

///|
test "parquet rejects missing columns, names, extra cells and wrong types" {
  assert_true(rejected({ columns: [], rows: [], }))
  assert_true(
    rejected({ columns: [{ name: "", kind: StringColumn, }], rows: [], }),
  )
  assert_true(
    rejected({
      columns: [{ name: "n", kind: IntegerColumn, }],
      rows: [[IntegerValue(1L), Null]],
    }),
  )
  assert_true(
    rejected({
      columns: [{ name: "n", kind: IntegerColumn, }],
      rows: [[StringValue("1")]],
    }),
  )
}
