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

///|
test "parquet RLE bit-packed dictionary indices" {
  let data = Bytes::from_array([3, 0x88, 0xc6, 0xfa])
  let values = parquet_rle(data, 3, 8)
  assert_eq(values, [0, 1, 2, 3, 4, 5, 6, 7])
}

///|
test "parquet Snappy literal and copy" {
  let literal = Bytes::from_array([5, 0x10, b'h', b'e', b'l', b'l', b'o'])
  assert_eq(@utf8.decode_lossy(parquet_snappy(literal, 64)), "hello")
  let copy = Bytes::from_array([5, 0x00, b'a', 0x01, 0x01])
  assert_eq(@utf8.decode_lossy(parquet_snappy(copy, 64)), "aaaaa")
}

///|
test "parquet LZ4 literal block" {
  let block = Bytes::from_array([0x50, b'h', b'e', b'l', b'l', b'o'])
  assert_eq(@utf8.decode_lossy(parquet_lz4_block(block, 64)), "hello")
}
