///|
/// A Type 1 font program converted to a bare CFF.
priv struct Type1Font {
  mut name : String
  mut font_matrix : Array[Double]
  mut bbox : Array[Double]
  encoding : Map[Int, String]
  info : Map[String, String]
  mut italic : Double
  mut fixed_pitch : Bool
  mut len_iv : Int
  subrs : Array[Bytes]
  names : Array[String]
  charstrings : Map[String, Bytes]
}

///|
priv struct PsScanner {
  data : Bytes
  mut pos : Int
}

///|
fn ps_space(c : Byte) -> Bool {
  c == b' ' || c == b'\t' || c == b'\r' || c == b'\n' || c == b'\x0c' || c == 0
}

///|
fn ps_delim(c : Byte) -> Bool {
  c == b'(' || c == b')' || c == b'<' || c == b'>' || c == b'[' ||
    c == b']' || c == b'{' || c == b'}' || c == b'/' || c == b'%'
}

///|
fn PsScanner::next(self : PsScanner) -> String? {
  while self.pos < self.data.length() {
    let c = self.data[self.pos]
    if ps_space(c) {
      self.pos += 1
    } else if c == b'%' {
      while self.pos < self.data.length() && self.data[self.pos] != b'\n' && self.data[self.pos] != b'\r' {
        self.pos += 1
      }
    } else {
      let start = self.pos
      if c == b'(' {
        let mut depth = 0
        while self.pos < self.data.length() {
          let d = self.data[self.pos]
          if d == b'\\' {
            self.pos += 1
          } else if d == b'(' {
            depth += 1
          } else if d == b')' {
            depth -= 1
          }
          self.pos += 1
          if depth == 0 { break }
        }
        return Some(@utf8.decode_lossy(self.data[start:Int::min(self.pos, self.data.length())]))
      }
      if c == b'[' || c == b']' || c == b'{' || c == b'}' {
        self.pos += 1
        return Some(@utf8.decode_lossy(self.data[start:self.pos]))
      }
      if c == b'<' || c == b'>' {
        self.pos += 1
        if self.pos < self.data.length() && self.data[self.pos] == c {
          self.pos += 1
        }
        return Some(@utf8.decode_lossy(self.data[start:self.pos]))
      }
      if c == b'/' {
        self.pos += 1
      }
      while self.pos < self.data.length() && !ps_space(self.data[self.pos]) && !ps_delim(self.data[self.pos]) {
        self.pos += 1
      }
      if self.pos == start {
        self.pos += 1
      }
      return Some(@utf8.decode_lossy(self.data[start:self.pos]))
    }
  }
  None
}

///|
fn PsScanner::number(self : PsScanner) -> Double? {
  match self.next() {
    Some(text) => Some(@string.parse_double(text) catch { _ => return None })
    None => None
  }
}

///|
fn PsScanner::numbers(self : PsScanner) -> Array[Double] {
  let open = self.next()
  match open {
    Some(text) =>
      if text != "[" && text != "{" {
        return []
      }
    None => return []
  }
  let output : Array[Double] = []
  while true {
    match self.next() {
      None => return output
      Some(text) => {
        if text == "]" || text == "}" {
          return output
        }
        let parsed = try {
          Some(@string.parse_double(text))
        } catch {
          _ => None
        }
        match parsed {
          Some(value) => output.push(value)
          None => ()
        }
      }
    }
  }
  output
}

///|
fn t1_decrypt(data : Bytes, r : Int, skip : Int) -> Bytes {
  if skip < 0 {
    return data
  }
  let output : Array[Byte] = []
  let mut state = r
  for c in data {
    output.push(c ^ ((state >> 8) & 255).to_byte())
    state = ((c.to_int() + state) * 52845 + 22719) & 0xffff
  }
  if skip >= output.length() {
    return b""
  }
  Bytes::from_array(output[skip:])
}

///|
fn t1_hex(c : Byte) -> Int {
  if c >= b'0' && c <= b'9' { c.to_int() - 48 }
  else if c >= b'a' && c <= b'f' { c.to_int() - 87 }
  else if c >= b'A' && c <= b'F' { c.to_int() - 55 }
  else { -1 }
}

///|
fn t1_ps_string(token : String) -> String {
  if token.length() < 2 || token[0].unsafe_to_char() != '(' {
    return ""
  }
  let body = token[1:token.length() - 1]
  let output = StringBuilder()
  let mut index = 0
  while index < body.length() {
    let c = body[index].unsafe_to_char()
    if c == '\\' && index + 1 < body.length() {
      index += 1
      let d = body[index].unsafe_to_char()
      match d {
        'n' => output.write_char('\n')
        'r' => output.write_char('\r')
        't' => output.write_char('\t')
        _ => output.write_char(d)
      }
      index += 1
    } else {
      output.write_char(c)
      index += 1
    }
  }
  output.to_string()
}

///|
fn parse_type1(data : Bytes) -> Type1Font raise {
  let mut input = data
  if input.length() > 6 && input[0] == b'\x80' {
    let joined : Array[Byte] = []
    let mut pos = 0
    while pos + 6 <= input.length() && input[pos] == b'\x80' && input[pos + 1] != 3 {
      let length = (input[pos + 2].to_int() |
        (input[pos + 3].to_int() << 8) |
        (input[pos + 4].to_int() << 16) |
        (input[pos + 5].to_int() << 24))
      if length < 0 || pos + 6 + length > input.length() {
        raise Failure("type1: truncated PFB segment")
      }
      let start = pos + 6
      let end = start + length
      for index in start..<end {
        joined.push(input[index])
      }
      pos += 6 + length
    }
    input = Bytes::from_array(joined)
  }
  let font : Type1Font = {
    name: "",
    font_matrix: [0.001, 0.0, 0.0, 0.001, 0.0, 0.0],
    bbox: [],
    encoding: Map([]),
    info: Map([]),
    italic: 0.0,
    fixed_pitch: false,
    len_iv: 4,
    subrs: [],
    names: [],
    charstrings: Map([]),
  }
  let scanner : PsScanner = { data: input, pos: 0 }
  let mut eexec = -1
  while eexec < 0 {
    match scanner.next() {
      None => raise Failure("type1: no eexec section")
      Some(token) =>
        if token == "eexec" {
          eexec = scanner.pos
        } else if token == "/FontName" {
          match scanner.next() {
            Some(value) => font.name = if value.has_prefix("/") { value[1:].to_owned() } else { value }
            None => ()
          }
        } else if token == "/FontMatrix" {
          let values = scanner.numbers()
          if values.length() == 6 { font.font_matrix = values }
        } else if token == "/FontBBox" {
          let values = scanner.numbers()
          if values.length() == 4 { font.bbox = values }
        } else if token == "/Encoding" {
          match scanner.next() {
            Some(value) =>
              if value != "StandardEncoding" {
                while true {
                  match scanner.next() {
                    None => break
                    Some(part) => {
                      if part == "def" { break }
                      if part != "dup" { continue }
                      let save = scanner.pos
                      let code = scanner.number()
                      let name = scanner.next()
                      let put = scanner.next()
                      if code is Some(value) && name is Some(name_value) &&
                        name_value.has_prefix("/") && put == Some("put") {
                        let code_value = value.to_int()
                        if code_value >= 0 && code_value < 256 {
                          font.encoding[code_value] = name_value[1:].to_owned()
                        }
                      } else {
                        scanner.pos = save
                      }
                    }
                  }
                }
              }
            None => ()
          }
        } else if token == "/Notice" || token == "/Copyright" || token == "/FullName" ||
          token == "/FamilyName" || token == "/Weight" {
          let save = scanner.pos
          match scanner.next() {
            Some(value) =>
              if value.has_prefix("(") {
                font.info[token[1:].to_owned()] = t1_ps_string(value)
              } else {
                scanner.pos = save
              }
            None => scanner.pos = save
          }
        } else if token == "/ItalicAngle" {
          match scanner.number() {
            Some(value) => font.italic = value
            None => ()
          }
        } else if token == "/isFixedPitch" {
          match scanner.next() {
            Some(value) => font.fixed_pitch = value == "true"
            None => ()
          }
        }
    }
  }
  let mut eexec_pos = eexec
  while eexec_pos < input.length() && ps_space(input[eexec_pos]) {
    eexec_pos += 1
  }
  let encrypted = input[eexec_pos:]
  let raw_bytes : Array[Byte] = []
  if encrypted.length() >= 4 && t1_hex(encrypted[0]) >= 0 &&
    t1_hex(encrypted[1]) >= 0 && t1_hex(encrypted[2]) >= 0 &&
    t1_hex(encrypted[3]) >= 0 {
    let mut high = 0
    let mut half = false
    for c in encrypted {
      let value = t1_hex(c)
      if value < 0 {
        if ps_space(c) { continue }
        break
      }
      if half {
        raw_bytes.push(((high << 4) | value).to_byte())
      } else {
        high = value
      }
      half = !half
    }
  } else {
    for c in encrypted {
      raw_bytes.push(c)
    }
  }
  let private_data = t1_decrypt(Bytes::from_array(raw_bytes), 55665, 4)
  let private_scanner : PsScanner = { data: private_data, pos: 0 }
  let subrs_raw : Array[Bytes] = []
  let charstrings_raw : Map[String, Bytes] = Map([])
  let read_binary = fn() -> Bytes? {
    match private_scanner.number() {
      None => None
      Some(value) =>
        if value < 0.0 || value > private_data.length().to_double() {
          None
        } else {
          ignore(private_scanner.next())
          private_scanner.pos += 1
          let count = value.to_int()
          if private_scanner.pos + count > private_data.length() {
            None
          } else {
            let bytes = private_data[private_scanner.pos:private_scanner.pos + count].to_owned()
            private_scanner.pos += count
            Some(bytes)
          }
        }
    }
  }
  while true {
    match private_scanner.next() {
      None => break
      Some(token) => {
        if token == "/lenIV" {
          match private_scanner.number() {
            Some(value) => font.len_iv = value.to_int()
            None => ()
          }
        } else if token == "/Subrs" {
          match private_scanner.number() {
            Some(count) =>
              if count < 0.0 || count > 65535.0 {
                raise Failure("type1: bad Subrs")
              } else {
                for _ in 0..<count.to_int() {
                  while true {
                    match private_scanner.next() {
                      None => break
                      Some(part) => {
                        if part == "dup" { break }
                      }
                    }
                  }
                  let save = private_scanner.pos
                  match private_scanner.number() {
                    None => {
                      private_scanner.pos = save
                      break
                    }
                    Some(_) =>
                      match read_binary() {
                        Some(bytes) => subrs_raw.push(bytes)
                        None => raise Failure("type1: truncated Subrs")
                      }
                  }
                }
              }
            None => raise Failure("type1: bad Subrs")
          }
        } else if token == "/CharStrings" {
          match private_scanner.number() {
            Some(count) =>
              if count < 0.0 {
                raise Failure("type1: bad CharStrings")
              } else {
                while font.names.length() < count.to_int() {
                  match private_scanner.next() {
                    None => break
                    Some(name) => {
                      if name == "end" { break }
                      if !name.has_prefix("/") { continue }
                      match read_binary() {
                        Some(bytes) => {
                          let key = name[1:].to_owned()
                          if !charstrings_raw.contains(key) {
                            charstrings_raw[key] = bytes
                            font.names.push(key)
                          }
                        }
                        None => raise Failure("type1: truncated CharStrings")
                      }
                    }
                  }
                }
              }
            None => raise Failure("type1: bad CharStrings")
          }
        }
      }
    }
  }
  if font.names.is_empty() {
    raise Failure("type1: no CharStrings")
  }
  for bytes in subrs_raw {
    font.subrs.push(t1_decrypt(bytes, 4330, font.len_iv))
  }
  for name in font.names {
    match charstrings_raw.get(name) {
      Some(bytes) => font.charstrings[name] = t1_decrypt(bytes, 4330, font.len_iv)
      None => ()
    }
  }
  font
}

///|
priv struct T2Writer {
  out : Array[Byte]
  mut cx : Double
  mut cy : Double
  mut op : Int
  args : Array[Double]
  mut width : Double
  mut width_done : Bool
}

///|
fn t2_number(out : Array[Byte], value : Double) -> Unit {
  if value == value.floor() && value >= -32768.0 && value <= 32767.0 {
    let number = value.to_int()
    if number >= -107 && number <= 107 {
      out.push((number + 139).to_byte())
    } else if number >= 108 && number <= 1131 {
      let adjusted = number - 108
      out.push((adjusted >> 8).to_byte() + 247U.to_byte())
      out.push(adjusted.to_byte())
    } else if number >= -1131 && number <= -108 {
      let adjusted = -number - 108
      out.push((adjusted >> 8).to_byte() + 251U.to_byte())
      out.push(adjusted.to_byte())
    } else {
      out.push(28)
      out.push((number >> 8).to_byte())
      out.push(number.to_byte())
    }
  } else {
    let fixed = (value * 65536.0).round().to_int()
    out.push(255)
    out.push((fixed >> 24).to_byte())
    out.push((fixed >> 16).to_byte())
    out.push((fixed >> 8).to_byte())
    out.push(fixed.to_byte())
  }
}

///|
fn T2Writer::flush(self : T2Writer) -> Unit {
  if self.op == 0 {
    return
  }
  for value in self.args {
    t2_number(self.out, value)
  }
  self.out.push(self.op.to_byte())
  self.op = 0
  self.args.clear()
}

///|
fn T2Writer::delta(self : T2Writer, x : Double, y : Double) -> (Double, Double) {
  let mut dx = x - self.cx
  let mut dy = y - self.cy
  if dx != dx.floor() {
    dx = (dx * 65536.0).round() / 65536.0
  }
  if dy != dy.floor() {
    dy = (dy * 65536.0).round() / 65536.0
  }
  self.cx += dx
  self.cy += dy
  (dx, dy)
}

///|
fn T2Writer::prefix_width(self : T2Writer) -> Unit {
  if !self.width_done {
    self.width_done = true
    if self.width != 0.0 {
      t2_number(self.out, self.width)
    }
  }
}

///|
fn T2Writer::move_to(self : T2Writer, x : Double, y : Double) -> Unit {
  self.flush()
  let (dx, dy) = self.delta(x, y)
  self.prefix_width()
  t2_number(self.out, dx)
  t2_number(self.out, dy)
  self.out.push(21)
}

///|
fn T2Writer::segment(self : T2Writer, op : Int, pts : Array[Double]) -> Unit {
  if self.op != op || self.args.length() + pts.length() > 48 {
    self.flush()
    self.op = op
  }
  let mut index = 0
  while index + 1 < pts.length() {
    let (dx, dy) = self.delta(pts[index], pts[index + 1])
    self.args.push(dx)
    self.args.push(dy)
    index += 2
  }
}

///|
fn T2Writer::end(self : T2Writer) -> Bytes {
  self.flush()
  self.prefix_width()
  self.out.push(14)
  Bytes::from_array(self.out)
}

///|
priv struct T1Converter {
  font : Type1Font
  writer : T2Writer
  mut stack : Array[Double]
  mut ps : Array[Double]
  mut x : Double
  mut y : Double
  mut ox : Double
  mut oy : Double
  mut sbx : Double
  mut moved : Bool
  mut component : Bool
  mut flex : Bool
  flex_points : Array[(Double, Double)]
  mut ops : Int
}

///|
fn T1Converter::pop(self : T1Converter, count : Int) -> Array[Double]? {
  if self.stack.length() < count {
    return None
  }
  let start = self.stack.length() - count
  let values = self.stack[start:].to_owned()
  self.stack = self.stack[:start].to_owned()
  Some(values)
}

///|
fn T1Converter::move_to(self : T1Converter, x : Double, y : Double) -> Unit {
  self.x = x
  self.y = y
  if self.flex {
    self.flex_points.push((x, y))
    return
  }
  self.writer.move_to(x, y)
  self.moved = true
}

///|
fn T1Converter::line_to(self : T1Converter, x : Double, y : Double) -> Unit {
  if !self.moved {
    self.writer.move_to(self.x, self.y)
    self.moved = true
  }
  self.x = x
  self.y = y
  self.writer.segment(5, [x, y])
}

///|
fn T1Converter::curve_to(self : T1Converter, x1 : Double, y1 : Double, x2 : Double, y2 : Double, x3 : Double, y3 : Double) -> Unit {
  if !self.moved {
    self.writer.move_to(self.x, self.y)
    self.moved = true
  }
  self.x = x3
  self.y = y3
  self.writer.segment(8, [x1, y1, x2, y2, x3, y3])
}

///|
fn T1Converter::run(self : T1Converter, data : Bytes, depth : Int) -> Bool raise {
  if depth > 10 {
    return false
  }
  let mut index = 0
  while index < data.length() {
    self.ops += 1
    if self.ops > 100000 || self.stack.length() > 64 {
      return false
    }
    let value = data[index].to_int()
    if value >= 32 && value <= 246 {
      self.stack.push((value - 139).to_double())
      index += 1
      continue
    }
    if value >= 247 && value <= 254 {
      if index + 1 >= data.length() { return false }
      if value <= 250 {
        self.stack.push(((value - 247) * 256 + data[index + 1].to_int() + 108).to_double())
      } else {
        self.stack.push((-((value - 251) * 256) - data[index + 1].to_int() - 108).to_double())
      }
      index += 2
      continue
    }
    if value == 255 {
      if index + 5 > data.length() { return false }
      let number = (data[index + 1].to_int() << 24) |
        (data[index + 2].to_int() << 16) |
        (data[index + 3].to_int() << 8) |
        data[index + 4].to_int()
      self.stack.push(number.to_double())
      index += 5
      continue
    }
    let mut op = value
    index += 1
    if value == 12 {
      if index >= data.length() { return false }
      op = 1200 + data[index].to_int()
      index += 1
    }
    if op == 1 || op == 3 || op == 9 || op == 1200 || op == 1201 || op == 1202 {
      continue
    }
    if op == 13 || op == 1207 {
      let n = if op == 1207 { 4 } else { 2 }
      let args = match self.pop(n) {
        Some(value) => value
        None => return false
      }
      let mut sby = 0.0
      let wx = if n == 4 { args[2] } else { args[1] }
      if n == 4 { sby = args[1] }
      if !self.component {
        self.writer.width = wx
        self.sbx = args[0]
      }
      self.x = self.ox + args[0]
      self.y = self.oy + sby
    } else if op == 21 {
      let args = match self.pop(2) {
        Some(value) => value
        None => return false
      }
      self.move_to(self.x + args[0], self.y + args[1])
    } else if op == 22 {
      let args = match self.pop(1) {
        Some(value) => value
        None => return false
      }
      self.move_to(self.x + args[0], self.y)
    } else if op == 4 {
      let args = match self.pop(1) {
        Some(value) => value
        None => return false
      }
      self.move_to(self.x, self.y + args[0])
    } else if op == 5 {
      let args = match self.pop(2) {
        Some(value) => value
        None => return false
      }
      self.line_to(self.x + args[0], self.y + args[1])
    } else if op == 6 {
      let args = match self.pop(1) {
        Some(value) => value
        None => return false
      }
      self.line_to(self.x + args[0], self.y)
    } else if op == 7 {
      let args = match self.pop(1) {
        Some(value) => value
        None => return false
      }
      self.line_to(self.x, self.y + args[0])
    } else if op == 8 || op == 30 || op == 31 {
      let mut d : Array[Double] = []
      if op == 8 {
        d = match self.pop(6) { Some(value) => value
          None => return false }
      } else if op == 30 {
        let args = match self.pop(4) { Some(value) => value
          None => return false }
        d = [0.0, args[0], args[1], args[2], args[3], 0.0]
      } else {
        let args = match self.pop(4) { Some(value) => value
          None => return false }
        d = [args[0], 0.0, args[1], args[2], 0.0, args[3]]
      }
      let x1 = self.x + d[0]
      let y1 = self.y + d[1]
      let x2 = x1 + d[2]
      let y2 = y1 + d[3]
      self.curve_to(x1, y1, x2, y2, x2 + d[4], y2 + d[5])
    } else if op == 10 {
      let args = match self.pop(1) { Some(value) => value
          None => return false }
      let k = args[0].to_int()
      if k < 0 || k >= self.font.subrs.length() {
        return false
      }
      if self.run(self.font.subrs[k], depth + 1) {
        return true
      }
    } else if op == 11 {
      return false
    } else if op == 14 {
      return true
    } else if op == 1206 {
      let args = match self.pop(5) { Some(value) => value
          None => return false }
      if self.component {
        return false
      }
      let asb = args[0]
      let adx = args[1]
      let ady = args[2]
      let base_code = args[3].to_int()
      let accent_code = args[4].to_int()
      if base_code < 0 || base_code > 255 || accent_code < 0 || accent_code > 255 {
        return false
      }
      let base_name = pdf_standard_encoding[base_code]
      let accent_name = pdf_standard_encoding[accent_code]
      let base = match self.font.charstrings.get(base_name) { Some(value) => value
          None => return false }
      let accent = match self.font.charstrings.get(accent_name) { Some(value) => value
          None => return false }
      self.component = true
      let parts = [base, accent]
      let mut part_index = 0
      for part in parts {
        self.stack.clear()
        self.moved = false
        self.ox = 0.0
        self.oy = 0.0
        if part_index == 1 {
          self.ox = self.sbx + adx - asb
          self.oy = ady
        }
        if self.run(part, depth + 1) is _ {
          ()
        }
        part_index += 1
      }
      return true
    } else if op == 1212 {
      let args = match self.pop(2) { Some(value) => value
          None => return false }
      if args[1] == 0.0 { return false }
      self.stack.push(args[0] / args[1])
    } else if op == 1216 {
      let args = match self.pop(2) { Some(value) => value
          None => return false }
      let n = args[0].to_int()
      let which = args[1].to_int()
      if n < 0 { return false }
      let values = match self.pop(n) { Some(value) => value
          None => return false }
      if which == 0 && n == 3 {
        self.flex = false
        let points = self.flex_points
        if points.length() == 7 {
          self.curve_to(points[1].0, points[1].1, points[2].0, points[2].1, points[3].0, points[3].1)
          self.curve_to(points[4].0, points[4].1, points[5].0, points[5].1, points[6].0, points[6].1)
        } else if !points.is_empty() {
          let last = points[points.length() - 1]
          self.line_to(last.0, last.1)
        }
        self.ps = [values[2], values[1]]
      } else if which == 1 && n == 0 {
        self.flex = true
        self.flex_points.clear()
      } else if which == 2 && n == 0 {
        ()
      } else if which == 3 && n == 1 {
        self.ps = [values[0]]
      } else if which >= 14 && which <= 18 {
        return false
      } else {
        self.ps.clear()
        let mut k = values.length() - 1
        while k >= 0 {
          self.ps.push(values[k])
          k -= 1
        }
      }
    } else if op == 1217 {
      if self.ps.is_empty() { return false }
      self.stack.push(self.ps[self.ps.length() - 1])
      self.ps = self.ps[:self.ps.length() - 1].to_owned()
    } else if op == 1233 {
      let args = match self.pop(2) { Some(value) => value
          None => return false }
      self.x = self.ox + args[0]
      self.y = self.oy + args[1]
    } else {
      return false
    }
    self.stack.clear()
  }
  false
}

///|
fn t1_convert_glyph(font : Type1Font, name : String) -> Bytes {
  let data = match font.charstrings.get(name) {
    Some(value) => value
    None => return b"\x0e"
  }
  let writer : T2Writer = {
    out: [],
    cx: 0.0,
    cy: 0.0,
    op: 0,
    args: [],
    width: 0.0,
    width_done: false,
  }
  let converter : T1Converter = {
    font,
    writer,
    stack: [],
    ps: [],
    x: 0.0,
    y: 0.0,
    ox: 0.0,
    oy: 0.0,
    sbx: 0.0,
    moved: false,
    component: false,
    flex: false,
    flex_points: [],
    ops: 0,
  }
  let _ = converter.run(data, 0) catch {
    _ => return b"\x0e"
  }
  converter.writer.end()
}

///|
fn t1_dict_number(out : Array[Byte], value : Double) -> Unit {
  if value == value.floor() && value >= -2147483648.0 && value <= 2147483647.0 {
    let number = value.to_int()
    if number >= -107 && number <= 107 {
      out.push((number + 139).to_byte())
    } else if number >= 108 && number <= 1131 {
      let adjusted = number - 108
      out.push((adjusted >> 8).to_byte() + 247U.to_byte())
      out.push(adjusted.to_byte())
    } else if number >= -1131 && number <= -108 {
      let adjusted = -number - 108
      out.push((adjusted >> 8).to_byte() + 251U.to_byte())
      out.push(adjusted.to_byte())
    } else if number >= -32768 && number <= 32767 {
      out.push(28)
      out.push((number >> 8).to_byte())
      out.push(number.to_byte())
    } else {
      out.push(29)
      out.push((number >> 24).to_byte())
      out.push((number >> 16).to_byte())
      out.push((number >> 8).to_byte())
      out.push(number.to_byte())
    }
  } else {
    let text = value.to_string()
    let nibbles : Array[Int] = []
    for character in text {
      let c = character
      if c >= '0' && c <= '9' {
        nibbles.push(c.to_int() - 48)
      } else if c == '.' {
        nibbles.push(10)
      } else if c == '-' {
        nibbles.push(14)
      }
    }
    nibbles.push(15)
    if nibbles.length() % 2 == 1 {
      nibbles.push(15)
    }
    out.push(30)
    let mut index = 0
    while index + 1 < nibbles.length() {
      out.push(((nibbles[index] << 4) | nibbles[index + 1]).to_byte())
      index += 2
    }
  }
}

///|
fn cff_index(items : Array[Bytes]) -> Bytes {
  if items.is_empty() {
    return b"\x00\x00"
  }
  let out : Array[Byte] = [
    (items.length() >> 8).to_byte(), items.length().to_byte(),
  ]
  out.push(4)
  let offsets : Array[Int] = []
  let mut total = 1
  for item in items {
    offsets.push(total)
    total += item.length()
  }
  offsets.push(total)
  for offset in offsets {
    out.push((offset >> 24).to_byte())
    out.push((offset >> 16).to_byte())
    out.push((offset >> 8).to_byte())
    out.push(offset.to_byte())
  }
  for item in items {
    for byte in item {
      out.push(byte)
    }
  }
  Bytes::from_array(out)
}

///|
fn t1_build_cff(font : Type1Font) -> Bytes {
  let names : Array[String] = [".notdef"]
  for name in font.names {
    if name != ".notdef" {
      names.push(name)
    }
  }
  let charstrings : Array[Bytes] = []
  for name in names {
    charstrings.push(t1_convert_glyph(font, name))
  }
  let strings : Array[Bytes] = []
  for index in 1..<names.length() {
    strings.push(@utf8.encode(names[index]))
  }
  let charset : Array[Byte] = [0]
  for index in 0..<strings.length() {
    let sid = 391 + index
    charset.push((sid >> 8).to_byte())
    charset.push(sid.to_byte())
  }
  let private_dict : Array[Byte] = [139, 20]
  let name = if font.name == "" { "Type1" } else { font.name }
  let name_index = cff_index([@utf8.encode(name)])
  let string_index = cff_index(strings)
  let gsubr_index = cff_index([])
  let charstrings_index = cff_index(charstrings)
  let mut offset_charset = 0
  let mut offset_charstrings = 0
  let mut offset_private = 0
  let mut top_length = 0
  for _ in 0..<8 {
    let dict : Array[Byte] = []
    if font.bbox.length() == 4 {
      for value in font.bbox { t1_dict_number(dict, value) }
      dict.push(5)
    }
    let matrix = font.font_matrix
    if matrix.length() == 6 &&
      (matrix[0] != 0.001 || matrix[1] != 0.0 || matrix[2] != 0.0 ||
        matrix[3] != 0.001 || matrix[4] != 0.0 || matrix[5] != 0.0) {
      for value in matrix { t1_dict_number(dict, value) }
      dict.push(12)
      dict.push(7)
    }
    t1_dict_number(dict, offset_charset.to_double())
    dict.push(15)
    t1_dict_number(dict, offset_charstrings.to_double())
    dict.push(17)
    t1_dict_number(dict, private_dict.length().to_double())
    t1_dict_number(dict, offset_private.to_double())
    dict.push(18)
    let top_index = cff_index([Bytes::from_array(dict)])
    let new_offset_charset = 4 + name_index.length() + top_index.length() + string_index.length() + gsubr_index.length()
    let new_offset_charstrings = new_offset_charset + charset.length()
    let new_offset_private = new_offset_charstrings + charstrings_index.length()
    let converged = new_offset_charset == offset_charset &&
      new_offset_charstrings == offset_charstrings &&
      new_offset_private == offset_private &&
      top_index.length() == top_length
    offset_charset = new_offset_charset
    offset_charstrings = new_offset_charstrings
    offset_private = new_offset_private
    top_length = top_index.length()
    if converged {
      break
    }
  }
  let dict : Array[Byte] = []
  if font.bbox.length() == 4 {
    for value in font.bbox { t1_dict_number(dict, value) }
    dict.push(5)
  }
  let matrix = font.font_matrix
  if matrix.length() == 6 &&
    (matrix[0] != 0.001 || matrix[1] != 0.0 || matrix[2] != 0.0 ||
      matrix[3] != 0.001 || matrix[4] != 0.0 || matrix[5] != 0.0) {
    for value in matrix { t1_dict_number(dict, value) }
    dict.push(12)
    dict.push(7)
  }
  t1_dict_number(dict, offset_charset.to_double())
  dict.push(15)
  t1_dict_number(dict, offset_charstrings.to_double())
  dict.push(17)
  t1_dict_number(dict, private_dict.length().to_double())
  t1_dict_number(dict, offset_private.to_double())
  dict.push(18)
  let top_index = cff_index([Bytes::from_array(dict)])
  let out : Array[Byte] = [1, 0, 4, 4]
  for part in [name_index, top_index, string_index, gsubr_index, Bytes::from_array(charset), charstrings_index, Bytes::from_array(private_dict)] {
    for byte in part { out.push(byte) }
  }
  Bytes::from_array(out)
}

///|
fn type1_to_cff(data : Bytes) -> Bytes? {
  let font = parse_type1(data) catch { _ => return None }
  Some(t1_build_cff(font))
}
