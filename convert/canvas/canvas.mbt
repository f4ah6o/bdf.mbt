///|
/// A font of an object whose program is embedded after the text has been
/// measured.
priv struct PendingFont {
  index : Int32
  choice : @fontdb.Choice
  codepoints : Map[Int32, Bool]
}

///|
/// An object under construction. Text is drawn with font references that
/// stay placeholders until `encode` embeds the subsets used.
pub struct Canvas {
  object : @core.ObjectBuilder
  priv fonts : Array[PendingFont]
  font_keys : Map[String, Int32]
  images : Map[String, Int32]
  children : Array[Canvas]
  doc_lang : String
  mut lang : String
  mut drawn : Bool
  mut encoded_hash : String?
}

///|
pub fn Canvas::new(doc_lang~ : String = "") -> Canvas {
  {
    object: @core.ObjectBuilder::new(),
    fonts: [],
    font_keys: Map([]),
    images: Map([]),
    children: [],
    doc_lang,
    lang: "",
    drawn: false,
    encoded_hash: None,
  }
}

///|
pub fn Canvas::object(self : Canvas) -> @core.ObjectBuilder {
  self.object
}

///|
pub fn Canvas::save(self : Canvas) -> Unit {
  self.object.save()
}

///|
pub fn Canvas::restore(self : Canvas) -> Unit {
  self.object.restore()
}

///|
pub fn Canvas::transform(self : Canvas, matrix : Matrix) -> Unit {
  if matrix.is_translation() {
    if matrix.e != 0.0 || matrix.f != 0.0 {
      self.object.translate(f32(matrix.e), f32(matrix.f))
    }
    return
  }
  self.object.transform(
    f32(matrix.a),
    f32(matrix.b),
    f32(matrix.c),
    f32(matrix.d),
    f32(matrix.e),
    f32(matrix.f),
  )
}

///|
pub fn Canvas::translate(self : Canvas, x : Double, y : Double) -> Unit {
  self.object.translate(f32(x), f32(y))
}

///|
pub fn Canvas::scale(self : Canvas, x : Double, y : Double) -> Unit {
  self.object.scale(f32(x), f32(y))
}

///|
pub fn Canvas::clip_path(self : Canvas, path : @core.Path, rule : Byte) -> Unit raise {
  let index = self.object.add_path(@core.Inline(path))
  self.object.clip_path(index, rule)
}

///|
pub fn Canvas::add_path(self : Canvas, path : @core.Path) -> Int32 {
  self.object.add_path(@core.Inline(path))
}

///|
pub fn Canvas::add_paint(self : Canvas, paint : @core.Paint) -> Int32 {
  self.object.add_paint(paint)
}

///|
pub fn Canvas::image(self : Canvas, hash : String) -> Int32 {
  match self.images.get(hash) {
    Some(index) => index
    None => {
      let index = self.object.add_image(hash)
      self.images[hash] = index
      index
    }
  }
}

///|
/// The reference of a text font, tracked for embedding. The characters the
/// run draws are recorded with the face.
pub fn Canvas::font(
  self : Canvas,
  choice : @fontdb.Choice,
  codepoints : Array[Int32],
) -> Int32 {
  let key = choice_key(choice)
  let index = match self.font_keys.get(key) {
    Some(value) => value
    None => {
      let value = self.object.add_font({
        hash: None,
        family: "\u{0}pending",
        weight: 400,
        style: 0,
      })
      self.font_keys[key] = value
      self.fonts.push({ index: value, choice, codepoints: Map([]), })
      value
    }
  }
  for pending in self.fonts {
    if pending.index == index {
      for code in codepoints {
        pending.codepoints[code] = true
      }
      break
    }
  }
  index
}

///|
/// Add a child object and return it with its reference.
pub fn Canvas::child(
  self : Canvas,
  bbox : (Float, Float, Float, Float),
) -> (Canvas, Int32) {
  let child = Canvas::new(doc_lang=self.doc_lang)
  let index = self.object.add_object("", bbox)
  self.children.push(child)
  (child, index)
}

///|
/// Make an already built child object a child of this one as well.
pub fn Canvas::share(
  self : Canvas,
  child : Canvas,
  bbox : (Float, Float, Float, Float),
) -> Int32 {
  let index = self.object.add_object("", bbox)
  self.children.push(child)
  index
}

///|
pub fn Canvas::used(self : Canvas, child : Canvas) -> Unit {
  self.lang = child.lang
}

///|
pub fn Canvas::lang(self : Canvas) -> String {
  self.lang
}

///|
pub fn Canvas::set_lang(self : Canvas, value : String) -> Unit {
  let lang = normalize_lang(value)
  let lang = if is_doc_lang(lang, self.doc_lang) { "" } else { lang }
  if lang != self.lang {
    self.object.mark(12, lang)
    self.lang = lang
  }
}

///|
pub fn Canvas::drawn(self : Canvas) -> Bool {
  self.drawn
}

///|
pub fn Canvas::set_drawn(self : Canvas) -> Unit {
  self.drawn = true
}

///|
/// Embed the font subsets of this canvas and add the object part to the
/// document. Child objects are encoded first.
pub fn Canvas::encode(
  self : Canvas,
  writer : @core.DocumentWriter,
  fonts : Fonts,
  warnings : Array[String],
  no_woff2~ : Bool = false,
) -> String raise {
  match self.encoded_hash {
    Some(hash) => return hash
    None => ()
  }
  self.finalize_fonts(writer, fonts, warnings, no_woff2)
  for index, child in self.children {
    let hash = child.encode(writer, fonts, warnings, no_woff2~)
    self.object.update_object(index, hash)
  }
  let data = self.object.encode()
  let hash = writer.add_part("obj", data)
  self.encoded_hash = Some(hash)
  hash
}

///|
fn Canvas::finalize_fonts(
  self : Canvas,
  writer : @core.DocumentWriter,
  fonts : Fonts,
  warnings : Array[String],
  no_woff2 : Bool,
) -> Unit raise {
  for pending in self.fonts {
    let codepoints : Array[Int32] = []
    for (code, _) in pending.codepoints {
      codepoints.push(code)
    }
    codepoints.sort()
    let (program, warning) = fonts.program(pending.choice, codepoints) catch {
      _ => (None, Some("font: the embedded font could not be prepared"))
    }
    match warning {
      Some(message) => warnings.push(message)
      None => ()
    }
    let mut hash : String? = None
    match program {
      Some(data) => {
        let stored = if no_woff2 { data } else { encode_font(data, warnings) }
        hash = Some(writer.add_part("font", stored))
      }
      None => ()
    }
    let record = fonts.font_record(pending.choice, hash)
    self.object.update_font(pending.index, record)
  }
}

///|
fn encode_font(data : Bytes, warnings : Array[String]) -> Bytes {
  @woff2.encode(data) catch {
    @woff2.Woff2Failure(message) => {
      if message != "woff2: the font compresses more than decoders accept" {
        warnings.push("font: not stored as WOFF2: " + message)
      }
      data
    }
    _ => data
  }
}

///|
fn normalize_lang(value : String) -> String {
  let output = StringBuilder()
  let mut started = false
  let pending = StringBuilder()
  for character in value {
    if character.is_whitespace() {
      if started {
        pending.write_char(character)
      }
    } else {
      if started {
        output.write_string(pending.to_string())
        pending.reset()
      }
      output.write_char(character)
      started = true
    }
  }
  let trimmed = output.to_string()
  if trimmed.to_lower() == "x-none" {
    ""
  } else {
    trimmed
  }
}

///|
fn is_doc_lang(lang : String, doc : String) -> Bool {
  if lang.to_lower() == doc.to_lower() {
    return true
  }
  if lang == "" || doc == "" {
    return false
  }
  let lowered = lang.to_lower()
  let document = doc.to_lower()
  !lowered.contains("-") && document.has_prefix(lowered + "-")
}
