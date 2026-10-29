///|
/// A rendered piece: text (0), a gap (1), or a repeated fill (2).
pub(all) struct XlsxFormatPiece {
  kind : Int32
  text : String
}

///|
fn xlsx_piece_text(pieces : Array[XlsxFormatPiece], text : String) -> Unit {
  if text == "" {
    return
  }
  let n = pieces.length()
  if n > 0 && pieces[n - 1].kind == 0 {
    pieces[n - 1] = { kind: 0, text: pieces[n - 1].text + text, }
  } else {
    pieces.push({ kind: 0, text, })
  }
}

///|
fn xlsx_append_digits(pieces : Array[XlsxFormatPiece], digits : String) -> Unit {
  let mut start = 0
  for i in 0..<digits.length() {
    if digits[i] == 0 {
      xlsx_piece_text(pieces, digits[start:i].to_owned())
      pieces.push({ kind: 1, text: "0", })
      start = i + 1
    }
  }
  xlsx_piece_text(pieces, digits[start:].to_owned())
}

///|
fn xlsx_fill_integer(digits : String, placeholders : String) -> Array[String] {
  let out = Array::make(placeholders.length(), "")
  if out.length() == 0 {
    return out
  }
  let units : Array[String] = []
  let mut i = 0
  while i < digits.length() {
    let start = i
    if digits[i] == 45 || digits[i] == 44 {
      i += 1
      while i < digits.length() && digits[i] == 44 {
        i += 1
      }
      if i < digits.length() {
        i += 1
      }
    } else {
      i += 1
    }
    units.push(digits[start:i].to_owned())
  }
  let mut j = units.length() - 1
  let mut p = out.length() - 1
  while p >= 0 {
    if j >= 0 {
      if p == 0 {
        let b = StringBuilder()
        for k in 0..<(j + 1) {
          b.write_string(units[k])
        }
        out[p] = b.to_string()
      } else {
        out[p] = units[j]
      }
      j -= 1
    } else if placeholders[p] == 48 {
      out[p] = "0"
    } else if placeholders[p] == 63 {
      out[p] = "\u0000"
    }
    p -= 1
  }
  out
}

///|
fn xlsx_fill_fraction(digits : String, placeholders : String) -> Array[String] {
  let out = Array::make(placeholders.length(), "")
  let mut last = digits.length() - 1
  while last >= 0 && digits[last] == 48 {
    last -= 1
  }
  for i in 0..<out.length() {
    let digit = if i < digits.length() {
      digits[i:i + 1].to_owned()
    } else {
      "0"
    }
    if i <= last || placeholders[i] == 48 {
      out[i] = digit
    } else if placeholders[i] == 63 {
      out[i] = "\u0000"
    }
  }
  out
}

///|
fn xlsx_group_thousands(digits : String) -> String {
  let negative = digits.has_prefix("-")
  let start = if negative { 1 } else { 0 }
  let b = StringBuilder()
  if negative {
    b.write_string("-")
  }
  for i in start..<digits.length() {
    if i > start && (digits.length() - i) % 3 == 0 {
      b.write_string(",")
    }
    b.write_string(digits[i:i + 1].to_owned())
  }
  b.to_string()
}

///|
fn xlsx_round_away(value : Double, decimals : Int32) -> Double {
  let p = xlsx_pow10(decimals)
  let result = (value * p).round() / p
  if result.is_inf() || result.is_nan() {
    value
  } else {
    result
  }
}

///|
fn xlsx_numeric_fixed_parts(
  value : Double,
  decimals : Int32,
) -> (String, String) {
  let s = xlsx_fixed(value, decimals)
  let mut i = 0
  while i < s.length() && s[i] != 46 {
    i += 1
  }
  if i == s.length() {
    (s, "")
  } else {
    (s[:i].to_owned(), s[i + 1:].to_owned())
  }
}

///|
fn xlsx_scientific_parts(
  value : Double,
  layout : XlsxNumberLayout,
) -> (String, String, String, Bool) {
  if value == 0.0 {
    let zeros = StringBuilder()
    for _ in 0..<layout.fraction_digits.length() {
      zeros.write_string("0")
    }
    return ("0", zeros.to_string(), "0", false)
  }
  let exp = xlsx_go_log10(value).floor().to_int()
  let n = layout.integer.length()
  let step = if n > 1 && layout.integer.contains("#") { n } else { 1 }
  let mut e = if step > 1 {
    (exp.to_double() / step.to_double()).floor().to_int() * step
  } else if n > 1 {
    exp - (n - 1)
  } else {
    exp
  }
  let mut m = xlsx_round_away(
    value / xlsx_pow10(e),
    layout.fraction_digits.length(),
  )
  if step == 1 && n <= 1 && m >= 10.0 {
    m /= 10.0
    e += 1
  }
  let (integer, fraction) = xlsx_numeric_fixed_parts(
    m,
    layout.fraction_digits.length(),
  )
  (integer, fraction, (if e < 0 { -e } else { e }).to_string(), e < 0)
}

///|
fn xlsx_fraction_parts(
  value : Double,
  layout : XlsxNumberLayout,
) -> (String, String, String) {
  let mut whole = 0.0
  let mut fraction = value
  if layout.integer != "" {
    whole = value.floor()
    fraction = value - whole
  }
  let mut num = 0L
  let mut den = 1L
  if layout.fixed_denominator > 0L {
    den = layout.fixed_denominator
    num = (fraction * den.to_double()).round().to_int64()
  } else {
    let places = Int32::max(layout.denominator.length(), 1)
    // The upstream search checks denominators in increasing order.
    let max_den = if places >= 19 {
      9223372036854775807L
    } else {
      xlsx_pow10(places).to_int64() - 1L
    }
    let mut best_error = fraction.abs()
    let mut d = 1L
    while d <= max_den {
      let n = (fraction * d.to_double()).round().to_int64()
      let error = (fraction - n.to_double() / d.to_double()).abs()
      if error < best_error - 1.0e-12 {
        num = n
        den = d
        best_error = error
        if error == 0.0 {
          break
        }
      }
      if d == 9223372036854775807L {
        break
      }
      d += 1L
    }
  }
  if den > 0L && num == den && layout.integer != "" {
    whole += 1.0
    num = 0L
  }
  let integer = if whole != 0.0 { xlsx_fixed(whole, 0) } else { "" }
  if num == 0L {
    if layout.integer != "" && whole != 0.0 {
      return (integer, "", "")
    }
    if layout.integer != "" {
      return ("0", "", "")
    }
    return ("", "0", Int64::max(den, 1L).to_string())
  }
  (integer, num.to_string(), den.to_string())
}

///|
/// Render a numeric section as text, gaps and fills, and report General mode.
pub fn xlsx_format_numeric(
  section : XlsxFormatSection,
  input : Double,
) -> (Array[XlsxFormatPiece], Bool) {
  let layout = xlsx_analyze_number_format(section)
  let neg = input < 0.0
  let mut value = input.abs()
  for _ in 0..<layout.percent {
    value *= 100.0
  }
  for _ in 0..<layout.scale {
    value /= 1000.0
  }
  let mut integer = ""
  let mut frac = ""
  let mut exponent = ""
  let mut numerator = ""
  let mut denominator = ""
  let mut exp_neg = false
  let mut general = false
  if layout.general && layout.integer == "" {
    integer = xlsx_format_general(value, 11)
    general = true
  } else if layout.fraction {
    let (whole, num, den) = xlsx_fraction_parts(value, layout)
    integer = whole
    numerator = num
    denominator = den
  } else if layout.exponent != "" {
    let (whole, decimals, exp, negative) = xlsx_scientific_parts(value, layout)
    integer = whole
    frac = decimals
    exponent = exp
    exp_neg = negative
  } else {
    let rounded = xlsx_round_away(
      xlsx_round15(value),
      layout.fraction_digits.length(),
    )
    let (whole, decimals) = xlsx_numeric_fixed_parts(
      rounded,
      layout.fraction_digits.length(),
    )
    integer = if whole == "0" { "" } else { whole }
    frac = decimals
  }
  let mut nonzero = false
  for c in integer + frac + numerator {
    if c >= '1' && c <= '9' {
      nonzero = true
    }
  }
  if neg && (nonzero || general) {
    integer = "-" + integer
    if general && integer.has_prefix("--") {
      integer = integer[1:].to_owned()
    }
  }
  if layout.thousands {
    integer = xlsx_group_thousands(integer)
  }
  let int_digits = xlsx_fill_integer(integer, layout.integer)
  let frac_digits = xlsx_fill_fraction(frac, layout.fraction_digits)
  let exp_digits = xlsx_fill_integer(exponent, layout.exponent_digits)
  let mut num_digits = xlsx_fill_integer(numerator, layout.numerator)
  let mut den_digits = xlsx_fill_fraction(denominator, layout.denominator)
  if layout.fraction && numerator == "" && denominator == "" {
    let n = StringBuilder()
    for _ in 0..<layout.numerator.length() {
      n.write_string("?")
    }
    let d = StringBuilder()
    for _ in 0..<layout.denominator.length() {
      d.write_string("?")
    }
    num_digits = xlsx_fill_integer("", n.to_string())
    den_digits = xlsx_fill_integer("", d.to_string())
  }
  let tokens = section.tokens
  let mut num_start = tokens.length()
  if layout.fraction {
    let mut i = tokens.length() - 1
    while i >= 0 {
      if tokens[i].kind == 9 {
        let mut count = 0
        let mut j = i - 1
        while j >= 0 {
          if tokens[j].kind == 4 {
            count += 1
            if count == layout.numerator.length() {
              num_start = j
              break
            }
          } else if tokens[j].kind != 0 {
            break
          }
          j -= 1
        }
        break
      }
      i -= 1
    }
  }
  let out : Array[XlsxFormatPiece] = []
  let mut part = 0
  let mut int_idx = 0
  let mut frac_idx = 0
  let mut exp_idx = 0
  let mut num_idx = 0
  let mut den_idx = 0
  let mut slash_seen = false
  for i in 0..<tokens.length() {
    let token = tokens[i]
    match token.kind {
      0 => {
        let mut only_spaces = true
        for c in token.text {
          if c != ' ' {
            only_spaces = false
          }
        }
        if layout.fraction &&
          i < num_start &&
          integer == "" &&
          layout.integer != "" &&
          !layout.integer.contains("0") &&
          only_spaces {
          out.push({ kind: 1, text: token.text, })
        } else {
          xlsx_piece_text(out, token.text)
        }
      }
      1 | 2 => out.push({ kind: token.kind, text: token.text, })
      12 => xlsx_piece_text(out, integer)
      7 => xlsx_piece_text(out, "%")
      5 => {
        xlsx_piece_text(out, ".")
        if part == 0 {
          part = 1
        }
      }
      8 => {
        let marker = token.text[:1].to_owned()
        if exp_neg {
          xlsx_piece_text(out, marker + "-")
        } else if token.text.length() > 1 && token.text[1] == 43 {
          xlsx_piece_text(out, marker + "+")
        } else {
          xlsx_piece_text(out, marker)
        }
        part = 2
      }
      9 => {
        if layout.fraction && numerator == "" && denominator == "" {
          out.push({ kind: 1, text: "/", })
        } else {
          xlsx_piece_text(out, "/")
        }
        slash_seen = true
      }
      4 =>
        if layout.fraction && slash_seen {
          if den_idx < den_digits.length() {
            xlsx_append_digits(out, den_digits[den_idx])
          }
          den_idx += 1
        } else if layout.fraction && i >= num_start {
          if num_idx < num_digits.length() {
            xlsx_append_digits(out, num_digits[num_idx])
          }
          num_idx += 1
        } else if part == 0 {
          if int_idx < int_digits.length() {
            xlsx_append_digits(out, int_digits[int_idx])
          }
          int_idx += 1
        } else if part == 1 {
          if frac_idx < frac_digits.length() {
            xlsx_append_digits(out, frac_digits[frac_idx])
          }
          frac_idx += 1
        } else {
          if exp_idx < exp_digits.length() {
            xlsx_append_digits(out, exp_digits[exp_idx])
          }
          exp_idx += 1
        }
      _ => ()
    }
  }
  if layout.integer == "" &&
    !layout.general &&
    integer != "" &&
    integer != "-" &&
    !layout.fraction {
    for i in 0..<out.length() {
      if out[i].kind == 0 && out[i].text.has_prefix(".") {
        out.insert(i, { kind: 0, text: integer, })
        break
      }
    }
  }
  (out, general)
}
