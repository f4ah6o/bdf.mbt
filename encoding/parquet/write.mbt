///|
struct Chunk {
  offset : Int32
  size : Int32
  values : Int32
}

///|
/// Encode a flat table using the upstream BDF writer's uncompressed format.
/// Missing trailing cells are encoded as nulls.
pub fn encode(table : Table) -> Bytes raise {
  if table.columns.length() == 0 {
    raise InvalidTable("parquet: a table needs a column")
  }
  if table.columns.length() > 16384 {
    raise InvalidTable("parquet: too many columns")
  }
  for i, column in table.columns {
    if column.name == "" {
      raise InvalidTable("parquet: column \{i + 1} has no name")
    }
  }
  for i, row in table.rows {
    if row.length() > table.columns.length() {
      raise InvalidTable("parquet: row \{i + 1} has too many values")
    }
  }
  let file = @buffer.new()
  file.write_bytes(b"PAR1")
  let chunks : Array[Chunk] = []
  let mut offset = 4
  for j, column in table.columns {
    let start_offset = offset
    let mut values = 0
    let mut start = 0
    while start < table.rows.length() || start == 0 {
      let end = if start + 65536 < table.rows.length() {
        start + 65536
      } else {
        table.rows.length()
      }
      let (page, count) = encode_page(column, table.rows, j, start, end)
      file.write_bytes(page)
      offset += page.length()
      values += count
      // The upstream writer advances by 65536 even when the byte limit ends
      // a page early, which can silently omit rows. Advance by the actual
      // number encoded so large cells do not lose subsequent values.
      start += count
      if start == table.rows.length() {
        break
      }
    }
    chunks.push({ offset: start_offset, size: offset - start_offset, values, })
  }
  let footer = Compact::new()
  footer.i32(1, 1)
  footer.list(2, 12, table.columns.length() + 1)
  footer.elem()
  footer.binary(4, "schema")
  footer.i32(5, table.columns.length())
  footer.end()
  for column in table.columns {
    footer.elem()
    footer.i32(1, physical(column.kind))
    footer.i32(3, 1)
    footer.binary(4, column.name)
    match column.kind {
      StringColumn => {
        footer.i32(6, 0)
        footer.begin(10)
        footer.begin(1)
        footer.end()
        footer.end()
      }
      DateColumn => {
        footer.i32(6, 6)
        footer.begin(10)
        footer.begin(6)
        footer.end()
        footer.end()
      }
      DateTimeColumn => {
        footer.i32(6, 9)
        footer.begin(10)
        footer.begin(8)
        footer.field(1, 1)
        footer.begin(2)
        footer.begin(1)
        footer.end()
        footer.end()
        footer.end()
        footer.end()
      }
      _ => ()
    }
    footer.end()
  }
  footer.i64(3, table.rows.length().to_int64())
  footer.list(4, 12, 1)
  footer.elem()
  footer.list(1, 12, table.columns.length())
  let mut total = 0
  for j, column in table.columns {
    let chunk = chunks[j]
    total += chunk.size
    footer.elem()
    footer.i64(2, chunk.offset.to_int64())
    footer.begin(3)
    footer.i32(1, physical(column.kind))
    footer.list(2, 5, 2)
    svarint(footer.out, 0L)
    svarint(footer.out, 3L)
    footer.list(3, 8, 1)
    let name = @utf8.encode(column.name)
    uvarint(footer.out, name.length().to_uint64())
    footer.out.write_bytes(name)
    footer.i32(4, 0)
    footer.i64(5, chunk.values.to_int64())
    footer.i64(6, chunk.size.to_int64())
    footer.i64(7, chunk.size.to_int64())
    footer.i64(9, chunk.offset.to_int64())
    footer.end()
    footer.end()
  }
  footer.i64(2, total.to_int64())
  footer.i64(3, table.rows.length().to_int64())
  footer.end()
  footer.binary(6, "bdf")
  let data = footer.bytes()
  file.write_bytes(data)
  file.write_uint_le(data.length().to_uint())
  file.write_bytes(b"PAR1")
  file.to_bytes()
}
