///|
/// Resolve an ECMA-376 built-in number format, including Japanese formats.
pub fn xlsx_builtin_format(id : Int32, locale : String) -> String {
  if locale == "ja" {
    match id {
      5 => return "\"¥\"#,##0;\"¥\"\\-#,##0"
      6 => return "\"¥\"#,##0;[Red]\"¥\"\\-#,##0"
      7 => return "\"¥\"#,##0.00;\"¥\"\\-#,##0.00"
      8 => return "\"¥\"#,##0.00;[Red]\"¥\"\\-#,##0.00"
      14 => return "yyyy/m/d"
      22 => return "yyyy/m/d h:mm"
      42 =>
        return "_ \"¥\"* #,##0_ ;_ \"¥\"* \\-#,##0_ ;_ \"¥\"* \"-\"_ ;_ @_ "
      44 =>
        return "_ \"¥\"* #,##0.00_ ;_ \"¥\"* \\-#,##0.00_ ;_ \"¥\"* \"-\"??_ ;_ @_ "
      _ => ()
    }
  }
  match id {
    1 => "0"
    2 => "0.00"
    3 => "#,##0"
    4 => "#,##0.00"
    5 => "\"$\"#,##0_);(\"$\"#,##0)"
    6 => "\"$\"#,##0_);[Red](\"$\"#,##0)"
    7 => "\"$\"#,##0.00_);(\"$\"#,##0.00)"
    8 => "\"$\"#,##0.00_);[Red](\"$\"#,##0.00)"
    9 => "0%"
    10 => "0.00%"
    11 => "0.00E+00"
    12 => "# ?/?"
    13 => "# ??/??"
    14 => "m/d/yyyy"
    15 => "d-mmm-yy"
    16 => "d-mmm"
    17 => "mmm-yy"
    18 => "h:mm AM/PM"
    19 => "h:mm:ss AM/PM"
    20 => "h:mm"
    21 => "h:mm:ss"
    22 => "m/d/yyyy h:mm"
    27 => "[$-411]ge.m.d"
    28 => "[$-411]ggge\"年\"m\"月\"d\"日\""
    29 => "[$-411]ggge\"年\"m\"月\"d\"日\""
    30 => "m/d/yy"
    31 => "yyyy\"年\"m\"月\"d\"日\""
    32 => "h\"時\"mm\"分\""
    33 => "h\"時\"mm\"分\"ss\"秒\""
    34 => "yyyy\"年\"m\"月\""
    35 => "m\"月\"d\"日\""
    36 => "[$-411]ge.m.d"
    37 => "#,##0 ;(#,##0)"
    38 => "#,##0 ;[Red](#,##0)"
    39 => "#,##0.00;(#,##0.00)"
    40 => "#,##0.00;[Red](#,##0.00)"
    41 => "_(* #,##0_);_(* \\(#,##0\\);_(* \"-\"_);_(@_)"
    42 => "_(\"$\"* #,##0_);_(\"$\"* \\(#,##0\\);_(\"$\"* \"-\"_);_(@_)"
    43 => "_(* #,##0.00_);_(* \\(#,##0.00\\);_(* \"-\"??_);_(@_)"
    44 => "_(\"$\"* #,##0.00_);_(\"$\"* \\(#,##0.00\\);_(\"$\"* \"-\"??_);_(@_)"
    45 => "mm:ss"
    46 => "[h]:mm:ss"
    47 => "mmss.0"
    48 => "##0.0E+0"
    49 => "@"
    50 => "[$-411]ge.m.d"
    51 => "[$-411]ggge\"年\"m\"月\"d\"日\""
    52 => "yyyy\"年\"m\"月\""
    53 => "m\"月\"d\"日\""
    54 => "[$-411]ggge\"年\"m\"月\"d\"日\""
    55 => "yyyy\"年\"m\"月\""
    56 => "m\"月\"d\"日\""
    57 => "[$-411]ge.m.d"
    58 => "[$-411]ggge\"年\"m\"月\"d\"日\""
    _ => "General"
  }
}

///|
/// Resolve a number format, preferring an explicitly defined workbook format.
pub fn XlsxStyles::number_format(
  self : XlsxStyles,
  id : Int32,
  locale : String,
) -> String {
  self.number_formats.get(id).unwrap_or(xlsx_builtin_format(id, locale))
}

///|
/// Split a number format into sections at unquoted, unescaped semicolons.
pub fn xlsx_split_format_sections(code : String) -> Array[String] {
  let data = @utf8.encode(code)
  let out = []
  let mut start = 0
  let mut i = 0
  let mut quoted = false
  let mut bracket = false
  while i < data.length() {
    let c = data[i]
    if quoted {
      if c == b'"' {
        quoted = false
      }
    } else if c == b'"' {
      quoted = true
    } else if c == b'\\' || c == b'_' || c == b'*' {
      if i + 1 < data.length() {
        i += 1
        while i + 1 < data.length() && (data[i + 1].to_int() & 0xc0) == 0x80 {
          i += 1
        }
      }
    } else if c == b'[' {
      bracket = true
    } else if c == b']' {
      bracket = false
    } else if c == b';' && !bracket {
      out.push(@utf8.decode_lossy(data[start:i]))
      start = i + 1
    }
    i += 1
  }
  out.push(@utf8.decode_lossy(data[start:]))
  out
}
