///|
struct Picture {
  format : String
  width : Int64
  height : Int64
  dc : Map[String, Array[String]]
}

///|
fn u16(data : Bytes, off : Int32) -> Int32 {
  data[off].to_int() | (data[off + 1].to_int() << 8)
}

///|
fn u32(data : Bytes, off : Int32) -> Int64 {
  u16(data, off).to_int64() | (u16(data, off + 2).to_int64() << 16)
}

///|
fn signed32(value : Int64) -> Int64 {
  if value >= 2147483648L {
    value - 4294967296L
  } else {
    value
  }
}

///|
fn bmp_header(data : Bytes) -> Bool {
  if data.length() < 18 || data[0] != b'B' || data[1] != b'M' {
    return false
  }
  match u32(data, 14) {
    12 | 16 | 40 | 52 | 56 | 64 | 108 | 124 => true
    _ => false
  }
}

///|
fn ico_header(data : Bytes) -> Bool {
  if data.length() < 22 ||
    u16(data, 0) != 0 ||
    u16(data, 2) != 1 ||
    data[9] != 0 {
    return false
  }
  let count = u16(data, 4).to_int64()
  let size = u32(data, 14)
  let offset = u32(data, 18)
  count > 0 &&
  size > 0 &&
  offset >= 6 + 16 * count &&
  offset + size <= data.length().to_int64()
}

///|
fn read_picture(data : Bytes) -> Picture raise {
  if data.length() >= 3 && data[:3] == b"\xff\xd8\xff"[:] {
    return read_jpeg(data)
  }
  if bmp_header(data) {
    if data.length() < 26 {
      raise ImageFailure("image: BMP: the image is truncated")
    }
    let (width, height) = if u32(data, 14) == 12 {
      (u16(data, 18).to_int64(), u16(data, 20).to_int64())
    } else {
      let w = signed32(u32(data, 18))
      let h = signed32(u32(data, 22))
      (w, if h < 0 { -h } else { h })
    }
    if width <= 0 || height <= 0 {
      raise ImageFailure("image: BMP: the BMP image has no size")
    }
    return { format: "bmp", width, height, dc: Map([]), }
  }
  if ico_header(data) {
    let count = u16(data, 4)
    let mut width = 0L
    let mut height = 0L
    let mut best_bits = 0
    for i in 0..<count {
      let e = 6 + 16 * i
      if e + 16 > data.length() {
        break
      }
      let w = if data[e] == 0 { 256L } else { data[e].to_int().to_int64() }
      let h = if data[e + 1] == 0 {
        256L
      } else {
        data[e + 1].to_int().to_int64()
      }
      let bits = u16(data, e + 6)
      if w * h > width * height || (w * h == width * height && bits > best_bits) {
        width = w
        height = h
        best_bits = bits
      }
    }
    return { format: "ico", width, height, dc: Map([]), }
  }
  raise ImageFailure("image: input is not a supported BMP, ICO or JPEG image")
}
