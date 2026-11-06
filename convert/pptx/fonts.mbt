///|
// Text measurement, font references and embedded font subsets. With no font
// database text keeps the estimated metrics and no font parts are written;
// with one, every run measures its glyphs and the used faces are embedded as
// subsets, as upstream fontset does.

///|
/// A font of one object whose program is embedded after the object is drawn.
priv struct PptxFontSlot {
  index : Int32
  choice : @fontdb.Choice?
  codepoints : Map[Int32, Bool]
}

///|
/// The fonts of one layer: the shared database and this object's slots. The
/// missing characters are collected per conversion so that one warning
/// reports them.
priv struct PptxFontContext {
  fonts : @canvas.Fonts
  slots : Map[String, PptxFontSlot]
  missing : Map[Int32, Bool]
}

///|
/// One character's measured style: its advance and the face it resolves to.
priv struct PptxFontMetrics {
  advance : Double
  face : String
  choice : @fontdb.Choice?
  record_family : String
  record_weight : Int32
  record_style : Int32
  asc : Double
  desc : Double
}

///|
fn pptx_font_context(
  fonts : @canvas.Fonts,
  missing : Map[Int32, Bool],
) -> PptxFontContext {
  { fonts, slots: Map([]), missing, }
}

///|
fn PptxFontContext::has_fonts(self : PptxFontContext) -> Bool {
  self.fonts.has_fonts()
}

///|
/// Measure one character. Without fonts the upstream estimated advance and
/// the 1.2 em line are used; with fonts the resolved face's advance and
/// vertical metrics are.
fn pptx_font_metrics(
  ctx : PptxFontContext,
  family : String,
  east_asian : String,
  weight : Int32,
  style : Int32,
  size : Double,
  code : Int32,
) -> PptxFontMetrics {
  if !ctx.has_fonts() {
    return {
      advance: pptx_char_width_code(code, size),
      face: "",
      choice: None,
      record_family: family,
      record_weight: weight,
      record_style: style,
      asc: size * 0.9,
      desc: size * 0.25,
    }
  }
  let bold = weight >= 600
  let italic = style != 0
  let choice = ctx.fonts.face(family, east_asian, code, bold~, italic~)
  let metrics = ctx.fonts.metrics(choice)
  let has_glyph = match choice.resolved.face {
    Some(id) =>
      match ctx.fonts.db().face(id) {
        Some(face) => face.font.glyph(code) is Some(_)
        None => false
      }
    None => false
  }
  if !has_glyph &&
    code >= 0x20 &&
    code != 0x200b &&
    code != 0xfeff &&
    code != 0xa0 &&
    code != 0x20 {
    ctx.missing[code] = true
  }
  let record = ctx.fonts.font_record(choice, None)
  {
    advance: ctx.fonts.advance(choice, code) * size,
    face: @canvas.choice_key(choice),
    choice: Some(choice),
    record_family: record.family,
    record_weight: record.weight,
    record_style: record.style,
    asc: metrics.asc * size,
    desc: metrics.desc * size,
  }
}

///|
/// Measure a whole string with the metrics of one run style (bullets, chart
/// labels and other text drawn outside the paragraph layout).
fn pptx_measure_text(
  ctx : PptxFontContext,
  family : String,
  east_asian : String,
  weight : Int32,
  style : Int32,
  size : Double,
  text : String,
) -> Double {
  let mut width = 0.0
  for character in text {
    width += pptx_font_metrics(
        ctx,
        family,
        east_asian,
        weight,
        style,
        size,
        character.to_int(),
      ).advance
  }
  width
}

///|
/// The font reference for a run, adding a slot and keeping the characters
/// used for its embedded subset. face is empty for estimated-metrics mode.
fn pptx_font_ref(
  ctx : PptxFontContext,
  object : @core.ObjectBuilder,
  face : String,
  choice : @fontdb.Choice?,
  family : String,
  weight : Int32,
  style : Int32,
  text : String,
) -> Int32 {
  let key = if face == "" {
    "sys|" + family + "|" + weight.to_string() + "|" + style.to_string()
  } else {
    face
  }
  match ctx.slots.get(key) {
    Some(slot) => {
      if choice is Some(_) && text != "" {
        for character in text {
          slot.codepoints[character.to_int()] = true
        }
      }
      slot.index
    }
    None => {
      let record = match choice {
        Some(value) => ctx.fonts.font_record(value, None)
        None => {
          hash: None,
          family: @fontdb.css_family(family),
          weight,
          style,
        }
      }
      let index = object.add_font(record)
      let codepoints : Map[Int32, Bool] = Map([])
      if choice is Some(_) && text != "" {
        for character in text {
          codepoints[character.to_int()] = true
        }
      }
      ctx.slots[key] = { index, choice, codepoints, }
      index
    }
  }
}

///|
/// Embed the subsets of the faces an object measured, and update the font
/// records to point at them. Returns how many fonts were embedded.
fn pptx_embed_fonts(
  ctx : PptxFontContext,
  object : @core.ObjectBuilder,
  writer : @core.DocumentWriter,
  warnings : Array[String],
) -> Int32 raise {
  if !ctx.has_fonts() || ctx.slots.is_empty() {
    return 0
  }
  // one subset per physical face; the font record keeps the use's weight
  // and style, as upstream Embed does
  let groups : Map[Int32, Array[PptxFontSlot]] = Map([])
  for (_, slot) in ctx.slots {
    match slot.choice {
      Some(choice) =>
        match choice.resolved.face {
          Some(id) => {
            let list = match groups.get(id) {
              Some(value) => value
              None => {
                let value : Array[PptxFontSlot] = []
                groups[id] = value
                value
              }
            }
            list.push(slot)
          }
          None => ()
        }
      None => ()
    }
  }
  let mut embedded = 0
  let face_ids : Array[Int32] = []
  for (id, _) in groups {
    face_ids.push(id)
  }
  face_ids.sort()
  for id in face_ids {
    let slots = groups[id]
    let codepoints : Array[Int32] = []
    let seen : Map[Int32, Bool] = Map([])
    for slot in slots {
      for (code, _) in slot.codepoints {
        if !seen.contains(code) {
          seen[code] = true
          codepoints.push(code)
        }
      }
    }
    let choice = slots[0].choice.unwrap()
    let (program, warning) = ctx.fonts.program(choice, codepoints) catch {
      _ => (None, Some("font: the embedded font could not be prepared"))
    }
    match warning {
      Some(message) => warnings.push(message)
      None => ()
    }
    let mut hash : String? = None
    match program {
      Some(data) => {
        let stored = @woff2.encode(data) catch { _ => data }
        hash = Some(writer.add_part("font", stored))
        embedded += 1
      }
      None => ()
    }
    for slot in slots {
      object.update_font(slot.index, ctx.fonts.font_record(choice, hash))
    }
  }
  embedded
}

///|
/// A stable hexadecimal code point for missing-glyph warnings.
fn pptx_code_hex(code : Int32) -> String {
  let digits = [
    '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'A', 'B', 'C', 'D', 'E', 'F',
  ]
  let chars : Array[Char] = []
  let mut value = code
  while value >= 16 {
    chars.push(digits[value & 15])
    value = value >> 4
  }
  chars.push(digits[value & 15])
  let out = StringBuilder()
  let mut index = chars.length() - 1
  while index >= 0 {
    out.write_char(chars[index])
    index -= 1
  }
  let text = out.to_string()
  if text.length() >= 4 {
    text
  } else {
    let padded = StringBuilder()
    for _ in 0..<(4 - text.length()) {
      padded.write_char('0')
    }
    padded.write_string(text)
    padded.to_string()
  }
}

///|
/// The warning upstream reports for characters no available font has.
fn pptx_missing_glyph_warning(missing : Map[Int32, Bool]) -> String? {
  if missing.is_empty() {
    return None
  }
  let codes : Array[Int32] = []
  for (code, _) in missing {
    codes.push(code)
  }
  codes.sort()
  let text = StringBuilder()
  for i, code in codes {
    if i == 20 {
      text.write_string(" … ({codes.length() - 20} more)")
      break
    }
    text.write_string(" ")
    text.write_string(code.unsafe_to_char().to_string())
    text.write_string(" U+")
    text.write_string(pptx_code_hex(code))
  }
  Some(
    "no available font has glyphs for:" +
    text.to_string() +
    "; viewers draw them with their own fonts",
  )
}

///|
/// The font reference for a string drawn outside the paragraph layout
/// (bullets, chart labels): the face of its first character, with all its
/// characters recorded for the embedded subset.
fn pptx_font_ref_text(
  ctx : PptxFontContext,
  object : @core.ObjectBuilder,
  family : String,
  east_asian : String,
  weight : Int32,
  style : Int32,
  size : Double,
  text : String,
) -> Int32 {
  let mut code = 32
  for character in text {
    code = character.to_int()
    break
  }
  let metrics = pptx_font_metrics(
    ctx, family, east_asian, weight, style, size, code,
  )
  pptx_font_ref(
    ctx,
    object,
    metrics.face,
    metrics.choice,
    metrics.record_family,
    metrics.record_weight,
    metrics.record_style,
    text,
  )
}
