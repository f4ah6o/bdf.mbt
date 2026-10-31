///|
// Metrics and encoding of supported unembedded PDF fonts.
priv struct PdfSimpleFont {
  encoding : PdfSimpleEncoding
  to_unicode : PdfCMap?
  first : Int32
  widths : Array[Double]
  missing_width : Double
  family : String
  weight : Int32
  style : Int32
  mut used_nul : Bool
  composite : Bool
  composite_map : PdfCMap?
  cid_widths : Map[Int64, Double]
  default_width : Double
  collection : String
}

///|
fn PdfFile::font_number(
  self : PdfFile,
  object : PdfObject?,
  default : Double,
) -> Double {
  match self.page_num(object) {
    Some(value) => value
    None => default
  }
}

///|
fn PdfFile::simple_font(
  self : PdfFile,
  object : PdfObject,
) -> PdfSimpleFont raise PdfStreamError {
  let key = match object {
    PdfRef(number, generation) => Some((number, generation))
    _ => None
  }
  match key {
    Some(value) =>
      match self.font_cache.get(value) {
        Some(font) => return font
        None => ()
      }
    None => ()
  }
  let dict = self.page_deref(Some(object))
  if !(dict is PdfDict(_)) {
    raise InvalidStream("PDF font dictionary missing")
  }
  let subtype = self.page_deref(pdf_dict_get(dict, b"Subtype"))
  if subtype == PdfName(b"Type3") {
    raise InvalidStream("unsupported PDF font subtype")
  }
  let composite = subtype == PdfName(b"Type0")
  let cid = if composite {
    match self.page_deref(pdf_dict_get(dict, b"DescendantFonts")) {
      PdfArray(values) if !values.is_empty() => self.page_deref(Some(values[0]))
      _ => PdfNull
    }
  } else {
    PdfNull
  }
  let desc = if composite {
    self.page_deref(pdf_dict_get(cid, b"FontDescriptor"))
  } else {
    self.page_deref(pdf_dict_get(dict, b"FontDescriptor"))
  }
  let composite_map : PdfCMap? = if composite {
    match self.page_deref(pdf_dict_get(dict, b"Encoding")) {
      PdfName(b"Identity-H") | PdfNull => {
        let map = PdfCMap::new()
        map.identity = true
        map.ranges.push({ size: 2, low: 0L, high: 65535L, })
        Some(map)
      }
      PdfName(bytes) => {
        let name = @utf8.decode_lossy(bytes[:])
        match pdf_cjk_maps.get(name) {
          Some(source) if !source.vertical => {
            let map = PdfCMap::new()
            map.predefined = name
            for space in source.codespaces {
              map.ranges.push(space)
            }
            Some(map)
          }
          _ => raise InvalidStream("unsupported composite PDF font encoding")
        }
      }
      _ => raise InvalidStream("unsupported composite PDF font encoding")
    }
  } else {
    None
  }
  let cid_widths = self.cid_font_widths(cid)
  let default_width = self.font_number(pdf_dict_get(cid, b"DW"), 1000.0)
  let system = self.page_deref(pdf_dict_get(cid, b"CIDSystemInfo"))
  let registry = self.metadata_text(pdf_dict_get(system, b"Registry"))
  let ordering = self.metadata_text(pdf_dict_get(system, b"Ordering"))
  let collection = if registry != "" && ordering != "" {
    registry + "-" + ordering
  } else {
    match composite_map {
      Some(map) =>
        match pdf_cjk_maps.get(map.predefined) {
          Some(source) => source.collection
          None => ""
        }
      None => ""
    }
  }
  for key in [b"FontFile2", b"FontFile3", b"FontFile"] {
    match pdf_dict_get(desc, key) {
      Some(PdfRef(number, _)) => {
        let loaded : PdfLoaded? = Some(self.load(number, 0)) catch { _ => None }
        if loaded is Some({ stream: Some(_), .. }) {
          raise InvalidStream("embedded PDF fonts are not supported yet")
        }
      }
      _ => ()
    }
  }
  let base_name = match self.page_deref(pdf_dict_get(dict, b"BaseFont")) {
    PdfName(value) => @utf8.decode_lossy(value[:])
    _ => ""
  }
  let raw_name = @utf8.encode(base_name)
  let mut earlier_plus = false
  for i in 0..<Int32::min(raw_name.length(), 6) {
    if raw_name[i] == b'+' {
      earlier_plus = true
    }
  }
  let raw_name = if raw_name.length() > 6 &&
    raw_name[6] == b'+' &&
    !earlier_plus {
    raw_name[7:].to_owned()
  } else {
    raw_name
  }
  let name = @utf8.decode_lossy(raw_name[:]).to_lower()
  let flags = self.font_number(pdf_dict_get(desc, b"Flags"), 0.0).to_int()
  let specified_weight = self.font_number(
    pdf_dict_get(desc, b"FontWeight"),
    0.0,
  )
  let mut weight = if specified_weight > 0.0 {
    specified_weight.to_int() & 0xffff
  } else if self.font_number(pdf_dict_get(desc, b"StemV"), 0.0) >= 120.0 {
    700
  } else {
    0
  }
  if weight == 0 {
    weight = if name.contains("black") ||
      name.contains("heavy") ||
      name.contains("extrabold") {
      900
    } else if name.contains("bold") ||
      name.contains("semibold") ||
      name.contains("demibold") {
      700
    } else if name.contains("light") {
      300
    } else {
      400
    }
  }
  let style = if (flags & 64) != 0 ||
    self.font_number(pdf_dict_get(desc, b"ItalicAngle"), 0.0) != 0.0 ||
    name.contains("italic") ||
    name.contains("oblique") {
    1
  } else {
    0
  }
  let family = if name.contains("symbol") || name.contains("dingbat") {
    "serif"
  } else if name.contains("courier") ||
    name.contains("mono") ||
    (flags & 1) != 0 {
    "monospace"
  } else if name.contains("times") ||
    (name.contains("serif") && !name.contains("sans")) ||
    name.contains("georgia") ||
    name.contains("book") ||
    name.contains("garamond") ||
    name.contains("mincho") ||
    name.contains("roman") ||
    (
      (flags & 2) != 0 &&
      !name.contains("arial") &&
      !name.contains("helvetica") &&
      !name.contains("gothic")
    ) {
    "serif"
  } else {
    "sans-serif"
  }
  let widths = match self.page_deref(pdf_dict_get(dict, b"Widths")) {
    PdfArray(values) =>
      values.map(fn(value) { self.font_number(Some(value), 0.0) })
    _ => []
  }
  let cmap : PdfCMap? = match pdf_dict_get(dict, b"ToUnicode") {
    Some(PdfRef(number, _)) => {
      let loaded : PdfLoaded? = Some(self.load(number, 0)) catch { _ => None }
      match loaded {
        Some(value) =>
          match value.stream {
            Some(raw) => {
              let decoded : (Bytes, Bytes?)? = Some(
                pdf_decode_stream(
                  raw,
                  self.resolved_stream_filters(value.value),
                  268435456L,
                  false,
                  268435456L,
                ),
              ) catch {
                _ => None
              }
              match decoded {
                Some((data, None)) => Some(pdf_parse_cmap(data, None))
                _ => None
              }
            }
            None => None
          }
        None => None
      }
    }
    _ => None
  }
  let font : PdfSimpleFont = {
    encoding: self.simple_encoding(pdf_dict_get(dict, b"Encoding")),
    to_unicode: cmap,
    first: self.font_number(pdf_dict_get(dict, b"FirstChar"), 0.0).to_int(),
    widths,
    missing_width: self.font_number(pdf_dict_get(desc, b"MissingWidth"), 0.0),
    family,
    weight,
    style,
    used_nul: false,
    composite,
    composite_map,
    cid_widths,
    default_width,
    collection,
  }
  match key {
    Some(value) => self.font_cache[value] = font
    None => ()
  }
  font
}

///|
fn PdfSimpleFont::unicode(self : PdfSimpleFont, code : Int32) -> String {
  match self.to_unicode {
    Some(cmap) => {
      let text = cmap.to_unicode(code.to_int64())
      if text != "" {
        return text
      }
    }
    None => ()
  }
  self.encoding.unicode(code)
}

///|
fn PdfSimpleFont::width(self : PdfSimpleFont, code : Int32) -> Double {
  let index = code.to_int64() - self.first.to_int64()
  if index >= 0L && index < self.widths.length().to_int64() {
    return self.widths[index.to_int()] / 1000.0
  }
  if self.missing_width > 0.0 || !self.widths.is_empty() {
    return self.missing_width / 1000.0
  }
  if self.family == "monospace" {
    return 0.6
  }
  if code == 32 {
    return 0.278
  }
  if code >= 65 && code <= 90 {
    return 0.667
  }
  if code >= 48 && code <= 57 {
    return 0.556
  }
  0.5
}

///|
fn PdfFile::cid_font_widths(
  self : PdfFile,
  cid : PdfObject,
) -> Map[Int64, Double] {
  let widths : Map[Int64, Double] = Map([])
  let values = match self.page_deref(pdf_dict_get(cid, b"W")) {
    PdfArray(entries) => entries
    _ => return widths
  }
  let mut i = 0
  while i < values.length() {
    let start = match self.page_num(Some(values[i])) {
      Some(value) => value
      None => {
        i += 1
        continue
      }
    }
    if i + 1 < values.length() {
      match self.page_deref(Some(values[i + 1])) {
        PdfArray(entries) => {
          let base = start.to_int64() & 0xffffffffL
          for j in 0..<entries.length() {
            widths[(base + j.to_int64()) & 0xffffffffL] = self.font_number(
              Some(entries[j]),
              1000.0,
            )
          }
          i += 2
          continue
        }
        _ => ()
      }
      if i + 2 < values.length() {
        let end = self.font_number(Some(values[i + 1]), start)
        let width = self.font_number(Some(values[i + 2]), 1000.0)
        if start >= 0.0 && end <= 4294967295.0 && end - start < 65536.0 {
          let first = start.to_int64()
          let last = end.to_int64()
          for code = first; code <= last; code = code + 1L {
            widths[code] = width
          }
        }
        i += 3
        continue
      }
    }
    i += 1
  }
  widths
}

///|
fn PdfSimpleFont::decode(
  self : PdfSimpleFont,
  bytes : Bytes,
) -> Array[PdfGlyphCode] {
  match self.composite_map {
    Some(map) => map.decode(bytes)
    None => {
      let glyphs : Array[PdfGlyphCode] = []
      for byte in bytes {
        let code = byte.to_int64()
        glyphs.push({ code, size: 1, cid: code, })
      }
      glyphs
    }
  }
}

///|
fn PdfSimpleFont::glyph_unicode(
  self : PdfSimpleFont,
  glyph : PdfGlyphCode,
) -> String {
  if !self.composite {
    return self.unicode(glyph.code.to_int())
  }
  match self.to_unicode {
    Some(cmap) => {
      let text = cmap.to_unicode(glyph.code)
      if text != "" {
        return text
      }
    }
    None => ()
  }
  match self.composite_map {
    Some(map) =>
      match pdf_cjk_maps.get(map.predefined) {
        Some(source) =>
          match source.code_point(glyph.code) {
            Some(code) if code >= 0x20L => {
              let out = StringBuilder()
              pdf_text_char(out, code.to_int())
              return out.to_string()
            }
            _ => ()
          }
        None => ()
      }
    None => ()
  }
  match pdf_cjk_unicode(self.collection, glyph.cid) {
    Some((code, _)) if code >= 0x20L => {
      let out = StringBuilder()
      pdf_text_char(out, code.to_int())
      out.to_string()
    }
    _ => ""
  }
}

///|
fn PdfSimpleFont::glyph_width(
  self : PdfSimpleFont,
  glyph : PdfGlyphCode,
) -> Double {
  if self.composite {
    self.cid_widths.get(glyph.cid).unwrap_or(self.default_width) / 1000.0
  } else {
    self.width(glyph.code.to_int())
  }
}
