///|
// Office Math (OMML) linearization for the text of a14:m elements.
//
// The output mirrors the DOCX converter's linearizer
// (convert/docx/document_text.mbt, docx_omml_linear) so that an equation
// reads the same whichever Office format holds it.

///|
fn pptx_omml_attr(
  node : PptxXmlNode,
  name : String,
  default : String,
) -> String {
  pptx_attribute(node.element, name, default)
}

///|
fn pptx_omml_join(node : PptxXmlNode) -> String {
  let out = StringBuilder()
  let mut previous : String? = None
  for child in node.children {
    let name = child.element.name.local_name
    if name == "rPr" ||
      name == "ctrlPr" ||
      name == "sdtPr" ||
      name == "bookmarkStart" ||
      name == "bookmarkEnd" {
      continue
    }
    let text = pptx_omml_linear(child)
    if text == "" {
      continue
    }
    match previous {
      Some(value) =>
        if pptx_omml_ends_function(value) && pptx_omml_starts_alnum(text) {
          out.write_string(" ")
        }
      None => ()
    }
    out.write_string(text)
    previous = Some(text)
  }
  out.to_string()
}

///|
// Whether text ends with the name of a function (sin, det, log …).
fn pptx_omml_ends_function(text : String) -> Bool {
  let names = [
    "arcsin", "arccos", "arctan", "sinh", "cosh", "tanh", "sin", "cos", "tan", "cot",
    "sec", "csc", "log", "ln", "exp", "lim", "max", "min", "det", "dim", "gcd", "sup",
    "inf", "arg",
  ]
  for name in names {
    if text.has_suffix(name) {
      // the name must be a word of its own, not the end of a longer one
      let before = text.length() - name.length()
      if before == 0 || !pptx_omml_is_letter(text[before - 1].to_int()) {
        return true
      }
    }
  }
  false
}

///|
fn pptx_omml_is_letter(code : Int32) -> Bool {
  (code >= 65 && code <= 90) || (code >= 97 && code <= 122)
}

///|
fn pptx_omml_starts_alnum(text : String) -> Bool {
  if text.length() == 0 {
    return false
  }
  let code = text[0].to_int()
  pptx_omml_is_letter(code) || (code >= 48 && code <= 57)
}

///|
fn pptx_omml_wrap(text : String) -> String {
  if text == "" {
    return text
  }
  let mut simple = text.length() == 1
  if text.length() > 1 {
    simple = true
    for c in text {
      if c == ' ' ||
        c == '+' ||
        c == '-' ||
        c == '=' ||
        c == ',' ||
        c == ';' ||
        c == '/' ||
        c == '*' ||
        c == '<' ||
        c == '>' ||
        c == '\u{2212}' ||
        c == '\u{00b1}' ||
        c == '\u{00d7}' ||
        c == '\u{00f7}' ||
        c == '\u{2211}' ||
        c == '\u{222b}' ||
        c == '\u{221a}' ||
        c == '\u{00b7}' ||
        c == '\u{2264}' ||
        c == '\u{2265}' ||
        c == '\u{2260}' ||
        c == '\u{221e}' ||
        c == '\u{03c0}' {
        simple = false
        break
      }
    }
  }
  if simple {
    text
  } else if text.length() >= 2 &&
    text[0] == '(' &&
    text[text.length() - 1] == ')' {
    text
  } else {
    "(" + text + ")"
  }
}

///|
fn pptx_omml_paren(text : String) -> String {
  if text.length() >= 2 && text[0] == '(' && text[text.length() - 1] == ')' {
    text
  } else {
    "(" + text + ")"
  }
}

///|
fn pptx_omml_node_text(node : PptxXmlNode?) -> String {
  match node {
    Some(value) => pptx_omml_join(value)
    None => ""
  }
}

///|
fn pptx_omml_linear(node : PptxXmlNode) -> String {
  let name = node.element.name.local_name
  match name {
    "t" => pptx_math_normalize(node.text.to_string())
    "r"
    | "e"
    | "num"
    | "den"
    | "sub"
    | "sup"
    | "deg"
    | "lim"
    | "fName"
    | "oMath" => pptx_omml_join(node)
    "oMathPara" => pptx_omml_join(node)
    "f" => {
      let num = pptx_omml_group(pptx_child(Some(node), "num"))
      let den = pptx_omml_group(pptx_child(Some(node), "den"))
      num + "/" + den
    }
    "rad" => {
      let body = pptx_omml_group(pptx_child(Some(node), "e"))
      let degree = pptx_omml_node_text(pptx_child(Some(node), "deg"))
      if degree == "" {
        "\u{221a}" + body
      } else {
        "\u{221a}(" + degree + "&" + body + ")"
      }
    }
    "sSup" => {
      let base = pptx_omml_group(pptx_child(Some(node), "e"))
      let sup = pptx_omml_group(pptx_child(Some(node), "sup"))
      base + "^" + sup
    }
    "sSub" => {
      let base = pptx_omml_group(pptx_child(Some(node), "e"))
      let sub = pptx_omml_group(pptx_child(Some(node), "sub"))
      base + "_" + sub
    }
    "sSubSup" => {
      let base = pptx_omml_group(pptx_child(Some(node), "e"))
      let sub = pptx_omml_group(pptx_child(Some(node), "sub"))
      let sup = pptx_omml_group(pptx_child(Some(node), "sup"))
      base + "_" + sub + "^" + sup
    }
    "sPre" => {
      let base = pptx_omml_group(pptx_child(Some(node), "e"))
      let sub = pptx_omml_group(pptx_child(Some(node), "sub"))
      let sup = pptx_omml_group(pptx_child(Some(node), "sup"))
      "_" + sub + "^" + sup + base
    }
    "nary" => {
      let chr = match pptx_child(Some(node), "naryPr") {
        Some(pr) => {
          let value = match pptx_child(Some(pr), "chr") {
            Some(element) => pptx_omml_attr(element, "val", "")
            None => ""
          }
          if value == "" {
            "\u{222b}"
          } else {
            value
          }
        }
        None => "\u{222b}"
      }
      let sub = pptx_omml_group(pptx_child(Some(node), "sub"))
      let sup = pptx_omml_group(pptx_child(Some(node), "sup"))
      let body = pptx_omml_node_text(pptx_child(Some(node), "e"))
      let mut out = chr
      if sub != "" {
        out += "_" + sub
      }
      if sup != "" {
        out += "^" + sup
      }
      if body != "" {
        out += " " + body
      }
      out
    }
    "func" => {
      let fname = pptx_omml_node_text(pptx_child(Some(node), "fName"))
      let body = pptx_omml_node_text(pptx_child(Some(node), "e"))
      fname + " " + body
    }
    "limLow" => {
      let base = pptx_omml_node_text(pptx_child(Some(node), "e"))
      let lim = pptx_omml_node_text(pptx_child(Some(node), "lim"))
      pptx_omml_wrap(base) + "_" + pptx_omml_wrap(lim)
    }
    "limUpp" => {
      let base = pptx_omml_node_text(pptx_child(Some(node), "e"))
      let lim = pptx_omml_node_text(pptx_child(Some(node), "lim"))
      pptx_omml_wrap(base) + "^" + pptx_omml_wrap(lim)
    }
    "d" => {
      let pr = pptx_child(Some(node), "dPr")
      let beg = match pr {
        Some(value) => {
          let attr = pptx_omml_attr(value, "begChr", "")
          if attr == "" {
            "("
          } else {
            attr
          }
        }
        None => "("
      }
      let end = match pr {
        Some(value) => {
          let attr = pptx_omml_attr(value, "endChr", "")
          if attr == "" {
            ")"
          } else {
            attr
          }
        }
        None => ")"
      }
      let body = pptx_omml_node_text(pptx_child(Some(node), "e"))
      if body.length() >= 2 && body.has_prefix(beg) && body.has_suffix(end) {
        body
      } else {
        beg + body + end
      }
    }
    "m" => {
      let rows : Array[String] = []
      for row in node.children {
        if row.element.name.local_name != "mr" {
          continue
        }
        let cells : Array[String] = []
        for cell in row.children {
          if cell.element.name.local_name == "e" {
            cells.push(pptx_omml_join(cell))
          }
        }
        rows.push(cells.join(", "))
      }
      rows.join("; ")
    }
    "acc" | "bar" | "groupChr" | "box" | "borderBox" | "phant" =>
      pptx_omml_node_text(pptx_child(Some(node), "e"))
    "eqArr" => {
      let rows : Array[String] = []
      for child in node.children {
        if child.element.name.local_name == "e" {
          rows.push(pptx_omml_join(child))
        }
      }
      rows.join("; ")
    }
    _ => pptx_omml_join(node)
  }
}

///|
// The font size of the first run of an Office Math element, in points.
fn pptx_math_size(node : PptxXmlNode) -> Double? {
  for child in node.children {
    if child.element.name.local_name == "rPr" {
      match pptx_attribute(child.element, "sz", "") {
        "" => ()
        text =>
          return Some((@string.parse_double(text) catch { _ => 0.0 }) / 100.0)
      }
    }
    match pptx_math_size(child) {
      Some(size) => return Some(size)
      None => ()
    }
  }
  None
}

///|
// Map the letters and digits of the Unicode mathematical alphanumeric
// styles (𝑥, 𝑏, 𝐴, …) to the plain characters they stand for: formulas
// read as the text they mean, like the upstream linear notation.
fn pptx_math_normalize(text : String) -> String {
  let out = StringBuilder()
  for c in text {
    let code = c.to_int()
    let mapped = pptx_math_normalized_code(code)
    if mapped >= 0 {
      out.write_char(Char::from_int(mapped))
    } else {
      out.write_char(c)
    }
  }
  out.to_string()
}

///|
fn pptx_math_style_code(
  code : Int32,
  start : Int32,
  upper_base : Int32,
  lower_base : Int32,
) -> Int32 {
  let offset = code - start
  if offset >= 0 && offset < 26 {
    upper_base + offset
  } else if offset >= 26 && offset < 52 {
    lower_base + offset - 26
  } else {
    -1
  }
}

///|
fn pptx_math_normalized_code(code : Int32) -> Int32 {
  let styles = [
    (0x1d400, 65, 97),
    (0x1d434, 65, 97),
    (0x1d468, 65, 97),
    (0x1d4d0, 65, 97),
    (0x1d56c, 65, 97),
    (0x1d5a0, 65, 97),
    (0x1d5d4, 65, 97),
    (0x1d608, 65, 97),
    (0x1d63c, 65, 97),
    (0x1d670, 65, 97),
  ]
  for (start, upper, lower) in styles {
    let mapped = pptx_math_style_code(code, start, upper, lower)
    if mapped >= 0 {
      return mapped
    }
  }
  if code >= 0x1d7ce && code <= 0x1d7d7 {
    return 48 + code - 0x1d7ce
  }
  if code >= 0x1d7d8 && code <= 0x1d7e1 {
    return 48 + code - 0x1d7d8
  }
  if code >= 0x1d7e2 && code <= 0x1d7eb {
    return 48 + code - 0x1d7e2
  }
  if code >= 0x1d7ec && code <= 0x1d7f5 {
    return 48 + code - 0x1d7ec
  }
  if code >= 0x1d7f6 && code <= 0x1d7ff {
    return 48 + code - 0x1d7f6
  }
  // mathematical italic Greek
  if code >= 0x1d6e2 && code <= 0x1d6fa {
    return 0x391 + code - 0x1d6e2
  }
  if code >= 0x1d6fc && code <= 0x1d714 {
    return 0x3b1 + code - 0x1d6fc
  }
  -1
}

///|
// Write an Office Math argument the way the linear notation groups it:
// in parentheses unless it is a single token.
fn pptx_omml_group(node : PptxXmlNode?) -> String {
  match node {
    Some(value) => {
      let text = pptx_omml_join(value).trim().to_owned()
      if text == "" {
        return text
      }
      if text.length() == 1 ||
        pptx_omml_is_simple(value) ||
        pptx_omml_is_fenced(text) {
        text
      } else {
        "(" + text + ")"
      }
    }
    None => ""
  }
}

///|
fn pptx_omml_is_simple(node : PptxXmlNode) -> Bool {
  let name = node.element.name.local_name
  match name {
    "r" => pptx_omml_join(node).trim().to_owned().length() <= 1
    "rad" =>
      match pptx_child(Some(node), "deg") {
        Some(value) => pptx_omml_join(value).trim() == ""
        None => true
      }
    "e" | "num" | "den" | "sub" | "sup" | "deg" | "lim" | "fName" =>
      match node.children.length() {
        1 => pptx_omml_is_simple(node.children[0])
        _ => false
      }
    _ => false
  }
}

///|
fn pptx_omml_fence_close(c : Char) -> Char {
  match c {
    '(' => ')'
    '[' => ']'
    '{' => '}'
    _ => '\u{0}'
  }
}

///|
fn pptx_omml_is_fenced(text : String) -> Bool {
  if text.length() < 2 {
    return false
  }
  let first = text[0].to_char().unwrap()
  let close = pptx_omml_fence_close(first)
  if close == '\u{0}' || text[text.length() - 1].to_char().unwrap() != close {
    return false
  }
  let mut depth = 0
  for i in 0..<text.length() {
    let c = text[i].to_char().unwrap()
    if c == first {
      depth += 1
    } else if c == close {
      depth -= 1
      if depth == 0 && i != text.length() - 1 {
        return false
      }
    }
  }
  depth == 0
}
