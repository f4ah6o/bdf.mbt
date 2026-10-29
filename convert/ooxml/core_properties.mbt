///|
/// Dublin Core properties stored in an OOXML package.
pub(all) struct OoxmlCoreProperties {
  title : Array[String]
  creator : Array[String]
  subject : Array[String]
  description : Array[String]
  identifier : Array[String]
  language : Array[String]
  created : Array[String]
  modified : Array[String]
}

///|
fn ooxml_trim_text(value : String) -> String {
  let out = StringBuilder()
  let mut pending = StringBuilder()
  let mut started = false
  for c in value {
    if c.is_whitespace() {
      if started {
        pending.write_char(c)
      }
    } else {
      if started {
        out.write_string(pending.to_string())
        pending = StringBuilder()
      }
      out.write_char(c)
      started = true
    }
  }
  out.to_string()
}

///|
fn ooxml_read_core(data : Bytes) -> OoxmlCoreProperties raise {
  let text = @utf8.decode_lossy(data[:], ignore_bom=true)
  if text.contains("<!ENTITY") {
    raise InvalidOoxml("ooxml: the part declares entities")
  }
  let reader = @xml.NamespaceReader::from_string(text)
  let result : OoxmlCoreProperties = {
    title: [],
    creator: [],
    subject: [],
    description: [],
    identifier: [],
    language: [],
    created: [],
    modified: [],
  }
  let mut depth = 0
  let mut capture = ""
  let mut captured = StringBuilder()
  let mut seen_keywords = false
  let keywords : Array[String] = []
  while true {
    let event = reader.read_event()
    match event.kind {
      Start(element) | Empty(element) => {
        let name = element.name.local_name
        if depth == 1 &&
          [
            "title", "creator", "subject", "description", "identifier", "language",
            "created", "modified", "keywords",
          ].contains(name) {
          if name != "keywords" || !seen_keywords {
            if name == "keywords" {
              seen_keywords = true
            }
            if event.kind is Start(_) {
              capture = name
              captured = StringBuilder()
            }
          }
        }
        if event.kind is Start(_) {
          depth += 1
        } else if depth == 0 {
          break
        }
      }
      Text(value) | CData(value) =>
        if depth == 2 && capture != "" {
          captured.write_string(value)
        }
      End(_) => {
        depth -= 1
        if depth == 1 && capture != "" {
          let value = ooxml_trim_text(captured.to_string())
          if value != "" {
            match capture {
              "title" => result.title.push(value)
              "creator" => result.creator.push(value)
              "subject" => result.subject.push(value)
              "description" => result.description.push(value)
              "identifier" => result.identifier.push(value)
              "language" => result.language.push(value)
              "created" => result.created.push(value)
              "modified" => result.modified.push(value)
              "keywords" => {
                let mut field = StringBuilder()
                for c in value {
                  if c == ',' ||
                    c == ';' ||
                    c == '，' ||
                    c == '；' ||
                    c == '、' {
                    let word = ooxml_trim_text(field.to_string())
                    if word != "" {
                      keywords.push(word)
                    }
                    field = StringBuilder()
                  } else {
                    field.write_char(c)
                  }
                }
                let word = ooxml_trim_text(field.to_string())
                if word != "" {
                  keywords.push(word)
                }
              }
              _ => ()
            }
          }
          capture = ""
        }
        if depth == 0 {
          break
        }
      }
      Eof =>
        if depth == 0 {
          break
        } else {
          raise InvalidOoxml("ooxml: unexpected EOF")
        }
      _ => ()
    }
  }
  for word in keywords {
    result.subject.push(word)
  }
  result
}

///|
/// Read the package's Dublin Core metadata, or return empty properties.
pub fn OoxmlPackage::core_properties(
  self : OoxmlPackage,
) -> OoxmlCoreProperties {
  let empty = fn() {
    {
      title: [],
      creator: [],
      subject: [],
      description: [],
      identifier: [],
      language: [],
      created: [],
      modified: [],
    }
  }
  let rel = match self.relationship_of_type("", "/core-properties") {
    Some(rel) => rel
    None => return empty()
  }
  let data = self.read(rel.target) catch { _ => return empty() }
  ooxml_read_core(data) catch {
    _ => empty()
  }
}
