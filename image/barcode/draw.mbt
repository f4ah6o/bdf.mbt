///|
/// Dark runs as `(x, y, width, height)` in module coordinates.
pub fn Symbol::rects(self : Symbol) -> Array[(Int32, Int32, Int32, Int32)] {
  let out : Array[(Int32, Int32, Int32, Int32)] = []
  let mut x = 0
  while x < self.width() {
    if !self.at(x, 0) {
      x += 1
      continue
    }
    let start = x
    while x < self.width() && self.at(x, 0) {
      x += 1
    }
    out.push((start, 0, x - start, 1))
  }
  out
}

///|
/// Convert dark modules to a BDF path within the requested finite box.
pub fn Symbol::path(
  self : Symbol,
  x : Float,
  y : Float,
  width : Float,
  height : Float,
) -> @core.Path raise BarcodeError {
  if !x.is_finite() ||
    !y.is_finite() ||
    !width.is_finite() ||
    !height.is_finite() ||
    !(x + width).is_finite() ||
    !(y + height).is_finite() ||
    width < 0.0F ||
    height < 0.0F {
    raise BarcodeError("barcode: invalid drawing box")
  }
  let verbs : Array[Byte] = []
  let coords : Array[Double] = []
  let unit = width / Float::from_double(self.width().to_double())
  if width > 0.0F && unit == 0.0F {
    raise BarcodeError("barcode: module width underflows")
  }
  for rect in self.rects() {
    verbs.push(5)
    let (left, _, span, _) = rect
    let px = x + Float::from_double(left.to_double()) * unit
    let w = Float::from_double(span.to_double()) * unit
    coords.push(px.to_double())
    coords.push(y.to_double())
    coords.push(w.to_double())
    coords.push(height.to_double())
  }
  { verbs: Bytes::from_array(verbs), coordinates: coords, }
}

///|
/// Build a black-on-transparent BDF object. The bounding box includes the
/// quiet zones. The bars encode the payload and can be decoded; no readable
/// text or font is added by this Code 39 drawing.
pub fn Symbol::object(
  self : Symbol,
  width : Float,
  height : Float,
) -> @core.ObjectBuilder raise {
  let path = self.path(0.0F, 0.0F, width, height)
  let object = @core.ObjectBuilder::new()
  object.fill_color(0x000000ffU)
  let index = object.add_path(@core.Inline(path))
  object.fill_path(index, 0)
  object.set_bbox(0.0F, 0.0F, width, height)
  object
}
