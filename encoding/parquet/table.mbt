///|
/// A flat Parquet column's logical type.
pub(all) enum ColumnType {
  StringColumn
  NumberColumn
  IntegerColumn
  BooleanColumn
  DateColumn
  DateTimeColumn
} derive(Debug, Eq)

///|
pub(all) struct Column {
  name : String
  kind : ColumnType
} derive(Debug, Eq)

///|
/// Dates are days and date-times are milliseconds since the Unix epoch.
pub(all) enum Value {
  Null
  StringValue(String)
  NumberValue(Double)
  IntegerValue(Int64)
  BooleanValue(Bool)
  DateValue(Int64)
  DateTimeValue(Int64)
} derive(Debug, Eq)

///|
pub(all) struct Table {
  columns : Array[Column]
  rows : Array[Array[Value]]
} derive(Debug, Eq)

///|
pub suberror ParquetError {
  InvalidTable(String)
} derive(Debug)

///|
fn physical(kind : ColumnType) -> Int32 {
  match kind {
    StringColumn => 6
    NumberColumn => 5
    IntegerColumn | DateTimeColumn => 2
    BooleanColumn => 0
    DateColumn => 1
  }
}
