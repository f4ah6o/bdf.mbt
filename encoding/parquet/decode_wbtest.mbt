///|
test "parquet decode round-trips the simplified writer" {
  let table : Table = {
    columns: [
      { name: "name", kind: StringColumn },
      { name: "count", kind: IntegerColumn },
      { name: "score", kind: NumberColumn },
      { name: "ok", kind: BooleanColumn },
    ],
    rows: [
      [StringValue("Ada"), IntegerValue(3L), NumberValue(1.5), BooleanValue(true)],
      [StringValue("Bob"), IntegerValue(4L), NumberValue(2.5), BooleanValue(false)],
      [Null, Null, Null, Null],
    ],
  }
  let data = encode(table) catch { _ => fail("parquet encode failed") }
  let decoded = try {
    decode(data)
  } catch {
    InvalidTable(message) => fail("parquet decode failed: " + message)
    _ => fail("parquet decode failed")
  }
  assert_eq(decoded.columns.length(), 4)
  assert_eq(decoded.rows.length(), 3)
  assert_eq(decoded.rows[0][0], StringValue("Ada"))
  assert_eq(decoded.rows[1][1], IntegerValue(4L))
  assert_eq(decoded.rows[2][0], Null)
}
