///|
test "page selections parse and preserve order" {
  assert_eq(parse_pages("+01"), Some([{ from: 1L, to: 1L, }]))
  assert_eq(
    parse_pages("\u{00a0}1\u{2003}-\u{2003}2\u{00a0}"),
    Some([{ from: 1L, to: 2L, }]),
  )
  let spans = parse_pages(" 3 , 1-1 , -3, 7-, - ")
  assert_eq(
    spans,
    Some([
      { from: 3L, to: 3L, },
      { from: 1L, to: 1L, },
      { from: 1L, to: 3L, },
      { from: 7L, to: 0L, },
      { from: 1L, to: 0L, },
    ]),
  )
  assert_eq(page_numbers(spans, 3L), Some([3L, 1L, 1L, 2L, 3L, 7L, 1L, 2L, 3L]))
  assert_eq(parse_pages(", ,"), None)
  assert_eq(format_pages(parse_pages("1-2,5,7-")), "1-2,5,7-")
  assert_eq(format_pages(None), "")
  assert_eq(page_numbers(None, 3L), None)
  assert_eq(
    page_numbers(parse_pages("3-999999999,8-9,7-"), 5L),
    Some([3L, 4L, 5L, 6L, 8L, 7L]),
  )
}

///|
test "invalid page selections produce upstream errors" {
  for
    (spec, message) in [
      ("0", "bad page \"0\" in \"0\": pages are numbered from 1"),
      ("1-x", "bad page \"x\" in \"1-x\": pages are numbered from 1"),
      ("5-3", "bad page range \"5-3\": it ends before it starts"),
      ("2--3", "bad page \"-3\" in \"2--3\": pages are numbered from 1"),
      ("1.5", "bad page \"1.5\" in \"1.5\": pages are numbered from 1"),
      ("\u{07}", "bad page \"\\a\" in \"\\a\": pages are numbered from 1"),
      (
        "\u{200b}", "bad page \"\\u200b\" in \"\\u200b\": pages are numbered from 1",
      ),
      ("あ", "bad page \"あ\" in \"あ\": pages are numbered from 1"),
      (
        "9223372036854775808", "bad page \"9223372036854775808\" in \"9223372036854775808\": pages are numbered from 1",
      ),
    ] {
    let actual = try {
      ignore(parse_pages(spec))
      ""
    } catch {
      InvalidInput(detail) => detail
      _ => "unexpected error"
    }
    assert_eq(actual, message)
  }
}
