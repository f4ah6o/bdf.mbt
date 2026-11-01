///|
test "parquet input renders a table" {
  let table : @parquet.Table = {
    columns: [
      { name: "name", kind: @parquet.StringColumn },
      { name: "count", kind: @parquet.IntegerColumn },
    ],
    rows: [
      [@parquet.StringValue("Ada"), @parquet.IntegerValue(3L)],
      [@parquet.StringValue("Bob"), @parquet.IntegerValue(5L)],
    ],
  }
  let data = @parquet.encode(table) catch { _ => fail("parquet encode failed") }
  assert_true(detect(data))
  let result = convert(data) catch {
    ParquetInputInvalid(message) => fail("parquet input failed: " + message)
  }
  assert_eq(result.pages, 1)
  let document = @core.open_single(result.bdf) catch {
    _ => fail("parquet BDF did not open")
  }
  let view = document.manifest.views[0]
  assert_eq(view.kind, "sheet")
  assert_true(view.tiles.length() > 0)
}
