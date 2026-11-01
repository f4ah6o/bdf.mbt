///|
/// Vertical metrics of a font face in ems.
pub(all) struct TextMetrics {
  asc : Double
  desc : Double
  cap : Double
  ul_pos : Double
  ul_thick : Double
} derive(Debug, Eq)

///|
/// The fonts one document measures text with. The database may be empty:
/// text is then measured with upstream's fallback metrics and drawn with
/// the viewer's own fonts.
pub struct Fonts {
  db : @fontdb.Database
  has_fonts : Bool
  cache : Map[String, @fontdb.Choice]
  warned : Map[String, Bool]
  warnings : Array[String]
}

///|
pub fn Fonts::new(db : @fontdb.Database?) -> Fonts {
  let database = match db {
    Some(value) => value
    None => @fontdb.Database::new()
  }
  { db: database, has_fonts: database.face_count() > 0, cache: Map([]), warned: Map([]), warnings: [] }
}

///|
pub fn Fonts::has_fonts(self : Fonts) -> Bool {
  self.has_fonts
}

///|
pub fn Fonts::db(self : Fonts) -> @fontdb.Database {
  self.db
}

///|
pub fn Fonts::warnings(self : Fonts) -> Array[String] {
  self.warnings.copy()
}

///|
/// Resolve the face for one character. The cache key includes the character
/// because the face falls back per glyph.
pub fn Fonts::face(
  self : Fonts,
  latin : String,
  east_asian : String,
  code : Int32,
  bold~ : Bool = false,
  italic~ : Bool = false,
) -> @fontdb.Choice {
  let key = latin +
    "\u{0}" +
    east_asian +
    "\u{0}" +
    code.to_string() +
    (if bold { ":b" } else { ":r" }) +
    (if italic { ":i" } else { ":n" })
  match self.cache.get(key) {
    Some(value) => value
    None => {
      let value = self.db.face_for(latin, east_asian, code, bold~, italic~)
      self.cache[key] = value
      value
    }
  }
}

///|
/// The advance of a character in ems.
pub fn Fonts::advance(self : Fonts, choice : @fontdb.Choice, code : Int32) -> Double {
  match choice.resolved.face {
    Some(id) =>
      match self.db.face(id) {
        Some(face) =>
          match face.font.glyph(code) {
            Some(glyph) => return face.font.advance(glyph)
            None => ()
          }
        None => ()
      }
    None => ()
  }
  if code == 32 || code == 0xa0 {
    return 0.25
  }
  if @fontdb.is_cjk(code) {
    return 1.0
  }
  if code < 0x20 || code == 0x200b || code == 0xfeff {
    return 0.0
  }
  0.55
}

///|
/// The vertical metrics of a face in ems.
pub fn Fonts::metrics(self : Fonts, choice : @fontdb.Choice) -> TextMetrics {
  match choice.resolved.face {
    Some(id) =>
      match self.db.face(id) {
        Some(face) => {
          let metrics = face.font.metrics
          return {
            asc: metrics.ascent,
            desc: -metrics.descent,
            cap: metrics.cap_height,
            ul_pos: metrics.underline_position,
            ul_thick: metrics.underline_thickness,
          }
        }
        None => ()
      }
    None => ()
  }
  { asc: 0.9, desc: 0.25, cap: 0.7, ul_pos: -0.1, ul_thick: 0.05 }
}

///|
/// Measure a string in ems.
pub fn Fonts::measure(
  self : Fonts,
  latin : String,
  east_asian : String,
  bold : Bool,
  italic : Bool,
  text : String,
) -> Double {
  let mut width = 0.0
  for character in text {
    let choice = self.face(latin, east_asian, character.to_int(), bold~, italic~)
    width += self.advance(choice, character.to_int())
  }
  width
}

///|
/// The BDF font record for a resolved face, embedded when `hash` is set.
pub fn Fonts::font_record(self : Fonts, choice : @fontdb.Choice, hash : String?) -> @core.Font {
  let generic = if choice.resolved.generic != "" {
    choice.resolved.generic
  } else {
    @fontdb.classify(choice.requested)
  }
  let generic = if generic == "" { "sans-serif" } else { generic }
  let bold = choice.bold || choice.resolved.synth_bold
  let italic = choice.italic || choice.resolved.synth_italic
  let weight = if bold { 700 } else { 400 }
  let style = if italic { 1 } else { 0 }
  match hash {
    Some(value) => {
      hash: Some(value),
      family: generic,
      weight,
      style,
    }
    None => {
      hash: None,
      family: self.family_css(choice, generic),
      weight,
      style,
    }
  }
}

///|
fn Fonts::family_css(self : Fonts, choice : @fontdb.Choice, generic : String) -> String {
  let names : Array[String] = []
  if choice.requested != "" && !is_generic(choice.requested) {
    names.push(css_quote(choice.requested))
  }
  match choice.resolved.face {
    Some(id) =>
      match self.db.face(id) {
        Some(face) => {
          let family = face.font.info.family
          if family != "" && family != choice.requested {
            names.push(css_quote(family))
          }
        }
        None => ()
      }
    None => ()
  }
  if is_generic(generic) {
    names.push(generic)
  } else {
    names.push(css_quote(generic))
  }
  names.join(", ")
}

///|
/// Prepare the subset program of a face for the characters used, with the
/// upstream embedding checks.
pub fn Fonts::program(
  self : Fonts,
  choice : @fontdb.Choice,
  codepoints : Array[Int32],
) -> (Bytes?, String?) raise {
  match choice.resolved.face {
    Some(id) =>
      match self.db.face(id) {
        Some(face) =>
          @fontdb.prepare_font_program(
            face.font,
            face.font.byte_length(),
            codepoints,
            false,
            false,
          )
        None => (None, None)
      }
    None => (None, None)
  }
}

///|
fn is_generic(name : String) -> Bool {
  match name {
    "sans-serif" | "serif" | "monospace" | "cursive" | "fantasy" | "system-ui" |
    "ui-sans-serif" | "ui-serif" | "ui-monospace" => true
    _ => false
  }
}

///|
fn css_quote(value : String) -> String {
  let output = StringBuilder()
  output.write_char('"')
  for character in value {
    if character == '"' || character == '\\' {
      output.write_char('\\')
    }
    output.write_char(character)
  }
  output.write_char('"')
  output.to_string()
}

///|
/// A stable key for a resolved face used by a canvas.
pub fn choice_key(choice : @fontdb.Choice) -> String {
  let face = match choice.resolved.face {
    Some(id) => id.to_string()
    None => "-"
  }
  face +
    "\u{0}" +
    choice.requested +
    "\u{0}" +
    choice.resolved.generic +
    (if choice.bold || choice.resolved.synth_bold { ":b" } else { ":r" }) +
    (if choice.italic || choice.resolved.synth_italic { ":i" } else { ":n" })
}
