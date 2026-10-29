///|
/// A run of music text in one resolved face, in points.
pub(all) struct MusicTextRun {
  choice : @db.Choice
  text : String
  cjk : Bool
  x : Double
  width : Double
}

///|
/// A music text line split by font and CJK status, in points.
pub(all) struct MusicTextLine {
  runs : Array[MusicTextRun]
  width : Double
  size : Double
  ascent : Double
  descent : Double
}

///|
/// Font selection, metrics and character usage for music text.
pub struct MusicTexter {
  db : @db.Database
  used : Map[Int32, Map[Int32, Bool]]
  missing : Map[Int32, Bool]
}

///|
pub fn MusicTexter::new(db : @db.Database) -> MusicTexter {
  { db, used: Map([]), missing: Map([]), }
}

///|
fn MusicTexter::advance(
  self : MusicTexter,
  choice : @db.Choice,
  c : Char,
) -> Double {
  match choice.resolved.face {
    Some(index) =>
      match self.db.face(index) {
        Some(face) =>
          match face.font.glyph(c.to_int()) {
            Some(glyph) => {
              let used = match self.used.get(index) {
                Some(used) => used
                None => {
                  let used : Map[Int32, Bool] = Map([])
                  self.used[index] = used
                  used
                }
              }
              used[c.to_int()] = true
              return face.font.advance(glyph)
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
  let code = c.to_int()
  if code == 0x20 || code == 0xa0 {
    0.25
  } else if @db.is_cjk(code) {
    1.0
  } else if code < 0x20 || code == 0x200b || code == 0xfeff {
    0.0
  } else {
    0.55
  }
}

///|
/// Measure text and record the characters needed for font embedding.
pub fn MusicTexter::line(
  self : MusicTexter,
  text : String,
  size : Double,
  bold : Bool,
  italic : Bool,
) -> MusicTextLine {
  let runs : Array[MusicTextRun] = []
  let mut previous : @db.Choice? = None
  let mut previous_cjk = false
  let mut start = 0.0
  let mut run_width = 0.0
  let mut x = 0.0
  let mut ascent = 0.8 * size
  let mut descent = 0.25 * size
  let mut buffer = StringBuilder()
  for c in text {
    let choice = self.db.face_for(
      "Times New Roman",
      "",
      c.to_int(),
      bold~,
      italic~,
    )
    let cjk = @db.is_cjk(c.to_int())
    if previous is None || previous != Some(choice) || previous_cjk != cjk {
      match previous {
        Some(old) =>
          runs.push({
            choice: old,
            text: buffer.to_string(),
            cjk: previous_cjk,
            x: start,
            width: run_width,
          })
        None => ()
      }
      previous = Some(choice)
      previous_cjk = cjk
      start = x
      run_width = 0.0
      buffer = StringBuilder()
      let (asc, desc) = match choice.resolved.face {
        Some(index) =>
          match self.db.face(index) {
            Some(face) => (face.font.metrics.ascent, face.font.metrics.descent)
            None => (0.9, 0.25)
          }
        None => (0.9, 0.25)
      }
      ascent = Double::max(ascent, asc * size)
      descent = Double::max(descent, desc * size)
    }
    let adv = self.advance(choice, c) * size
    buffer.write_char(c)
    run_width += adv
    x += adv
  }
  match previous {
    Some(choice) =>
      runs.push({
        choice,
        text: buffer.to_string(),
        cjk: previous_cjk,
        x: start,
        width: run_width,
      })
    None => ()
  }
  { runs, width: x, size, ascent, descent, }
}

///|
/// Code points used by each resolved font face.
pub fn MusicTexter::used_codepoints(
  self : MusicTexter,
) -> Array[(Int32, Array[Int32])] {
  let result : Array[(Int32, Array[Int32])] = []
  for face, chars in self.used {
    let values : Array[Int32] = []
    for char, _ in chars {
      values.push(char)
    }
    values.sort()
    result.push((face, values))
  }
  result.sort_by((a, b) => a.0.compare(b.0))
  result
}

///|
/// Characters missing from every resolved face, in code point order.
pub fn MusicTexter::missing_codepoints(self : MusicTexter) -> Array[Int32] {
  let result : Array[Int32] = []
  for code, _ in self.missing {
    result.push(code)
  }
  result.sort()
  result
}
