///|
test "records match upstream lenient CSV reader" {
  let std = Dialect::{ delimiter: b',', quote: b'"', escape: 0, }
  let escaped = Dialect::{ delimiter: b',', quote: b'"', escape: b'\\', }
  let single = Dialect::{ delimiter: b';', quote: b'\'', escape: 0, }
  let tab = Dialect::{ delimiter: b'\t', quote: 0, escape: 0, }
  for
    (input, dialect, expected) in [
      ("a,b\r\nc,d\r\n", std, [["a", "b"], ["c", "d"]]),
      ("a,b\rc,d", std, [["a", "b"], ["c", "d"]]),
      ("a,,\n,b", std, [["a", "", ""], ["", "b"]]),
      ("a\n\nb\n", std, [["a"], [], ["b"]]),
      ("\"a,b\",\"c\"\"d\",e", std, [["a,b", "c\"d", "e"]]),
      ("\"two\r\nlines\",x\ny,z", std, [["two\r\nlines", "x"], ["y", "z"]]),
      ("a, \"b, c\" ,d", std, [["a", "b, c", "d"]]),
      (
        "5\" screen,\"say \"hi\" now\",x",
        std,
        [["5\" screen", "say \"hi\" now", "x"]],
      ),
      ("\"open,x\ny", std, [["open,x\ny"]]),
      ("\"a\\\"b\",c", escaped, [["a\"b", "c"]]),
      ("'a;b';'it''s'", single, [["a;b", "it's"]]),
      ("\"a\"\tb\n", tab, [["\"a\"", "b"]]),
      (
        "名前,\"東京, 日本\"\n😀,文字",
        std,
        [["名前", "東京, 日本"], ["😀", "文字"]],
      ),
    ] {
    assert_eq(read_records(input, dialect).rows, expected)
  }
}

///|
test "record diagnostics track bad and unfinished quotes" {
  let std = Dialect::{ delimiter: b',', quote: b'"', escape: 0, }
  let parsed = read_records("bad\"quote,\"unfinished", std)
  assert_eq(parsed.rows, [["bad\"quote", "unfinished"]])
  assert_eq(parsed.bad_quotes, 1)
  assert_eq(parsed.quoted_fields, 1)
  assert_true(parsed.unfinished_quote)
}

///|
test "record reader rejects invalid delimiters and quotes" {
  for
    dialect in [
      Dialect::{ delimiter: 0, quote: 0, escape: 0, },
      Dialect::{ delimiter: b'\n', quote: b'"', escape: 0, },
      Dialect::{ delimiter: b',', quote: b'\r', escape: 0, },
      Dialect::{ delimiter: b',', quote: 0, escape: 0xff, },
    ] {
    let rejected = try {
      ignore(read_records("a,b", dialect))
      false
    } catch {
      InvalidDialect(_) => true
      _ => false
    }
    assert_true(rejected)
  }
}
