///|
// Go math.Pow's integer exponent path for the decimal powers used here.
fn xlsx_pow10(exp : Int32) -> Double {
  if exp == 0 {
    return 1.0
  }
  if exp == 1 {
    return 10.0
  }
  let mut n = if exp < 0 { -exp } else { exp }
  let mut fraction = 0.625
  let mut binary_exp = 4
  let mut result = 1.0
  let mut result_exp = 0
  while n != 0 {
    if (n & 1) == 1 {
      result *= fraction
      result_exp += binary_exp
    }
    fraction *= fraction
    binary_exp *= 2
    if fraction < 0.5 {
      fraction += fraction
      binary_exp -= 1
    }
    n = n >> 1
  }
  if exp < 0 {
    result = 1.0 / result
    result_exp = -result_exp
  }
  let bits = result.reinterpret_as_uint64()
  let final_exp = result_exp + ((bits >> 52) & 0x7ffUL).to_int() - 1023
  if final_exp < -1075 {
    return 0.0
  }
  if final_exp > 1023 {
    return 0x7ff0000000000000UL.reinterpret_as_double()
  }
  let adjusted = if final_exp < -1022 { final_exp + 53 } else { final_exp }
  let output_bits = (bits & 0x800fffffffffffffUL) |
    ((adjusted + 1023).to_uint64() << 52)
  let output = output_bits.reinterpret_as_double()
  if final_exp < -1022 {
    output * (1.0 / 9007199254740992.0)
  } else {
    output
  }
}

///|
fn xlsx_pow10_big(n : Int32) -> @bigint.BigInt {
  @bigint.BigInt::from_int(10).pow(@bigint.BigInt::from_int(n))
}

///|
// Round the exact binary value times 10^scale to nearest, ties to even.
fn xlsx_scaled_integer(value : Double, scale : Int32) -> @bigint.BigInt {
  let bits = value.reinterpret_as_uint64()
  let exponent_bits = ((bits >> 52) & 0x7ffUL).to_int()
  let fraction = bits & 0xfffffffffffffUL
  let mantissa = if exponent_bits == 0 {
    fraction
  } else {
    fraction | 0x10000000000000UL
  }
  let exp2 = if exponent_bits == 0 { -1074 } else { exponent_bits - 1023 - 52 }
  let mut numerator = @bigint.BigInt::from_uint64(mantissa)
  let mut denominator = @bigint.BigInt::from_int(1)
  if scale >= 0 {
    numerator = numerator * xlsx_pow10_big(scale)
  } else {
    denominator = xlsx_pow10_big(-scale)
  }
  if exp2 >= 0 {
    numerator = numerator << exp2
  } else {
    denominator = denominator << -exp2
  }
  let q = numerator / denominator
  let rem = numerator % denominator
  let comparison = (rem << 1).compare(denominator)
  if comparison > 0 ||
    (comparison == 0 && !(q % @bigint.BigInt::from_int(2)).is_zero()) {
    q + @bigint.BigInt::from_int(1)
  } else {
    q
  }
}

///|
fn xlsx_round15(value : Double) -> Double {
  if value == 0.0 || value.is_nan() || value.is_inf() {
    return value
  }
  let mut exp = @math.log10(value).floor().to_int()
  if value >= xlsx_pow10(exp + 1) {
    exp += 1
  } else if value < xlsx_pow10(exp) {
    exp -= 1
  }
  let scale = 14 - exp
  let digits = xlsx_scaled_integer(value, scale).to_string()
  @string.parse_double(digits + "e" + (-scale).to_string()) catch {
    _ => value
  }
}

///|
fn xlsx_fixed(value : Double, decimals : Int32) -> String {
  if value.is_nan() {
    return "NaN"
  }
  if value.is_inf() {
    return if value < 0.0 { "-Inf" } else { "+Inf" }
  }
  let digits = xlsx_scaled_integer(value, decimals).to_string()
  if decimals == 0 {
    return digits
  }
  let out = StringBuilder()
  if digits.length() <= decimals {
    out.write_string("0.")
    for _ in 0..<(decimals - digits.length()) {
      out.write_char('0')
    }
    out.write_string(digits)
  } else {
    let split = digits.length() - decimals
    out.write_string(digits[:split].to_owned())
    out.write_char('.')
    out.write_string(digits[split:].to_owned())
  }
  out.to_string()
}

///|
fn xlsx_trim_decimal(value : String) -> String {
  if !value.contains(".") {
    return value
  }
  let mut end = value.length()
  while end > 0 && value[end - 1] == 48 {
    end -= 1
  }
  if end > 0 && value[end - 1] == 46 {
    end -= 1
  }
  value[:end].to_owned()
}

///|
/// Format a number using Excel's General format and a character budget.
pub fn xlsx_format_general(input : Double, max_chars : Int32) -> String {
  xlsx_format_general_inner(input, max_chars, 0)
}

///|
fn xlsx_format_general_inner(
  input : Double,
  max_chars : Int32,
  depth : Int32,
) -> String {
  if depth > 8 {
    return ""
  }
  if input == 0.0 || input.is_nan() {
    return "0"
  }
  if input.is_inf() {
    return "#NUM!"
  }
  let sign = if input < 0.0 { "-" } else { "" }
  let value = xlsx_round15(if input < 0.0 { -input } else { input })
  let mut exp = @math.log10(value).floor().to_int()
  if value >= xlsx_pow10(exp + 1) {
    exp += 1
  } else if value < xlsx_pow10(exp) {
    exp -= 1
  }
  if exp < 11 && exp >= -9 {
    let digits = Int32::max(exp + 1, 1)
    if digits <= max_chars {
      let decimals = Int32::min(Int32::max(max_chars - digits - 1, 0), 30)
      let text = xlsx_trim_decimal(xlsx_fixed(value, decimals))
      if text != "0" && text.length() <= max_chars {
        return sign + text
      }
    }
  }
  let exponent = if exp < 0 { -exp } else { exp }
  let exponent_text = (if exp < 0 { "E-" } else { "E+" }) +
    (if exponent < 10 { "0" } else { "" }) +
    exponent.to_string()
  let room = max_chars - exponent_text.length()
  if room < 1 {
    return ""
  }
  let magnitude = value / xlsx_pow10(exp)
  let mantissa = xlsx_fixed(magnitude, Int32::max(room - 2, 0))
  if mantissa.has_prefix("10") {
    return xlsx_format_general_inner(
      (if sign == "-" { -1.0 } else { 1.0 }) * xlsx_pow10(exp + 1),
      max_chars,
      depth + 1,
    )
  }
  sign + xlsx_trim_decimal(mantissa) + exponent_text
}

///|
// Go's portable math.Log polynomial, derived from FreeBSD msun/e_log.c:
// Copyright (C) 1993 by Sun Microsystems, Inc. All rights reserved.
// Developed at SunPro, a Sun Microsystems, Inc. business.
// Permission to use, copy, modify, and distribute this software is freely
// granted, provided that this notice is preserved.
fn xlsx_go_log10(value : Double) -> Double {
  if value == 0.0 || value.is_nan() || value.is_inf() || value < 0.0 {
    return @math.log10(value)
  }
  let normalized = if value < 2.2250738585072014e-308 {
    value * 4503599627370496.0
  } else {
    value
  }
  let correction = if value < 2.2250738585072014e-308 { -52 } else { 0 }
  let bits = normalized.reinterpret_as_uint64()
  let mut power = correction + ((bits >> 52) & 0x7ffUL).to_int() - 1023 + 1
  let mut fraction = ((bits & 0x800fffffffffffffUL) | (1022UL << 52)).reinterpret_as_double()
  if fraction < 0.7071067811865475244 {
    fraction *= 2.0
    power -= 1
  }
  let f = fraction - 1.0
  let k = power.to_double()
  let s = f / (2.0 + f)
  let s2 = s * s
  let s4 = s2 * s2
  let t1 = s2 *
    (
      0.6666666666666735130 +
      s4 *
      (
        0.2857142874366239149 +
        s4 * (0.1818357216161805012 + s4 * 0.1479819860511658591)
      )
    )
  let t2 = s4 *
    (
      0.3999999999940941908 +
      s4 * (0.2222219843214978396 + s4 * 0.1531383769920937332)
    )
  let r = t1 + t2
  let hfsq = 0.5 * f * f
  let log = k * 0.693147180369123816490 -
    (hfsq - (s * (hfsq + r) + k * 1.90821492927058770002e-10) - f)
  log * 0.43429448190325182765
}
