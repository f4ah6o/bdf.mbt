///|
priv struct CgmElement {
  class : Int
  id : Int
  data : Bytes
}

///|
fn cgm_u16(data : Bytes, offset : Int) -> Int {
  if offset + 1 >= data.length() {
    return 0
  }
  (data[offset].to_int() << 8) | data[offset + 1].to_int()
}

///|
fn cgm_u32(data : Bytes, offset : Int) -> Int {
  if offset + 3 >= data.length() {
    return 0
  }
  (data[offset].to_int() << 24) |
  (data[offset + 1].to_int() << 16) |
  (data[offset + 2].to_int() << 8) |
  data[offset + 3].to_int()
}

///|
fn cgm_float(data : Bytes, offset : Int) -> Double {
  Float::reinterpret_from_uint(cgm_u32(data, offset).to_uint()).to_double()
}

///|
fn read_cgm_elements(data : Bytes) -> Array[CgmElement] raise {
  if data.length() >= 2 && data[0] == 0x1f && data[1] == 0x8b {
    raise Failure("cgm: gzip-compressed metafiles are not supported yet")
  }
  if cgm_is_clear_text(data) {
    return read_clear_text_elements(data)
  }
  let output : Array[CgmElement] = []
  let mut offset = 0
  while offset + 2 <= data.length() {
    if offset % 2 == 1 { offset += 1 }
    if offset + 2 > data.length() { break }
    let header = cgm_u16(data, offset)
    offset += 2
    let class = header >> 12
    let id = (header >> 5) & 0x7f
    let length = header & 0x1f
    let chunks : Array[Byte] = []
    if length < 31 {
      let end = Int::min(offset + length, data.length())
      for index in offset..<end {
        chunks.push(data[index])
      }
      offset = end
    } else {
      let mut more = true
      while more && offset + 2 <= data.length() {
        let word = cgm_u16(data, offset)
        offset += 2
        let count = word & 0x7fff
        let end = Int::min(offset + count, data.length())
        for index in offset..<end {
          chunks.push(data[index])
        }
        offset = end
        more = (word & 0x8000) != 0
        if more && offset % 2 == 1 { offset += 1 }
      }
    }
    if class == 0 && id == 0 {
      continue
    }
    output.push({ class, id, data: Bytes::from_array(chunks) })
    if class == 0 && id == 2 {
      break
    }
  }
  output
}

///|
priv struct CgmParams {
  data : Bytes
  mut offset : Int
  mut vdc_real : Bool
  mut vdc_bits : Int
}

///|
fn CgmParams::new(data : Bytes) -> CgmParams {
  { data, offset: 0, vdc_real: false, vdc_bits: 16 }
}

///|
fn CgmParams::more(self : CgmParams) -> Bool {
  self.offset < self.data.length()
}

///|
fn CgmParams::u8(self : CgmParams) -> Int {
  if self.offset >= self.data.length() { return 0 }
  let value = self.data[self.offset].to_int()
  self.offset += 1
  value
}

///|
fn CgmParams::u16(self : CgmParams) -> Int {
  let value = cgm_u16(self.data, self.offset)
  self.offset += 2
  value
}

///|
fn CgmParams::i16(self : CgmParams) -> Int {
  let value = self.u16()
  if value >= 0x8000 { value - 0x10000 } else { value }
}

///|
/// An unsigned 16-bit value (a colour table value may use the whole range).
fn CgmParams::u16_value(self : CgmParams) -> Int {
  self.u16()
}

///|
fn CgmParams::i32(self : CgmParams) -> Int {
  let value = cgm_u32(self.data, self.offset)
  self.offset += 4
  value
}

///|
fn CgmParams::real(self : CgmParams) -> Double {
  let value = cgm_float(self.data, self.offset)
  self.offset += 4
  value
}

///|
fn CgmParams::vdc(self : CgmParams) -> Double {
  if self.vdc_real {
    self.real()
  } else if self.vdc_bits == 32 {
    self.i32().to_double()
  } else {
    self.i16().to_double()
  }
}

///|
fn CgmParams::point(self : CgmParams) -> @cad.Point {
  let x = self.vdc()
  { x, y: self.vdc() }
}

///|
fn CgmParams::string(self : CgmParams) -> Bytes {
  if self.offset >= self.data.length() {
    return b""
  }
  let length = self.data[self.offset].to_int()
  self.offset += 1
  let end = Int::min(self.offset + length, self.data.length())
  let value = self.data[self.offset:end].to_owned()
  self.offset = end
  value
}

///|
fn cgm_decode_text(data : Bytes) -> String {
  let mut high = 0
  let mut euc = true
  for byte in data {
    let value = byte.to_int()
    if value >= 0x80 {
      high += 1
      if value < 0xa1 && value != 0x8e && value != 0x8f {
        euc = false
      }
    }
  }
  if high > 0 && euc {
    match @encoding.decode(data, "EUC-JP") {
      Ok(value) => return value
      Err(_) => ()
    }
  }
  match @encoding.decode(data, "shift_jis") {
    Ok(value) => value
    Err(_) => @utf8.decode_lossy(data)
  }
}

///|
/// A clear-text metafile starts with `BEGMF` (optionally after whitespace).
fn cgm_is_clear_text(data : Bytes) -> Bool {
  let head = @utf8.decode_lossy(data[:Int::min(data.length(), 64)].to_owned())
  let trimmed = head.trim_start()
  trimmed.has_prefix("BEGMF") || trimmed.has_prefix("begmf")
}

///|
/// One token of a clear-text metafile: a command name, a number, a
/// delimiter or a string.
priv enum CgmToken {
  Word(String)
  Number(Double)
  Delim(Char)
  Quoted(String)
} derive(Eq, Debug)

///|
/// Split a clear-text metafile into tokens. Strings are single-quoted with
/// `''` for a literal quote, as in the CGM clear-text encoding.
fn cgm_text_tokens(text : String) -> Array[CgmToken] {
  let tokens : Array[CgmToken] = []
  let chars = text.to_array()
  let mut index = 0
  let length = chars.length()
  while index < length {
    let c = chars[index]
    if c == ' ' || c == '\n' || c == '\r' || c == '\t' {
      index += 1
      continue
    }
    if c == '\'' {
      index += 1
      let builder = StringBuilder()
      while index < length {
        let d = chars[index]
        if d == '\'' {
          if index + 1 < length && chars[index + 1] == '\'' {
            builder.write_char('\'')
            index += 2
            continue
          }
          index += 1
          break
        }
        builder.write_char(d)
        index += 1
      }
      tokens.push(Quoted(builder.to_string()))
      continue
    }
    if c == '(' || c == ')' || c == ',' || c == ';' {
      tokens.push(Delim(c))
      index += 1
      continue
    }
    let start = index
    while index < length {
      let d = chars[index]
      if d == ' ' || d == '\n' || d == '\r' || d == '\t' || d == '\'' ||
        d == '(' || d == ')' || d == ',' || d == ';' {
        break
      }
      index += 1
    }
    let word = String::from_iter(chars[start:index].iter())
    let number : Double? = try Some(@string.parse_double(word)) catch {
      _ => None
    }
    match number {
      Some(value) => tokens.push(Number(value))
      None => tokens.push(Word(word))
    }
  }
  tokens
}

///|
/// A growable big-endian byte buffer for the binary element bodies.
priv struct CgmBytes {
  data : Array[Byte]
}

///|
fn CgmBytes::new() -> CgmBytes {
  { data: [] }
}

///|
fn CgmBytes::push_u8(self : CgmBytes, value : Int) -> Unit {
  self.data.push((value & 0xff).to_byte())
}

///|
fn CgmBytes::push_i32(self : CgmBytes, value : Int) -> Unit {
  self.push_u8(value >> 24)
  self.push_u8(value >> 16)
  self.push_u8(value >> 8)
  self.push_u8(value)
}

///|
fn CgmBytes::push_f32(self : CgmBytes, value : Double) -> Unit {
  self.push_i32(@canvas.f32(value).reinterpret_as_uint().reinterpret_as_int())
}

///|
/// Convert a clear-text metafile into the binary elements the interpreter
/// reads. Coordinates are written as 32-bit integers, real values as f32 and
/// strings as a length byte followed by their bytes.
fn read_clear_text_elements(data : Bytes) -> Array[CgmElement] {
  let text = @utf8.decode_lossy(data)
  let tokens = cgm_text_tokens(text)
  let output : Array[CgmElement] = []
  let mut index = 0
  while index < tokens.length() {
    let (class, id) = match tokens[index] {
      Word(name) => match cgm_text_command(name.to_upper()) {
        Some(command) => command
        None => {
          index += 1
          continue
        }
      }
      _ => {
        index += 1
        continue
      }
    }
    index += 1
    let body = CgmBytes::new()
    if class == 1 && id == 13 {
      // FONTLIST: a count, then the names.
      let names : Array[String] = []
      while index < tokens.length() {
        match tokens[index] {
          Quoted(name) => {
            names.push(name)
            index += 1
          }
          _ => break
        }
      }
      body.push_u8(names.length())
      for name in names {
        body.push_u8(name.length())
        for byte in @utf8.encode(name) {
          body.push_u8(byte.to_int())
        }
      }
    } else {
      while index < tokens.length() {
        match tokens[index] {
          Delim(';') => {
            index += 1
            break
          }
          Delim(_) => index += 1
          Number(value) => {
            if cgm_text_is_real(class, id) {
              body.push_f32(value)
            } else {
              body.push_i32(value.to_int())
            }
            index += 1
          }
          Quoted(value) => {
            body.push_u8(value.length())
            for byte in @utf8.encode(value) {
              body.push_u8(byte.to_int())
            }
            index += 1
          }
          Word(_) => {
            // A bare word (an enumeration such as STD94) has no binary form.
            index += 1
          }
        }
      }
    }
    output.push({ class, id, data: Bytes::from_array(body.data) })
    if class == 0 && id == 2 {
      break
    }
  }
  output
}

///|
/// The elements whose numeric arguments are real (f32) rather than integer.
fn cgm_text_is_real(class : Int, id : Int) -> Bool {
  match (class, id) {
    (2, 1) | (5, 3) | (5, 7) | (5, 12) | (5, 13) | (5, 15) | (5, 16) => true
    _ => false
  }
}

///|
/// Map a clear-text command name to its (class, id).
fn cgm_text_command(name : String) -> (Int, Int)? {
  match name {
    "BEGMF" => Some((0, 1))
    "ENDMF" => Some((0, 2))
    "BEGPIC" => Some((0, 3))
    "BEGPICBODY" => Some((0, 4))
    "ENDPIC" => Some((0, 5))
    "BEGSEG" => Some((0, 6))
    "ENDSEG" => Some((0, 7))
    "BEGFIGURE" => Some((0, 8))
    "ENDFIGURE" => Some((0, 9))
    "MFVERSION" => Some((1, 1))
    "MFDESC" => Some((1, 2))
    "VDCTYPE" => Some((1, 3))
    "INTEGERPREC" => Some((1, 4))
    "REALPREC" => Some((1, 5))
    "INDEXPREC" => Some((1, 7))
    "COLRPREC" => Some((1, 8))
    "COLRINDEXPREC" => Some((1, 9))
    "MAXCOLRINDEX" => Some((1, 10))
    "COLRVALUEEXT" => Some((1, 11))
    "FONTLIST" => Some((1, 13))
    "CHARSETLIST" => Some((1, 14))
    "CHARCODING" => Some((1, 15))
    "SCALEMODE" => Some((2, 1))
    "COLRMODE" => Some((2, 3))
    "COLRPRECISION" => Some((2, 4))
    "COLRINDEXPRECISION" => Some((2, 5))
    "VDCEXT" => Some((2, 6))
    "BACKCOLR" => Some((2, 7))
    "LINEINDEXPREC" => Some((3, 1))
    "LINETYPEPREC" => Some((3, 5))
    "LINEWIDTHPREC" => Some((3, 10))
    "POLYLINE" => Some((4, 1))
    "DISJTLINE" => Some((4, 2))
    "POLYMARKER" => Some((4, 3))
    "TEXT" => Some((4, 4))
    "RESTRTEXT" => Some((4, 5))
    "APNDTEXT" => Some((4, 6))
    "POLYGON" => Some((4, 7))
    "POLYGONSET" => Some((4, 8))
    "CELLARRAY" => Some((4, 9))
    "RECT" => Some((4, 11))
    "CIRCLE" => Some((4, 12))
    "ARC3PT" => Some((4, 13))
    "ARC3PTCLOSE" => Some((4, 14))
    "ARCCTR" => Some((4, 15))
    "ARCCTRCLOSE" => Some((4, 16))
    "ELLIPSE" => Some((4, 17))
    "ELLIPARC" => Some((4, 18))
    "ELLIPARCCLOSE" => Some((4, 19))
    "LINETYPE" => Some((5, 2))
    "LINEWIDTH" => Some((5, 3))
    "LINECOLR" => Some((5, 4))
    "MARKERSIZE" => Some((5, 7))
    "MARKERTYPE" => Some((5, 8))
    "TEXTFONTINDEX" => Some((5, 10))
    "CHAREXPANSION" => Some((5, 12))
    "CHARSPACING" => Some((5, 13))
    "TEXTCOLR" => Some((5, 14))
    "CHARHEIGHT" => Some((5, 16))
    "CHARPATH" => Some((5, 17))
    "TEXTALIGN" => Some((5, 18))
    "CHARORI" => Some((5, 20))
    "FILLREFPT" => Some((5, 22))
    "FILLCOLR" => Some((5, 23))
    "HATCHINDEX" => Some((5, 24))
    "PATINDEX" => Some((5, 25))
    "EDGEWIDTH" => Some((5, 28))
    "EDGEVIS" => Some((5, 29))
    "FILLVIS" => Some((5, 30))
    "EDGETYPE" => Some((5, 31))
    "EDGECOLR" => Some((5, 32))
    "EDGEWIDTHMODE" => Some((5, 37))
    "COLRTABLE" => Some((5, 34))
    _ => None
  }
}
