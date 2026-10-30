///|
// Match strconv.FormatFloat(number, 'g', 15) for comparisons without
// depending on its choice of scientific or decimal notation.
fn xlsx_conditional_duplicate_key(cell : XlsxCell) -> String? raise {
  if cell.kind == 0 || (cell.kind == 2 && xlsx_trim(cell.text) == "") {
    return None
  }
  if cell.kind == 1 {
    let number = cell.number
    if number.is_nan() || number.is_inf() {
      xlsx_reject_conditional()
    }
    let negative = number.reinterpret_as_uint64() >> 63 != 0UL
    let sign = if negative { "-" } else { "+" }
    if number == 0.0 {
      return Some("n" + sign + "0")
    }
    let magnitude = if negative { -number } else { number }
    let mut exponent = @math.log10(magnitude).floor().to_int()
    if xlsx_compare_decimal_power(magnitude, exponent + 1) >= 0 {
      exponent += 1
    } else if xlsx_compare_decimal_power(magnitude, exponent) < 0 {
      exponent -= 1
    }
    let mut scale = 14 - exponent
    let mut digits = xlsx_scaled_integer(magnitude, scale).to_string()
    if digits.length() < 15 {
      // Rounded powers of ten can be one exponent off for subnormals.
      scale += 15 - digits.length()
      digits = xlsx_scaled_integer(magnitude, scale).to_string()
    }
    if digits.length() > 15 {
      digits = digits[:digits.length() - 1].to_owned()
      scale -= 1
    }
    if digits.length() != 15 {
      xlsx_reject_conditional()
    }
    return Some("n" + sign + digits + ":" + scale.to_string())
  }
  let value = if cell.kind == 3 {
    if cell.number != 0.0 {
      "TRUE"
    } else {
      "FALSE"
    }
  } else if cell.kind == 2 || cell.kind == 4 {
    cell.text
  } else {
    xlsx_reject_conditional()
    ""
  }
  Some("s" + xlsx_go_lower(value))
}

///|
fn xlsx_conditional_duplicate_counts(
  rows : Array[XlsxRow],
  ranges : Array[XlsxRange],
  row_count : Int32,
  col_count : Int32,
) -> Map[String, Int32] raise {
  let counts : Map[String, Int32] = Map([])
  let seen : Map[Int32, Map[Int32, Bool]] = Map([])
  for range in ranges {
    let last_row = Int64::min(range.row_end, (row_count - 1).to_int64())
    let last_col = Int32::min(range.column_end, col_count - 1)
    for row in rows {
      if row.index.to_int64() < range.row_start ||
        row.index.to_int64() > last_row {
        continue
      }
      for cell in row.cells {
        if cell.column < range.column_start || cell.column > last_col {
          continue
        }
        let key = xlsx_conditional_duplicate_key(cell)
        if key is None {
          continue
        }
        let columns = match seen.get(row.index) {
          Some(columns) => columns
          None => {
            let columns : Map[Int32, Bool] = Map([])
            seen[row.index] = columns
            columns
          }
        }
        if !columns.contains(cell.column) {
          columns[cell.column] = true
          let key = key.unwrap()
          counts[key] = counts.get(key).unwrap_or(0) + 1
        }
      }
    }
  }
  counts
}

///|
// Compare a finite positive binary float to 10^exponent exactly. Rounded
// double powers can fall on the wrong side of a subnormal boundary.
fn xlsx_compare_decimal_power(value : Double, exponent : Int32) -> Int32 {
  let bits = value.reinterpret_as_uint64()
  let exponent_bits = ((bits >> 52) & 0x7ffUL).to_int()
  let fraction = bits & 0xfffffffffffffUL
  let mantissa = if exponent_bits == 0 {
    fraction
  } else {
    fraction | 0x10000000000000UL
  }
  let binary_exponent = if exponent_bits == 0 {
    -1074
  } else {
    exponent_bits - 1023 - 52
  }
  let mut numerator = @bigint.BigInt::from_uint64(mantissa)
  let mut denominator = @bigint.BigInt::from_int(1)
  if binary_exponent >= 0 {
    numerator = numerator << binary_exponent
  } else {
    denominator = denominator << -binary_exponent
  }
  if exponent >= 0 {
    denominator = denominator * xlsx_pow10_big(exponent)
  } else {
    numerator = numerator * xlsx_pow10_big(-exponent)
  }
  numerator.compare(denominator)
}
