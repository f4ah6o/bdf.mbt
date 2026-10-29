///|
fn musicxml_entity_name_byte(b : Byte) -> Bool {
  let c = b.to_int()
  (c >= 65 && c <= 90) ||
  (c >= 97 && c <= 122) ||
  (c >= 48 && c <= 57) ||
  c == 95 ||
  c == 45 ||
  c == 46 ||
  c == 58
}

///|
fn musicxml_entity_names(data : Bytes) -> Map[String, Bool] {
  let names : Map[String, Bool] = Map([])
  let mut pos = 0
  let mut in_doctype = false
  let mut brackets = 0
  let mut quote = 0
  while pos < data.length() {
    if quote != 0 {
      if data[pos].to_int() == quote {
        quote = 0
      }
      pos += 1
      continue
    }
    if pos + 4 <= data.length() && data[pos:pos + 4] == b"<!--"[:] {
      let end = musicxml_find(data, b"-->", pos + 4, data.length())
      if end < 0 {
        break
      }
      pos = end + 3
      continue
    }
    if !in_doctype {
      if pos + 9 <= data.length() && data[pos:pos + 9] == b"<!DOCTYPE"[:] {
        in_doctype = true
        pos += 9
      } else if pos + 9 <= data.length() && data[pos:pos + 9] == b"<![CDATA["[:] {
        let end = musicxml_find(data, b"]]>", pos + 9, data.length())
        if end < 0 {
          break
        }
        pos = end + 3
      } else {
        pos += 1
      }
      continue
    }
    if pos + 8 <= data.length() && data[pos:pos + 8] == b"<!ENTITY"[:] {
      pos += 8
      while pos < data.length() &&
            (
              data[pos] == b' ' ||
              data[pos] == b'\t' ||
              data[pos] == b'\r' ||
              data[pos] == b'\n'
            ) {
        pos += 1
      }
      if pos < data.length() && data[pos] == b'%' {
        pos += 1
        continue
      }
      let start = pos
      while pos < data.length() && musicxml_entity_name_byte(data[pos]) {
        pos += 1
      }
      if pos > start {
        names[@utf8.decode_lossy(data[start:pos])] = true
      }
      continue
    }
    let c = data[pos].to_int()
    if c == 34 || c == 39 {
      quote = c
    } else if c == 91 {
      brackets += 1
    } else if c == 93 {
      brackets -= 1
    } else if c == 62 && brackets <= 0 {
      in_doctype = false
    }
    pos += 1
  }
  names
}

///|
fn musicxml_repair_entities(input : String) -> String {
  let data = @utf8.encode(input)
  if !input.contains("&") {
    return input
  }
  let declared = musicxml_entity_names(data)
  let out : Array[Byte] = []
  let mut i = 0
  while i < data.length() {
    if data[i] == b'<' {
      let close = if i + 4 <= data.length() && data[i:i + 4] == b"<!--"[:] {
        let n = musicxml_find(data, b"-->", i + 4, data.length())
        if n < 0 {
          data.length()
        } else {
          n + 3
        }
      } else if i + 9 <= data.length() && data[i:i + 9] == b"<![CDATA["[:] {
        let n = musicxml_find(data, b"]]>", i + 9, data.length())
        if n < 0 {
          data.length()
        } else {
          n + 3
        }
      } else if i + 9 <= data.length() && data[i:i + 9] == b"<!DOCTYPE"[:] {
        let mut n = i + 9
        let mut bracket = 0
        let mut quote = 0
        while n < data.length() {
          let c = data[n].to_int()
          n += 1
          if quote != 0 {
            if c == quote {
              quote = 0
            }
          } else if c == 34 || c == 39 {
            quote = c
          } else if c == 91 {
            bracket += 1
          } else if c == 93 {
            bracket -= 1
          } else if c == 62 && bracket <= 0 {
            break
          }
        }
        n
      } else if i + 2 <= data.length() && data[i:i + 2] == b"<?"[:] {
        let n = musicxml_find(data, b"?>", i + 2, data.length())
        if n < 0 {
          data.length()
        } else {
          n + 2
        }
      } else {
        i
      }
      if close > i {
        for j in i..<close {
          out.push(data[j])
        }
        i = close
        continue
      }
    }
    if data[i] == b'&' {
      let mut end = i + 1
      while end < data.length() && musicxml_entity_name_byte(data[end]) {
        end += 1
      }
      if end > i + 1 && end < data.length() && data[end] == b';' {
        let name = @utf8.decode_lossy(data[i + 1:end])
        if !["amp", "lt", "gt", "quot", "apos"].contains(name) &&
          !declared.contains(name) {
          match musicxml_html_entities.get(name) {
            Some(value) =>
              for c in value {
                for b in @utf8.encode("&#" + c.to_int().to_string() + ";") {
                  out.push(b)
                }
              }
            None => {
              for b in b"&amp;" {
                out.push(b)
              }
              for j in (i + 1)..<(end + 1) {
                out.push(data[j])
              }
            }
          }
          i = end + 1
          continue
        }
      }
    }
    out.push(data[i])
    i += 1
  }
  @utf8.decode_lossy(Bytes::from_array(out)[:])
}
