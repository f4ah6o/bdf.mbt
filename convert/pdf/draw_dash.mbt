///|
// The upstream interpreter deduplicates dash state by formatting every
// component to four decimal places. Round the exact binary value, not an
// already-rounded multiplication, to match Go's formatting at ties.
fn pdf_dash_number_key(value : Double) -> String {
  if value.is_nan() {
    return "NaN"
  }
  if value.is_inf() {
    return if value < 0.0 { "-Inf" } else { "+Inf" }
  }
  let bits = value.reinterpret_as_uint64()
  let negative = bits >> 63 != 0UL
  let exponent = ((bits >> 52) & 0x7ffUL).to_int()
  let fraction = bits & 0xfffffffffffffUL
  let mantissa = if exponent == 0 {
    fraction
  } else {
    fraction | 0x10000000000000UL
  }
  let power = if exponent == 0 { -1074 } else { exponent - 1023 - 52 }
  let mut numerator = @bigint.BigInt::from_uint64(mantissa) *
    @bigint.BigInt::from_int(10000)
  let mut denominator = @bigint.BigInt::from_int(1)
  if power >= 0 {
    numerator = numerator << power
  } else {
    denominator = denominator << -power
  }
  let quotient = numerator / denominator
  let remainder = numerator % denominator
  let cmp = (remainder << 1).compare(denominator)
  let rounded = if cmp > 0 ||
    (cmp == 0 && !(quotient % @bigint.BigInt::from_int(2)).is_zero()) {
    quotient + @bigint.BigInt::from_int(1)
  } else {
    quotient
  }
  (if negative { "-" } else { "" }) + rounded.to_string()
}

///|
fn pdf_dash_key(segments : Array[Double], phase : Double) -> String {
  if segments.is_empty() {
    return ""
  }
  let out = StringBuilder()
  for segment in segments {
    out.write_string(pdf_dash_number_key(segment))
    out.write_char(',')
  }
  out.write_string(pdf_dash_number_key(phase))
  out.to_string()
}
