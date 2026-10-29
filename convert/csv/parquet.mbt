///|
/// Encode inferred CSV values as the Parquet table attached to a BDF sheet.
pub fn encode_table(table : Table) -> Bytes raise {
  let columns = table.columns.map(column => {
    let kind : @parquet.ColumnType = match column.kind {
      TextColumn => StringColumn
      NumberColumn => NumberColumn
      IntegerColumn => IntegerColumn
      BooleanColumn => BooleanColumn
      DateColumn => DateColumn
      DateTimeColumn => DateTimeColumn
    }
    @parquet.Column::{ name: column.name, kind, }
  })
  let rows = table.rows.map(row => {
    row.map(value => {
      let v : @parquet.Value = match value {
        NullValue => Null
        TextValue(s) => StringValue(s)
        NumberValue(n) => NumberValue(n)
        IntegerValue(n) => IntegerValue(n)
        BooleanValue(b) => BooleanValue(b)
        DateValue(n) => DateValue(n)
        DateTimeValue(n) => DateTimeValue(n)
      }
      v
    })
  })
  @parquet.encode({ columns, rows, })
}
