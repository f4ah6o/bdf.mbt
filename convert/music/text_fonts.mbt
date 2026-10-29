///|
/// Embedded font hashes and warnings for music text.
pub(all) struct MusicTextFonts {
  hashes : Map[Int32, String]
  warnings : Array[String]
}

///|
fn music_path_compare(a : String, b : String) -> Int32 {
  let left : Array[Char] = [ for c in a => c ]
  let right : Array[Char] = [ for c in b => c ]
  for i in 0..<Int32::min(left.length(), right.length()) {
    if left[i] != right[i] {
      return left[i].to_int().compare(right[i].to_int())
    }
  }
  left.length().compare(right.length())
}

///|
/// Embed faces measured so far, using the same licensing and size rules as
/// other BDF converters. Measure all text before embedding.
pub fn MusicTexter::embed(
  self : MusicTexter,
  document : @core.DocumentWriter,
  no_subset~ : Bool = false,
  ignore_restrictions~ : Bool = false,
  no_woff2~ : Bool = false,
) -> MusicTextFonts raise {
  let used = self.used_codepoints()
  used.sort_by((a, b) => {
    let left = self.db.face(a.0).unwrap()
    let right = self.db.face(b.0).unwrap()
    let order = music_path_compare(left.path, right.path)
    if order == 0 {
      left.index.compare(right.index)
    } else {
      order
    }
  })
  let hashes : Map[Int32, String] = Map([])
  let warnings : Array[String] = []
  for (index, codepoints) in used {
    let face = self.db.face(index).unwrap()
    let (data, warning) = @db.prepare_font_program(
      face.font,
      face.font.byte_length(),
      codepoints,
      no_subset,
      ignore_restrictions,
    )
    match warning {
      Some(message) => warnings.push(message)
      None => ()
    }
    match data {
      None => ()
      Some(data) => {
        let encoded = if no_woff2 {
          data
        } else {
          @woff2.encode(data) catch {
            @woff2.Woff2Failure(message) => {
              if message !=
                "woff2: the font compresses more than decoders accept" {
                warnings.push(
                  "font " +
                  face.font.info.family +
                  ": not stored as WOFF2: " +
                  message,
                )
              }
              data
            }
            error => {
              warnings.push(
                "font " +
                face.font.info.family +
                ": not stored as WOFF2: " +
                error.to_string(),
              )
              data
            }
          }
        }
        hashes[index] = document.add_part("font", encoded)
      }
    }
  }
  { hashes, warnings, }
}

///|
fn music_css_quote(text : String) -> String {
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
/// Produce the embedded or system-font record for a measured run.
pub fn MusicTexter::font_record(
  self : MusicTexter,
  choice : @db.Choice,
  fonts : MusicTextFonts,
) -> @core.Font {
  let hash = match choice.resolved.face {
    Some(face) => fonts.hashes.get(face)
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
      let generic = match choice.requested {
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
      if choice.requested != "" && !generic {
        names.push(music_css_quote(choice.requested))
      }
      match choice.resolved.face {
        Some(index) =>
          match self.db.face(index) {
            Some(face) if face.font.info.family != choice.requested =>
              names.push(music_css_quote(face.font.info.family))
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
