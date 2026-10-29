///|
fn xlsx_float_parts(value : Double) -> (@bigint.BigInt, Int32) {
  let bits = value.reinterpret_as_uint64()
  let raw = ((bits >> 52) & 0x7ffUL).to_int()
  let mantissa = (bits & 0xfffffffffffffUL) |
    (if raw == 0 { 0UL } else { 0x10000000000000UL })
  let n = @bigint.BigInt::from_uint64(mantissa)
  (
    if bits >> 63 != 0UL {
      -n
    } else {
      n
    },
    if raw == 0 {
      -1074
    } else {
      raw - 1075
    },
  )
}

///|
fn xlsx_round_binary(value : @bigint.BigInt, shift : Int32) -> @bigint.BigInt {
  if shift <= 0 {
    return value << -shift
  }
  let q = value >> shift
  let rem = value - (q << shift)
  let half = @bigint.BigInt::from_int(1) << (shift - 1)
  if rem > half || (rem == half && !(q % @bigint.BigInt::from_int(2)).is_zero()) {
    q + @bigint.BigInt::from_int(1)
  } else {
    q
  }
}

///|
// Fused multiply-add matches Go's hardware arithmetic on finite inputs.
fn xlsx_fma(a : Double, b : Double, c : Double) -> Double {
  if a.is_nan() ||
    b.is_nan() ||
    c.is_nan() ||
    a.is_inf() ||
    b.is_inf() ||
    c.is_inf() {
    return a * b + c
  }
  let (am, ae) = xlsx_float_parts(a)
  let (bm, be) = xlsx_float_parts(b)
  let (cm, ce) = xlsx_float_parts(c)
  let common = Int32::min(ae + be, ce)
  let sum = ((am * bm) << (ae + be - common)) + (cm << (ce - common))
  if sum.is_zero() {
    return 0.0
  }
  let negative = sum.compare_int(0) < 0
  let magnitude = if negative { -sum } else { sum }
  let mut exponent = common + magnitude.bit_length() - 1
  if exponent > 1023 {
    return (if negative { 0xfff0000000000000UL } else { 0x7ff0000000000000UL }).reinterpret_as_double()
  }
  let mut significand = if exponent < -1022 {
    xlsx_round_binary(magnitude, -1074 - common)
  } else {
    xlsx_round_binary(magnitude, magnitude.bit_length() - 53)
  }
  if exponent >= -1022 && significand.bit_length() > 53 {
    significand = significand >> 1
    exponent += 1
  }
  let sign = if negative { 0x8000000000000000UL } else { 0UL }
  if exponent > 1023 {
    return (sign | 0x7ff0000000000000UL).reinterpret_as_double()
  }
  if exponent < -1022 {
    return (sign | significand.to_uint64()).reinterpret_as_double()
  }
  (sign |
  ((exponent + 1023).to_uint64() << 52) |
  (significand.to_uint64() & 0xfffffffffffffUL)).reinterpret_as_double()
}
