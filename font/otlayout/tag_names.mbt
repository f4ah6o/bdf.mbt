///|
/// OpenType's registered display name, including stylistic sets and character variants.
pub fn feature_name(tag : String) -> String {
  let name = registered_feature_name(tag)
  if name != "" {
    return name
  }
  let chars : Array[Char] = [ for c in tag => c ]
  if chars.length() != 4 ||
    chars[2] < '0' ||
    chars[2] > '9' ||
    chars[3] < '0' ||
    chars[3] > '9' {
    return ""
  }
  let n = (chars[2].to_int() - 48) * 10 + chars[3].to_int() - 48
  if chars[0] == 's' && chars[1] == 's' && n >= 1 && n <= 20 {
    "Stylistic Set " + n.to_string()
  } else if chars[0] == 'c' && chars[1] == 'v' && n >= 1 && n <= 99 {
    "Character Variant " + n.to_string()
  } else {
    ""
  }
}

///|
/// Return when a feature is applied: 0 optional, 1 default, 2 script-specific, 3 vertical.
pub fn feature_default(tag : String) -> Int32 {
  match tag {
    "abvm"
    | "blwm"
    | "calt"
    | "ccmp"
    | "clig"
    | "curs"
    | "dist"
    | "kern"
    | "liga"
    | "locl"
    | "mark"
    | "mkmk"
    | "rclt"
    | "rlig"
    | "rvrn" => 1
    "isol"
    | "init"
    | "medi"
    | "med2"
    | "fina"
    | "fin2"
    | "fin3"
    | "mset"
    | "stch"
    | "nukt"
    | "akhn"
    | "rphf"
    | "rkrf"
    | "pref"
    | "blwf"
    | "abvf"
    | "half"
    | "pstf"
    | "vatu"
    | "cjct"
    | "cfar"
    | "pres"
    | "abvs"
    | "blws"
    | "psts"
    | "haln"
    | "ljmo"
    | "vjmo"
    | "tjmo"
    | "ltra"
    | "ltrm"
    | "rtla"
    | "rtlm" => 2
    "vert" | "vrt2" | "vrtr" | "vkrn" => 3
    _ => 0
  }
}

///|
/// OpenType language-system display name, with trailing ASCII spaces ignored.
pub fn language_name(tag : String) -> String {
  let chars : Array[Char] = [ for c in tag => c ]
  let mut n = chars.length()
  while n > 0 && chars[n - 1] == ' ' {
    n -= 1
  }
  let out = StringBuilder()
  for i in 0..<n {
    out.write_char(chars[i])
  }
  registered_language_name(out.to_string())
}

///|
/// Describe a GSUB or GPOS lookup type using upstream's wording.
pub fn lookup_type_name(typ : Int32, gpos~ : Bool = false) -> String {
  let names = if gpos {
    [
      "", "single adjustment", "pair adjustment", "cursive attachment", "mark to base",
      "mark to ligature", "mark to mark", "contextual", "chained contextual", "extension",
    ]
  } else {
    [
      "", "single", "multiple", "alternate", "ligature", "contextual", "chained contextual",
      "extension", "reverse chaining",
    ]
  }
  if typ > 0 && typ < names.length() {
    names[typ]
  } else {
    "type " + typ.to_string()
  }
}
