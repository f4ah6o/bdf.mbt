///|
/// Builds a BDF object and its local resources.
pub struct ObjectBuilder {
  strings : Array[String]
  string_index : Map[String, Int32]
  paths : Array[PathEntry]
  paints : Array[Paint]
  fonts : Array[Font]
  images : Array[String]
  children : Array[String]
  child_boxes : Array[(Float, Float, Float, Float)]
  ops : @buffer.Buffer
  mut bbox : (Float, Float, Float, Float)
  mut auto_bbox : Bool
  mut has_bbox : Bool
}

///|
pub fn ObjectBuilder::new() -> ObjectBuilder {
  {
    strings: [],
    string_index: Map([]),
    paths: [],
    paints: [],
    fonts: [],
    images: [],
    children: [],
    child_boxes: [],
    ops: @buffer.Buffer(),
    bbox: (0.0F, 0.0F, 0.0F, 0.0F),
    auto_bbox: true,
    has_bbox: false,
  }
}

///|
/// Fix the object bounding box, disabling automatic bounds.
pub fn ObjectBuilder::set_bbox(
  self : ObjectBuilder,
  x : Float,
  y : Float,
  width : Float,
  height : Float,
) -> Unit {
  self.bbox = (x, y, width, height)
  self.auto_bbox = false
  self.has_bbox = true
}

///|
pub fn ObjectBuilder::bbox(
  self : ObjectBuilder,
) -> (Float, Float, Float, Float) {
  self.bbox
}

///|
fn ObjectBuilder::grow(
  self : ObjectBuilder,
  x0 : Float,
  y0 : Float,
  width : Float,
  height : Float,
) -> Unit {
  if !self.auto_bbox {
    return
  }
  let x = if width < 0.0F { x0 + width } else { x0 }
  let y = if height < 0.0F { y0 + height } else { y0 }
  let w = if width < 0.0F { -width } else { width }
  let h = if height < 0.0F { -height } else { height }
  if !self.has_bbox {
    self.bbox = (x, y, w, h)
    self.has_bbox = true
    return
  }
  let (bx, by, bw, bh) = self.bbox
  let left = if x < bx { x } else { bx }
  let top = if y < by { y } else { by }
  let right = if x + w > bx + bw { x + w } else { bx + bw }
  let bottom = if y + h > by + bh { y + h } else { by + bh }
  self.bbox = (left, top, right - left, bottom - top)
}

///|
fn object_trim_bom(value : String) -> String {
  let bytes = @utf8.encode(value)
  let mut start = 0
  while start + 3 <= bytes.length() &&
        bytes[start] == 0xef &&
        bytes[start + 1] == 0xbb &&
        bytes[start + 2] == 0xbf {
    start += 3
  }
  if start == 0 {
    value
  } else {
    @utf8.decode_lossy(bytes[start:])
  }
}

///|
fn ObjectBuilder::string_ref(self : ObjectBuilder, value : String) -> Int32 {
  let value = object_trim_bom(value)
  match self.string_index.get(value) {
    Some(index) => index
    None => {
      let index = self.strings.length()
      self.strings.push(value)
      self.string_index[value] = index
      index
    }
  }
}

///|
pub fn ObjectBuilder::add_path(self : ObjectBuilder, path : PathEntry) -> Int32 {
  let index = self.paths.length()
  self.paths.push(path)
  index
}

///|
pub fn ObjectBuilder::add_paint(self : ObjectBuilder, paint : Paint) -> Int32 {
  let index = self.paints.length()
  self.paints.push(paint)
  index
}

///|
pub fn ObjectBuilder::add_font(self : ObjectBuilder, font : Font) -> Int32 {
  let index = self.fonts.length()
  self.fonts.push(font)
  index
}

///|
pub fn ObjectBuilder::update_font(
  self : ObjectBuilder,
  index : Int32,
  font : Font,
) -> Unit raise {
  if index < 0 || index >= self.fonts.length() {
    raise BadFormat("invalid font reference")
  }
  self.fonts[index] = font
}

///|
pub fn ObjectBuilder::add_image(self : ObjectBuilder, hash : String) -> Int32 {
  let index = self.images.length()
  self.images.push(hash)
  index
}

///|
/// Add a child object and the bounds used for automatic bounding boxes.
pub fn ObjectBuilder::add_object(
  self : ObjectBuilder,
  hash : String,
  bbox : (Float, Float, Float, Float),
) -> Int32 {
  let index = self.children.length()
  self.children.push(hash)
  self.child_boxes.push(bbox)
  index
}

///|
pub fn ObjectBuilder::update_object(
  self : ObjectBuilder,
  index : Int32,
  hash : String,
) -> Unit raise {
  if index < 0 || index >= self.children.length() {
    raise BadFormat("invalid object reference")
  }
  self.children[index] = hash
}

///|
/// Return the encoded object, including resource tables and instructions.
pub fn ObjectBuilder::encode(self : ObjectBuilder) -> Bytes raise {
  let (x, y, w, h) = self.bbox
  encode_object_resources({
    object: {
      bbox: (x.to_double(), y.to_double(), w.to_double(), h.to_double()),
      strings: self.strings,
      images: self.images,
      objects: self.children,
      ops: self.ops.to_bytes(),
    },
    paths: self.paths,
    paints: self.paints,
    fonts: self.fonts,
  })
}
