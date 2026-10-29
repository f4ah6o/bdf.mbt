///|
/// Guess the text's language using its encoding and its kana or hangul.
pub fn guess_language(text : String, charset : String) -> String {
  match charset {
    "Shift_JIS" | "EUC-JP" | "ISO-2022-JP" => return "ja"
    "EUC-KR" => return "ko"
    "GBK" | "GB18030" => return "zh-CN"
    "BIG5" => return "zh-TW"
    _ => ()
  }
  let mut kana = 0
  let mut hangul = 0
  let mut offset = 0
  for c in text {
    if offset > 1048576 {
      break
    }
    let code = c.to_int()
    if csv_kana(code) {
      kana += 1
    } else if csv_hangul(code) {
      hangul += 1
    }
    offset += if code < 0x80 {
      1
    } else if code < 0x800 {
      2
    } else if code < 0x10000 {
      3
    } else {
      4
    }
  }
  if kana > 0 && kana >= hangul {
    "ja"
  } else if hangul > 0 {
    "ko"
  } else {
    ""
  }
}

///|
fn csv_kana(c : Int32) -> Bool {
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
fn csv_hangul(c : Int32) -> Bool {
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
