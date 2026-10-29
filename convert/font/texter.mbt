///|
/// A measured UI text run using one resolved font and language.
pub(all) struct SpecimenTextRun {
  choice : @db.Choice
  text : String
  lang : String
  x : Double
  width : Double
}

///|
/// UI text measured in points, with per-font runs for drawing.
pub(all) struct SpecimenTextLine {
  runs : Array[SpecimenTextRun]
  width : Double
  size : Double
}

///|
/// Font selection and measurement for specimen labels.
pub struct SpecimenTexter {
  priv db : @db.Database
  priv cache : Map[String, (@db.Choice, String)]
  priv fallbacks : Map[String, @db.Choice]
  priv mut cache_faces : Int32
  priv used : Map[Int32, Map[Int32, Bool]]
  priv missing : Map[Int32, Bool]
}

///|
pub fn SpecimenTexter::new(db : @db.Database) -> SpecimenTexter {
  {
    db,
    cache: Map([]),
    fallbacks: Map([]),
    cache_faces: db.face_count(),
    used: Map([]),
    missing: Map([]),
  }
}

///|
fn SpecimenTexter::choice(
  self : SpecimenTexter,
  c : Char,
  bold : Bool,
) -> (@db.Choice, String) {
  let count = self.db.face_count()
  if count != self.cache_faces {
    self.cache.clear()
    self.fallbacks.clear()
    self.cache_faces = count
  }
  let cache_key = c.to_int().to_string() + ":" + bold.to_string()
  match self.cache.get(cache_key) {
    Some(value) => return value
    None => ()
  }
  let cjk = @db.is_cjk(c.to_int())
  let initial = self.db.resolve("Arial", bold~, cjk~)
  let mut choice = self.db.face_for("Arial", "", c.to_int(), bold~)
  let fallback = match initial.face {
    Some(index) => {
      let has = match self.db.face(index) {
        Some(face) => face.font.glyph(c.to_int()) is Some(_)
        None => false
      }
      !has && c != '\t' && c != '\n' && choice.resolved.face != initial.face
    }
    None => false
  }
  if fallback {
    let fallback_key = choice.resolved.face.unwrap_or(-1).to_string() +
      ":" +
      bold.to_string()
    match self.fallbacks.get(fallback_key) {
      Some(cached) => choice = cached
      None => self.fallbacks[fallback_key] = choice
    }
  }
  let key = if fallback {
    "fallback:" + choice.resolved.face.unwrap_or(-1).to_string()
  } else if cjk {
    "primary:cjk"
  } else {
    "primary:latin"
  }
  let result = (choice, key)
  self.cache[cache_key] = result
  result
}

///|
fn SpecimenTexter::advance(
  self : SpecimenTexter,
  choice : @db.Choice,
  c : Char,
) -> Double {
  match choice.resolved.face {
    Some(index) =>
      match self.db.face(index) {
        Some(face) =>
          match face.font.glyph(c.to_int()) {
            Some(g) => {
              let used = match self.used.get(index) {
                Some(used) => used
                None => {
                  let used : Map[Int32, Bool] = Map([])
                  self.used[index] = used
                  used
                }
              }
              used[c.to_int()] = true
              return face.font.advance(g)
            }
            None => {
              let code = c.to_int()
              if !c.is_whitespace() &&
                code >= 0x20 &&
                code != 0x200b &&
                code != 0xfeff {
                self.missing[code] = true
              }
            }
          }
        None => ()
      }
    None => ()
  }
  let n = c.to_int()
  if n == 0x20 || n == 0xa0 {
    0.25
  } else if @db.is_cjk(n) {
    1.0
  } else if n < 0x20 || n == 0x200b || n == 0xfeff {
    0.0
  } else {
    0.55
  }
}

///|
fn specimen_rune_lang(c : Char) -> String {
  match specimen_script(c.to_int()) {
    "Hiragana" | "Katakana" => "ja"
    "Hangul" => "ko"
    _ => ""
  }
}

///|
/// Measure and split a label into font and language runs.
pub fn SpecimenTexter::line(
  self : SpecimenTexter,
  text : String,
  size : Double,
  bold : Bool,
) -> SpecimenTextLine {
  let runs : Array[SpecimenTextRun] = []
  let mut current : @db.Choice? = None
  let mut key = ""
  let mut lang = ""
  let mut start = 0.0
  let mut width = 0.0
  let mut x = 0.0
  let mut buffer = StringBuilder()
  for c in text {
    let (choice, next_key) = self.choice(c, bold)
    let next_lang = specimen_rune_lang(c)
    let split = current is None ||
      key != next_key ||
      (next_lang != "" && next_lang != lang)
    if split {
      match current {
        Some(old) =>
          runs.push({
            choice: old,
            text: buffer.to_string(),
            lang,
            x: start,
            width,
          })
        None => ()
      }
      current = Some(choice)
      key = next_key
      lang = next_lang
      start = x
      width = 0.0
      buffer = StringBuilder()
    }
    let advance = self.advance(choice, c) * size
    buffer.write_char(c)
    width += advance
    x += advance
  }
  match current {
    Some(old) =>
      runs.push({
        choice: old,
        text: buffer.to_string(),
        lang,
        x: start,
        width,
      })
    None => ()
  }
  { runs, width: x, size, }
}

///|
fn SpecimenTexter::rune_advance(
  self : SpecimenTexter,
  c : Char,
  size : Double,
  bold : Bool,
) -> Double {
  let (choice, _) = self.choice(c, bold)
  self.advance(choice, c) * size
}

///|
/// Fit text to a width, adding an ellipsis when it must be shortened.
pub fn SpecimenTexter::fit(
  self : SpecimenTexter,
  text : String,
  size : Double,
  bold : Bool,
  max_width : Double,
) -> String {
  let chars : Array[Char] = [ for c in text => c ]
  let mut x = 0.0
  let mut n = 0
  while n < chars.length() &&
        x + self.rune_advance(chars[n], size, bold) <= max_width {
    x += self.rune_advance(chars[n], size, bold)
    n += 1
  }
  if n == chars.length() {
    return text
  }
  let ellipsis = self.rune_advance('…', size, bold)
  while n > 0 && x + ellipsis > max_width {
    n -= 1
    x -= self.rune_advance(chars[n], size, bold)
  }
  let out = StringBuilder()
  for i in 0..<n {
    out.write_char(chars[i])
  }
  out.write_char('…')
  out.to_string()
}

///|
/// Wrap a label at spaces and common punctuation, or within long unbroken text.
pub fn SpecimenTexter::wrap(
  self : SpecimenTexter,
  text : String,
  size : Double,
  bold : Bool,
  max_width : Double,
) -> Array[String] {
  let lines : Array[Array[Char]] = []
  let mut current : Array[Char] = []
  for c in text {
    if c == '\r' {
      continue
    }
    if c == '\n' || c == '\u{2028}' || c == '\u{2029}' {
      lines.push(current)
      current = []
    } else {
      current.push(c)
    }
  }
  lines.push(current)
  let result : Array[String] = []
  for line in lines {
    let mut start = 0
    while start < line.length() {
      let mut x = 0.0
      let mut last_break = -1
      let mut end = line.length()
      for i in start..<line.length() {
        let c = line[i]
        x += self.rune_advance(c, size, bold)
        if x > max_width && i > start {
          end = i
          break
        }
        if c == ' ' || c == '/' || c == '-' || c == ',' {
          last_break = i + 1
        }
      }
      if end < line.length() && last_break > start {
        end = last_break
      }
      let mut trimmed = end
      while trimmed > start && line[trimmed - 1] == ' ' {
        trimmed -= 1
      }
      let out = StringBuilder()
      for i in start..<trimmed {
        out.write_char(line[i])
      }
      result.push(out.to_string())
      start = end
      while start < line.length() && line[start] == ' ' {
        start += 1
      }
    }
  }
  result
}

///|
/// Characters measured from one supplied font face.
pub(all) struct SpecimenFaceUsage {
  face : Int32
  codepoints : Array[Int32]
}

///|
/// Measured glyphs and missing printable characters, sorted for determinism.
pub fn SpecimenTexter::usage(
  self : SpecimenTexter,
) -> (Array[SpecimenFaceUsage], Array[Int32]) {
  let indices = self.used.keys().collect()
  indices.sort()
  let faces : Array[SpecimenFaceUsage] = []
  for face in indices {
    let codepoints = self.used[face].keys().collect()
    codepoints.sort()
    faces.push({ face, codepoints, })
  }
  let missing = self.missing.keys().collect()
  missing.sort()
  (faces, missing)
}
