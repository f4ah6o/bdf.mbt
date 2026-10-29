///|
test "CSV value types match upstream table inference" {
  for
    (value, expected) in [
      ("12", IntegerColumn),
      ("-3", IntegerColumn),
      ("0", IntegerColumn),
      ("0012", TextColumn),
      ("1.5", NumberColumn),
      ("1.5e3", NumberColumn),
      (".5", NumberColumn),
      ("2024-01-15", DateColumn),
      ("2024-02-30", TextColumn),
      ("2024-05-20T14:05:00Z", DateTimeColumn),
      ("2024-04-01 09:30", DateTimeColumn),
      ("TRUE", BooleanColumn),
      ("false", BooleanColumn),
      ("$4.50", TextColumn),
      ("12,500", TextColumn),
      ("2024/3/1", TextColumn),
    ] {
    assert_eq(table_value_type(value), expected)
  }
}

///|
test "CSV typed tables merge numbers and preserve nulls and dates" {
  let parsed = parse(
    @utf8.encode("n,d\n1,2024-01-15\n2.5,\n,2024-01-16"),
    header=HeaderYes,
  )
  let table = values_table(parsed).unwrap()
  assert_eq(table.columns, [
    { name: "n", kind: NumberColumn, },
    { name: "d", kind: DateColumn, },
  ])
  assert_eq(table.rows, [
    [NumberValue(1.0), DateValue(19737L)],
    [NumberValue(2.5), NullValue],
    [NullValue, DateValue(19738L)],
  ])
  let no_header = values_table(
    parse(@utf8.encode("1,yes\n2,no"), header=HeaderNo),
  ).unwrap()
  assert_eq(no_header.columns[0].name, "C1")
  assert_eq(no_header.columns[1].name, "C2")
}

///|
test "CSV date-times become UTC milliseconds" {
  assert_eq(csv_table_datetime("1970-01-01T00:00:00Z"), Some(0L))
  assert_eq(csv_table_datetime("1969-12-31T23:59:59.999Z"), Some(-1L))
  assert_eq(csv_table_datetime("1970-01-01T09:00:00+09:00"), Some(0L))
  assert_eq(csv_table_datetime("1970-01-01 09:00"), Some(32400000L))
  assert_eq(csv_table_datetime("1970-01-01T09:00Z"), None)
}

///|
test "CSV preserves negative zero in numeric table values" {
  let table = values_table(parse(@utf8.encode("-0.0"), header=HeaderNo)).unwrap()
  guard table.rows[0][0] is NumberValue(number) else { fail("expected number") }
  assert_eq(number.reinterpret_as_uint64(), 0x8000000000000000UL)
}
