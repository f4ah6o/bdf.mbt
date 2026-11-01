///|
/// A Photoshop conversion failure.
pub suberror PsdError {
  PsdInvalid(String)
}

///|
const PSD_MODE_BITMAP : Int32 = 0

///|
const PSD_MODE_GRAYSCALE : Int32 = 1

///|
const PSD_MODE_INDEXED : Int32 = 2

///|
const PSD_MODE_RGB : Int32 = 3

///|
const PSD_MODE_CMYK : Int32 = 4

///|
const PSD_MODE_MULTICHANNEL : Int32 = 7

///|
const PSD_MODE_DUOTONE : Int32 = 8

///|
const PSD_MODE_LAB : Int32 = 9

///|
const PSD_RESOLUTION : Int32 = 1005

///|
const PSD_TRANSPARENCY : Int32 = 1047

///|
const PSD_VERSION : Int32 = 1057

///|
const PSD_XMP : Int32 = 1060

///|
const PSD_MAX_PIXELS : Int64 = 1073741824L

///|
const PSD_MAX_CANVAS : Int32 = 30000

///|
const PSD_MAX_LAYERS : Int32 = 65536

///|
priv struct PsdCursor {
  data : Bytes
  mut off : Int32
  end : Int32
  mut failed : Bool
}

///|
fn psd_cursor(data : Bytes) -> PsdCursor {
  { data, off: 0, end: data.length(), failed: false, }
}

///|
fn PsdCursor::left(self : PsdCursor) -> Int32 {
  let left = self.end - self.off
  if left < 0 {
    0
  } else {
    left
  }
}

///|
fn PsdCursor::ensure(self : PsdCursor, count : Int32) -> Bool {
  if self.failed || count < 0 || count > self.left() {
    self.failed = true
    false
  } else {
    true
  }
}

///|
fn PsdCursor::skip(self : PsdCursor, count : Int32) -> Unit {
  if self.ensure(count) {
    self.off += count
  }
}

///|
fn PsdCursor::bytes(self : PsdCursor, count : Int32) -> Bytes {
  if !self.ensure(count) {
    return b""
  }
  let result = self.data[self.off:self.off + count].to_owned()
  self.off += count
  result
}

///|
fn PsdCursor::sub(self : PsdCursor, count : Int32) -> PsdCursor {
  if !self.ensure(count) {
    return { data: self.data, off: self.off, end: self.off, failed: true, }
  }
  let result = {
    data: self.data,
    off: self.off,
    end: self.off + count,
    failed: self.failed,
  }
  self.off += count
  result
}

///|
fn PsdCursor::u8(self : PsdCursor) -> Int32 {
  if !self.ensure(1) {
    return 0
  }
  let value = self.data[self.off].to_int()
  self.off += 1
  value
}

///|
fn PsdCursor::u16(self : PsdCursor) -> Int32 {
  if !self.ensure(2) {
    return 0
  }
  let value = (self.data[self.off].to_int() << 8) |
    self.data[self.off + 1].to_int()
  self.off += 2
  value
}

///|
fn PsdCursor::u32(self : PsdCursor) -> Int64 {
  if !self.ensure(4) {
    return 0L
  }
  let value = (self.data[self.off].to_int64() << 24) |
    (self.data[self.off + 1].to_int64() << 16) |
    (self.data[self.off + 2].to_int64() << 8) |
    self.data[self.off + 3].to_int64()
  self.off += 4
  value
}

///|
fn PsdCursor::i32(self : PsdCursor) -> Int32 {
  self.u32().to_int()
}

///|
fn PsdCursor::u64(self : PsdCursor) -> Int64 {
  let high = self.u32()
  let low = self.u32()
  (high << 32) | low
}

///|
fn PsdCursor::f64(self : PsdCursor) -> Double {
  self.u64().reinterpret_as_double()
}

///|
fn PsdCursor::length(self : PsdCursor, wide : Bool) -> Int32 {
  if wide {
    let value = self.u64()
    if value < 0L || value > 2147483647L {
      self.failed = true
      0
    } else {
      value.to_int()
    }
  } else {
    let value = self.u32()
    if value < 0L || value > 2147483647L {
      self.failed = true
      0
    } else {
      value.to_int()
    }
  }
}

///|
fn PsdCursor::pascal(self : PsdCursor, pad : Int32) -> String {
  let count = self.u8()
  let value = @utf8.decode_lossy(self.bytes(count))
  let total = 1 + count
  let remainder = total % pad
  if remainder != 0 {
    self.skip(pad - remainder)
  }
  value
}

///|
fn PsdCursor::unicode(self : PsdCursor) -> String {
  let count = self.u32()
  if count < 0L || count > self.left().to_int64() / 2L {
    self.failed = true
    return ""
  }
  let data = self.bytes((count * 2L).to_int())
  @utf16.decode(data, endianness=@utf16.Big) catch {
    _ => @utf16.decode_lossy(data, endianness=@utf16.Big)
  }
}

///|
priv struct PsdHeader {
  psb : Bool
  channels : Int32
  width : Int32
  height : Int32
  depth : Int32
  mode : Int32
}

///|
fn psd_base_channels(header : PsdHeader) -> Int32 {
  match header.mode {
    PSD_MODE_RGB | PSD_MODE_LAB => 3
    PSD_MODE_CMYK => 4
    PSD_MODE_MULTICHANNEL => header.channels
    _ => 1
  }
}

///|
priv struct PsdLayer {
  top : Int32
  left : Int32
  bottom : Int32
  right : Int32
  hidden : Bool
  section : Int32
  artboard : (Int32, Int32, Int32, Int32)?
  channel_bytes : Int64
}

///|
priv struct PsdFile {
  data : Bytes
  header : PsdHeader
  palette : Bytes
  resources : Map[Int32, Bytes]
  layers : Array[PsdLayer]
  image_data : Int32
  global_alpha : Bool
  layer_error : String?
}

///|
fn psd_detect(data : Bytes) -> Bool {
  data.length() >= 6 &&
  data[:4] == b"8BPS"[:] &&
  data[4] == 0 &&
  (data[5] == 1 || data[5] == 2)
}

///|
fn psd_mode_known(mode : Int32) -> Bool {
  match mode {
    PSD_MODE_BITMAP
    | PSD_MODE_GRAYSCALE
    | PSD_MODE_INDEXED
    | PSD_MODE_RGB
    | PSD_MODE_CMYK
    | PSD_MODE_MULTICHANNEL
    | PSD_MODE_DUOTONE
    | PSD_MODE_LAB => true
    _ => false
  }
}

///|
fn psd_read_file(data : Bytes) -> PsdFile raise PsdError {
  let cursor = psd_cursor(data)
  if !psd_detect(data) {
    raise PsdInvalid("psd: not a Photoshop document")
  }
  ignore(cursor.bytes(4))
  let version = cursor.u16()
  let psb = version == 2
  if version != 1 && version != 2 {
    raise PsdInvalid("psd: unknown version")
  }
  cursor.skip(6)
  let channels = cursor.u16()
  let height = cursor.u32().to_int()
  let width = cursor.u32().to_int()
  let depth = cursor.u16()
  let mode = cursor.u16()
  let limit = if psb { 300000 } else { PSD_MAX_CANVAS }
  if cursor.failed ||
    width < 1 ||
    height < 1 ||
    width > limit ||
    height > limit ||
    channels < 1 ||
    channels > 56 {
    raise PsdInvalid("psd: bad image size or channel count")
  }
  match depth {
    1 | 8 | 16 | 32 => ()
    _ => raise PsdInvalid("psd: unsupported bit depth \{depth}")
  }
  if !psd_mode_known(mode) {
    raise PsdInvalid("psd: unsupported colour mode \{mode}")
  }
  let header : PsdHeader = { psb, channels, width, height, depth, mode, }
  if channels < psd_base_channels(header) {
    raise PsdInvalid("psd: too few channels for the colour mode")
  }
  let mut palette : Bytes = b""
  let color_length = cursor.u32()
  let color = cursor.sub(color_length.to_int())
  if mode == PSD_MODE_INDEXED {
    palette = color.bytes(768)
    if color.failed {
      raise PsdInvalid("psd: the colour table is truncated")
    }
  }
  let resources : Map[Int32, Bytes] = Map([])
  let resource_length = cursor.u32()
  let resource_cursor = cursor.sub(resource_length.to_int())
  while resource_cursor.left() >= 12 && !resource_cursor.failed {
    let signature = resource_cursor.bytes(4)
    if signature != b"8BIM" &&
      signature != b"MeSa" &&
      signature != b"AgHg" &&
      signature != b"PHUT" &&
      signature != b"DCSR" {
      break
    }
    let id = resource_cursor.u16()
    ignore(resource_cursor.pascal(2))
    let length = resource_cursor.u32()
    if length < 0L || length > resource_cursor.left().to_int64() {
      break
    }
    let value = resource_cursor.bytes(length.to_int())
    if length % 2L != 0L {
      resource_cursor.skip(1)
    }
    if !resources.contains(id) && signature == b"8BIM" {
      resources[id] = value
    }
  }
  let layer_length = cursor.length(psb)
  let layer_cursor = cursor.sub(layer_length)
  if cursor.failed {
    raise PsdInvalid("psd: the layer and mask section is truncated")
  }
  let image_data = cursor.off
  let mut layers : Array[PsdLayer] = []
  let mut global_alpha = false
  let mut layer_error : String? = None
  if layer_cursor.left() > 0 {
    let result = psd_read_layers(layer_cursor, psb, header)
    layers = result.layers
    global_alpha = result.global_alpha
    layer_error = result.error
  }
  {
    data,
    header,
    palette,
    resources,
    layers,
    image_data,
    global_alpha,
    layer_error,
  }
}

///|
priv struct PsdLayersResult {
  layers : Array[PsdLayer]
  global_alpha : Bool
  error : String?
}

///|
fn psd_read_layers(
  layer_cursor : PsdCursor,
  psb : Bool,
  header : PsdHeader,
) -> PsdLayersResult {
  let mut global_alpha = false
  let info_length = layer_cursor.length(psb)
  let info = layer_cursor.sub(info_length)
  if info.left() <= 0 {
    return { layers: [], global_alpha: false, error: None, }
  }
  let count = info.u16()
  let mut number = count
  if number >= 32768 {
    number = 65536 - number
    global_alpha = true
  }
  if info.failed || number > PSD_MAX_LAYERS {
    return {
      layers: [],
      global_alpha: false,
      error: Some("the layer count is invalid"),
    }
  }
  let layers : Array[PsdLayer] = []
  for i in 0..<number {
    let top = info.i32()
    let left = info.i32()
    let bottom = info.i32()
    let right = info.i32()
    let channel_count = info.u16()
    if channel_count > 56 {
      return {
        layers: [],
        global_alpha: false,
        error: Some("layer \{i + 1} has \{channel_count} channels"),
      }
    }
    let mut channel_bytes = 0L
    for _ in 0..<channel_count {
      ignore(info.u16())
      channel_bytes += info.length(psb).to_int64()
    }
    if info.bytes(4) != b"8BIM" {
      return {
        layers: [],
        global_alpha: false,
        error: Some("layer \{i + 1} has a bad blend mode signature"),
      }
    }
    ignore(info.bytes(4)) // blend mode
    ignore(info.u8()) // opacity
    ignore(info.u8()) // clipping
    let flags = info.u8()
    ignore(info.u8())
    let extra_length = info.u32()
    let extra = info.sub(extra_length.to_int())
    let mask_length = extra.u32()
    ignore(extra.sub(mask_length.to_int()))
    ignore(extra.u32()) // blending ranges
    ignore(extra.pascal(4)) // layer name
    let mut section = 0
    let mut artboard : (Int32, Int32, Int32, Int32)? = None
    let tagged = extra
    while !tagged.failed {
      while tagged.left() > 0 &&
            tagged.ensure(1) &&
            tagged.data[tagged.off] == 0 {
        tagged.skip(1)
      }
      if tagged.left() < 12 {
        break
      }
      let signature = tagged.bytes(4)
      if signature != b"8BIM" && signature != b"8B64" {
        break
      }
      let key = @utf8.decode_lossy(tagged.bytes(4))
      let wide = psb &&
        (
          signature == b"8B64" ||
          [
            "LMsk", "Lr16", "Lr32", "Layr", "Mt16", "Mt32", "Mtrn", "Alph", "FMsk",
            "lnk2", "FEid", "FXid", "PxSD",
          ].contains(key)
        )
      let length = tagged.length(wide)
      if tagged.failed {
        break
      }
      let value = tagged.sub(length)
      match key {
        "lsct" | "lsdk" => section = value.u32().to_int()
        "artb" | "artd" | "abdd" =>
          match artboard {
            None => artboard = psd_read_artboard(value)
            Some(_) => ()
          }
        _ => ()
      }
      if length % 2 != 0 && tagged.left() > 0 {
        tagged.skip(1)
      }
    }
    layers.push({
      top,
      left,
      bottom,
      right,
      hidden: (flags & 2) != 0,
      section,
      artboard,
      channel_bytes,
    })
    if info.failed {
      return {
        layers: [],
        global_alpha: false,
        error: Some("the layer records are truncated"),
      }
    }
  }
  for layer in layers {
    info.skip(layer.channel_bytes.to_int())
  }
  if info.failed {
    return {
      layers: [],
      global_alpha: false,
      error: Some("the layer channel data is truncated"),
    }
  }
  { layers, global_alpha, error: None, }
}

///|
priv enum PsdValue {
  PsdFloat(Double)
  PsdInt(Int64)
  PsdBool(Bool)
  PsdText(String)
  PsdObject(PsdDescriptor)
  PsdList(Array[PsdValue])
  PsdNone
}

///|
priv struct PsdDescriptor {
  items : Map[String, PsdValue]
}

///|
fn PsdDescriptor::float(self : PsdDescriptor, key : String) -> Double? {
  match self.items.get(key) {
    Some(PsdFloat(value)) => Some(value)
    Some(PsdInt(value)) => Some(value.to_double())
    _ => None
  }
}

///|
fn psd_descriptor_id(cursor : PsdCursor) -> String {
  let length = cursor.u32()
  if length == 0L {
    return @utf8.decode_lossy(cursor.bytes(4))
  }
  if length < 0L || length > cursor.left().to_int64() || length > 1024L {
    cursor.failed = true
    return ""
  }
  @utf8.decode_lossy(cursor.bytes(length.to_int()))
}

///|
fn psd_read_descriptor(cursor : PsdCursor) -> PsdDescriptor? {
  let descriptor = psd_read_descriptor_depth(cursor, 0)
  descriptor
}

///|
fn psd_read_descriptor_depth(
  cursor : PsdCursor,
  depth : Int32,
) -> PsdDescriptor? {
  if depth > 16 || cursor.failed {
    return None
  }
  ignore(cursor.unicode()) // name
  ignore(psd_descriptor_id(cursor))
  let count = cursor.u32()
  if count < 0L || count > cursor.left().to_int64() {
    cursor.failed = true
    return None
  }
  let items : Map[String, PsdValue] = Map([])
  for _ in 0..<count.to_int() {
    let key = psd_descriptor_id(cursor)
    let value = psd_read_value(cursor, depth)
    match value {
      Some(value) => items[key] = value
      None => return None
    }
  }
  Some({ items, })
}

///|
fn psd_read_value(cursor : PsdCursor, depth : Int32) -> PsdValue? {
  if depth > 16 || cursor.failed {
    return None
  }
  let kind = @utf8.decode_lossy(cursor.bytes(4))
  match kind {
    "Objc" | "GlbO" => {
      let descriptor = psd_read_descriptor_depth(cursor, depth + 1)
      match descriptor {
        Some(value) => Some(PsdObject(value))
        None => None
      }
    }
    "VlLs" => {
      let count = cursor.u32()
      if count < 0L || count > cursor.left().to_int64() {
        cursor.failed = true
        return None
      }
      let values : Array[PsdValue] = []
      for _ in 0..<count.to_int() {
        match psd_read_value(cursor, depth + 1) {
          Some(value) => values.push(value)
          None => return None
        }
      }
      Some(PsdList(values))
    }
    "doub" => Some(PsdFloat(cursor.f64()))
    "UntF" => {
      ignore(cursor.bytes(4))
      Some(PsdFloat(cursor.f64()))
    }
    "long" => Some(PsdInt(cursor.i32().to_int64()))
    "comp" => Some(PsdInt(cursor.u64()))
    "bool" => Some(PsdBool(cursor.u8() != 0))
    "TEXT" => Some(PsdText(cursor.unicode()))
    "enum" => {
      ignore(psd_descriptor_id(cursor))
      Some(PsdText(psd_descriptor_id(cursor)))
    }
    "type" | "GlbC" => {
      ignore(cursor.unicode())
      Some(PsdText(psd_descriptor_id(cursor)))
    }
    "alis" | "tdta" => {
      let length = cursor.u32()
      cursor.skip(length.to_int())
      Some(PsdNone)
    }
    "UnFl" => {
      ignore(cursor.bytes(4))
      let count = cursor.u32()
      if count < 0L || count * 8L > cursor.left().to_int64() {
        cursor.failed = true
        return None
      }
      cursor.skip((count * 8L).to_int())
      Some(PsdNone)
    }
    _ => None
  }
}

///|
fn psd_read_artboard(cursor : PsdCursor) -> (Int32, Int32, Int32, Int32)? {
  ignore(cursor.bytes(4))
  let descriptor = psd_read_descriptor(cursor)
  let descriptor = match descriptor {
    Some(value) => value
    None => return None
  }
  let rect = match descriptor.items.get("artboardRect") {
    Some(PsdObject(value)) => value
    _ => return None
  }
  let top = rect.float("Top ")
  let left = rect.float("Left")
  let bottom = rect.float("Btom")
  let right = rect.float("Rght")
  match (top, left, bottom, right) {
    (Some(top), Some(left), Some(bottom), Some(right)) =>
      Some(
        (
          top.round().to_int(),
          left.round().to_int(),
          bottom.round().to_int(),
          right.round().to_int(),
        ),
      )
    _ => None
  }
}

///|
fn psd_resolution(file : PsdFile) -> (Double, Double) {
  let mut x = 72.0
  let mut y = 72.0
  match file.resources.get(PSD_RESOLUTION) {
    Some(data) =>
      if data.length() >= 16 {
        let value_x = psd_be32(data, 0).to_double() / 65536.0
        if value_x >= 1.0 && value_x < 1000000.0 {
          x = value_x
        }
        let value_y = psd_be32(data, 8).to_double() / 65536.0
        if value_y >= 1.0 && value_y < 1000000.0 {
          y = value_y
        }
      }
    None => ()
  }
  (x, y)
}

///|
fn psd_be32(data : Bytes, offset : Int32) -> Int64 {
  if offset < 0 || offset + 4 > data.length() {
    return 0L
  }
  (data[offset].to_int64() << 24) |
  (data[offset + 1].to_int64() << 16) |
  (data[offset + 2].to_int64() << 8) |
  data[offset + 3].to_int64()
}

///|
fn psd_has_composite(file : PsdFile) -> Bool {
  match file.resources.get(PSD_VERSION) {
    Some(data) => data.length() < 5 || data[4] != 0
    None => true
  }
}
