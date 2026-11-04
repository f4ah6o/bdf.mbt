///|
fn md_bool_attr(attrs : String, name : String) -> String {
  let needle = name + "=\""
  match attrs.find(needle) {
    Some(index) => {
      let start = index + needle.length()
      match attrs[start:].find("\"") {
        Some(length) => attrs[start:start + length].to_owned()
        None => ""
      }
    }
    None => ""
  }
}

///|
fn md_html_entity(text : String) -> String {
  match text {
    "&amp;" => "&"
    "&lt;" => "<"
    "&gt;" => ">"
    "&quot;" => "\""
    "&apos;" | "&#39;" => "'"
    "&nbsp;" => " "
    _ => {
      if text.has_prefix("&#x") || text.has_prefix("&#X") {
        let hex = text[3:text.length() - 1].to_owned()
        let value = @string.parse_int(hex, base=16) catch { _ => -1 }
        if value > 0 && value <= 0x10ffff {
          Char::from_int(value).to_string()
        } else {
          text
        }
      } else if text.has_prefix("&#") && text.has_suffix(";") {
        let digits = text[2:text.length() - 1].to_owned()
        let value = @string.parse_int(digits) catch { _ => -1 }
        if value > 0 && value <= 0x10ffff {
          Char::from_int(value).to_string()
        } else {
          text
        }
      } else {
        text
      }
    }
  }
}

///|
fn md_strip_html(html : String) -> String {
  let out = StringBuilder()
  let chars = html.to_array()
  let mut i = 0
  while i < chars.length() {
    let c = chars[i]
    if c == '<' {
      let mut j = i + 1
      while j < chars.length() && chars[j] != '>' {
        j += 1
      }
      let tag = String::from_array(chars[i + 1:j])
      let lower = tag.to_lower()
      if lower == "br" || lower == "br/" {
        out.write_char('\n')
      } else if lower.has_prefix("img") {
        out.write_string(md_bool_attr(tag, "alt"))
      } else if lower == "/p" ||
        lower == "/div" ||
        lower == "/li" ||
        lower == "/tr" ||
        lower == "/h1" ||
        lower == "/h2" ||
        lower == "/h3" ||
        lower == "/h4" ||
        lower == "/h5" ||
        lower == "/h6" ||
        lower == "/summary" ||
        lower == "/details" ||
        lower == "/blockquote" {
        out.write_char('\n')
      }
      i = j + 1
      continue
    }
    if c == '&' {
      let mut j = i + 1
      while j < chars.length() && chars[j] != ';' && j - i < 12 {
        j += 1
      }
      if j < chars.length() && chars[j] == ';' {
        out.write_string(md_html_entity(String::from_array(chars[i:j + 1])))
        i = j + 1
        continue
      }
    }
    out.write_char(c)
    i += 1
  }
  out.to_string()
}

///|
fn md_table_alignment(tag : String) -> Int {
  let lower = tag.to_lower()
  if lower.contains("center") {
    1
  } else if lower.contains("right") {
    2
  } else {
    0
  }
}

///|
fn md_html_cell_text(chars : Array[Char], start : Int) -> (String, Int) {
  let out = StringBuilder()
  let mut i = start
  while i < chars.length() {
    if chars[i] == '<' {
      let mut j = i + 1
      while j < chars.length() && chars[j] != '>' {
        j += 1
      }
      let tag = String::from_array(chars[i + 1:j]).to_lower()
      if tag.has_prefix("/td") || tag.has_prefix("/th") {
        return (md_strip_html(out.to_string()), j + 1)
      }
      if tag == "br" || tag == "br/" {
        out.write_char('\n')
      }
      i = j + 1
      continue
    }
    out.write_char(chars[i])
    i += 1
  }
  (md_strip_html(out.to_string()), i)
}

///|
fn md_html_table(html : String, formulas : Array[String]) -> MdBlock? {
  let lower = html.to_lower()
  let start = match lower.find("<table") {
    Some(index) => index
    None => return None
  }
  let header : Array[Array[MdRun]] = []
  let rows : Array[Array[Array[MdRun]]] = []
  let alignments : Array[Int] = []
  let chars = html.to_array()
  let mut i = start
  let mut current_row : Array[Array[MdRun]] = []
  let mut header_row = false
  while i < chars.length() {
    if chars[i] != '<' {
      i += 1
      continue
    }
    let mut j = i + 1
    while j < chars.length() && chars[j] != '>' {
      j += 1
    }
    let tag = String::from_array(chars[i + 1:j])
    let lower_tag = tag.to_lower()
    if lower_tag.has_prefix("tr") {
      current_row = []
      header_row = false
    } else if lower_tag.has_prefix("th") {
      header_row = true
      let align = md_table_alignment(tag)
      if alignments.length() < current_row.length() + 1 {
        alignments.push(align)
      }
      let (text, end) = md_html_cell_text(chars, j + 1)
      let cell : Array[MdRun] = []
      md_push_text(text, md_style(bold=true), "", cell, formulas)
      current_row.push(cell)
      i = end
      continue
    } else if lower_tag.has_prefix("td") {
      let align = md_table_alignment(tag)
      if alignments.length() < current_row.length() + 1 {
        alignments.push(align)
      }
      let (text, end) = md_html_cell_text(chars, j + 1)
      let cell : Array[MdRun] = []
      md_push_text(text, md_style(), "", cell, formulas)
      current_row.push(cell)
      i = end
      continue
    } else if lower_tag.has_prefix("/tr") {
      if header_row && header.is_empty() {
        for cell in current_row {
          header.push(cell)
        }
      } else if !current_row.is_empty() {
        rows.push(current_row)
      }
      current_row = []
    } else if lower_tag.has_prefix("/table") {
      break
    }
    i = j + 1
  }
  if current_row.length() > 0 {
    rows.push(current_row)
  }
  if header.is_empty() && rows.is_empty() {
    return None
  }
  Some(MdTable(header, rows, alignments))
}

///|
fn md_block_from_html(html : String, formulas : Array[String], warnings : Array[String]) -> Array[MdBlock] {
  let blocks : Array[MdBlock] = []
  match md_html_table(html, formulas) {
    Some(table) => blocks.push(table)
    None => {
      let text = md_strip_html(html)
      for paragraph in text.split("\n") {
        let value = paragraph.trim().to_string()
        if value != "" {
          let runs : Array[MdRun] = []
          md_push_text(value, md_style(), "", runs, formulas)
          blocks.push(MdParagraph(runs))
        }
      }
    }
  }
  let lower = html.to_lower()
  if lower.contains("<img") &&
    (lower.contains("src=\"http") || lower.contains("src=\"data:")) {
    warnings.push("Markdown images are drawn only when they are embedded as data URIs")
  }
  blocks
}
