///|
fn encode_page(
  column : Column,
  rows : Array[Array[Value]],
  j : Int32,
  start : Int32,
  end : Int32,
) -> (Bytes, Int32) raise {
  let vals = @buffer.new()
  let defs = @buffer.new()
  let mut run = 0
  let mut level = 1
  let mut bits = 0
  let mut nbits = 0
  let mut count = 0
  for i in start..<end {
    let row = rows[i]
    let v = if j < row.length() { row[j] } else { Null }
    let next = if v == Null { 0 } else { 1 }
    if next != level {
      if run > 0 {
        uvarint(defs, (run * 2).to_uint64())
        defs.write_byte(level.to_byte())
      }
      run = 0
      level = next
    }
    run += 1
    count += 1
    match (column.kind, v) {
      (_, Null) => ()
      (StringColumn, StringValue(s)) => {
        let data = @utf8.encode(s)
        vals.write_uint_le(data.length().to_uint())
        vals.write_bytes(data)
      }
      (NumberColumn, NumberValue(n)) =>
        vals.write_uint64_le(n.reinterpret_as_uint64())
      (NumberColumn, IntegerValue(n)) =>
        vals.write_uint64_le(n.to_double().reinterpret_as_uint64())
      (IntegerColumn, IntegerValue(n)) =>
        vals.write_uint64_le(n.reinterpret_as_uint64())
      (BooleanColumn, BooleanValue(b)) => {
        if b {
          bits = bits | (1 << nbits)
        }
        nbits += 1
        if nbits == 8 {
          vals.write_byte(bits.to_byte())
          bits = 0
          nbits = 0
        }
      }
      // Go's time.Time.Sub saturates at the duration limits before dividing
      // by a day, so dates more than about 292 years from the epoch clamp.
      (DateColumn, DateValue(n)) => {
        let days = if n > 106751L {
          106751
        } else if n < -106751L {
          -106751
        } else {
          n.to_int()
        }
        vals.write_uint_le(days.reinterpret_as_uint())
      }
      (DateTimeColumn, DateTimeValue(n)) =>
        vals.write_uint64_le(n.reinterpret_as_uint64())
      _ =>
        raise InvalidTable(
          "parquet: column \{column.name}, row \{i - start + 1}: incompatible value",
        )
    }
    if vals.length() >= 1048576 && i + 1 < end {
      break
    }
  }
  if nbits > 0 {
    vals.write_byte(bits.to_byte())
  }
  if run > 0 {
    uvarint(defs, (run * 2).to_uint64())
    defs.write_byte(level.to_byte())
  }
  let definition = defs.to_bytes()
  let body = @buffer.new()
  body.write_uint_le(definition.length().to_uint())
  body.write_bytes(definition)
  body.write_bytes(vals.to_bytes())
  let data = body.to_bytes()
  let header = Compact::new()
  header.i32(1, 0)
  header.i32(2, data.length())
  header.i32(3, data.length())
  header.begin(5)
  header.i32(1, count)
  header.i32(2, 0)
  header.i32(3, 3)
  header.i32(4, 3)
  header.end()
  let page = @buffer.new()
  page.write_bytes(header.bytes())
  page.write_bytes(data)
  (page.to_bytes(), count)
}
