///|
#export_name("encode_fixture")
pub fn encode_fixture(which : Int32) -> Bytes {
  if which == 4 {
    let csv = try! @csv.parse(
      @utf8.encode("name,amount,day\nAlice,1,2024-01-01\nBob,2.5,2024-01-02\n"),
      header=HeaderYes,
    )
    return try! @csv.encode_table(@csv.values_table(csv).unwrap())
  }
  let table : @parquet.Table = match which {
    0 => { columns: [{ name: "empty", kind: StringColumn, }], rows: [], }
    1 =>
      {
        columns: [
          { name: "名前", kind: StringColumn, },
          { name: "number", kind: NumberColumn, },
          { name: "integer", kind: IntegerColumn, },
          { name: "bool", kind: BooleanColumn, },
          { name: "date", kind: DateColumn, },
          { name: "time", kind: DateTimeColumn, },
        ],
        rows: [
          [
            StringValue("日本語"),
            NumberValue(-0.0),
            IntegerValue(-123456789L),
            BooleanValue(true),
            DateValue(-1L),
            DateTimeValue(-123456789L),
          ],
          [
            Null,
            NumberValue(1.25),
            Null,
            BooleanValue(false),
            DateValue(19723L),
            DateTimeValue(1704067200123L),
          ],
          [StringValue(""), Null, IntegerValue(9223372036854775807L)],
          [Null, Null, Null, Null, DateValue(2932896L)],
          [Null, Null, Null, Null, DateValue(-719162L)],
        ],
      }
    2 => {
      let columns : Array[@parquet.Column] = []
      let row : Array[@parquet.Value] = []
      for i in 0..<16 {
        columns.push({ name: "c\{i}", kind: BooleanColumn, })
        row.push(BooleanValue(i % 2 == 0))
      }
      { columns, rows: [row], }
    }
    _ => {
      let rows : Array[Array[@parquet.Value]] = []
      for i in 0..<65538 {
        rows.push([if i % 3 == 0 { Null } else { BooleanValue(i % 2 == 0) }])
      }
      { columns: [{ name: "flag", kind: BooleanColumn, }], rows, }
    }
  }
  try! @parquet.encode(table)
}

///|
#export_name("encode_large_fixture")
pub fn encode_large_fixture(large : String) -> Bytes {
  try! @parquet.encode({
    columns: [{ name: "text", kind: StringColumn, }],
    rows: [[StringValue(large)], [StringValue("preserved")]],
  })
}
