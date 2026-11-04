///|
fn md_tag_name(tag : String) -> String {
  let lower = tag.trim().to_lower()
  let chars = lower.to_array()
  let mut start = 0
  if start < chars.length() && chars[start] == '/' {
    start += 1
  }
  let mut end = start
  while end < chars.length() &&
    !md_is_space(chars[end]) &&
    chars[end] != '/' &&
    chars[end] != '>' {
    end += 1
  }
  String::from_array(chars[start:end])
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
  let mut skip = 0 // 1 script, 2 style
  while i < chars.length() {
    let c = chars[i]
    if skip != 0 {
      if c == '<' {
        let mut j = i + 1
        while j < chars.length() && chars[j] != '>' {
          j += 1
        }
        let name = md_tag_name(String::from_array(chars[i + 1:j]))
        if skip == 1 && name == "script" || skip == 2 && name == "style" {
          let closing = j > i + 1 && chars[i + 1] == '/'
          if closing {
            skip = 0
          }
        }
        i = j + 1
      } else {
        i += 1
      }
      continue
    }
    if c == '<' {
      if i + 3 < chars.length() &&
        chars[i + 1] == '!' &&
        chars[i + 2] == '-' &&
        chars[i + 3] == '-' {
        let rest = String::from_array(chars[i + 4:])
        match rest.find("-->") {
          Some(index) => {
            i = i + 4 + index + 3
            continue
          }
          None => break
        }
      }
      let mut j = i + 1
      while j < chars.length() && chars[j] != '>' {
        j += 1
      }
      let tag = String::from_array(chars[i + 1:j])
      let name = md_tag_name(tag)
      let closing = tag.trim().has_prefix("/")
      if !closing && name == "script" {
        skip = 1
      } else if !closing && name == "style" {
        skip = 2
      } else if name == "br" {
        out.write_char('\n')
      } else if name == "img" {
        out.write_string(md_attr_in_tag(tag, "alt"))
      } else if closing &&
        (
          name == "p" ||
          name == "div" ||
          name == "li" ||
          name == "tr" ||
          name == "h1" ||
          name == "h2" ||
          name == "h3" ||
          name == "h4" ||
          name == "h5" ||
          name == "h6" ||
          name == "summary" ||
          name == "details" ||
          name == "blockquote"
        ) {
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
fn md_html_table(
  html : String,
  formulas : Array[String],
  svgs : Array[MdSvg],
  sprite : StringBuilder,
  images : Array[(String, String, String)],
) -> MdBlock? {
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
      md_push_text(text, md_style(bold=true), "", cell, formulas, svgs, sprite)
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
      md_push_text(text, md_style(), "", cell, formulas, svgs, sprite)
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
fn md_block_from_html(
  html : String,
  formulas : Array[String],
  images : Array[(String, String, String)],
  svgs : Array[MdSvg],
  sprite : StringBuilder,
  warnings : Array[String],
) -> Array[MdBlock] {
  let blocks : Array[MdBlock] = []
  let first_svg = svgs.length()
  let remaining = md_extract_block_svgs(html, svgs, sprite)
  let remaining_lower = remaining.to_lower()
  let mut search = 0
  while search < remaining_lower.length() {
    let at = match remaining_lower[search:].find("<img") {
      Some(index) => search + index
      None => break
    }
    let open_end = match remaining_lower[at:].find(">") {
      Some(index) => at + index
      None => break
    }
    if open_end + 1 > remaining.length() {
      break
    }
    let tag = remaining[at + 4:open_end].to_owned()
    let src = md_attr_in_tag(tag, "src")
    if src != "" && !src.has_prefix("data:") {
      md_warn_image(warnings, src)
    }
    search = open_end + 1
  }
  for i in first_svg..<svgs.length() {
    let runs : Array[MdRun] = []
    md_image_run(svgs[i], sprite, md_style(), "", runs)
    if !runs.is_empty() {
      blocks.push(MdParagraph(runs))
    }
  }
  match md_html_table(remaining, formulas, svgs, sprite, images) {
    Some(table) => blocks.push(table)
    None => {
      let text = md_strip_html(remaining)
      for paragraph in text.split("\n") {
        let value = paragraph.trim().to_string()
        if value != "" {
          let runs : Array[MdRun] = []
          md_push_text(value, md_style(), "", runs, formulas, svgs, sprite)
          blocks.push(MdParagraph(runs))
        }
      }
    }
  }
  blocks
}
