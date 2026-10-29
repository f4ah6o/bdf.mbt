///|
/// Formatted cell contents, including format color and numeric overflow hints.
pub(all) struct XlsxFormatted {
  pieces : Array[XlsxFormatPiece]
  color : UInt32?
  general : Bool
  number : Bool
}

///|
/// Concatenate the visible text pieces of a formatted cell.
pub fn XlsxFormatted::text(self : XlsxFormatted) -> String {
  let b = StringBuilder()
  for piece in self.pieces {
    if piece.kind == 0 {
      b.write_string(piece.text)
    }
  }
  b.to_string()
}

///|
fn xlsx_dbnum(text : String, kind : Int32) -> String {
  let digits = match kind {
    1 => ["〇", "一", "二", "三", "四", "五", "六", "七", "八", "九"]
    2 => ["〇", "壱", "弐", "参", "四", "伍", "六", "七", "八", "九"]
    3 => ["０", "１", "２", "３", "４", "５", "６", "７", "８", "９"]
    _ => return text
  }
  let b = StringBuilder()
  for c in text {
    if c >= '0' && c <= '9' {
      b.write_string(digits[c.to_int() - 48])
    } else {
      b.write_char(c)
    }
  }
  b.to_string()
}

///|
/// Apply a parsed XLSX number format to a numeric value.
pub fn xlsx_format_number(
  sections : Array[XlsxFormatSection],
  value : Double,
  date1904 : Bool,
) -> XlsxFormatted {
  if sections.length() == 0 {
    return { pieces: [], color: None, general: false, number: true, }
  }
  let (index, unsigned) = xlsx_select_format_section(sections, value)
  let section = sections[index]
  if section.date {
    return {
      pieces: xlsx_format_date(section, value, date1904).unwrap_or([
        { kind: 0, text: "#", },
      ]),
      color: section.color,
      general: false,
      number: true,
    }
  }
  let v = if unsigned { value.abs() } else { value }
  if section.tokens.length() == 0 {
    return { pieces: [], color: section.color, general: false, number: true, }
  }
  let mut only_text = section.text
  for token in section.tokens {
    if token.kind == 4 ||
      token.kind == 12 ||
      token.kind == 5 ||
      token.kind == 7 ||
      token.kind == 8 ||
      token.kind == 10 ||
      token.kind == 11 {
      only_text = false
    }
  }
  if only_text {
    return {
      pieces: [{ kind: 0, text: xlsx_format_general(v, 11), }],
      color: section.color,
      general: true,
      number: true,
    }
  }
  let (pieces, general) = xlsx_format_numeric(section, v)
  if section.dbnum > 0 {
    for i in 0..<pieces.length() {
      if pieces[i].kind == 0 {
        pieces[i] = {
          kind: 0,
          text: xlsx_dbnum(pieces[i].text, section.dbnum),
        }
      }
    }
  }
  { pieces, color: section.color, general, number: true, }
}

///|
/// Apply the text section of a parsed XLSX number format.
pub fn xlsx_format_text(
  sections : Array[XlsxFormatSection],
  text : String,
) -> XlsxFormatted {
  let mut selected = -1
  for i in 0..<sections.length() {
    if sections[i].text || i == 3 {
      selected = i
    }
  }
  if selected < 0 {
    return {
      pieces: [{ kind: 0, text, }],
      color: None,
      general: false,
      number: false,
    }
  }
  let section = sections[selected]
  let pieces : Array[XlsxFormatPiece] = []
  for token in section.tokens {
    match token.kind {
      3 => pieces.push({ kind: 0, text, })
      0 | 1 | 2 => pieces.push({ kind: token.kind, text: token.text, })
      _ => ()
    }
  }
  { pieces, color: section.color, general: false, number: false, }
}
