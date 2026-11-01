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
