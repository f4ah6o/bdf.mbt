///|
/// An inclusive range of one-based pages. A `to` value of zero means the
/// range continues to the last page.
pub(all) struct PageSpan {
  from : Int64
  to : Int64
} derive(Debug, Eq)

///|
/// Parse the page-selection syntax shared by upstream conversion engines.
/// An empty selection returns `None`, meaning all pages.
pub fn parse_pages(spec : String) -> Array[PageSpan]? raise {
  let spans : Array[PageSpan] = []
  for segment in spec.split(",") {
    let part = page_trim(segment.to_owned())
    if part == "" {
      continue
    }
    let low = StringBuilder()
    let high = StringBuilder()
    let mut range = false
    for c in part {
      if c == '-' && !range {
        range = true
      } else if range {
        high.write_char(c)
      } else {
        low.write_char(c)
      }
    }
    let lo = page_trim(low.to_string())
    if !range {
      let n = page_number(lo, part)
      spans.push({ from: n, to: n, })
    } else {
      let hi = page_trim(high.to_string())
      let from = if lo == "" { 1L } else { page_number(lo, part) }
      let to = if hi == "" { 0L } else { page_number(hi, part) }
      if to != 0L && to < from {
        raise InvalidInput(
          "bad page range " + page_quote(part) + ": it ends before it starts",
        )
      }
      spans.push({ from, to, })
    }
  }
  if spans.length() == 0 {
    None
  } else {
    Some(spans)
  }
}

///|
fn page_trim(text : String) -> String {
  let output = StringBuilder()
  let pending = StringBuilder()
  let mut started = false
  for c in text {
    if c.is_whitespace() {
      if started {
        pending.write_char(c)
      }
    } else {
      if started {
        output.write_string(pending.to_string())
        pending.reset()
      }
      output.write_char(c)
      started = true
    }
  }
  output.to_string()
}

///|
// Go's %q uses Unicode printability and Go escapes rather than JSON escapes.
fn page_quote(text : String) -> String {
  let output = StringBuilder()
  let hex = [
    '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'a', 'b', 'c', 'd', 'e', 'f',
  ]
  output.write_char('"')
  for c in text {
    match c {
      '"' => output.write_string("\\\"")
      '\\' => output.write_string("\\\\")
      '\u{07}' => output.write_string("\\a")
      '\b' => output.write_string("\\b")
      '\u{0c}' => output.write_string("\\f")
      '\n' => output.write_string("\\n")
      '\r' => output.write_string("\\r")
      '\t' => output.write_string("\\t")
      '\u{0b}' => output.write_string("\\v")
      _ => {
        let category = @ucd.general_category(c).group()
        if c == ' ' || (category != @ucd.C && category != @ucd.Z) {
          output.write_char(c)
        } else {
          let code = c.to_int()
          let digits = if code < 0x20 || code == 0x7f {
            output.write_string("\\x")
            2
          } else if code < 0x10000 {
            output.write_string("\\u")
            4
          } else {
            output.write_string("\\U")
            8
          }
          for i = digits - 1; i >= 0; i = i - 1 {
            output.write_char(hex[(code >> (i * 4)) & 15])
          }
        }
      }
    }
  }
  output.write_char('"')
  output.to_string()
}

///|
fn page_number(text : String, part : String) -> Int64 raise {
  let bytes = @utf8.encode(text)
  let mut i = if bytes.length() > 0 && bytes[0] == b'+' { 1 } else { 0 }
  let valid_start = i < bytes.length()
  while i < bytes.length() && bytes[i] >= b'0' && bytes[i] <= b'9' {
    i += 1
  }
  let n = if valid_start && i == bytes.length() {
    @string.parse_int64(text) catch {
      _ => 0L
    }
  } else {
    0L
  }
  if n < 1L {
    raise InvalidInput(
      "bad page " +
      page_quote(text) +
      " in " +
      page_quote(part) +
      ": pages are numbered from 1",
    )
  }
  n
}

///|
/// Expand a selection for an input of `count` pages, preserving order and
/// repeats. A closed range extending past the input includes at most its
/// first out-of-range page, so the converter can report it.
pub fn page_numbers(spans : Array[PageSpan]?, count : Int64) -> Array[Int64]? {
  guard spans is Some(spans) else { return None }
  let numbers : Array[Int64] = []
  for span in spans {
    let from = if span.from < 1L { 1L } else { span.from }
    let to = if span.to == 0L {
      if from > count {
        from
      } else {
        count
      }
    } else if span.to > count {
      if from > count {
        from
      } else {
        count + 1L
      }
    } else {
      span.to
    }
    let mut n = from
    while n <= to {
      numbers.push(n)
      if n == to {
        break
      }
      n += 1L
    }
  }
  Some(numbers)
}

///|
/// Format a selection in the syntax accepted by `parse_pages`.
pub fn format_pages(spans : Array[PageSpan]?) -> String {
  guard spans is Some(spans) else { return "" }
  let output = StringBuilder()
  for i, span in spans {
    if i > 0 {
      output.write_char(',')
    }
    output.write_string(span.from.to_string())
    if span.to != span.from {
      output.write_char('-')
      if span.to != 0L {
        output.write_string(span.to.to_string())
      }
    }
  }
  output.to_string()
}
