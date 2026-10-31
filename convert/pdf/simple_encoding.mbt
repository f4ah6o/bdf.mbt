///|
// Encoding for an unembedded simple PDF font. Embedded and Type 3 font
// programs can carry their own encoding and are handled separately.
priv struct PdfSimpleEncoding {
  base : Array[String]
  differences : Map[Int32, String]
}

///|
fn pdf_simple_encoding_base(name : Bytes) -> Array[String] {
  match name {
    b"WinAnsiEncoding" => pdf_win_ansi_encoding
    b"MacRomanEncoding" => pdf_mac_roman_encoding
    _ => pdf_standard_encoding
  }
}

///|
fn PdfFile::simple_encoding(
  self : PdfFile,
  encoding : PdfObject?,
) -> PdfSimpleEncoding {
  let source = self.page_deref(encoding)
  let mut base = pdf_standard_encoding
  let differences : Map[Int32, String] = Map([])
  match source {
    PdfName(name) => base = pdf_simple_encoding_base(name)
    PdfDict(_) => {
      match self.page_deref(pdf_dict_get(source, b"BaseEncoding")) {
        PdfName(name) => base = pdf_simple_encoding_base(name)
        _ => ()
      }
      match self.page_deref(pdf_dict_get(source, b"Differences")) {
        PdfArray(values) => {
          let mut code = 0
          for value in values {
            match self.page_num(Some(value)) {
              Some(number) => code = number.to_int()
              None =>
                match self.page_deref(Some(value)) {
                  PdfName(name) if name.length() > 0 && code >= 0 && code < 256 => {
                    differences[code] = @utf8.decode_lossy(name[:])
                    code += 1
                  }
                  _ => ()
                }
            }
          }
        }
        _ => ()
      }
    }
    _ => ()
  }
  { base, differences, }
}

///|
fn PdfSimpleEncoding::name(self : PdfSimpleEncoding, code : Int32) -> String {
  if code < 0 || code >= 256 {
    return ""
  }
  match self.differences.get(code) {
    Some(value) if value != "" => value
    _ => self.base[code]
  }
}

///|
fn PdfSimpleEncoding::unicode(self : PdfSimpleEncoding, code : Int32) -> String {
  let name = self.name(code)
  if name == "" {
    if code >= 32 && code < 127 {
      return code.to_char().unwrap().to_string()
    }
    return ""
  }
  pdf_cmap_glyph_name(@utf8.encode(name))
}
