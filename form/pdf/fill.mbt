///|
fn pdf_escape_value(text : String) -> String {
  let out = StringBuilder()
  for c in text {
    if c == '\\' || c == '(' || c == ')' {
      out.write_char('\\')
      out.write_char(c)
    } else if c == '\n' {
      out.write_string("\\n")
    } else if c == '\r' {
      out.write_string("\\r")
    } else if c == '\t' {
      out.write_string("\\t")
    } else if c == '\b' {
      out.write_string("\\b")
    } else if c == '\f' {
      out.write_string("\\f")
    } else {
      out.write_char(c)
    }
  }
  out.to_string()
}

///|
fn pdf_hex_value(text : String) -> String {
  let out = StringBuilder()
  out.write_string("<FEFF")
  for c in text {
    let code = c.to_int()
    if code <= 0xFFFF {
      let hi = (code >> 12) & 0xF
      let h2 = (code >> 8) & 0xF
      let h3 = (code >> 4) & 0xF
      let h4 = code & 0xF
      out.write_char(hex_char(hi))
      out.write_char(hex_char(h2))
      out.write_char(hex_char(h3))
      out.write_char(hex_char(h4))
    } else {
      let value = code - 0x10000
      let high = 0xD800 + (value >> 10)
      let low = 0xDC00 + (value & 0x3FF)
      for unit in [high, low] {
        out.write_char(hex_char((unit >> 12) & 0xF))
        out.write_char(hex_char((unit >> 8) & 0xF))
        out.write_char(hex_char((unit >> 4) & 0xF))
        out.write_char(hex_char(unit & 0xF))
      }
    }
  }
  out.write_char('>')
  out.to_string()
}

///|
fn hex_char(value : Int) -> Char {
  if value < 10 {
    Char::from_int('0'.to_int() + value)
  } else {
    Char::from_int('A'.to_int() + value - 10)
  }
}

///|
fn pdf_value_repr(text : String) -> String {
  let mut ascii = true
  for c in text {
    if c.to_int() > 0x7F {
      ascii = false
    }
  }
  if ascii {
    "(" + pdf_escape_value(text) + ")"
  } else {
    pdf_hex_value(text)
  }
}

///|
fn last_index(text : String, needle : String) -> Int? {
  let mut found : Int? = None
  let mut from = 0
  while from <= text.length() {
    let at = match text[from:].find(needle) {
      Some(index) => from + index
      None => break
    }
    found = Some(at)
    from = at + 1
  }
  found
}

///|
fn find_t(body : String) -> Int? {
  match body.find("/T (") {
    Some(index) => Some(index)
    None =>
      match body.find("/T(") {
        Some(index) => Some(index)
        None => body.find("/T <")
      }
  }
}

///|
fn data_values(data : Json, name : String) -> Array[String] {
  let values : Array[String] = []
  match data {
    Json::Object(object) =>
      match object.get(name) {
        Some(Json::Array(items)) =>
          for item in items {
            let text = match item {
              Json::String(text) => text
              Json::Number(number, ..) => number.to_string()
              Json::True => "true"
              Json::False => "false"
              _ => ""
            }
            values.push(text)
          }
        _ => ()
      }
    _ => ()
  }
  values
}

///|
fn replace_pdf_repr(body : String, escaped : String) -> String {
  let v_at = match body.find("/V") {
    Some(index) => index
    None => {
      let t_at = match find_t(body) {
        Some(index) => index
        None => return body
      }
      let name_at = skip_spaces(body, t_at + 2)
      if name_at < body.length() &&
        (body[name_at].to_char().unwrap() == '(' ||
          body[name_at].to_char().unwrap() == '<') {
        match field_name_string(body, name_at) {
          Some((_, end)) =>
            return body[:end].to_owned() + " /V " + escaped +
              body[end:].to_owned()
          None => ()
        }
      }
      return body[:t_at].to_owned() + "/V " + escaped + " " + body[t_at:].to_owned()
    }
  }
  let mut i = skip_spaces(body, v_at + 2)
  let end = if i < body.length() && body[i].to_char().unwrap() == '(' {
    match literal_string(body, i) {
      Some((_, end)) => end
      None => return body
    }
  } else if i < body.length() && body[i].to_char().unwrap() == '<' {
    match body[i:].find(">") {
      Some(index) => i + index + 1
      None => return body
    }
  } else if i < body.length() && body[i].to_char().unwrap() == '[' {
    match body[i:].find("]") {
      Some(index) => i + index + 1
      None => return body
    }
  } else if i < body.length() && body[i].to_char().unwrap() == '/' {
    while i < body.length() && !is_space(body[i].to_char().unwrap()) {
      i += 1
    }
    i
  } else {
    return body
  }
  body[:v_at + 2].to_owned() + " " + escaped + body[end:].to_owned()
}

///|
fn pdf_array_repr(values : Array[String]) -> String {
  let out = StringBuilder()
  out.write_char('[')
  for i, value in values {
    if i > 0 {
      out.write_char(' ')
    }
    out.write_string(pdf_value_repr(value))
  }
  out.write_char(']')
  out.to_string()
}

///|
fn replace_pdf_value(body : String, value : String) -> String {
  replace_pdf_repr(body, pdf_value_repr(value))
}

///|
fn last_index_before(text : String, needle : String, limit : Int) -> Int? {
  let mut found : Int? = None
  let mut from = 0
  while from < limit {
    let at = match text[from:limit].find(needle) {
      Some(index) => from + index
      None => break
    }
    found = Some(at)
    from = at + 1
  }
  found
}

///|
fn object_header(text : String, obj_at : Int) -> (Int, Int)? {
  let line_start = match last_index_before(text, "\n", obj_at) {
    Some(index) => index + 1
    None => 0
  }
  let header = text[line_start:obj_at + 3]
  let tokens = header.split(" ").collect()
  let numbers : Array[Int] = []
  for token in tokens {
    let cleaned = token.trim().to_owned()
    if cleaned == "obj" {
      break
    }
    let value = @string.parse_int(cleaned) catch {
      _ => -1
    }
    if value >= 0 {
      numbers.push(value)
    }
  }
  if numbers.length() < 2 {
    None
  } else {
    Some((numbers[numbers.length() - 2], numbers[numbers.length() - 1]))
  }
}

///|
fn pdf_root(text : String) -> (Int, Int)? {
  let at = match text.find("/Root") {
    Some(index) => index
    None => return None
  }
  let tokens = text[at + 5:].split(" ").collect()
  let numbers : Array[Int] = []
  for token in tokens {
    let cleaned = token.trim().to_owned()
    if cleaned == "R" {
      break
    }
    let value = @string.parse_int(cleaned) catch {
      _ => -1
    }
    if value >= 0 {
      numbers.push(value)
    }
  }
  if numbers.length() >= 2 {
    Some((numbers[0], numbers[1]))
  } else {
    None
  }
}

///|
fn pdf_startxref(text : String) -> Int? {
  let at = match last_index(text, "startxref") {
    Some(index) => index
    None => return None
  }
  let mut i = at + 9
  while i < text.length() && is_space(text[i].to_char().unwrap()) {
    i += 1
  }
  let begin = i
  while i < text.length() && text[i].to_char().unwrap() >= '0' && text[i].to_char().unwrap() <= '9' {
    i += 1
  }
  if i == begin {
    return None
  }
  try {
    Some(@string.parse_int(text[begin:i].to_owned()))
  } catch {
    _ => None
  }
}

///|
fn acroform_reference(body : String) -> (Int, Int)? {
  let at = match body.find("/AcroForm") {
    Some(index) => index
    None => return None
  }
  let mut i = skip_spaces(body, at + 9)
  let begin = i
  while i < body.length() && body[i].to_char().unwrap() >= '0' &&
    body[i].to_char().unwrap() <= '9' {
    i += 1
  }
  if i == begin {
    return None
  }
  let first = @string.parse_int(body[begin:i].to_owned()) catch {
    _ => return None
  }
  i = skip_spaces(body, i)
  let second_begin = i
  while i < body.length() && body[i].to_char().unwrap() >= '0' &&
    body[i].to_char().unwrap() <= '9' {
    i += 1
  }
  if i == second_begin {
    return None
  }
  let second = @string.parse_int(body[second_begin:i].to_owned()) catch {
    _ => return None
  }
  i = skip_spaces(body, i)
  if i < body.length() && body[i].to_char().unwrap() == 'R' {
    Some((first, second))
  } else {
    None
  }
}

///|
fn add_need_appearances_dict(body : String) -> String? {
  if body.contains("/NeedAppearances") {
    return None
  }
  let open = match body.find("<<") {
    Some(index) => index + 2
    None => return None
  }
  Some(body[:open].to_owned() + " /NeedAppearances true " + body[open:].to_owned())
}

///|
fn choice_export_value(body : String, value : String) -> String {
  for pair in find_option_pairs(body, 0, body.length()) {
    if pair.0 == value {
      return pair.1
    }
  }
  value
}

///|
fn find_object_body(text : String, number : Int) -> String? {
  let mut pos = 0
  while pos < text.length() {
    let at = match text[pos:].find(" obj") {
      Some(index) => pos + index + 1
      None => return None
    }
    let (found, _) = match object_header(text, at) {
      Some(header) => header
      None => {
        pos = at + 3
        continue
      }
    }
    let body_start = at + 3
    let endobj = match text[body_start:].find("endobj") {
      Some(index) => body_start + index
      None => return None
    }
    if found == number {
      return Some(text[body_start:endobj].to_owned())
    }
    pos = endobj + 6
  }
  None
}

///|
fn add_need_appearances(body : String) -> String? {
  if body.contains("/NeedAppearances") {
    return None
  }
  let at = match body.find("/AcroForm") {
    Some(index) => index
    None => return None
  }
  let rest = body[at + 9:]
  let open = match rest.find("<<") {
    Some(index) => at + 9 + index + 2
    None => return None
  }
  Some(body[:open].to_owned() + " /NeedAppearances true " + body[open:].to_owned())
}

///|
fn replace_pdf_name(body : String, key : String, value : String) -> String {
  let at = match body.find(key) {
    Some(index) => index
    None => return body
  }
  let mut i = skip_spaces(body, at + key.length())
  let end = if i < body.length() && body[i].to_char().unwrap() == '/' {
    while i < body.length() && !is_space(body[i].to_char().unwrap()) &&
      body[i].to_char().unwrap() != '>' && body[i].to_char().unwrap() != ']' {
      i += 1
    }
    i
  } else {
    return body
  }
  body[:at + key.length()].to_owned() + " " + value + body[end:].to_owned()
}

///|
fn insert_pdf_name_after(body : String, key : String, value : String, name : String) -> String {
  let at = match body.find(key) {
    Some(index) => index
    None => return body
  }
  let mut i = skip_spaces(body, at + key.length())
  if i < body.length() &&
    (body[i].to_char().unwrap() == '(' || body[i].to_char().unwrap() == '<') {
    match field_name_string(body, i) {
      Some((_, end)) => i = end
      None => return body
    }
  } else if i < body.length() && body[i].to_char().unwrap() == '/' {
    while i < body.length() && !is_space(body[i].to_char().unwrap()) &&
      body[i].to_char().unwrap() != '>' && body[i].to_char().unwrap() != ']' {
      i += 1
    }
  } else {
    return body
  }
  body[:i].to_owned() + " " + name + " " + value + body[i:].to_owned()
}

///|
fn button_on_state(body : String) -> String? {
  let ap = match body.find("/AP") {
    Some(index) => index
    None => return None
  }
  let n = match body[ap:].find("/N") {
    Some(index) => ap + index
    None => return None
  }
  let open = match body[n:].find("<<") {
    Some(index) => n + index + 2
    None => return None
  }
  let mut i = open
  while i < body.length() {
    if body[i].to_char().unwrap() == '/' {
      let begin = i
      i += 1
      while i < body.length() && !is_space(body[i].to_char().unwrap()) &&
        body[i].to_char().unwrap() != '>' {
        i += 1
      }
      let name = body[begin:i].to_owned()
      if name != "/Off" && name != "/N" {
        return Some(name)
      }
    } else if body[i].to_char().unwrap() == '>' {
      break
    } else {
      i += 1
    }
  }
  None
}

///|
fn data_button_state(data : Json, name : String, on : String) -> String? {
  match data {
    Json::Object(object) =>
      match object.get(name) {
        Some(Json::True) => Some(on)
        Some(Json::False) => Some("/Off")
        Some(Json::String(text)) =>
          if text == "" {
            None
          } else if text.has_prefix("/") {
            Some(text)
          } else {
            Some("/" + text)
          }
        _ => None
      }
    _ => None
  }
}

///|
fn data_text(data : Json, name : String) -> String? {
  match data {
    Json::Object(object) =>
      match object.get(name) {
        Some(Json::String(text)) => Some(text)
        Some(Json::Number(number, ..)) => Some(number.to_string())
        Some(Json::True) => Some("true")
        Some(Json::False) => Some("false")
        _ => None
      }
    _ => None
  }
}

///|
/// Names of required fields whose data is missing or empty.
pub fn missing_required(pdf_bytes : Bytes, data_bytes : Bytes) -> Array[String] {
  let data = @json.parse(@utf8.decode_lossy(data_bytes[:])) catch {
    _ => return []
  }
  let missing : Array[String] = []
  for field in read_fields(pdf_bytes) {
    if !field.required {
      continue
    }
    let value = match data {
      Json::Object(object) =>
        match object.get(field.name) {
          Some(Json::String(text)) => text
          Some(Json::Number(number, ..)) => number.to_string()
          Some(Json::True) => "true"
          Some(Json::False) => "false"
          _ => ""
        }
      _ => ""
    }
    if value == "" {
      missing.push(field.name)
    }
  }
  missing
}

///|
/// Write field values into a classic PDF with an incremental update. The
/// original bytes stay untouched; new object versions, an xref section and
/// a trailer that points to the previous xref are appended.
pub fn fill_pdf(
  pdf_bytes : Bytes,
  data_bytes : Bytes,
  skip_read_only~ : Bool = false,
) -> Bytes raise PdfFillError {
  let data = @json.parse(@utf8.decode_lossy(data_bytes[:])) catch {
    _ => raise PdfFillError("form/pdf: the data is not JSON")
  }
  let text = @utf8.decode_lossy(pdf_bytes[:])
  let old_xref = match pdf_startxref(text) {
    Some(offset) => offset
    None => raise PdfFillError("form/pdf: the PDF has no startxref")
  }
  if old_xref < 0 || old_xref >= text.length() {
    raise PdfFillError("form/pdf: the startxref offset is invalid")
  }
  let classic_xref = old_xref + 4 <= text.length() &&
    text[old_xref:old_xref + 4] == "xref"
  let tail_end = if old_xref + 512 < text.length() {
    old_xref + 512
  } else {
    text.length()
  }
  let xref_stream = text[old_xref:tail_end].contains("/XRef")
  if !classic_xref && !xref_stream {
    raise PdfFillError("form/pdf: the PDF has no cross-reference section")
  }
  let root = match pdf_root(text) {
    Some(root) => root
    None => raise PdfFillError("form/pdf: the PDF has no Root")
  }
  let updates : Array[(Int, Int, String)] = []
  let mut pos = 0
  while pos < text.length() {
    let at = match text[pos:].find(" obj") {
      Some(index) => pos + index + 1
      None => break
    }
    let header = match object_header(text, at) {
      Some(header) => header
      None => {
        pos = at + 3
        continue
      }
    }
    let (number, generation) = header
    let body_start = at + 3
    let endobj = match text[body_start:].find("endobj") {
      Some(index) => body_start + index
      None => break
    }
    let body = text[body_start:endobj].to_owned()
    let t_at = match find_t(body) {
      Some(index) => index
      None => -1
    }
    let mut name = ""
    if t_at >= 0 {
      let name_at = skip_spaces(body, t_at + 2)
      if name_at < body.length() &&
        (body[name_at].to_char().unwrap() == '(' ||
          body[name_at].to_char().unwrap() == '<') {
        name = match field_name_string(body, name_at) {
          Some((name, _)) => name
          None => ""
        }
      }
    }
    let read_only = match find_flags(body, 0, body.length()) {
      Some(value) => (value & 1) != 0
      None => false
    }
    if name != "" && !(skip_read_only && read_only) {
      if body.contains("/Btn") {
        let on = match button_on_state(body) {
          Some(value) => value
          None => "/Yes"
        }
        match data_button_state(data, name, on) {
          Some(state) =>
            updates.push((
              number,
              generation,
              {
                let with_v = replace_pdf_name(body, "/V", state)
                if with_v.contains("/AS") {
                  replace_pdf_name(with_v, "/AS", state)
                } else {
                  insert_pdf_name_after(with_v, "/V", state, "/AS")
                }
              },
            ))
          None => ()
        }
      } else {
        let values = data_values(data, name)
        if body.contains("/Ch") && values.length() > 0 {
          let mapped = values.map(fn(value) { choice_export_value(body, value) })
          updates.push((number, generation, replace_pdf_repr(body, pdf_array_repr(mapped))))
        } else {
          match data_text(data, name) {
            Some(value) => {
              let value = match find_max_len(body, 0, body.length()) {
                Some(limit) =>
                  if limit >= 0 && value.length() > limit {
                    value[:limit].to_owned()
                  } else {
                    value
                  }
                None => value
              }
              let mapped = if body.contains("/Ch") {
                choice_export_value(body, value)
              } else {
                value
              }
              updates.push((number, generation, replace_pdf_value(body, mapped)))
            }
            None => ()
          }
        }
      }
    }
    pos = endobj + 6
  }
  match find_object_body(text, root.0) {
    Some(root_body) =>
      match acroform_reference(root_body) {
        Some((number, generation)) =>
          match find_object_body(text, number) {
            Some(acro_body) =>
              match add_need_appearances_dict(acro_body) {
                Some(updated) => updates.push((number, generation, updated))
                None => ()
              }
            None => ()
          }
        None =>
          match add_need_appearances(root_body) {
            Some(updated) => updates.push((root.0, root.1, updated))
            None => ()
          }
      }
    None => ()
  }
  if updates.is_empty() {
    return pdf_bytes
  }
  let out = pdf_bytes.to_array()
  if out.length() > 0 && out[out.length() - 1] != b'\n' {
    out.push(b'\n')
  }
  let new_entries : Array[(Int, Int, Int)] = []
  for update in updates {
    let (number, generation, body) = update
    let mut duplicate = false
    for entry in new_entries {
      if entry.0 == number {
        duplicate = true
      }
    }
    if duplicate {
      continue
    }
    let offset = out.length()
    new_entries.push((number, generation, offset))
    for byte in @utf8.encode(number.to_string() + " " + generation.to_string() + " obj\n") {
      out.push(byte)
    }
    for byte in @utf8.encode(body) {
      out.push(byte)
    }
    for byte in @utf8.encode("\nendobj\n") {
      out.push(byte)
    }
  }
  let xref_at = out.length()
  for byte in @utf8.encode("xref\n") {
    out.push(byte)
  }
  let mut max_number = 0
  for entry in new_entries {
    max_number = Int::max(max_number, entry.0)
    for byte in @utf8.encode(entry.0.to_string() + " 1\n") {
      out.push(byte)
    }
    let offset = entry.2
    let digits = offset.to_string()
    let mut text_offset = ""
    for _ in 0..<(10 - digits.length()) {
      text_offset = text_offset + "0"
    }
    for byte in @utf8.encode(text_offset + digits + " 00000 n \n") {
      out.push(byte)
    }
  }
  let trailer =
    "trailer\n<< /Size " + (max_number + 1).to_string() + " /Root " +
    root.0.to_string() + " " + root.1.to_string() + " R /Prev " +
    old_xref.to_string() + " >>\nstartxref\n" + xref_at.to_string() + "\n%%EOF\n"
  for byte in @utf8.encode(trailer) {
    out.push(byte)
  }
  Bytes::from_array(out)
}
