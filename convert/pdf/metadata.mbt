///|
priv struct PdfMetadata {
  title : String
  creator : String
  description : String
  subjects : Array[String]
  created : String
  modified : String
} derive(Debug, Eq)

///|
fn PdfFile::metadata_text(self : PdfFile, object : PdfObject?) -> String {
  match self.page_deref(object) {
    PdfString(value) | PdfHex(value) => pdf_decode_text(value)
    _ => ""
  }
}

///|
fn pdf_metadata_keywords(input : String) -> Array[String] {
  let result : Array[String] = []
  let mut current = StringBuilder()
  for character in input {
    if character == ',' ||
      character == ';' ||
      character == '，' ||
      character == '；' ||
      character == '、' {
      let value = current.to_string().trim().to_owned()
      if value != "" {
        result.push(value)
      }
      current = StringBuilder()
    } else {
      current.write_char(character)
    }
  }
  let value = current.to_string().trim().to_owned()
  if value != "" {
    result.push(value)
  }
  result
}

///|
fn PdfFile::metadata(self : PdfFile) -> PdfMetadata {
  let info = self.page_deref(self.trailer_entry(b"Info"))
  {
    title: self.metadata_text(pdf_dict_get(info, b"Title")).trim().to_owned(),
    creator: self.metadata_text(pdf_dict_get(info, b"Author")).trim().to_owned(),
    description: self
    .metadata_text(pdf_dict_get(info, b"Subject"))
    .trim()
    .to_owned(),
    subjects: pdf_metadata_keywords(
      self.metadata_text(pdf_dict_get(info, b"Keywords")),
    ),
    created: pdf_metadata_date(
      self.metadata_text(pdf_dict_get(info, b"CreationDate")),
    ),
    modified: pdf_metadata_date(
      self.metadata_text(pdf_dict_get(info, b"ModDate")),
    ),
  }
}
