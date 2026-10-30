///|
// Non-numeric operands are compared as Go's lowercased UTF-8 strings. Numeric
// and blank operands sort before strings, booleans, and errors.
fn xlsx_conditional_literal_compare(
  left_number : Double,
  left_text : String?,
  right_number : Double,
  right_text : String?,
) -> Int32 {
  match (left_text, right_text) {
    (None, None) =>
      if left_number < right_number {
        -1
      } else if left_number > right_number {
        1
      } else {
        0
      }
    (None, Some(_)) => -1
    (Some(_), None) => 1
    (Some(left), Some(right)) => {
      let a = @utf8.encode(xlsx_go_lower(left))
      let b = @utf8.encode(xlsx_go_lower(right))
      let common = Int32::min(a.length(), b.length())
      for i in 0..<common {
        if a[i] < b[i] {
          return -1
        }
        if a[i] > b[i] {
          return 1
        }
      }
      a.length().compare(b.length())
    }
  }
}

///|
fn xlsx_conditional_literal_matches(
  value : Double,
  text : String?,
  threshold : Double,
  literal : String?,
  threshold_end : Double,
  literal_end : String?,
  operator : String,
) -> Bool {
  let first = xlsx_conditional_literal_compare(value, text, threshold, literal)
  match operator {
    "lessThan" => first < 0
    "lessThanOrEqual" => first <= 0
    "equal" => first == 0
    "notEqual" => first != 0
    "greaterThan" => first > 0
    "greaterThanOrEqual" => first >= 0
    "between" | "notBetween" => {
      let second = xlsx_conditional_literal_compare(
        value, text, threshold_end, literal_end,
      )
      let ordered = xlsx_conditional_literal_compare(
        threshold, literal, threshold_end, literal_end,
      )
      let inside = if ordered <= 0 {
        first >= 0 && second <= 0
      } else {
        second >= 0 && first <= 0
      }
      if operator == "between" {
        inside
      } else {
        !inside
      }
    }
    _ => false
  }
}
