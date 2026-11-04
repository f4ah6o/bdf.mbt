///|
// A small LaTeX-to-linear-text converter for the mathematics GitHub renders in
// Markdown. It is not a typesetter: it produces the text a formula contributes
// to BDF's searchable runs, the way the upstream converter does.
priv struct MdLatex {
  chars : Array[Char]
  mut i : Int
}

///|
fn md_latex_command_map(name : String) -> String? {
  match name {
    "alpha" => Some("α")
    "beta" => Some("β")
    "gamma" => Some("γ")
    "delta" => Some("δ")
    "epsilon" | "varepsilon" => Some("ε")
    "zeta" => Some("ζ")
    "eta" => Some("η")
    "theta" => Some("θ")
    "iota" => Some("ι")
    "kappa" => Some("κ")
    "lambda" => Some("λ")
    "mu" => Some("μ")
    "nu" => Some("ν")
    "xi" => Some("ξ")
    "pi" => Some("π")
    "rho" => Some("ρ")
    "sigma" => Some("σ")
    "tau" => Some("τ")
    "upsilon" => Some("υ")
    "phi" | "varphi" => Some("φ")
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
    "cdot" => Some("⋅")
    "times" => Some("×")
    "div" => Some("÷")
    "pm" => Some("±")
    "mp" => Some("∓")
    "le" | "leq" => Some("≤")
    "ge" | "geq" => Some("≥")
    "neq" | "ne" => Some("≠")
    "approx" => Some("≈")
    "equiv" => Some("≡")
    "infty" => Some("∞")
    "partial" => Some("∂")
    "nabla" => Some("∇")
    "sum" => Some("∑")
    "prod" => Some("∏")
    "int" => Some("∫")
    "iint" => Some("∬")
    "iiint" => Some("∭")
    "oint" => Some("∮")
    "sqrt" => Some("√")
    "to" | "rightarrow" => Some("→")
    "leftarrow" => Some("←")
    "mapsto" => Some("↦")
    "in" => Some("∈")
    "notin" => Some("∉")
    "subseteq" => Some("⊆")
    "supseteq" => Some("⊇")
    "cup" => Some("∪")
    "cap" => Some("∩")
    "forall" => Some("∀")
    "exists" => Some("∃")
    "emptyset" => Some("∅")
    "angle" => Some("∠")
    "degree" => Some("°")
    "prime" => Some("'")
    "ldots" | "dots" => Some("…")
    "cdots" => Some("⋯")
    "vdots" => Some("⋮")
    "ddots" => Some("⋱")
    "quad" | "qquad" => Some(" ")
    "," | ";" => Some(" ")
    ":" | "!" => Some("")
    "{" => Some("{")
    "}" => Some("}")
    "|" => Some("‖")
    "langle" => Some("⟨")
    "rangle" => Some("⟩")
    "lvert" | "rvert" => Some("|")
    "lVert" | "rVert" => Some("‖")
    _ => None
  }
}

///|
fn md_latex_wrap(text : String) -> String {
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
        c == '\u2212' ||
        c == '\u00b1' ||
        c == '\u00d7' ||
        c == '\u00f7' ||
        c == '\u2211' ||
        c == '\u222b' ||
        c == '\u221a' ||
        c == '\u00b7' ||
        c == '\u2264' ||
        c == '\u2265' ||
        c == '\u2260' ||
        c == '\u221e' {
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
fn md_latex_wrap_script(text : String) -> String {
  if text.length() > 1 &&
    !(text.length() >= 2 && text[0] == '(' && text[text.length() - 1] == ')') {
    "(" + text + ")"
  } else {
    text
  }
}

///|
fn md_latex_fraction_part(text : String) -> String {
  if text.length() > 1 {
    if text.length() >= 2 && text[0] == '(' && text[text.length() - 1] == ')' {
      text
    } else {
      "(" + text + ")"
    }
  } else {
    text
  }
}

///|
fn md_latex_paren(text : String) -> String {
  if text.length() >= 2 && text[0] == '(' && text[text.length() - 1] == ')' {
    text
  } else {
    "(" + text + ")"
  }
}

///|
fn md_latex_normalize(text : String) -> String {
  let out = StringBuilder()
  let chars = text.to_array()
  let mut i = 0
  while i < chars.length() {
    let c = chars[i]
    if c == ' ' {
      let current = out.to_string()
      if current.length() > 0 {
        let previous = current[current.length() - 1]
        if previous == '=' ||
          previous == '+' ||
          previous == '-' ||
          previous == '\u2212' ||
          previous == '\u00b1' ||
          previous == '/' ||
          previous == '^' ||
          previous == '_' {
          i += 1
          continue
        }
        let mut j = i
        while j < chars.length() && chars[j] == ' ' {
          j += 1
        }
        if j < chars.length() {
          let next = chars[j]
          if previous == ';' || previous == ',' || previous == '(' {
            out.write_char(' ')
            i = j
            continue
          }
          if next == '=' ||
            next == '+' ||
            next == '-' ||
            next == '\u2212' ||
            next == '\u00b1' ||
            next == '/' ||
            next == '^' ||
            next == '_' ||
            next == ')' ||
            next == ']' {
            i = j
            continue
          }
        }
        out.write_char(' ')
        i = j
        continue
      }
      i += 1
      continue
    }
    if c == '-' {
      out.write_char('\u2212')
    } else {
      out.write_char(c)
    }
    i += 1
  }
  out.to_string().trim().to_string()
}

///|
fn md_latex_symbol_command(c : Char) -> String {
  match c {
    ',' | ';' => " "
    '!' | ':' => ""
    '{' => "{"
    '}' => "}"
    '|' => "‖"
    _ => c.to_string()
  }
}

///|
fn MdLatex::skip_space(self : MdLatex) -> Unit {
  while self.i < self.chars.length() &&
    (self.chars[self.i] == ' ' ||
      self.chars[self.i] == '\t' ||
      self.chars[self.i] == '\n') {
    self.i += 1
  }
}

///|
fn MdLatex::read_name(self : MdLatex) -> String {
  let out = StringBuilder()
  while self.i < self.chars.length() {
    let c = self.chars[self.i]
    if (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') {
      out.write_char(c)
      self.i += 1
    } else {
      break
    }
  }
  out.to_string()
}

///|
fn MdLatex::parse_arg(self : MdLatex) -> String {
  self.skip_space()
  if self.i >= self.chars.length() {
    return ""
  }
  match self.chars[self.i] {
    '{' => {
      self.i += 1
      self.parse_sequence('}')
    }
    '\\' => {
      self.i += 1
      if self.i < self.chars.length() {
        let next = self.chars[self.i]
        let letter = (next >= 'a' && next <= 'z') ||
          (next >= 'A' && next <= 'Z')
        if !letter {
          self.i += 1
          return md_latex_symbol_command(next)
        }
      }
      let name = self.read_name()
      match md_latex_command_map(name) {
        Some(value) => value
        None => name
      }
    }
    c => {
      self.i += 1
      c.to_string()
    }
  }
}

///|
fn MdLatex::parse_script(self : MdLatex) -> String {
  self.parse_arg()
}

///|
fn MdLatex::render_environment(self : MdLatex, env : String) -> String {
  let rest = String::from_array(self.chars[self.i:])
  let end_marker = "\\end{" + env + "}"
  let length = match rest.find(end_marker) {
    Some(index) => index
    None => rest.length()
  }
  let body = rest[:length].to_owned()
  self.i += length
  if String::from_array(self.chars[self.i:]).has_prefix(end_marker) {
    self.i += end_marker.length()
  }
  let lines : Array[String] = []
  for row in body.split("\\\\") {
    let cells : Array[String] = []
    for cell in row.split("&") {
      let parser : MdLatex = { chars: cell.to_string().to_array(), i: 0 }
      cells.push(parser.parse_sequence('\u0000'))
    }
    let aligned = env == "aligned" || env == "align" || env == "alignedat"
    lines.push(if aligned { cells.join("") } else { cells.join(", ") })
  }
  match env {
    "pmatrix" | "bmatrix" | "Bmatrix" | "vmatrix" | "Vmatrix" | "matrix" |
    "smallmatrix" => "(" + lines.join("; ") + ")"
    "cases" | "dcases" => "{" + lines.join("; ")
    "aligned" | "align" | "alignedat" | "gathered" => lines.join("\n")
    _ => lines.join("; ")
  }
}

///|
fn MdLatex::render_command(self : MdLatex, name : String) -> String {
  match name {
    "frac" | "dfrac" | "tfrac" => {
      let num = self.parse_arg()
      let den = self.parse_arg()
      md_latex_fraction_part(num) + "/" + md_latex_fraction_part(den)
    }
    "sqrt" => {
      self.skip_space()
      let mut degree = ""
      if self.i < self.chars.length() && self.chars[self.i] == '[' {
        self.i += 1
        degree = self.parse_sequence(']')
        self.skip_space()
      }
      let body = self.parse_arg()
      if degree == "" {
        "√" + md_latex_wrap(body)
      } else {
        degree + "√" + md_latex_wrap(body)
      }
    }
    "text" | "textrm" | "mathrm" | "mathit" | "mathbf" | "mathsf" | "mathtt" |
    "operatorname" | "mbox" | "hbox" => self.parse_arg()
    "overline" | "underline" | "widehat" | "widetilde" | "vec" | "bar" |
    "dot" | "ddot" | "hat" | "check" | "breve" | "acute" | "grave" |
    "mathbb" | "mathcal" | "mathfrak" | "mathscr" | "boldsymbol" |
    "boxed" | "phantom" => self.parse_arg()
    "left" | "right" => {
      self.skip_space()
      if self.i < self.chars.length() {
        let c = self.chars[self.i]
        self.i += 1
        match c {
          '.' => ""
          '{' => "{"
          _ => c.to_string()
        }
      } else {
        ""
      }
    }
    "begin" => {
      self.skip_space()
      if self.i < self.chars.length() && self.chars[self.i] == '{' {
        self.i += 1
        let env = self.parse_sequence('}')
        self.render_environment(env)
      } else {
        ""
      }
    }
    "sum" | "prod" | "int" | "iint" | "iiint" | "oint" | "coprod" |
    "bigcup" | "bigcap" | "bigoplus" | "bigotimes" |
    "lim" | "max" | "min" | "sup" | "inf" | "det" | "gcd" => {
      let symbol = match md_latex_command_map(name) {
        Some(value) => value
        None => name
      }
      let mut sub = ""
      let mut sup = ""
      let mut more = true
      while more {
        self.skip_space()
        if self.i >= self.chars.length() {
          more = false
        } else {
          let c = self.chars[self.i]
          if c == '_' {
            self.i += 1
            sub = self.parse_script()
          } else if c == '^' {
            self.i += 1
            sup = self.parse_script()
          } else {
            more = false
          }
        }
      }
      let out = StringBuilder()
      out.write_string(symbol)
      if sub != "" {
        out.write_char('_')
        out.write_string(md_latex_wrap_script(sub))
      }
      if sup != "" {
        out.write_char('^')
        out.write_string(md_latex_wrap_script(sup))
      }
      out.write_char(' ')
      out.to_string()
    }
    "not" => "¬"
    "displaystyle" | "textstyle" | "scriptstyle" | "scriptscriptstyle" |
    "limits" | "nolimits" => ""
    "newline" => "; "
    _ =>
      match md_latex_command_map(name) {
        Some(value) => value
        None => name
      }
  }
}

///|
fn MdLatex::parse_sequence(self : MdLatex, stop : Char) -> String {
  let out = StringBuilder()
  while self.i < self.chars.length() {
    let c = self.chars[self.i]
    if c == stop {
      self.i += 1
      break
    }
    if c == ' ' || c == '\t' || c == '\n' || c == '\r' {
      self.i += 1
      continue
    }
    if c == '\\' {
      self.i += 1
      if self.i < self.chars.length() {
        let next = self.chars[self.i]
        let letter = (next >= 'a' && next <= 'z') ||
          (next >= 'A' && next <= 'Z')
        if !letter {
          self.i += 1
          out.write_string(md_latex_symbol_command(next))
          continue
        }
      }
      let name = self.read_name()
      out.write_string(self.render_command(name))
      continue
    }
    if c == '{' {
      self.i += 1
      out.write_string(self.parse_sequence('}'))
      continue
    }
    if c == '^' || c == '_' {
      self.i += 1
      let arg = self.parse_script()
      let current = out.to_string().trim_end().to_string()
      out.reset()
      out.write_string(current)
      out.write_char(c)
      out.write_string(md_latex_wrap_script(arg))
      continue
    }
    if c == '&' {
      self.i += 1
      out.write_string(", ")
      continue
    }
    if c == '}' {
      self.i += 1
      continue
    }
    out.write_char(c)
    self.i += 1
  }
  out.to_string()
}

///|
/// Linearize a LaTeX formula into the text BDF stores for search and copy.
pub fn md_latex_linear(source : String) -> String {
  let parser : MdLatex = { chars: source.to_array(), i: 0 }
  let text = parser.parse_sequence('\u0000')
  md_latex_normalize(text)
}
