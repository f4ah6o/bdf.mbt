///|
// The metrics and encoding of an unembedded, non-Type-3 simple font.
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
  if subtype == PdfName(b"Type0") || subtype == PdfName(b"Type3") {
    raise InvalidStream("unsupported PDF font subtype")
  }
  let desc = self.page_deref(pdf_dict_get(dict, b"FontDescriptor"))
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
