///|
/// An embedded font and the PDF objects that describe it.
struct PdfFont {
  name : String
  font_ref : Int32
  desc_ref : Int32
  tounicode_ref : Int32
  parsed : @sfnt.Font
  program : Bytes
  is_cff : Bool
  used : Map[Int32, Int32]
}

///|
/// The resources of a PDF document. The page dictionary includes all fonts and
/// shadings of the document, which keeps the page writer independent of the
/// order in which resources are discovered.
struct PdfResources {
  writer : PdfWriter
  fonts : Array[PdfFont]
  font_keys : Map[String, Int32]
  mut std_ref : Int32?
  shadings : Array[(String, Int32)]
  patterns : Array[(String, Int32)]
  gstates : Array[(String, Double, Int32)]
  /// The subset of the fallback font that draws the characters of the
  /// document, and the font it was made from. The subset joins `fonts` only
  /// when a text run needs it.
  mut fallback : Bytes?
  mut fallback_parsed : @sfnt.Font?
  mut fallback_index : Int32
  /// The characters that no font of the document could draw.
  missing : Map[Int32, Bool]
  /// The characters that the PDF standard font drew as "?": a run without
  /// a font of its own draws it, and a character outside its codeset —
  /// Japanese, an accented letter, a control code — becomes a "?" that
  /// the writer reports instead of hiding.
  missing_std : Map[Int32, Bool]
}

///|
fn PdfResources::new(writer : PdfWriter) -> PdfResources {
  {
    writer,
    fonts: [],
    font_keys: Map([]),
    std_ref: None,
    shadings: [],
    patterns: [],
    gstates: [],
    fallback: None,
    fallback_parsed: None,
    fallback_index: -1,
    missing: Map([]),
    missing_std: Map([]),
  }
}

///|
fn woff2(bytes : Bytes) -> Bool {
  bytes.length() >= 4 &&
  bytes[0] == b'w' &&
  bytes[1] == b'O' &&
  bytes[2] == b'F' &&
  bytes[3] == b'2'
}

///|
fn font_program(bytes : Bytes) -> Bytes? {
  if woff2(bytes) {
    Some(@woff2.decode(bytes)) catch {
      _ => None
    }
  } else {
    Some(bytes)
  }
}

///|
fn PdfResources::standard_font(self : PdfResources) -> String {
  match self.std_ref {
    Some(_) => "Fstd"
    None => {
      let id = self.writer.add_string(
        "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>",
      )
      self.std_ref = Some(id)
      "Fstd"
    }
  }
}

///|
fn PdfResources::font(
  self : PdfResources,
  document : @core.Document,
  font : @core.Font,
) -> (String, Int32) {
  let hash = match font.hash {
    Some(hash) => hash
    None => return (self.standard_font(), -1)
  }
  match self.font_keys.get(hash) {
    Some(index) => (self.fonts[index].name, index)
    None => {
      let bytes = document.part(hash) catch {
        _ => return (self.standard_font(), -1)
      }
      let program = match font_program(bytes) {
        Some(program) => program
        None => return (self.standard_font(), -1)
      }
      let parsed = match (Some(@sfnt.parse(program)) catch { _ => None }) {
        Some(parsed) => parsed
        None => return (self.standard_font(), -1)
      }
      let name = "F" + self.fonts.length().to_string()
      let font_ref = self.writer.reserve()
      let desc_ref = self.writer.reserve()
      let tounicode_ref = self.writer.reserve()
      let index = self.fonts.length()
      self.fonts.push({
        name,
        font_ref,
        desc_ref,
        tounicode_ref,
        parsed,
        program,
        is_cff: parsed.metrics.is_cff,
        used: Map([]),
      })
      self.font_keys[hash] = index
      (name, index)
    }
  }
}

///|
fn hex4(value : Int32) -> String {
  let out = StringBuilder()
  let v = value & 0xffff
  for shift in [12, 8, 4, 0] {
    out.write_char(hex_digit((v >> shift) & 0xf))
  }
  out.to_string()
}

///|
fn unicode_hex(value : Int32) -> String {
  if value > 0xffff {
    let adjusted = value - 0x10000
    let high = 0xd800 + (adjusted >> 10)
    let low = 0xdc00 + (adjusted & 0x3ff)
    hex4(high) + hex4(low)
  } else {
    hex4(value)
  }
}

///|
fn PdfResources::text(
  self : PdfResources,
  document : @core.Document,
  run : @render.TextRun,
) -> (String, String) {
  let (name, encoded, _, _) = self.encode_text(document, run.font, run.text)
  (name, encoded)
}

///|
/// The font and the glyphs of the text, the width of the glyphs in
/// thousandths of an em (0 when the standard font draws it), and the index of
/// the font in the resources (-1 when the standard font draws it).
fn PdfResources::encode_text(
  self : PdfResources,
  document : @core.Document,
  font : @core.Font?,
  text : String,
) -> (String, String, Int32, Int32) {
  let (name, index) = match font {
    Some(font) => self.font(document, font)
    None => (self.standard_font(), -1)
  }
  if index < 0 {
    if self.fallback_parsed is Some(_) {
      return self.fallback_text(text)
    }
    return (name, standard_text(text, self.missing_std), 0, -1)
  }
  let pdf_font = self.fonts[index]
  let (encoded, width) = self.glyph_text(pdf_font, text)
  (pdf_font.name, encoded, width, index)
}

///|
/// The glyphs of the text in the font, as the hexadecimal codes of a PDF
/// string, and their width in thousandths of an em. A character the font does
/// not have becomes the glyph 0, which draws nothing, and is remembered so
/// that the writer can warn about it: a wrong glyph would be worse than none.
fn PdfResources::glyph_text(
  self : PdfResources,
  font : PdfFont,
  text : String,
) -> (String, Int32) {
  let codes = StringBuilder()
  let mut units = 0
  for ch in text {
    let codepoint = ch.to_int()
    let glyph = match font.parsed.glyph(codepoint) {
      Some(glyph) => glyph
      None => {
        self.missing[codepoint] = true
        0
      }
    }
    if glyph != 0 {
      if !font.used.contains(glyph) {
        font.used[glyph] = codepoint
      }
      units += font.parsed.advance_units(glyph)
    }
    codes.write_string(hex4(glyph))
  }
  let width = (units.to_double() *
    1000.0 /
    font.parsed.metrics.units_per_em.to_double())
    .round()
    .to_int()
  ("<" + codes.to_string() + ">", width)
}

///|
/// The glyph of each character of the text and its advance in font units, for
/// the writer that puts every character on its own cell.
fn PdfResources::char_glyphs(
  self : PdfResources,
  font : PdfFont,
  text : String,
) -> Array[(Int32, Int32)] {
  let out : Array[(Int32, Int32)] = []
  for ch in text {
    let codepoint = ch.to_int()
    let glyph = match font.parsed.glyph(codepoint) {
      Some(glyph) => glyph
      None => {
        self.missing[codepoint] = true
        0
      }
    }
    if glyph != 0 {
      if !font.used.contains(glyph) {
        font.used[glyph] = codepoint
      }
      out.push((glyph, font.parsed.advance_units(glyph)))
    } else {
      out.push((0, 0))
    }
  }
  out
}

///|
/// Prepare the subset of the fallback font that draws the characters the
/// document uses. Nothing is embedded when the document has no text, and a
/// font whose license does not allow embedding is left out with a warning.
fn PdfResources::prepare_fallback(
  self : PdfResources,
  program : Bytes?,
  codes : Array[Int32],
) -> String? {
  let program = match program {
    Some(program) => program
    None => return None
  }
  if codes.length() == 0 {
    return None
  }
  let font = match (Some(@sfnt.parse(program)) catch { _ => None }) {
    Some(font) => font
    None => return Some("the fallback font could not be read")
  }
  let requested : Array[Int32] = []
  for code in codes {
    requested.push(code)
  }
  let (subset, warning) = @font_db.prepare_font_program(
    font,
    program.length(),
    requested,
    false,
    false,
  ) catch {
    _ => (None, Some("the fallback font could not be subset"))
  }
  let subset = match subset {
    Some(subset) => subset
    None => return warning
  }
  let parsed = match (Some(@sfnt.parse(subset)) catch { _ => None }) {
    Some(parsed) => parsed
    None => return Some("the fallback font could not be read")
  }
  self.fallback = Some(subset)
  self.fallback_parsed = Some(parsed)
  warning
}

///|
/// The text in the subset of the fallback font, which joins the fonts of the
/// document the first time a run needs it.
fn PdfResources::fallback_text(
  self : PdfResources,
  text : String,
) -> (String, String, Int32, Int32) {
  let parsed = match self.fallback_parsed {
    Some(parsed) => parsed
    None => return (self.standard_font(), standard_text(text, self.missing_std), 0, -1)
  }
  if self.fallback_index < 0 {
    let program = match self.fallback {
      Some(program) => program
      None => return (self.standard_font(), standard_text(text, self.missing_std), 0, -1)
    }
    let name = "F" + self.fonts.length().to_string()
    let font_ref = self.writer.reserve()
    let desc_ref = self.writer.reserve()
    let tounicode_ref = self.writer.reserve()
    let index = self.fonts.length()
    self.fonts.push({
      name,
      font_ref,
      desc_ref,
      tounicode_ref,
      parsed,
      program,
      is_cff: parsed.metrics.is_cff,
      used: Map([]),
    })
    self.fallback_index = index
  }
  let pdf_font = self.fonts[self.fallback_index]
  let (encoded, width) = self.glyph_text(pdf_font, text)
  (pdf_font.name, encoded, width, self.fallback_index)
}

///|
/// The characters the fallback font could not draw, for a warning.
fn PdfResources::missing_text(self : PdfResources) -> String {
  let out = StringBuilder()
  let codes = self.missing.keys().collect()
  codes.sort()
  for index, code in codes {
    if index >= 16 {
      out.write_string("…")
      break
    }
    out.write_char(code.unsafe_to_char())
  }
  out.to_string()
}

///|
/// The characters that the PDF standard font wrote as "?", for a warning:
/// a run without a font of its own draws it, and without a readable
/// fallback font it has no glyph for the characters beyond its codeset.
fn PdfResources::missing_standard_text(self : PdfResources) -> String {
  let out = StringBuilder()
  let codes = self.missing_std.keys().collect()
  codes.sort()
  for index, code in codes {
    if index >= 16 {
      out.write_string("…")
      break
    }
    out.write_char(code.unsafe_to_char())
  }
  out.to_string()
}

///|
fn PdfResources::paint(
  self : PdfResources,
  paint : @core.Paint,
  matrix : @render.Matrix,
) -> String {
  match paint {
    @core.Gradient(kind, coordinates, stops) => {
      if stops.length() < 2 {
        return ""
      }
      let functions : Array[Int32] = []
      let sorted = [ for stop in stops => stop ]
      sorted.sort_by((a, b) => a.offset.compare(b.offset))
      let bounds : Array[String] = []
      for index in 0..<(sorted.length() - 1) {
        let c0 = sorted[index].color
        let c1 = sorted[index + 1].color
        let f = self.writer.add_string(
          "<< /FunctionType 2 /Domain [0 1] /C0 [" +
          color_text(c0) +
          "] /C1 [" +
          color_text(c1) +
          "] /N 1 >>",
        )
        functions.push(f)
        if index > 0 {
          bounds.push(num(sorted[index].offset))
        }
      }
      let function = if functions.length() == 1 {
        functions[0]
      } else {
        let list = StringBuilder()
        for index, f in functions {
          if index > 0 {
            list.write_string(" ")
          }
          list.write_string(f.to_string() + " 0 R")
        }
        self.writer.add_string(
          "<< /FunctionType 3 /Domain [0 1] /Functions [" +
          list.to_string() +
          "] /Bounds [" +
          bounds.join(" ") +
          "] /Encode [" +
          encode_ones(functions.length()) +
          "] >>",
        )
      }
      let shading_type = if kind == 1 { 3 } else { 2 }
      let coords = if kind == 1 {
        "[" +
        num(coordinates[0]) +
        " " +
        num(coordinates[1]) +
        " " +
        num(coordinates[2]) +
        " " +
        num(coordinates[3]) +
        " " +
        num(coordinates[4]) +
        " " +
        num(coordinates[5]) +
        "]"
      } else {
        "[" +
        num(coordinates[0]) +
        " " +
        num(coordinates[1]) +
        " " +
        num(coordinates[2]) +
        " " +
        num(coordinates[3]) +
        "]"
      }
      let shading = self.writer.add_string(
        "<< /ShadingType " +
        shading_type.to_string() +
        " /ColorSpace /DeviceRGB /Coords " +
        coords +
        " /Function " +
        function.to_string() +
        " 0 R /Extend [true true] >>",
      )
      let (a, b, c, d, e, f) = matrix
      let name = "P" + self.patterns.length().to_string()
      let pattern = self.writer.add_string(
        "<< /Type /Pattern /PatternType 2 /Shading " +
        shading.to_string() +
        " 0 R /Matrix [" +
        num(a) +
        " " +
        num(b) +
        " " +
        num(c) +
        " " +
        num(d) +
        " " +
        num(e) +
        " " +
        num(f) +
        "] >>",
      )
      self.patterns.push((name, pattern))
      name
    }
    @core.Pattern(_, _, _) => ""
  }
}

///|
fn PdfResources::alpha_gs(self : PdfResources, alpha : Double) -> String {
  let value = if alpha < 0.0 { 0.0 } else if alpha > 1.0 { 1.0 } else { alpha }
  for entry in self.gstates {
    if (entry.1 - value).abs() < 0.001 {
      return entry.0
    }
  }
  let name = "GS" + self.gstates.length().to_string()
  let id = self.writer.add_string(
    "<< /Type /ExtGState /ca " + num(value) + " /CA " + num(value) + " >>",
  )
  self.gstates.push((name, value, id))
  name
}

///|
fn encode_ones(count : Int32) -> String {
  let out = StringBuilder()
  for index in 0..<count {
    if index > 0 {
      out.write_string(" ")
    }
    out.write_string("0 1")
  }
  out.to_string()
}

///|
fn color_text(color : Int32) -> String {
  let value = color.reinterpret_as_uint()
  let r = ((value >> 24) & 0xffU).to_int()
  let g = ((value >> 16) & 0xffU).to_int()
  let b = ((value >> 8) & 0xffU).to_int()
  num(r.to_double() / 255.0) +
  " " +
  num(g.to_double() / 255.0) +
  " " +
  num(b.to_double() / 255.0)
}

///|
fn PdfResources::finish(self : PdfResources) -> String {
  for font in self.fonts {
    let gids = font.used.keys().collect()
    gids.sort()
    let advance_parts : Array[String] = []
    let cmap = StringBuilder()
    for gid in gids {
      let advance = font.parsed.advance_units(gid)
      let scaled = (advance.to_double() *
        1000.0 /
        font.parsed.metrics.units_per_em.to_double())
        .round()
        .to_int()
      advance_parts.push(gid.to_string() + " [" + scaled.to_string() + "]")
      let codepoint = font.used[gid]
      cmap.write_string(
        "<" + hex4(gid) + "> <" + unicode_hex(codepoint) + ">\n",
      )
    }
    let w = "[" + advance_parts.join(" ") + "]"
    let cid_subtype = if font.is_cff { "CIDFontType0" } else { "CIDFontType2" }
    let cid_extra = if font.is_cff { "" } else { " /CIDToGIDMap /Identity" }
    let cid = self.writer.add_string(
      "<< /Type /Font /Subtype " +
      cid_subtype +
      " /BaseFont /BDF" +
      font.name +
      " /CIDSystemInfo << /Registry (Adobe) /Ordering (Identity) /Supplement 0 >> /FontDescriptor " +
      font.desc_ref.to_string() +
      " 0 R /DW 1000 /W " +
      w +
      cid_extra +
      " >>",
    )
    let font_file = if font.is_cff {
      self.writer.add_stream("/Subtype /OpenType", font.program)
    } else {
      self.writer.add_stream(
        "/Length1 " + font.program.length().to_string(),
        font.program,
      )
    }
    let flags = 4
    let ascent = (font.parsed.metrics.ascent * 1000.0).round().to_int()
    let descent = (-font.parsed.metrics.descent * 1000.0).round().to_int()
    let cap = (font.parsed.metrics.cap_height * 1000.0).round().to_int()
    let desc_name = if font.is_cff { "/FontFile3" } else { "/FontFile2" }
    self.writer.set_string(
      font.desc_ref,
      "<< /Type /FontDescriptor /FontName /BDF" +
      font.name +
      " /Flags " +
      flags.to_string() +
      " /FontBBox [-1000 -1000 2000 2000] /ItalicAngle 0 /Ascent " +
      ascent.to_string() +
      " /Descent " +
      descent.to_string() +
      " /CapHeight " +
      cap.to_string() +
      " /StemV 80 " +
      desc_name +
      " " +
      font_file.to_string() +
      " 0 R >>",
    )
    let cmap_text = "/CIDInit /ProcSet findresource begin\n" +
      "12 dict begin\nbegincmap\n" +
      "/CIDSystemInfo << /Registry (Adobe) /Ordering (UCS) /Supplement 0 >> def\n" +
      "/CMapName /Adobe-Identity-UCS def\n/CMapType 2 def\n" +
      "1 begincodespacerange\n<0000> <FFFF>\nendcodespacerange\n" +
      font.used.length().to_string() +
      " beginbfchar\n" +
      cmap.to_string() +
      "endbfchar\nendcmap\n" +
      "CMapName currentdict /CMap defineresource pop\nend\nend"
    self.writer.set(
      font.tounicode_ref,
      stream_body("", @utf8.encode(cmap_text)),
    )
    self.writer.set_string(
      font.font_ref,
      "<< /Type /Font /Subtype /Type0 /BaseFont /BDF" +
      font.name +
      " /Encoding /Identity-H /DescendantFonts [" +
      cid.to_string() +
      " 0 R] /ToUnicode " +
      font.tounicode_ref.to_string() +
      " 0 R >>",
    )
  }
  let font_entries = StringBuilder()
  if self.std_ref is Some(id) {
    font_entries.write_string(" /Fstd " + id.to_string() + " 0 R")
  }
  for font in self.fonts {
    font_entries.write_string(
      " /" + font.name + " " + font.font_ref.to_string() + " 0 R",
    )
  }
  let shading_entries = StringBuilder()
  for entry in self.shadings {
    shading_entries.write_string(
      " /" + entry.0 + " " + entry.1.to_string() + " 0 R",
    )
  }
  let pattern_entries = StringBuilder()
  for entry in self.patterns {
    pattern_entries.write_string(
      " /" + entry.0 + " " + entry.1.to_string() + " 0 R",
    )
  }
  let gstate_entries = StringBuilder()
  for entry in self.gstates {
    gstate_entries.write_string(
      " /" + entry.0 + " " + entry.2.to_string() + " 0 R",
    )
  }
  let mut resources = "<< /Font <<" + font_entries.to_string() + " >>"
  if self.shadings.length() > 0 {
    resources = resources + " /Shading <<" + shading_entries.to_string() + " >>"
  }
  if self.patterns.length() > 0 {
    resources = resources + " /Pattern <<" + pattern_entries.to_string() + " >>"
  }
  if self.gstates.length() > 0 {
    resources = resources +
      " /ExtGState <<" +
      gstate_entries.to_string() +
      " >>"
  }
  resources + " >>"
}

///|
fn stream_body(extra : String, data : Bytes) -> Bytes {
  let out = @buffer.Buffer()
  out.write_bytes(@utf8.encode("<< /Length " + data.length().to_string()))
  if extra != "" {
    out.write_bytes(@utf8.encode(" " + extra))
  }
  out.write_bytes(@utf8.encode(" >>\nstream\n"))
  out.write_bytesview(data[:])
  out.write_bytes(@utf8.encode("\nendstream"))
  out.to_bytes()
}

///|
///|
/// The text of the PDF standard font: a character outside its codeset
/// becomes a "?", and the replacement is recorded so that the writer can
/// warn about it: a silent loss would be mistaken for a complete write.
fn standard_text(text : String, missing : Map[Int32, Bool]) -> String {
  let out = StringBuilder()
  out.write_string("(")
  for ch in text {
    let code = ch.to_int()
    if code < 32 || code > 126 {
      missing[code] = true
    }
    let c = if code < 32 || code > 126 { '?' } else { ch }
    if c == '\\' || c == '(' || c == ')' {
      out.write_char('\\')
    }
    out.write_char(c)
  }
  out.write_string(")")
  out.to_string()
}
