///|
/// Embedded UI fonts and nonfatal embedding warnings.
pub(all) struct SpecimenUIFonts {
  hashes : Map[Int32, String]
  warnings : Array[String]
}

///|
fn specimen_path_order(a : String, b : String) -> Int32 {
  let aa : Array[Char] = [ for c in a => c ]
  let bb : Array[Char] = [ for c in b => c ]
  for i in 0..<Int32::min(aa.length(), bb.length()) {
    if aa[i] != bb[i] {
      return aa[i].to_int().compare(bb[i].to_int())
    }
  }
  aa.length().compare(bb.length())
}

///|
/// Embed the UI faces measured so far. Programs use SFNT rather than WOFF2.
pub fn SpecimenTexter::embed(
  self : SpecimenTexter,
  document : @core.DocumentWriter,
  no_subset~ : Bool = false,
  ignore_restrictions~ : Bool = false,
) -> SpecimenUIFonts raise {
  let (used, _) = self.usage()
  used.sort_by((a, b) => {
    let left = self.db.face(a.face).unwrap()
    let right = self.db.face(b.face).unwrap()
    let order = specimen_path_order(left.path, right.path)
    if order == 0 {
      left.index.compare(right.index)
    } else {
      order
    }
  })
  let warnings : Array[String] = []
  for usage in used {
    let face = self.db.face(usage.face).unwrap()
    let (program, warning) = @db.prepare_font_program(
      face.font,
      face.font.byte_length(),
      usage.codepoints,
      no_subset,
      ignore_restrictions,
    )
    match warning {
      Some(warning) => warnings.push(warning)
      None => ()
    }
    match program {
      Some(data) => self.embedded[usage.face] = document.add_part("font", data)
      None => ()
    }
  }
  { hashes: self.embedded.copy(), warnings, }
}

///|
fn specimen_css_quote(text : String) -> String {
  let out = StringBuilder()
  out.write_char('"')
  for c in text {
    if c == '"' || c == '\\' {
      out.write_char('\\')
    }
    out.write_char(c)
  }
  out.write_char('"')
  out.to_string()
}

///|
/// Convert a resolved text run to its embedded or system-font BDF record.
pub fn SpecimenTexter::font_record(
  self : SpecimenTexter,
  choice : @db.Choice,
  embedded : SpecimenUIFonts,
) -> @core.Font {
  let hash = match choice.resolved.face {
    Some(face) => embedded.hashes.get(face)
    None => None
  }
  match hash {
    Some(hash) =>
      {
        hash: Some(hash),
        family: choice.resolved.generic,
        weight: if choice.resolved.synth_bold {
          700
        } else {
          400
        },
        style: if choice.resolved.synth_italic {
          1
        } else {
          0
        },
      }
    None => {
      let names : Array[String] = []
      let generic_requested = match choice.requested {
        "sans-serif"
        | "serif"
        | "monospace"
        | "cursive"
        | "fantasy"
        | "system-ui"
        | "ui-sans-serif"
        | "ui-serif"
        | "ui-monospace" => true
        _ => false
      }
      if choice.requested != "" && !generic_requested {
        names.push(specimen_css_quote(choice.requested))
      }
      match choice.resolved.face {
        Some(index) =>
          match self.db.face(index) {
            Some(face) if face.font.info.family != choice.requested =>
              names.push(specimen_css_quote(face.font.info.family))
            _ => ()
          }
        None => ()
      }
      names.push(choice.resolved.generic)
      {
        hash: None,
        family: names.join(", "),
        weight: if choice.bold {
          700
        } else {
          400
        },
        style: if choice.italic {
          1
        } else {
          0
        },
      }
    }
  }
}
