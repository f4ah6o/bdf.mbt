///|
test "CSV parse combines encoding, dialect, header and records" {
  let data = @utf8.encode("name;amount\nA;1,5\nB;2,5\n")
  let result = parse(data)
  assert_eq(result.charset, "UTF-8")
  assert_eq(result.dialect, { delimiter: b';', quote: b'"', escape: 0, })
  assert_eq(result.rows, [["name", "amount"], ["A", "1,5"], ["B", "2,5"]])
  assert_eq(result.columns, 2)
  assert_true(result.header)
  assert_eq(parse(data, header=HeaderNo).header, false)
  assert_true(parse(@utf8.encode("x"), header=HeaderYes).header)
  assert_false(parse(b"", header=HeaderYes).header)
}

///|
test "CSV parse reports an unclosed final quoted field" {
  let result = parse(@utf8.encode("a,b\n1,\"open"), delimiter=b',', quote=34)
  assert_eq(result.rows, [["a", "b"], ["1", "open"]])
  assert_eq(result.warnings, [
    "record 2: a quote is never closed; the rest of the file is one value",
  ])
}

///|
test "CSV parse preserves upstream handling when quote equals delimiter" {
  let result = parse(@utf8.encode("a,b\nc,d"), delimiter=b',', quote=44)
  assert_eq(result.dialect, { delimiter: 0, quote: 0, escape: 0, })
  assert_eq(result.rows, [["a,b"], ["c,d"]])
}

///|
test "CSV parse reports invalid options before decoding" {
  let error = try {
    ignore(parse(b"\xef\xbb\xbf", delimiter=b'\n', charset="unknown"))
    ""
  } catch {
    InvalidDialect(detail) => detail
    _ => "unexpected"
  }
  assert_eq(
    error, "csv: the delimiter must be an ASCII character other than a line break, not '\\n'",
  )
  let bad_quote = try {
    ignore(parse(b"", quote=13))
    ""
  } catch {
    InvalidDialect(detail) => detail
    _ => "unexpected"
  }
  assert_eq(
    bad_quote, "csv: the quote must be an ASCII character other than a line break, not '\\r'",
  )
}
