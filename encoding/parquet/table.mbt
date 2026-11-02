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
/// Values finer than a millisecond (TIME_MILLIS/TIME_MICROS/TIME_NANOS,
/// TIMESTAMP with microsecond or nanosecond units, and INT96), and the logical
/// types that have no value of their own (UUID, JSON, geometries, intervals,
/// binary columns), are shown as ISO 8601 or canonical text through
/// `StringValue`, so that their precision is not lost.
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
