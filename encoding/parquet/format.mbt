///|
/// The physical scalar of a leaf value, kept as the file stores it so that the
/// bytes of geometries, UUIDs, decimals and binary columns are not lost to a
/// lossy text decode.
priv enum ParquetScalar {
  ScalarNull
  ScalarBool(Bool)
  ScalarInt(Int64)
  ScalarDouble(Double)
  ScalarBytes(Bytes)
  ScalarInt96(Int64, Int64)
} derive(Eq, Debug)

///|
/// How the values of a leaf are shown: the logical type when it applies to the
/// physical type, else the converted type, else the physical type.
priv enum ParquetFormat {
  FormatBool
  FormatInt(Bool, Int) // signed, bit width
  FormatUInt(Int) // bit width
  FormatDecimal(Int) // scale
  FormatFloat
  FormatDouble
  FormatFloat16
  FormatDate
  FormatTime(Int) // unit
  FormatTimestamp(Int) // unit
  FormatInt96
  FormatString
  FormatJSON
  FormatUUID
  FormatInterval
  FormatGeometry
  FormatBinary // text when it is text, else hexadecimal
  FormatBytes // hexadecimal
  FormatNull
} derive(Eq, Debug)

///|
let parquet_unit_millis : Int = 1

///|
let parquet_unit_micros : Int = 2

///|
let parquet_unit_nanos : Int = 3

///|
fn parquet_is_bytes(physical : Int) -> Bool {
  physical == 6 || physical == 7
}

///|
/// What the format of a leaf depends on: the physical and converted types, the
/// length of fixed byte arrays, the scale of decimals, the logical type and
/// whether GeoParquet metadata marks the column as geometry.
priv struct ParquetFormatSource {
  physical : Int
  converted : Int
  type_length : Int
  scale : Int
  logical : ParquetLogicalType
  geo : Bool
  geo_kind : Int
}

///|
fn parquet_format_source(meta : ParquetMetaColumn) -> ParquetFormatSource {
  {
    physical: meta.physical,
    converted: meta.converted,
    type_length: meta.type_length,
    scale: meta.scale,
    logical: meta.logical,
    geo: meta.geo,
    geo_kind: meta.geo_kind,
  }
}

///|
fn parquet_format_logical(source : ParquetFormatSource) -> ParquetFormat? {
  let physical = source.physical
  let logical = source.logical
  let bytes = parquet_is_bytes(physical)
  match logical.kind {
    1 | 4 => if bytes { Some(FormatString) } else { None }
    5 =>
      if physical == 1 || physical == 2 || bytes {
        Some(FormatDecimal(source.scale))
      } else {
        None
      }
    6 => if physical == 1 { Some(FormatDate) } else { None }
    7 =>
      if (physical == 1 && logical.unit == parquet_unit_millis) ||
        (physical == 2 &&
          (logical.unit == parquet_unit_micros ||
            logical.unit == parquet_unit_nanos)) {
        Some(FormatTime(logical.unit))
      } else {
        None
      }
    8 =>
      if physical == 2 && logical.unit >= 1 && logical.unit <= 3 {
        Some(FormatTimestamp(logical.unit))
      } else {
        None
      }
    10 =>
      if physical == 1 || physical == 2 {
        if logical.signed {
          Some(FormatInt(true, logical.bit_width))
        } else {
          Some(FormatUInt(logical.bit_width))
        }
      } else {
        None
      }
    11 => Some(FormatNull)
    12 => if bytes { Some(FormatJSON) } else { None }
    13 => if bytes { Some(FormatBytes) } else { None }
    14 =>
      if physical == 7 && source.type_length == 16 {
        Some(FormatUUID)
      } else {
        None
      }
    15 =>
      if physical == 7 && source.type_length == 2 {
        Some(FormatFloat16)
      } else {
        None
      }
    17 | 18 =>
      if bytes {
        Some(if source.geo_kind == 2 { FormatString } else { FormatGeometry })
      } else {
        None
      }
    _ => None
  }
}

///|
fn parquet_format_converted(source : ParquetFormatSource) -> ParquetFormat {
  let physical = source.physical
  let bytes = parquet_is_bytes(physical)
  if source.geo && bytes {
    return if source.geo_kind == 2 { FormatString } else { FormatGeometry }
  }
  match source.converted {
    0 | 4 => if bytes { FormatString } else { parquet_format_physical(physical) }
    5 =>
      if physical == 1 || physical == 2 || bytes {
        FormatDecimal(source.scale)
      } else {
        parquet_format_physical(physical)
      }
    6 => if physical == 1 { FormatDate } else { parquet_format_physical(physical) }
    7 =>
      if physical == 1 {
        FormatTime(parquet_unit_millis)
      } else {
        parquet_format_physical(physical)
      }
    8 =>
      if physical == 2 {
        FormatTime(parquet_unit_micros)
      } else {
        parquet_format_physical(physical)
      }
    9 =>
      if physical == 2 {
        FormatTimestamp(parquet_unit_millis)
      } else {
        parquet_format_physical(physical)
      }
    10 =>
      if physical == 2 {
        FormatTimestamp(parquet_unit_micros)
      } else {
        parquet_format_physical(physical)
      }
    11 | 12 | 13 | 14 => FormatUInt(8 << (source.converted - 11))
    15 | 16 | 17 | 18 => FormatInt(true, 8 << (source.converted - 15))
    19 => if bytes { FormatJSON } else { parquet_format_physical(physical) }
    20 => if bytes { FormatBytes } else { parquet_format_physical(physical) }
    21 =>
      if physical == 7 && source.type_length == 12 {
        FormatInterval
      } else {
        parquet_format_physical(physical)
      }
    _ => parquet_format_physical(physical)
  }
}

///|
fn parquet_format_physical(physical : Int) -> ParquetFormat {
  match physical {
    0 => FormatBool
    1 => FormatInt(true, 32)
    2 => FormatInt(true, 64)
    3 => FormatInt96
    4 => FormatFloat
    5 => FormatDouble
    6 | 7 => FormatBinary
    _ => FormatBinary
  }
}

///|
fn parquet_format(source : ParquetFormatSource) -> ParquetFormat {
  match parquet_format_logical(source) {
    Some(format) => format
    None => parquet_format_converted(source)
  }
}

///|
fn parquet_node_format_source(node : ParquetSchemaNode) -> ParquetFormatSource {
  let scale = if node.logical.kind == 5 {
    node.logical.scale
  } else if node.converted == 5 {
    node.scale
  } else {
    0
  }
  {
    physical: node.physical,
    converted: node.converted,
    type_length: node.type_length,
    scale,
    logical: node.logical,
    geo: node.geo,
    geo_kind: node.geo_kind,
  }
}

///|
fn parquet_floor_div(value : Int64, divisor : Int64) -> Int64 {
  let quotient = value / divisor
  let remainder = value - quotient * divisor
  if remainder < 0L {
    quotient - 1L
  } else {
    quotient
  }
}

///|
fn parquet_civil_from_days(days : Int64) -> (Int64, Int64, Int64) {
  let z = days + 719468L
  let era = parquet_floor_div(z, 146097L)
  let doe = z - era * 146097L
  let yoe = (doe - doe / 1460L + doe / 36524L - doe / 146096L) / 365L
  let mut year = yoe + era * 400L
  let doy = doe - (365L * yoe + yoe / 4L - yoe / 100L)
  let mp = (5L * doy + 2L) / 153L
  let day = doy - (153L * mp + 2L) / 5L + 1L
  let month = if mp < 10L { mp + 3L } else { mp - 9L }
  if month <= 2L {
    year += 1L
  }
  (year, month, day)
}

///|
fn parquet_pad2(value : Int64) -> String {
  if value < 10L {
    "0" + value.to_string()
  } else {
    value.to_string()
  }
}

///|
fn parquet_pad4(value : Int64) -> String {
  let text = value.to_string()
  let mut padded = text
  while padded.length() < 4 {
    padded = "0" + padded
  }
  padded
}

///|
fn parquet_date_text(days : Int64) -> String {
  let (year, month, day) = parquet_civil_from_days(days)
  parquet_pad4(year) + "-" + parquet_pad2(month) + "-" + parquet_pad2(day)
}

///|
/// The fraction of a second of a time or timestamp, in the given number of
/// digits (nanoseconds of the value, zero padded).
fn parquet_frac_text(nanos : Int64, digits : Int) -> String {
  if digits <= 0 {
    return ""
  }
  let text = (nanos + 1000000000L).to_string()
  "." + text[1:1 + Int::min(digits, 9)].to_owned()
}

///|
fn parquet_clock_text(seconds : Int64, nanos : Int64, digits : Int) -> String {
  let mut second = seconds % 86400L
  if second < 0L {
    second += 86400L
  }
  parquet_pad2(second / 3600L) + ":" + parquet_pad2(second / 60L % 60L) + ":" +
  parquet_pad2(second % 60L) + parquet_frac_text(nanos, digits)
}

///|
fn parquet_timestamp_text(seconds : Int64, nanos : Int64, digits : Int) -> String {
  let days = parquet_floor_div(seconds, 86400L)
  let rest = seconds - days * 86400L
  parquet_date_text(days) + " " + parquet_clock_text(rest, nanos, digits)
}

///|
fn parquet_frac_digits(nanos : Int64) -> Int {
  if nanos == 0L {
    0
  } else if nanos % 1000000L == 0L {
    3
  } else if nanos % 1000L == 0L {
    6
  } else {
    9
  }
}

///|
fn parquet_format_max_digits(format : ParquetFormat) -> Int {
  match format {
    FormatInt96 => 9
    FormatTime(unit) | FormatTimestamp(unit) =>
      if unit == parquet_unit_nanos {
        9
      } else if unit == parquet_unit_micros {
        6
      } else {
        3
      }
    _ => 0
  }
}

///|
/// The seconds and nanoseconds of a time (of the day) or timestamp (since the
/// Unix epoch).
fn parquet_format_nanos(format : ParquetFormat, scalar : ParquetScalar) -> (Int64, Int64) {
  let mut seconds = 0L
  let mut nanos = 0L
  match (format, scalar) {
    (FormatInt96, ScalarInt96(value, julian)) => {
      let days = julian - 2440588L
      seconds = days * 86400L + value / 1000000000L
      nanos = value % 1000000000L
    }
    (FormatTime(unit), ScalarInt(value)) | (FormatTimestamp(unit), ScalarInt(value)) => {
      if unit == parquet_unit_millis {
        seconds = value / 1000L
        nanos = value % 1000L * 1000000L
      } else if unit == parquet_unit_micros {
        seconds = value / 1000000L
        nanos = value % 1000000L * 1000L
      } else {
        seconds = value / 1000000000L
        nanos = value % 1000000000L
      }
    }
    (_, _) => ()
  }
  if nanos < 0L {
    seconds -= 1L
    nanos += 1000000000L
  }
  (seconds, nanos)
}

///|
fn parquet_format_digits(format : ParquetFormat, scalar : ParquetScalar) -> Int {
  let (_, nanos) = parquet_format_nanos(format, scalar)
  Int::min(parquet_frac_digits(nanos), parquet_format_max_digits(format))
}

///|
fn parquet_hex_text(data : Bytes) -> String {
  let digits = "0123456789abcdef"
  let output = StringBuilder()
  output.write_string("0x")
  let limit = Int::min(data.length(), 32)
  for index in 0..<limit {
    let byte = data[index].to_int()
    output.write_char(digits.get_char(byte >> 4).unwrap())
    output.write_char(digits.get_char(byte & 0x0f).unwrap())
  }
  if data.length() > limit {
    output.write_string("… (" + data.length().to_string() + " bytes)")
  }
  output.to_string()
}

///|
fn parquet_uuid_text(data : Bytes) -> String {
  if data.length() != 16 {
    return parquet_hex_text(data)
  }
  let hex = parquet_hex_text(data)
  let digits = hex[2:].to_owned()
  digits[:8].to_owned() + "-" + digits[8:12].to_owned() + "-" +
  digits[12:16].to_owned() + "-" + digits[16:20].to_owned() + "-" +
  digits[20:].to_owned()
}

///|
fn parquet_binary_text(data : Bytes) -> String {
  if data.length() > 0 {
    let text = @utf8.decode(data) catch { _ => return parquet_hex_text(data) }
    let mut printable = true
    for character in text {
      let code = character.to_int()
      if (code < 0x20 && character != '\t' && character != '\n' &&
        character != '\r') ||
        code == 0x7f {
        printable = false
        break
      }
    }
    if printable {
      return text
    }
  }
  parquet_hex_text(data)
}

///|
fn parquet_text_text(data : BytesView) -> String {
  @utf8.decode_lossy(data)
}

///|
fn parquet_interval_text(data : Bytes) -> String {
  if data.length() != 12 {
    return parquet_hex_text(data)
  }
  let months = (data[0].to_int() | (data[1].to_int() << 8) |
    (data[2].to_int() << 16) |
    (data[3].to_int() << 24)).to_uint().to_int64()
  let days = (data[4].to_int() | (data[5].to_int() << 8) |
    (data[6].to_int() << 16) |
    (data[7].to_int() << 24)).to_uint().to_int64()
  let millis = (data[8].to_int() | (data[9].to_int() << 8) |
    (data[10].to_int() << 16) |
    (data[11].to_int() << 24)).to_uint().to_int64()
  let output = StringBuilder()
  output.write_char('P')
  let years = months / 12L
  if years > 0L {
    output.write_string(years.to_string() + "Y")
  }
  let rest_months = months % 12L
  if rest_months > 0L {
    output.write_string(rest_months.to_string() + "M")
  }
  if days > 0L {
    output.write_string(days.to_string() + "D")
  }
  if millis > 0L || output.to_string() == "P" {
    output.write_char('T')
    let seconds = millis / 1000L
    let hours = seconds / 3600L
    if hours > 0L {
      output.write_string(hours.to_string() + "H")
    }
    let minutes = seconds / 60L % 60L
    if minutes > 0L {
      output.write_string(minutes.to_string() + "M")
    }
    if seconds % 60L > 0L || millis % 1000L > 0L ||
      output.to_string() == "PT" {
      output.write_string((seconds % 60L).to_string())
      let fraction = millis % 1000L
      if fraction > 0L {
        let mut text = parquet_frac_text(fraction * 1000000L, 3)
        while text.has_suffix("0") {
          text = text[:text.length() - 1].to_owned()
        }
        output.write_string(text)
      }
      output.write_char('S')
    }
  }
  output.to_string()
}

///|
fn parquet_decimal_digits_text(signed : String, scale : Int) -> String {
  let negative = signed.has_prefix("-")
  let mut digits = if negative {
    signed[1:].to_owned()
  } else {
    signed
  }
  if scale > 0 && scale <= 1000 {
    while digits.length() <= scale {
      digits = "0" + digits
    }
    let cut = digits.length() - scale
    digits = digits[:cut].to_owned() + "." + digits[cut:].to_owned()
  } else if scale < 0 && scale >= -1000 {
    for _ in 0..<(-scale) {
      digits = digits + "0"
    }
  }
  if negative {
    "-" + digits
  } else {
    digits
  }
}

///|
fn parquet_decimal_int_text(value : Int64, scale : Int) -> String {
  parquet_decimal_digits_text(value.to_string(), scale)
}

///|
fn parquet_decimal_bytes_text(data : Bytes, scale : Int) -> String {
  if data.length() == 0 {
    return "0"
  }
  let mut value = @bigint.BigInt::from_octets(data, signum=1)
  if (data[0].to_int() & 0x80) != 0 {
    let modulus = @bigint.BigInt::shl(
      @bigint.BigInt::from_int(1),
      data.length() * 8,
    )
    value = @bigint.BigInt::sub(value, modulus)
  }
  parquet_decimal_digits_text(@bigint.BigInt::to_string(value), scale)
}

///|
/// Normalize the exponent of a floating-point number to at least two digits,
/// as Go writes it (1e-07 rather than 1e-7).
fn parquet_normalize_exponent(text : String) -> String {
  match text.find("e") {
    Some(index) => {
      let mantissa = text[:index].to_owned()
      let rest = text[index + 1:].to_owned()
      if rest.length() < 2 {
        return text
      }
      let sign = rest[:1].to_owned()
      let digits = rest[1:].to_owned()
      if digits.length() >= 2 {
        return text
      }
      mantissa + "e" + sign + "0" + digits
    }
    None => text
  }
}

///|
/// Show a floating-point number in its shortest form, with an exponent only
/// when it is very large or small (as JavaScript writes it).
fn parquet_float_text(value : Double, bits : Int) -> String {
  if value.is_nan() {
    return "NaN"
  }
  if value.is_inf() {
    if value > 0.0 {
      return "Infinity"
    }
    return "-Infinity"
  }
  let text = if bits == 32 {
    Float::from_double(value).to_string()
  } else {
    value.to_string()
  }
  parquet_normalize_exponent(text)
}

///|
fn parquet_half_value(half : Int) -> Double {
  let sign = if (half & 0x8000) != 0 { -1.0 } else { 1.0 }
  let exponent = (half >> 10) & 0x1f
  let fraction = (half & 0x3ff).to_double()
  match exponent {
    0 => sign * @math.scalbn(fraction, -24)
    31 =>
      if fraction != 0.0 {
        0x7ff8000000000000UL.reinterpret_as_double()
      } else {
        sign * 0x7ff0000000000000UL.reinterpret_as_double()
      }
    _ => sign * @math.scalbn(1024.0 + fraction, exponent - 25)
  }
}

///|
/// Show a half-precision number with the fewest digits that read back as it.
fn parquet_half_text(data : Bytes) -> String {
  if data.length() < 2 {
    return parquet_hex_text(data)
  }
  let half = data[0].to_int() | (data[1].to_int() << 8)
  let magnitude = half & 0x7fff
  let value = parquet_half_value(half)
  if magnitude == 0 || magnitude >= 0x7c00 {
    return parquet_float_text(value, 64)
  }
  let a = value.abs()
  let lo = parquet_half_value(magnitude - 1)
  let mut hi = parquet_half_value(magnitude + 1)
  if magnitude + 1 >= 0x7c00 {
    hi = a + (a - lo)
  }
  for precision in 0..<6 {
    let exponent = @math.floor(@math.log10(a)).to_int()
    let scale = @math.pow(10.0, (precision - exponent).to_double())
    let rounded = (a * scale).round() / scale
    let candidate = rounded.to_string()
    let parsed = @string.parse_double(candidate) catch {
      _ => continue
    }
    if (parsed - a).abs() < (parsed - lo).abs() &&
      (parsed - a).abs() < (parsed - hi).abs() {
      return parquet_float_text(if value < 0.0 { -parsed } else { parsed }, 64)
    }
  }
  parquet_float_text(value, 64)
}

///|
fn parquet_unsigned_text(value : Int64, width : Int) -> String {
  let bits = value.reinterpret_as_uint64()
  let mask = if width >= 64 {
    0xffffffffffffffffUL
  } else {
    (1UL << width) - 1UL
  }
  (bits & mask).to_string()
}

///|
fn parquet_unsigned_fits_int64(value : Int64, width : Int) -> Bool {
  let bits = value.reinterpret_as_uint64()
  let mask = if width >= 64 {
    0xffffffffffffffffUL
  } else {
    (1UL << width) - 1UL
  }
  (bits & mask) <= 0x7fffffffffffffffUL
}

///|
fn parquet_scalar_text(
  format : ParquetFormat,
  scalar : ParquetScalar,
  digits~ : Int = -1,
) -> String {
  match (format, scalar) {
    (_, ScalarNull) => ""
    (FormatNull, _) => ""
    (FormatBool, ScalarBool(value)) => if value { "true" } else { "false" }
    (FormatInt(signed, width), ScalarInt(value)) =>
      if signed {
        value.to_string()
      } else {
        parquet_unsigned_text(value, width)
      }
    (FormatUInt(width), ScalarInt(value)) =>
      parquet_unsigned_text(value, width)
    (FormatDecimal(scale), ScalarInt(value)) =>
      parquet_decimal_int_text(value, scale)
    (FormatDecimal(scale), ScalarBytes(value)) =>
      parquet_decimal_bytes_text(value, scale)
    (FormatFloat, ScalarDouble(value)) => parquet_float_text(value, 32)
    (FormatFloat16, ScalarBytes(value)) => parquet_half_text(value)
    (FormatDouble, ScalarDouble(value)) => parquet_float_text(value, 64)
    (FormatDate, ScalarInt(value)) => parquet_date_text(value)
    (FormatTime(_), ScalarInt(value)) => {
      let (seconds, nanos) = parquet_format_nanos(format, scalar)
      let used = if digits >= 0 {
        digits
      } else {
        parquet_format_digits(format, scalar)
      }
      let _ = value
      parquet_clock_text(seconds, nanos, used)
    }
    (FormatTimestamp(_), ScalarInt(value)) => {
      let (seconds, nanos) = parquet_format_nanos(format, scalar)
      let used = if digits >= 0 {
        digits
      } else {
        parquet_format_digits(format, scalar)
      }
      let _ = value
      parquet_timestamp_text(seconds, nanos, used)
    }
    (FormatInt96, ScalarInt96(value, julian)) => {
      let (seconds, nanos) = parquet_format_nanos(format, scalar)
      let used = if digits >= 0 {
        digits
      } else {
        parquet_format_digits(format, scalar)
      }
      let _ = value
      let _ = julian
      parquet_timestamp_text(seconds, nanos, used)
    }
    (FormatString, ScalarBytes(value)) => parquet_text_text(value)
    (FormatJSON, ScalarBytes(value)) => parquet_text_text(value)
    (FormatUUID, ScalarBytes(value)) => parquet_uuid_text(value)
    (FormatInterval, ScalarBytes(value)) => parquet_interval_text(value)
    (FormatGeometry, ScalarBytes(value)) =>
      match parquet_wkb_text(value) {
        Some(text) => text
        None => parquet_hex_text(value)
      }
    (FormatBinary, ScalarBytes(value)) => parquet_binary_text(value)
    (FormatBytes, ScalarBytes(value)) => parquet_hex_text(value)
    (_, _) => ""
  }
}

///|
/// Escape a string as JSON writes it.
fn parquet_json_escape(text : String) -> String {
  let output = StringBuilder()
  for character in text {
    let code = character.to_int()
    if character == '"' || character == '\\' {
      output.write_char('\\')
      output.write_char(character)
    } else if character == '\n' {
      output.write_string("\\n")
    } else if character == '\r' {
      output.write_string("\\r")
    } else if character == '\t' {
      output.write_string("\\t")
    } else if code < 0x20 || code == 0x7f {
      let hex = "0123456789abcdef"
      output.write_string("\\u00")
      output.write_char(hex.get_char(code >> 4).unwrap())
      output.write_char(hex.get_char(code & 0x0f).unwrap())
    } else {
      output.write_char(character)
    }
  }
  output.to_string()
}

///|
fn parquet_format_quoted(format : ParquetFormat) -> Bool {
  match format {
    FormatBool | FormatInt(_, _) | FormatUInt(_) | FormatDecimal(_) |
    FormatFloat | FormatDouble | FormatFloat16 | FormatJSON | FormatNull => false
    _ => true
  }
}

///|
fn parquet_scalar_json(
  format : ParquetFormat,
  scalar : ParquetScalar,
  digits~ : Int = -1,
) -> String {
  match format {
    FormatNull => return "null"
    _ => ()
  }
  if scalar is ScalarNull {
    return "null"
  }
  let text = parquet_scalar_text(format, scalar, digits~)
  if parquet_format_quoted(format) {
    "\"" + parquet_json_escape(text) + "\""
  } else {
    text
  }
}

///|
fn parquet_scalar_value(
  format : ParquetFormat,
  scalar : ParquetScalar,
  digits~ : Int = -1,
) -> Value {
  match (format, scalar) {
    (_, ScalarNull) => Null
    (FormatNull, _) => Null
    (FormatBool, ScalarBool(value)) => BooleanValue(value)
    (FormatInt(signed, width), ScalarInt(value)) =>
      if signed {
        IntegerValue(value)
      } else if parquet_unsigned_fits_int64(value, width) {
        IntegerValue(
          (value.reinterpret_as_uint64() &
            (if width >= 64 {
              0xffffffffffffffffUL
            } else {
              (1UL << width) - 1UL
            })).reinterpret_as_int64(),
        )
      } else {
        StringValue(parquet_unsigned_text(value, width))
      }
    (FormatUInt(width), ScalarInt(value)) =>
      if parquet_unsigned_fits_int64(value, width) {
        IntegerValue(
          (value.reinterpret_as_uint64() &
            (if width >= 64 {
              0xffffffffffffffffUL
            } else {
              (1UL << width) - 1UL
            })).reinterpret_as_int64(),
        )
      } else {
        StringValue(parquet_unsigned_text(value, width))
      }
    (FormatDecimal(_), _) => StringValue(parquet_scalar_text(format, scalar))
    (FormatFloat, ScalarDouble(_)) =>
      StringValue(parquet_scalar_text(format, scalar))
    (FormatFloat16, ScalarBytes(value)) =>
      StringValue(parquet_half_text(value))
    (FormatDouble, ScalarDouble(value)) => NumberValue(value)
    (FormatDate, ScalarInt(value)) => DateValue(value)
    (FormatTimestamp(unit), ScalarInt(value)) =>
      if unit == parquet_unit_millis {
        DateTimeValue(value)
      } else {
        StringValue(parquet_scalar_text(format, scalar, digits~))
      }
    (FormatInt96, _) =>
      StringValue(parquet_scalar_text(format, scalar, digits~))
    (FormatString, ScalarBytes(value)) => StringValue(parquet_text_text(value))
    (FormatJSON, ScalarBytes(value)) => StringValue(parquet_text_text(value))
    (FormatUUID, ScalarBytes(value)) => StringValue(parquet_uuid_text(value))
    (FormatInterval, ScalarBytes(value)) =>
      StringValue(parquet_interval_text(value))
    (FormatGeometry, ScalarBytes(value)) =>
      StringValue(
        match parquet_wkb_text(value) {
          Some(text) => text
          None => parquet_hex_text(value)
        },
      )
    (FormatBinary, ScalarBytes(value)) => StringValue(parquet_binary_text(value))
    (FormatBytes, ScalarBytes(value)) => StringValue(parquet_hex_text(value))
    (FormatTime(_), ScalarInt(_)) =>
      StringValue(parquet_scalar_text(format, scalar, digits~))
    (_, _) => Null
  }
}

///|
fn parquet_format_kind(format : ParquetFormat, physical : Int) -> ColumnType {
  match format {
    FormatBool => BooleanColumn
    FormatDate => DateColumn
    FormatTime(_) | FormatString | FormatJSON | FormatUUID | FormatInterval |
    FormatGeometry | FormatBinary | FormatBytes | FormatNull => StringColumn
    FormatTimestamp(_) | FormatInt96 => DateTimeColumn
    FormatFloat | FormatDouble | FormatFloat16 | FormatDecimal(_) =>
      NumberColumn
    FormatInt(_, _) | FormatUInt(_) => IntegerColumn
  }
}
