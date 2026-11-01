///|
/// TIFF tags used by the converter.
const TIFF_TAG_NEW_SUBFILE_TYPE : Int32 = 254

///|
const TIFF_TAG_IMAGE_WIDTH : Int32 = 256

///|
const TIFF_TAG_IMAGE_LENGTH : Int32 = 257

///|
const TIFF_TAG_BITS_PER_SAMPLE : Int32 = 258

///|
const TIFF_TAG_COMPRESSION : Int32 = 259

///|
const TIFF_TAG_PHOTOMETRIC : Int32 = 262

///|
const TIFF_TAG_FILL_ORDER : Int32 = 266

///|
const TIFF_TAG_DOCUMENT_NAME : Int32 = 269

///|
const TIFF_TAG_IMAGE_DESCRIPTION : Int32 = 270

///|
const TIFF_TAG_STRIP_OFFSETS : Int32 = 273

///|
const TIFF_TAG_ORIENTATION : Int32 = 274

///|
const TIFF_TAG_SAMPLES_PER_PIXEL : Int32 = 277

///|
const TIFF_TAG_ROWS_PER_STRIP : Int32 = 278

///|
const TIFF_TAG_STRIP_BYTE_COUNTS : Int32 = 279

///|
const TIFF_TAG_X_RESOLUTION : Int32 = 282

///|
const TIFF_TAG_Y_RESOLUTION : Int32 = 283

///|
const TIFF_TAG_PLANAR_CONFIG : Int32 = 284

///|
const TIFF_TAG_T4_OPTIONS : Int32 = 292

///|
const TIFF_TAG_RESOLUTION_UNIT : Int32 = 296

///|
const TIFF_TAG_SOFTWARE : Int32 = 305

///|
const TIFF_TAG_DATE_TIME : Int32 = 306

///|
const TIFF_TAG_ARTIST : Int32 = 315

///|
const TIFF_TAG_PREDICTOR : Int32 = 317

///|
const TIFF_TAG_COLOR_MAP : Int32 = 320

///|
const TIFF_TAG_TILE_WIDTH : Int32 = 322

///|
const TIFF_TAG_TILE_LENGTH : Int32 = 323

///|
const TIFF_TAG_TILE_OFFSETS : Int32 = 324

///|
const TIFF_TAG_TILE_BYTE_COUNTS : Int32 = 325

///|
const TIFF_TAG_INK_SET : Int32 = 332

///|
const TIFF_TAG_EXTRA_SAMPLES : Int32 = 338

///|
const TIFF_TAG_SAMPLE_FORMAT : Int32 = 339

///|
const TIFF_TAG_COPYRIGHT : Int32 = 33432

///|
/// The photometric interpretations.
const TIFF_WHITE_IS_ZERO : Int32 = 0

///|
const TIFF_BLACK_IS_ZERO : Int32 = 1

///|
const TIFF_RGB : Int32 = 2

///|
const TIFF_PALETTE : Int32 = 3

///|
const TIFF_SEPARATED : Int32 = 5

///|
const TIFF_YCBCR : Int32 = 6

///|
/// The compressions the converter reads.
const TIFF_COMPRESSION_NONE : Int32 = 1

///|
const TIFF_COMPRESSION_CCITT_RLE : Int32 = 2

///|
const TIFF_COMPRESSION_G3 : Int32 = 3

///|
const TIFF_COMPRESSION_G4 : Int32 = 4

///|
const TIFF_COMPRESSION_LZW : Int32 = 5

///|
const TIFF_COMPRESSION_JPEG : Int32 = 7

///|
const TIFF_COMPRESSION_DEFLATE : Int32 = 8

///|
const TIFF_COMPRESSION_PACKBITS : Int32 = 32773

///|
const TIFF_COMPRESSION_DEFLATE_OLD : Int32 = 32946

///|
/// The resolution units.
const TIFF_RESOLUTION_NONE : Int32 = 1

///|
const TIFF_RESOLUTION_INCH : Int32 = 2

///|
const TIFF_RESOLUTION_CENTIMETER : Int32 = 3

///|
/// The limits the converter puts on a file's demands.
const TIFF_MAX_IFDS : Int32 = 65536

///|
const TIFF_MAX_ENTRIES : Int32 = 65536

///|
const TIFF_MAX_PIXELS : Int64 = 100000000L

///|
const TIFF_MAX_DECODE_BYTES : Int64 = 536870912L

///|
const TIFF_MAX_RATIO : Int64 = 2048L

///|
const TIFF_DECODE_SLACK : Int64 = 65536L

///|
pub suberror TiffError {
  TiffInvalid(String)
}

///|
priv struct TiffField {
  typ : Int32
  count : Int32
  value : Bytes
}

///|
priv struct TiffIfd {
  offset : Int32
  big_endian : Bool
  fields : Map[Int32, TiffField]
}

///|
priv struct TiffFile {
  data : Bytes
  big_endian : Bool
  big_tiff : Bool
  ifds : Array[TiffIfd]
  chain_error : String?
}

///|
fn tiff_type_size(typ : Int32) -> Int32 {
  match typ {
    1 | 2 | 6 | 7 => 1
    3 | 8 => 2
    4 | 9 | 11 | 13 => 4
    5 | 10 | 12 | 16 | 17 | 18 => 8
    _ => 0
  }
}

///|
fn tiff_byte(data : Bytes, offset : Int32) -> Int32 {
  if offset < 0 || offset >= data.length() {
    return 0
  }
  data[offset].to_int()
}

///|
fn tiff_u16(data : Bytes, offset : Int32, big : Bool) -> Int32 {
  if offset < 0 || offset + 2 > data.length() {
    return 0
  }
  let a = data[offset].to_int()
  let b = data[offset + 1].to_int()
  if big {
    (a << 8) | b
  } else {
    a | (b << 8)
  }
}

///|
fn tiff_u32(data : Bytes, offset : Int32, big : Bool) -> Int64 {
  if offset < 0 || offset + 4 > data.length() {
    return 0L
  }
  let a = data[offset].to_int64()
  let b = data[offset + 1].to_int64()
  let c = data[offset + 2].to_int64()
  let d = data[offset + 3].to_int64()
  if big {
    (a << 24) | (b << 16) | (c << 8) | d
  } else {
    a | (b << 8) | (c << 16) | (d << 24)
  }
}

///|
fn tiff_u64(data : Bytes, offset : Int32, big : Bool) -> Int64 {
  let hi = tiff_u32(data, offset, big)
  let lo = tiff_u32(data, offset + 4, big)
  if big {
    (hi << 32) | lo
  } else {
    (lo << 32) | hi
  }
}

///|
fn tiff_sniff(data : Bytes) -> Bool {
  if data.length() < 4 {
    return false
  }
  (data[0] == b'I' && data[1] == b'I' && data[2] == 42 && data[3] == 0) ||
  (data[0] == b'M' && data[1] == b'M' && data[2] == 0 && data[3] == 42) ||
  (data[0] == b'I' && data[1] == b'I' && data[2] == 43 && data[3] == 0) ||
  (data[0] == b'M' && data[1] == b'M' && data[2] == 0 && data[3] == 43)
}

///|
/// Detect a classic or BigTIFF file. Canon CR2 raw files share the TIFF
/// signature and are not detected as TIFF.
pub fn detect(data : Bytes) -> Bool {
  if !tiff_sniff(data) {
    return false
  }
  if data.length() >= 10 && data[8] == b'C' && data[9] == b'R' {
    return false
  }
  true
}

///|
fn tiff_read_ifd(
  data : Bytes,
  offset : Int64,
  big_endian : Bool,
  big_tiff : Bool,
) -> (TiffIfd, Int64) raise TiffError {
  let count_width = if big_tiff { 8L } else { 2L }
  let entry_width = if big_tiff { 20L } else { 12L }
  let inline_width = if big_tiff { 8L } else { 4L }
  if offset < 0L || offset + count_width > data.length().to_int64() {
    raise TiffInvalid("TIFF: the IFD is outside the file")
  }
  let at = offset.to_int()
  let count = if big_tiff {
    tiff_u64(data, at, big_endian)
  } else {
    tiff_u16(data, at, big_endian).to_int64()
  }
  if count <= 0L || count > TIFF_MAX_ENTRIES.to_int64() {
    raise TiffInvalid("TIFF: the IFD has a bad entry count")
  }
  let entries_start = offset + count_width
  let entries_end = entries_start + count * entry_width + inline_width
  if entries_end > data.length().to_int64() {
    raise TiffInvalid("TIFF: the IFD is outside the file")
  }
  let fields : Map[Int32, TiffField] = Map([])
  for i in 0..<count.to_int() {
    let entry = (entries_start + i.to_int64() * entry_width).to_int()
    let tag = tiff_u16(data, entry, big_endian)
    let typ = tiff_u16(data, entry + 2, big_endian)
    let number = if big_tiff {
      tiff_u64(data, entry + 4, big_endian)
    } else {
      tiff_u32(data, entry + 4, big_endian)
    }
    let type_size = tiff_type_size(typ)
    if type_size == 0 || number <= 0L || number > data.length().to_int64() {
      continue
    }
    let total = type_size.to_int64() * number
    let value_offset = if big_tiff { entry + 12 } else { entry + 8 }
    let value = if total <= inline_width {
      data[value_offset:value_offset + total.to_int()].to_owned()
    } else {
      let value_at = if big_tiff {
        tiff_u64(data, value_offset, big_endian)
      } else {
        tiff_u32(data, value_offset, big_endian)
      }
      if value_at < 0L ||
        value_at + total > data.length().to_int64() ||
        total > 16777216L {
        continue
      }
      data[value_at.to_int():value_at.to_int() + total.to_int()].to_owned()
    }
    fields[tag] = { typ, count: number.to_int(), value, }
  }
  let next_at = (entries_start + count * entry_width).to_int()
  let next = if big_tiff {
    tiff_u64(data, next_at, big_endian)
  } else {
    tiff_u32(data, next_at, big_endian)
  }
  ({ offset: offset.to_int(), big_endian, fields, }, next)
}

///|
fn tiff_open(data : Bytes) -> TiffFile raise TiffError {
  if data.length() > 1073741824 {
    raise TiffInvalid("TIFF: the file is larger than 1073741824 bytes")
  }
  if !tiff_sniff(data) || data.length() < 8 {
    raise TiffInvalid("TIFF: not a TIFF file")
  }
  let big_endian = data[0] == b'M'
  let version = tiff_u16(data, 2, big_endian)
  let big_tiff = version == 43
  if big_tiff && (data.length() < 16 || tiff_u16(data, 4, big_endian) != 8) {
    raise TiffInvalid("TIFF: bad BigTIFF header")
  }
  let mut next = if big_tiff {
    tiff_u64(data, 8, big_endian)
  } else {
    tiff_u32(data, 4, big_endian)
  }
  let ifds : Array[TiffIfd] = []
  let seen : Map[Int64, Bool] = Map([])
  let mut chain_error : String? = None
  while next != 0L {
    if ifds.length().to_int64() >= TIFF_MAX_IFDS.to_int64() {
      chain_error = Some("TIFF: more than 65536 IFDs")
      break
    }
    if seen.contains(next) {
      chain_error = Some("TIFF: the IFD chain loops")
      break
    }
    seen[next] = true
    let (ifd, following) = tiff_read_ifd(data, next, big_endian, big_tiff) catch {
      TiffInvalid(message) => {
        if ifds.is_empty() {
          raise TiffInvalid(message)
        }
        chain_error = Some(message)
        break
      }
    }
    ifds.push(ifd)
    next = following
  }
  if ifds.is_empty() {
    raise TiffInvalid("TIFF: no IFD")
  }
  { data, big_endian, big_tiff, ifds, chain_error, }
}

///|
fn TiffIfd::has(self : TiffIfd, tag : Int32) -> Bool {
  self.fields.contains(tag)
}

///|
fn TiffIfd::raw(self : TiffIfd, tag : Int32) -> Bytes? {
  match self.fields.get(tag) {
    Some(field) => Some(field.value)
    None => None
  }
}

///|
fn TiffIfd::uints(self : TiffIfd, tag : Int32) -> Array[Int64] {
  match self.fields.get(tag) {
    None => []
    Some(field) => {
      let size = tiff_type_size(field.typ)
      if size == 0 {
        return []
      }
      let count = field.count
      let out : Array[Int64] = []
      let data = field.value
      for i in 0..<count {
        let offset = i * size
        if offset + size > data.length() {
          break
        }
        let value = match field.typ {
          1 | 7 => data[offset].to_int64()
          6 => data[offset].to_int().to_int64()
          3 => tiff_u16(data, offset, self.big_endian).to_int64()
          8 => tiff_u16(data, offset, self.big_endian).to_int64()
          4 | 13 => tiff_u32(data, offset, self.big_endian)
          9 => tiff_u32(data, offset, self.big_endian)
          16 | 17 | 18 => tiff_u64(data, offset, self.big_endian)
          _ => 0L
        }
        out.push(value)
      }
      out
    }
  }
}

///|
fn TiffIfd::uint(self : TiffIfd, tag : Int32, default : Int64) -> Int64 {
  let values = self.uints(tag)
  if values.is_empty() {
    default
  } else {
    values[0]
  }
}

///|
fn tiff_float_value(field : TiffField, offset : Int32, big : Bool) -> Double? {
  match field.typ {
    5 => {
      let numerator = tiff_u32(field.value, offset, big)
      let denominator = tiff_u32(field.value, offset + 4, big)
      if denominator == 0L {
        None
      } else {
        Some(numerator.to_double() / denominator.to_double())
      }
    }
    10 => {
      let numerator = tiff_u32(field.value, offset, big)
      let denominator = tiff_u32(field.value, offset + 4, big)
      if denominator == 0L {
        None
      } else {
        Some(numerator.to_double() / denominator.to_double())
      }
    }
    11 => Some(tiff_u32(field.value, offset, big).to_double())
    12 => Some(tiff_u64(field.value, offset, big).to_double())
    _ => {
      let values = field.value
      if offset < values.length() {
        Some(values[offset].to_int().to_double())
      } else {
        None
      }
    }
  }
}

///|
fn TiffIfd::resolution(self : TiffIfd) -> (Double, Double, Int32) {
  let big = self.big_endian
  let x = match self.fields.get(TIFF_TAG_X_RESOLUTION) {
    Some(field) => tiff_float_value(field, 0, big)
    None => None
  }
  let y = match self.fields.get(TIFF_TAG_Y_RESOLUTION) {
    Some(field) => tiff_float_value(field, 0, big)
    None => None
  }
  let unit = self
    .uint(TIFF_TAG_RESOLUTION_UNIT, TIFF_RESOLUTION_INCH.to_int64())
    .to_int()
  let xx = match x {
    Some(value) if value > 0.0 && value.is_inf() == false => value
    _ => 0.0
  }
  let yy = match y {
    Some(value) if value > 0.0 && value.is_inf() == false => value
    _ => 0.0
  }
  (xx, yy, unit)
}

///|
fn TiffIfd::orientation(self : TiffIfd) -> Int32 {
  let value = self.uint(TIFF_TAG_ORIENTATION, 1L).to_int()
  if value >= 1 && value <= 8 {
    value
  } else {
    1
  }
}

///|
fn TiffIfd::compression(self : TiffIfd) -> Int32 {
  self.uint(TIFF_TAG_COMPRESSION, TIFF_COMPRESSION_NONE.to_int64()).to_int()
}

///|
fn TiffIfd::photometric(self : TiffIfd) -> Int32 {
  let values = self.uints(TIFF_TAG_PHOTOMETRIC)
  if !values.is_empty() {
    return values[0].to_int()
  }
  match self.compression() {
    TIFF_COMPRESSION_CCITT_RLE | TIFF_COMPRESSION_G3 | TIFF_COMPRESSION_G4 =>
      TIFF_WHITE_IS_ZERO
    _ =>
      if self.uint(TIFF_TAG_SAMPLES_PER_PIXEL, 1L) >= 3L {
        TIFF_RGB
      } else {
        TIFF_BLACK_IS_ZERO
      }
  }
}

///|
fn TiffIfd::size(self : TiffIfd) -> (Int32, Int32) {
  let w = self.uint(TIFF_TAG_IMAGE_WIDTH, 0L)
  let h = self.uint(TIFF_TAG_IMAGE_LENGTH, 0L)
  (
    if w <= 0L {
      0
    } else if w > 2147483647L {
      2147483647
    } else {
      w.to_int()
    },
    if h <= 0L {
      0
    } else if h > 2147483647L {
      2147483647
    } else {
      h.to_int()
    },
  )
}

///|
fn TiffIfd::strings(self : TiffIfd, tag : Int32) -> Array[String] {
  match self.fields.get(tag) {
    Some(field) =>
      if field.typ != 2 && field.typ != 7 && field.typ != 1 {
        []
      } else {
        let text = @utf8.decode_lossy(field.value)
        let values : Array[String] = []
        for part in text.split("\u{0}") {
          let value = part.trim().to_owned()
          if value != "" {
            values.push(value)
          }
        }
        values
      }
    None => []
  }
}
