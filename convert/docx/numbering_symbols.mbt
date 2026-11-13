///|
/// Symbol-font list labels use legacy byte codes, not Unicode. Match the
/// upstream fontset mapping and fall back to the paragraph mark's fonts.
fn docx_numbering_is_symbol_font(font : String) -> Bool {
  match @fontdb.normalize(font) {
    "wingdings" | "wingdings2" | "wingdings3" | "symbol" | "webdings" => true
    _ => false
  }
}

///|
fn docx_numbering_map_symbol(font : String, text : String) -> String {
  let name = @fontdb.normalize(font)
  if name != "wingdings" && name != "symbol" {
    return text
  }
  let out = StringBuilder()
  for ch in text {
    let code = ch.to_int()
    let byte = if code >= 0xf000 && code <= 0xf0ff {
      code - 0xf000
    } else {
      code
    }
    let mapped = if name == "wingdings" {
      match byte {
        0x6c => '●'
        0x6d => '❍'
        0x6e => '■'
        0x6f => '□'
        0x70 => '◻'
        0x71 => '❑'
        0x72 => '❒'
        0x73 => '⬧'
        0x74 => '⧫'
        0x75 => '◆'
        0x76 => '❖'
        0x77 => '⬥'
        0x78 => '⌧'
        0xa7 => '▪'
        0xa8 => '◻'
        0x9f => '•'
        0xa1 => '○'
        0xa2 => '⭕'
        0xd8 => '➢'
        0xe0 | 0xe8 => '➔'
        0xfc => '✔'
        0xfb => '✘'
        0xfd => '☒'
        0xfe => '☑'
        0xf0 => '⇨'
        0xef => '⇦'
        0xd9 => '⮙'
        0xda => '⮛'
        0x46 => '☞'
        0x4a => '☺'
        0x4c => '☹'
        0xab => '★'
        0xb2 => '✧'
        0x2a => '✉'
        0x3e => '✇'
        0x3f => '✍'
        0x41 => '✌'
        0x43 => '👍'
        0x44 => '👎'
        0x51 => '✈'
        0x52 => '☼'
        0x54 => '❄'
        _ => Char::from_int(byte)
      }
    } else {
      match byte {
        0xb7 => '•'
        0xa8 => '♣'
        0xa9 => '♦'
        0xaa => '♥'
        0xab => '♠'
        0xae => '→'
        0xde => '⇒'
        0xd8 => '¬'
        0x2d => '−'
        0xb0 => '°'
        0xb1 => '±'
        0xb4 => '×'
        0xb8 => '÷'
        0xa5 => '∞'
        0x61 => 'α'
        0x62 => 'β'
        0x67 => 'γ'
        0x64 => 'δ'
        0x70 => 'π'
        0x6d => 'μ'
        0x53 => 'Σ'
        0x57 => 'Ω'
        0xe0 => '◊'
        _ => Char::from_int(byte)
      }
    }
    out.write_char(mapped)
  }
  out.to_string()
}
