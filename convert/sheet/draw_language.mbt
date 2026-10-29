///|
fn grid_script(language : String) -> Int32 {
  let lang = language.to_lower()
  if lang.has_prefix("ja") {
    1
  } else if lang.has_prefix("zh-tw") ||
    lang.has_prefix("zh-hk") ||
    lang.has_prefix("zh-mo") ||
    lang.has_prefix("zh-hant") {
    3
  } else if lang.has_prefix("zh") {
    2
  } else if lang.has_prefix("ko") {
    4
  } else {
    0
  }
}

///|
fn grid_family(language : String) -> String {
  match grid_script(language) {
    1 => "\"游ゴシック\", sans-serif"
    2 => "\"等线\", sans-serif"
    3 => "\"新細明體\", serif"
    4 => "\"맑은 고딕\", sans-serif"
    _ => "\"Calibri\", sans-serif"
  }
}

///|
fn grid_han(c : Int32) -> Bool {
  (c >= 0x2e80 && c <= 0x2e99) ||
  (c >= 0x2e9b && c <= 0x2ef3) ||
  (c >= 0x2f00 && c <= 0x2fd5) ||
  c == 0x3005 ||
  c == 0x3007 ||
  (c >= 0x3021 && c <= 0x3029) ||
  (c >= 0x3038 && c <= 0x303b) ||
  (c >= 0x3400 && c <= 0x4dbf) ||
  (c >= 0x4e00 && c <= 0x9fff) ||
  (c >= 0xf900 && c <= 0xfa6d) ||
  (c >= 0xfa70 && c <= 0xfad9) ||
  (c >= 0x16fe2 && c <= 0x16fe3) ||
  (c >= 0x16ff0 && c <= 0x16ff6) ||
  (c >= 0x20000 && c <= 0x2a6df) ||
  (c >= 0x2a700 && c <= 0x2b81d) ||
  (c >= 0x2b820 && c <= 0x2cead) ||
  (c >= 0x2ceb0 && c <= 0x2ebe0) ||
  (c >= 0x2ebf0 && c <= 0x2ee5d) ||
  (c >= 0x2f800 && c <= 0x2fa1d) ||
  (c >= 0x30000 && c <= 0x3134a) ||
  (c >= 0x31350 && c <= 0x33479)
}

///|
fn grid_kana(c : Int32) -> Bool {
  (c >= 0x3041 && c <= 0x3096) ||
  (c >= 0x309d && c <= 0x309f) ||
  (c >= 0x1b001 && c <= 0x1b11f) ||
  c == 0x1b132 ||
  (c >= 0x1b150 && c <= 0x1b152) ||
  c == 0x1f200 ||
  (c >= 0x30a1 && c <= 0x30fa) ||
  (c >= 0x30fd && c <= 0x30ff) ||
  (c >= 0x31f0 && c <= 0x31ff) ||
  (c >= 0x32d0 && c <= 0x32fe) ||
  (c >= 0x3300 && c <= 0x3357) ||
  (c >= 0xff66 && c <= 0xff6f) ||
  (c >= 0xff71 && c <= 0xff9d) ||
  (c >= 0x1aff0 && c <= 0x1aff3) ||
  (c >= 0x1aff5 && c <= 0x1affb) ||
  (c >= 0x1affd && c <= 0x1affe) ||
  c == 0x1b000 ||
  (c >= 0x1b120 && c <= 0x1b122) ||
  c == 0x1b155 ||
  (c >= 0x1b164 && c <= 0x1b167)
}

///|
fn grid_hangul(c : Int32) -> Bool {
  (c >= 0x1100 && c <= 0x11ff) ||
  (c >= 0x302e && c <= 0x302f) ||
  (c >= 0x3131 && c <= 0x318e) ||
  (c >= 0x3200 && c <= 0x321e) ||
  (c >= 0x3260 && c <= 0x327e) ||
  (c >= 0xa960 && c <= 0xa97c) ||
  (c >= 0xac00 && c <= 0xd7a3) ||
  (c >= 0xd7b0 && c <= 0xd7c6) ||
  (c >= 0xd7cb && c <= 0xd7fb) ||
  (c >= 0xffa0 && c <= 0xffbe) ||
  (c >= 0xffc2 && c <= 0xffc7) ||
  (c >= 0xffca && c <= 0xffcf) ||
  (c >= 0xffd2 && c <= 0xffd7) ||
  (c >= 0xffda && c <= 0xffdc)
}

///|
fn grid_cell_language(
  lines : Array[WrappedLine],
  lang : String,
) -> (String, Bool) {
  let mut has_han = false
  for line in lines {
    for character in line.text {
      let c = character.to_int()
      if grid_kana(c) {
        return ("ja", true)
      }
      if grid_hangul(c) {
        return ("ko", true)
      }
      if is_cjk(c) && grid_han(c) {
        has_han = true
      }
    }
  }
  if !has_han {
    ("", true)
  } else if grid_script(lang) != 0 {
    (lang, true)
  } else {
    ("", false)
  }
}
