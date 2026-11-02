///|
/// Best-effort LaTeX typesetting for labels: formulas are turned into
/// readable Unicode text instead of being laid out by a formula engine.
/// This covers the notation that flowchart and UML labels use — fractions,
/// roots, scripts, operators and Greek letters — and falls back to the
/// literal source (with a warning) for what it cannot simplify.
///
/// The delimiters are draw.io's: `$$…$$` and `\[…\]` for display formulas
/// and `\(…\)` for inline ones. AsciiMath between backquotes is left
/// alone.

///|
const DRAWIO_MATH_MAX_LEN : Int = 4096

///|
const DRAWIO_MATH_MAX_DEPTH : Int = 24

///|
fn drawio_math_symbol(name : String) -> String? {
  return match name {
    "pm" => Some("±")
    "mp" => Some("∓")
    "times" => Some("×")
    "div" => Some("÷")
    "cdot" => Some("·")
    "ast" => Some("∗")
    "star" => Some("⋆")
    "bullet" => Some("•")
    "circ" => Some("∘")
    "ne" | "neq" => Some("≠")
    "le" | "leq" => Some("≤")
    "ge" | "geq" => Some("≥")
    "ll" => Some("≪")
    "gg" => Some("≫")
    "approx" => Some("≈")
    "equiv" => Some("≡")
    "sim" => Some("∼")
    "propto" => Some("∝")
    "perp" => Some("⊥")
    "parallel" => Some("∥")
    "angle" => Some("∠")
    "degree" => Some("°")
    "prime" => Some("′")
    "therefore" => Some("∴")
    "because" => Some("∵")
    "to" | "rightarrow" | "longrightarrow" => Some("→")
    "leftarrow" | "longleftarrow" => Some("←")
    "leftrightarrow" => Some("↔")
    "Rightarrow" | "Longrightarrow" => Some("⇒")
    "Leftarrow" => Some("⇐")
    "Leftrightarrow" => Some("⇔")
    "mapsto" => Some("↦")
    "uparrow" => Some("↑")
    "downarrow" => Some("↓")
    "sum" => Some("∑")
    "prod" => Some("∏")
    "coprod" => Some("∐")
    "int" => Some("∫")
    "iint" => Some("∬")
    "iiint" => Some("∭")
    "oint" => Some("∮")
    "infty" => Some("∞")
    "partial" => Some("∂")
    "nabla" => Some("∇")
    "emptyset" => Some("∅")
    "forall" => Some("∀")
    "exists" => Some("∃")
    "in" => Some("∈")
    "notin" => Some("∉")
    "subset" => Some("⊂")
    "subseteq" => Some("⊆")
    "cup" => Some("∪")
    "cap" => Some("∩")
    "setminus" => Some("∖")
    "neg" | "lnot" => Some("¬")
    "land" | "wedge" => Some("∧")
    "lor" | "vee" => Some("∨")
    "oplus" => Some("⊕")
    "otimes" => Some("⊗")
    "ldots" | "dots" => Some("…")
    "cdots" => Some("⋯")
    "vdots" => Some("⋮")
    "ddots" => Some("⋱")
    "langle" => Some("⟨")
    "rangle" => Some("⟩")
    "lfloor" => Some("⌊")
    "rfloor" => Some("⌋")
    "lceil" => Some("⌈")
    "rceil" => Some("⌉")
    "lbrace" => Some("{")
    "rbrace" => Some("}")
    "lbrack" => Some("[")
    "rbrack" => Some("]")
    "backslash" => Some("\\")
    "colon" => Some(":")
    "vert" | "mid" => Some("|")
    "Vert" => Some("‖")
    "alpha" => Some("α")
    "beta" => Some("β")
    "gamma" => Some("γ")
    "delta" => Some("δ")
    "epsilon" | "varepsilon" => Some("ε")
    "zeta" => Some("ζ")
    "eta" => Some("η")
    "theta" => Some("θ")
    "vartheta" => Some("ϑ")
    "iota" => Some("ι")
    "kappa" => Some("κ")
    "lambda" => Some("λ")
    "mu" => Some("μ")
    "nu" => Some("ν")
    "xi" => Some("ξ")
    "omicron" => Some("ο")
    "pi" => Some("π")
    "varpi" => Some("ϖ")
    "rho" => Some("ρ")
    "varrho" => Some("ϱ")
    "sigma" => Some("σ")
    "varsigma" => Some("ς")
    "tau" => Some("τ")
    "upsilon" => Some("υ")
    "phi" => Some("φ")
    "varphi" => Some("ϕ")
    "chi" => Some("χ")
    "psi" => Some("ψ")
    "omega" => Some("ω")
    "Gamma" => Some("Γ")
    "Delta" => Some("Δ")
    "Theta" => Some("Θ")
    "Lambda" => Some("Λ")
    "Xi" => Some("Ξ")
    "Pi" => Some("Π")
    "Sigma" => Some("Σ")
    "Upsilon" => Some("Υ")
    "Phi" => Some("Φ")
    "Psi" => Some("Ψ")
    "Omega" => Some("Ω")
    "lim" => Some("lim")
    "sin" => Some("sin")
    "cos" => Some("cos")
    "tan" => Some("tan")
    "cot" => Some("cot")
    "sec" => Some("sec")
    "csc" => Some("csc")
    "log" => Some("log")
    "ln" => Some("ln")
    "lg" => Some("lg")
    "exp" => Some("exp")
    "max" => Some("max")
    "min" => Some("min")
    "sup" => Some("sup")
    "inf" => Some("inf")
    "det" => Some("det")
    "dim" => Some("dim")
    "gcd" => Some("gcd")
    "mod" => Some("mod")
    "arg" => Some("arg")
    "deg" => Some("deg")
    "quad" | "qquad" => Some(" ")
    "space" => Some(" ")
    _ => None
  }
}


fn drawio_math_is_letter(c : Char) -> Bool {
  (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z')
}

///|
fn drawio_math_skip_space(tex : String, start : Int) -> Int {
  let mut index = start
  while index < tex.length() {
    let c = tex[index].unsafe_to_char()
    if c == ' ' || c == '\t' || c == '\n' || c == '\r' {
      index += 1
    } else {
      break
    }
  }
  index
}

///|
/// The contents of the braced group that starts at `start` and the index
/// after its closing brace.
fn drawio_math_group(tex : String, start : Int) -> (String, Int) {
  let mut index = start
  if index >= tex.length() || tex[index].unsafe_to_char() != '{' {
    return ("", start)
  }
  index += 1
  let begin = index
  let mut depth = 1
  while index < tex.length() {
    let c = tex[index].unsafe_to_char()
    if c == '\\' {
      index += 2
      continue
    }
    if c == '{' {
      depth += 1
    } else if c == '}' {
      depth -= 1
      if depth == 0 {
        return (tex[begin:index].to_owned(), index + 1)
      }
    }
    index += 1
  }
  (tex[begin:].to_owned(), tex.length())
}

///|
/// One TeX argument: a braced group, a command, or a single character.
fn drawio_math_argument(tex : String, start : Int) -> (String, Int) {
  let index = drawio_math_skip_space(tex, start)
  if index >= tex.length() {
    return ("", index)
  }
  let c = tex[index].unsafe_to_char()
  if c == '{' {
    return drawio_math_group(tex, index)
  }
  if c == '\\' {
    let mut end = index + 1
    if end < tex.length() && drawio_math_is_letter(tex[end].unsafe_to_char()) {
      while end < tex.length() && drawio_math_is_letter(tex[end].unsafe_to_char()) {
        end += 1
      }
    } else if end < tex.length() {
      end += 1
    }
    return (tex[index:end].to_owned(), end)
  }
  (c.to_string(), index + 1)
}

///|
fn drawio_math_optional(tex : String, start : Int) -> (String, Int) {
  let index = drawio_math_skip_space(tex, start)
  if index < tex.length() && tex[index].unsafe_to_char() == '[' {
    let close = tex[index:].find("]")
    match close {
      Some(offset) => (tex[index + 1:index + offset].to_owned(), index + offset + 1)
      None => ("", index)
    }
  } else {
    ("", index)
  }
}

///|


///|
fn drawio_math_superscript(text : String) -> String? {
  if text == "" || text.length() > 8 {
    return None
  }
  let output = StringBuilder()
  for character in text {
    let mapped = match character {
      '0' => Some('⁰')
      '1' => Some('¹')
      '2' => Some('²')
      '3' => Some('³')
      '4' => Some('⁴')
      '5' => Some('⁵')
      '6' => Some('⁶')
      '7' => Some('⁷')
      '8' => Some('⁸')
      '9' => Some('⁹')
      '+' => Some('⁺')
      '-' => Some('⁻')
      '−' => Some('⁻')
      '=' => Some('⁼')
      '(' => Some('⁽')
      ')' => Some('⁾')
      'n' => Some('ⁿ')
      'i' => Some('ⁱ')
      'a' => Some('ᵃ')
      'b' => Some('ᵇ')
      'c' => Some('ᶜ')
      'd' => Some('ᵈ')
      'e' => Some('ᵉ')
      'f' => Some('ᶠ')
      'g' => Some('ᵍ')
      'h' => Some('ʰ')
      'j' => Some('ʲ')
      'k' => Some('ᵏ')
      'l' => Some('ˡ')
      'm' => Some('ᵐ')
      'o' => Some('ᵒ')
      'p' => Some('ᵖ')
      'r' => Some('ʳ')
      's' => Some('ˢ')
      't' => Some('ᵗ')
      'u' => Some('ᵘ')
      'v' => Some('ᵛ')
      'w' => Some('ʷ')
      'x' => Some('ˣ')
      'y' => Some('ʸ')
      'z' => Some('ᶻ')
      'T' => Some('ᵀ')
      _ => None
    }
    match mapped {
      Some(value) => output.write_char(value)
      None => return None
    }
  }
  Some(output.to_string())
}

///|
fn drawio_math_subscript(text : String) -> String? {
  if text == "" || text.length() > 8 {
    return None
  }
  let output = StringBuilder()
  for character in text {
    let mapped = match character {
      '0' => Some('₀')
      '1' => Some('₁')
      '2' => Some('₂')
      '3' => Some('₃')
      '4' => Some('₄')
      '5' => Some('₅')
      '6' => Some('₆')
      '7' => Some('₇')
      '8' => Some('₈')
      '9' => Some('₉')
      '+' => Some('₊')
      '-' => Some('₋')
      '−' => Some('₋')
      '=' => Some('₌')
      '(' => Some('₍')
      ')' => Some('₎')
      'a' => Some('ₐ')
      'e' => Some('ₑ')
      'h' => Some('ₕ')
      'i' => Some('ᵢ')
      'j' => Some('ⱼ')
      'k' => Some('ₖ')
      'l' => Some('ₗ')
      'm' => Some('ₘ')
      'n' => Some('ₙ')
      'o' => Some('ₒ')
      'p' => Some('ₚ')
      'r' => Some('ᵣ')
      's' => Some('ₛ')
      't' => Some('ₜ')
      'u' => Some('ᵤ')
      'v' => Some('ᵥ')
      'x' => Some('ₓ')
      _ => None
    }
    match mapped {
      Some(value) => output.write_char(value)
      None => return None
    }
  }
  Some(output.to_string())
}

///|
fn drawio_math_is_simple(text : String) -> Bool {
  if text == "" || text.length() > 4 {
    return false
  }
  for character in text {
    if character == ' ' || character == '\t' || character == '+' ||
      character == '-' || character == '±' || character == '=' ||
      character == '<' || character == '>' || character == '≤' ||
      character == '≥' || character == ',' || character == ';' ||
      character == '·' || character == '×' || character == '/' {
      return false
    }
  }
  true
}

///|
fn drawio_math_fraction(numerator : String, denominator : String) -> String {
  let top = sfc_drawio_trim(numerator)
  let bottom = sfc_drawio_trim(denominator)
  let top_text = if drawio_math_is_simple(top) { top } else { "(" + top + ")" }
  let bottom_text = if drawio_math_is_simple(bottom) { bottom } else { "(" + bottom + ")" }
  top_text + "/" + bottom_text
}

///|
fn drawio_math_root(index_text : String, body : String) -> String {
  let text = sfc_drawio_trim(body)
  let radix = match sfc_drawio_trim(index_text) {
    "" | "2" => "√"
    "3" => "∛"
    "4" => "∜"
    other => "√[" + other + "]"
  }
  if drawio_math_is_simple(text) || (text.length() <= 2 && !text.contains(" ")) {
    radix + text
  } else {
    radix + "(" + text + ")"
  }
}

///|
/// Split a matrix body into rows of cells at `&` and `\\` outside braces.
fn drawio_math_matrix_rows(body : String) -> Array[Array[String]] {
  let rows : Array[Array[String]] = []
  let cells : Array[String] = []
  let current = StringBuilder()
  let mut depth = 0
  let mut index = 0
  while index < body.length() {
    let c = body[index].unsafe_to_char()
    if c == '\\' && index + 1 < body.length() && body[index + 1].unsafe_to_char() == '\\' &&
      depth == 0 {
      cells.push(sfc_drawio_trim(current.to_string()))
      rows.push(cells.copy())
      cells.clear()
      current.reset()
      index += 2
      continue
    }
    if c == '&' && depth == 0 {
      cells.push(sfc_drawio_trim(current.to_string()))
      current.reset()
      index += 1
      continue
    }
    if c == '{' {
      depth += 1
    } else if c == '}' && depth > 0 {
      depth -= 1
    }
    current.write_char(c)
    index += 1
  }
  cells.push(sfc_drawio_trim(current.to_string()))
  rows.push(cells.copy())
  rows
}

///|
fn drawio_math_environment(env : String, body : String) -> String {
  let rows = drawio_math_matrix_rows(body)
  let lines : Array[String] = []
  for row in rows {
    let cells : Array[String] = []
    for cell in row {
      if cell != "" {
        cells.push(cell)
      }
    }
    if !cells.is_empty() {
      lines.push(cells.join(" "))
    }
  }
  let inner = lines.join("; ")
  if env == "pmatrix" || env == "bmatrix" || env == "matrix" || env == "smallmatrix" {
    "[" + inner + "]"
  } else if env == "Bmatrix" {
    "{" + inner + "}"
  } else if env == "vmatrix" {
    "|" + inner + "|"
  } else if env == "Vmatrix" {
    "‖" + inner + "‖"
  } else if env == "cases" {
    "{" + inner + "}"
  } else {
    inner
  }
}

///|
/// Convert one command. `start` is the index after the command's name;
/// the returned index is after the arguments the command consumed.
fn drawio_math_command(
  tex : String,
  name : String,
  start : Int,
  depth : Int,
  warn : DrawioWarn,
) -> (String, Int) {
  if name == "frac" || name == "dfrac" || name == "tfrac" {
    let (numerator, after_numerator) = drawio_math_argument(tex, start)
    let (denominator, after_denominator) = drawio_math_argument(tex, after_numerator)
    return (
      drawio_math_fraction(
        drawio_math_tex(numerator, depth + 1, warn),
        drawio_math_tex(denominator, depth + 1, warn),
      ),
      after_denominator,
    )
  }
  if name == "binom" || name == "dbinom" {
    let (top, after_top) = drawio_math_argument(tex, start)
    let (bottom, after_bottom) = drawio_math_argument(tex, after_top)
    return (
      "C(" + drawio_math_tex(top, depth + 1, warn) + "," +
      drawio_math_tex(bottom, depth + 1, warn) + ")",
      after_bottom,
    )
  }
  if name == "sqrt" {
    let (index_text, after_index) = drawio_math_optional(tex, start)
    let (body, after_body) = drawio_math_argument(tex, after_index)
    return (
      drawio_math_root(index_text, drawio_math_tex(body, depth + 1, warn)),
      after_body,
    )
  }
  if name == "text" || name == "textrm" || name == "textnormal" || name == "mbox" ||
    name == "mathrm" || name == "mathbf" || name == "mathit" || name == "mathsf" ||
    name == "mathtt" || name == "operatorname" || name == "mathcal" ||
    name == "boxed" {
    let (body, after_body) = drawio_math_argument(tex, start)
    return (drawio_math_tex(body, depth + 1, warn), after_body)
  }
  if name == "overline" || name == "underline" || name == "hat" || name == "bar" ||
    name == "vec" || name == "tilde" || name == "dot" || name == "ddot" ||
    name == "widehat" || name == "widetilde" {
    let (body, after_body) = drawio_math_argument(tex, start)
    return (drawio_math_tex(body, depth + 1, warn), after_body)
  }
  if name == "begin" {
    let (env, after_env) = drawio_math_group(tex, drawio_math_skip_space(tex, start))
    let marker = "\\end{" + env + "}"
    let rest = tex[after_env:].to_owned()
    let close = rest.find(marker)
    if env == "" || close is None {
      warn.once(
        "math-env",
        "drawio: math: an unsupported environment is drawn as text",
      )
      return ("", after_env)
    }
    let offset = close.unwrap()
    let body = rest[:offset].to_owned()
    let converted = drawio_math_environment(env, body)
    return (converted, after_env + offset + marker.length())
  }
  if name == "end" {
    let (_, after_env) = drawio_math_group(tex, drawio_math_skip_space(tex, start))
    return ("", after_env)
  }
  if name == "left" || name == "right" || name == "big" || name == "Big" ||
    name == "bigg" || name == "Bigg" || name == "bigl" || name == "bigr" ||
    name == "Bigl" || name == "Bigr" || name == "middle" {
    let index = drawio_math_skip_space(tex, start)
    if index < tex.length() && tex[index].unsafe_to_char() == '.' {
      return ("", index + 1)
    }
    return ("", index)
  }
  if name == "!" {
    return ("", start)
  }
  if name == " " || name == "," || name == ";" || name == ":" || name == ">" {
    return (" ", start)
  }
  if name == "displaystyle" || name == "textstyle" || name == "scriptstyle" ||
    name == "scriptscriptstyle" || name == "limits" || name == "nolimits" ||
    name == "vphantom" || name == "phantom" || name == "hphantom" {
    return ("", start)
  }
  if name == "\\" {
    return (" ", start)
  }
  if name == "{" {
    return ("{", start)
  }
  if name == "}" {
    return ("}", start)
  }
  if name == "$" {
    return ("$", start)
  }
  if name == "%" {
    return ("%", start)
  }
  if name == "&" {
    return ("&", start)
  }
  if name == "#" {
    return ("#", start)
  }
  if name == "_" {
    return ("_", start)
  }
  if name == "|" {
    return ("‖", start)
  }
  match drawio_math_symbol(name) {
    Some(symbol) => (symbol, start)
    None => {
      warn.once(
        "math:" + name,
        "drawio: math: the LaTeX command \\" + name + " is not supported; kept as text",
      )
      (name, start)
    }
  }
}

///|
fn drawio_math_tex(tex : String, depth : Int, warn : DrawioWarn) -> String {
  if depth > DRAWIO_MATH_MAX_DEPTH {
    warn.once(
      "math-depth",
      "drawio: math: a formula is nested too deeply; drawn as text",
    )
    return tex
  }
  let out = StringBuilder()
  let mut index = 0
  while index < tex.length() {
    let c = tex[index].unsafe_to_char()
    if c == '\\' {
      let start = index + 1
      if start >= tex.length() {
        out.write_char('\\')
        break
      }
      let first = tex[start].unsafe_to_char()
      if drawio_math_is_letter(first) {
        let mut end = start
        while end < tex.length() && drawio_math_is_letter(tex[end].unsafe_to_char()) {
          end += 1
        }
        let name = tex[start:end].to_owned()
        let (replacement, next) = drawio_math_command(tex, name, end, depth, warn)
        out.write_string(replacement)
        index = next
      } else {
        let name = first.to_string()
        let (replacement, next) = drawio_math_command(tex, name, start + 1, depth, warn)
        out.write_string(replacement)
        index = next
      }
    } else if c == '{' {
      let (body, next) = drawio_math_group(tex, index)
      out.write_string(drawio_math_tex(body, depth + 1, warn))
      index = next
    } else if c == '}' {
      index += 1
    } else if c == '^' || c == '_' {
      let (argument, next) = drawio_math_argument(tex, index + 1)
      let body = drawio_math_tex(argument, depth + 1, warn)
      if c == '^' {
        match drawio_math_superscript(body) {
          Some(value) => out.write_string(value)
          None => {
            out.write_string("^(")
            out.write_string(body)
            out.write_string(")")
          }
        }
      } else {
        match drawio_math_subscript(body) {
          Some(value) => out.write_string(value)
          None => {
            out.write_string("_(")
            out.write_string(body)
            out.write_string(")")
          }
        }
      }
      index = next
    } else if c == '&' || c == '~' {
      out.write_char(' ')
      index += 1
    } else if c == '\n' || c == '\r' || c == '\t' {
      out.write_char(' ')
      index += 1
    } else {
      out.write_char(c)
      index += 1
    }
  }
  out.to_string()
}

///|
/// The start of the next formula in `text`, or None.
fn drawio_math_next_open(text : String, from : Int) -> (Int, String, String, Bool)? {
  let mut index = from
  while index < text.length() {
    let c = text[index].unsafe_to_char()
    if c == '$' && index + 1 < text.length() && text[index + 1].unsafe_to_char() == '$' {
      return Some((index, "$$", "$$", true))
    }
    if c == '\\' && index + 1 < text.length() {
      let next = text[index + 1].unsafe_to_char()
      if next == '(' {
        return Some((index, "\\(", "\\)", false))
      }
      if next == '[' {
        return Some((index, "\\[", "\\]", true))
      }
    }
    index += 1
  }
  None
}

///|
/// Collapse runs of spaces to one, as TeX does.
fn drawio_math_collapse_spaces(text : String) -> String {
  let out = StringBuilder()
  let mut index = 0
  let mut space = false
  let mut wrote = false
  while index < text.length() {
    let c = text[index].unsafe_to_char()
    if c == ' ' || c == '\t' {
      space = true
    } else {
      if space && wrote {
        out.write_char(' ')
      }
      space = false
      out.write_char(c)
      wrote = true
    }
    index += 1
  }
  out.to_string()
}

///|
/// Whether a space has to be inserted before more text.
fn drawio_math_needs_space(out : StringBuilder) -> Bool {
  let text = out.to_string()
  if text == "" {
    return false
  }
  let last = text[text.length() - 1].unsafe_to_char()
  last != ' ' && last != '\n' && last != '\t'
}

///|
/// Replace the LaTeX formulas of a label with readable text. Returns the
/// new text and whether a formula was found. With `enabled` false (a
/// diagram without `math="1"`) the text is left as it is, like draw.io.
fn drawio_math_text(
  text : String,
  enabled : Bool,
  warn : DrawioWarn,
) -> (String, Bool) {
  if !enabled || (!text.contains("$") && !text.contains("\\(") && !text.contains("\\[")) {
    return (text, false)
  }
  let out = StringBuilder()
  let mut index = 0
  let mut converted = false
  while index < text.length() {
    match drawio_math_next_open(text, index) {
      None => {
        out.write_string(text[index:].to_owned())
        break
      }
      Some((start, open, close, display)) => {
        out.write_string(text[index:start].to_owned())
        if display && drawio_math_needs_space(out) {
          out.write_char(' ')
        }
        let body_start = start + open.length()
        let rest = text[body_start:].to_owned()
        let found = rest.find(close)
        match found {
          None => {
            warn.once(
              "math-unclosed",
              "drawio: math: an unclosed formula is drawn as text",
            )
            out.write_string(text[start:].to_owned())
            break
          }
          Some(offset) => {
            let body = rest[:offset].to_owned()
            if body.length() > DRAWIO_MATH_MAX_LEN {
              warn.once(
                "math-len",
                "drawio: math: a formula is too long to convert; drawn as text",
              )
              out.write_string(text[start:body_start + offset + close.length()].to_owned())
            } else {
              let simplified = drawio_math_collapse_spaces(drawio_math_tex(body, 0, warn))
              out.write_string(simplified)
              if simplified != "" && simplified != body {
                converted = true
              }
            }
            index = body_start + offset + close.length()
            if display && index < text.length() {
              let next = text[index].unsafe_to_char()
              if next != ' ' && next != '\n' && next != '\t' {
                out.write_char(' ')
              }
            }
          }
        }
      }
    }
  }
  (out.to_string(), converted)
}
