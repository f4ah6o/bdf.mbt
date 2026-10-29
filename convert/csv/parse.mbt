///|
/// Whether the first record is a header, or should be guessed from the data.
pub(all) enum Header {
  HeaderAuto
  HeaderYes
  HeaderNo
} derive(Debug, Eq)

///|
/// CSV records and the encoding, dialect and header information found.
pub(all) struct ParseResult {
  rows : Array[Array[String]]
  columns : Int32
  charset : String
  bom : Bool
  dialect : Dialect
  header : Bool
  warnings : Array[String]
} derive(Debug, Eq)

///|
/// Decode and read CSV bytes using the upstream record-reading rules. A BOM
/// overrides `charset`; zero delimiter and quote select automatic detection,
/// while quote `-1` disables quoting.
pub fn parse(
  data : Bytes,
  charset~ : String = "",
  delimiter~ : Byte = 0,
  quote~ : Int32 = 0,
  header~ : Header = HeaderAuto,
) -> ParseResult raise {
  // As upstream does, validate options before decoding even if a BOM is present.
  if delimiter >= 0x80 || delimiter == b'\r' || delimiter == b'\n' {
    raise InvalidDialect(
      "csv: the delimiter must be an ASCII character other than a line break, not " +
      csv_quote_rune(delimiter.to_int()),
    )
  }
  if quote < -1 || quote >= 0x80 || quote == 10 || quote == 13 {
    raise InvalidDialect(
      "csv: the quote must be an ASCII character other than a line break, not " +
      csv_quote_rune(quote),
    )
  }
  let decoded = decode_text(data, charset~)
  let dialect = detect_dialect(decoded.text, delimiter~, quote~).dialect
  let records = csv_read_text(decoded.text, dialect)
  let mut columns = 0
  for row in records.rows {
    if row.length() > columns {
      columns = row.length()
    }
  }
  let warnings = if records.unfinished_quote {
    [
      "record \{records.rows.length()}: a quote is never closed; the rest of the file is one value",
    ]
  } else {
    []
  }
  let header = match header {
    HeaderAuto => has_header(records.rows)
    HeaderYes => records.rows.length() > 0
    HeaderNo => false
  }
  {
    rows: records.rows,
    columns,
    charset: decoded.charset,
    bom: decoded.bom,
    dialect,
    header,
    warnings,
  }
}
