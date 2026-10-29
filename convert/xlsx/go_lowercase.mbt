///|
// Go's strings.ToLower applies Unicode simple lowercase mappings, while
// String::to_lower only changes ASCII in MoonBit.
fn xlsx_go_lower(text : String) -> String {
  let out = StringBuilder()
  for ch in text {
    let code = ch.to_int()
    let mut lo = 0
    let mut hi = xlsx_go_lowercase.length()
    while lo < hi {
      let mid = lo + (hi - lo) / 2
      if xlsx_go_lowercase[mid].0 < code {
        lo = mid + 1
      } else {
        hi = mid
      }
    }
    if lo < xlsx_go_lowercase.length() && xlsx_go_lowercase[lo].0 == code {
      out.write_char(xlsx_go_lowercase[lo].1.to_char().unwrap())
    } else {
      out.write_char(ch)
    }
  }
  out.to_string()
}

///|
fn xlsx_conditional_text_matches(
  kind : String,
  value : String,
  needle : String,
) -> Bool {
  let value = xlsx_go_lower(value)
  match kind {
    "containsText" => value.contains(needle)
    "notContainsText" => !value.contains(needle)
    "beginsWith" => value.has_prefix(needle)
    "endsWith" => value.has_suffix(needle)
    _ => false
  }
}
