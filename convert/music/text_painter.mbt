///|
fn music_rune_language(c : Char) -> String {
  let code = c.to_int()
  for (first, last, stride, language) in music_language_ranges {
    if code >= first && code <= last && (code - first) % stride == 0 {
      return language
    }
  }
  ""
}

///|
fn music_language_script(language : String) -> Bool {
  let lang = language.to_lower()
  lang.has_prefix("ja") || lang.has_prefix("zh") || lang.has_prefix("ko")
}

///|
fn music_choice_key(choice : @db.Choice) -> String {
  let resolved = choice.resolved
  resolved.face.unwrap_or(-1).to_string() +
  ":" +
  choice.bold.to_string() +
  ":" +
  choice.italic.to_string() +
  ":" +
  resolved.synth_bold.to_string() +
  ":" +
  resolved.synth_italic.to_string() +
  ":" +
  choice.requested.length().to_string() +
  ":" +
  choice.requested +
  ":" +
  resolved.generic
}

///|
/// Writes measured music text to an object, maintaining its font and language state.
pub struct MusicTextPainter {
  object : @core.ObjectBuilder
  texter : MusicTexter
  fonts : MusicTextFonts
  document_language : String
  refs : Map[String, Int32]
  mut language : String
  mut current : @db.Choice?
  mut size : Double
}

///|
pub fn MusicTextPainter::new(
  object : @core.ObjectBuilder,
  texter : MusicTexter,
  fonts : MusicTextFonts,
  document_language~ : String = "",
) -> MusicTextPainter {
  {
    object,
    texter,
    fonts,
    document_language,
    refs: Map([]),
    language: "",
    current: None,
    size: 0.0,
  }
}

///|
fn MusicTextPainter::set_language(
  self : MusicTextPainter,
  lang : String,
) -> Unit {
  let doc = self.document_language.to_lower()
  let lower = lang.to_lower()
  let value = if lower == doc || (lower != "" && doc.has_prefix(lower + "-")) {
    ""
  } else {
    lang
  }
  if value != self.language {
    self.object.mark(12, value)
    self.language = value
  }
}

///|
/// Draw a measured line aligned left, center or right at x in points.
pub fn MusicTextPainter::draw(
  self : MusicTextPainter,
  line : MusicTextLine,
  x : Double,
  y : Double,
  align : Int32,
) -> Unit raise {
  let left = x - line.width * align.to_double() / 2.0
  for run in line.runs {
    if run.text == "" {
      continue
    }
    let mut lang = ""
    if run.cjk {
      for c in run.text {
        lang = music_rune_language(c)
        if lang != "" {
          break
        }
      }
      if lang == "" && music_language_script(self.language) {
        lang = self.language
      }
    }
    self.set_language(lang)
    let key = music_choice_key(run.choice)
    let reference = match self.refs.get(key) {
      Some(reference) => reference
      None => {
        let reference = self.object.add_font(
          self.texter.font_record(run.choice, self.fonts),
        )
        self.refs[key] = reference
        reference
      }
    }
    if self.current != Some(run.choice) || self.size != line.size {
      self.object.font(reference, music_f32(line.size))
      self.current = Some(run.choice)
      self.size = line.size
    }
    self.object.fill_text(
      run.text,
      music_f32(left + run.x),
      music_f32(y),
      music_f32(run.width),
    )
  }
}
