///|
priv struct PrefixReplay {
  source : @core.ObjectResources
  target : @core.ObjectBuilder
  child_boxes : Array[(Float, Float, Float, Float)]
  paths : Map[Int32, Int32]
  paints : Map[Int32, Int32]
  fonts : Map[Int32, Int32]
  images : Map[Int32, Int32]
  children : Map[Int32, Int32]
  font_refs : Array[Int32]
  child_refs : Array[Int32]
}

///|
fn PrefixReplay::new(
  source : @core.ObjectResources,
  child_boxes : Array[(Float, Float, Float, Float)],
) -> PrefixReplay {
  let target = @core.ObjectBuilder::new()
  let (x, y, w, h) = source.object.bbox
  target.set_bbox(
    Float::from_double(x),
    Float::from_double(y),
    Float::from_double(w),
    Float::from_double(h),
  )
  {
    source,
    target,
    child_boxes,
    paths: {},
    paints: {},
    fonts: {},
    images: {},
    children: {},
    font_refs: [],
    child_refs: [],
  }
}

///|
fn PrefixReplay::path(self : PrefixReplay, index : Int32) -> Int32 raise {
  if self.paths.get(index) is Some(value) {
    return value
  }
  if index < 0 || index >= self.source.paths.length() {
    raise InvalidReference("prefix path index out of range")
  }
  let value = self.target.add_path(self.source.paths[index])
  self.paths[index] = value
  value
}

///|
fn PrefixReplay::image(self : PrefixReplay, index : Int32) -> Int32 raise {
  if self.images.get(index) is Some(value) {
    return value
  }
  if index < 0 || index >= self.source.object.images.length() {
    raise InvalidReference("prefix image index out of range")
  }
  let value = self.target.add_image(self.source.object.images[index])
  self.images[index] = value
  value
}

///|
fn PrefixReplay::paint(self : PrefixReplay, index : Int32) -> Int32 raise {
  if self.paints.get(index) is Some(value) {
    return value
  }
  if index < 0 || index >= self.source.paints.length() {
    raise InvalidReference("prefix paint index out of range")
  }
  let paint = match self.source.paints[index] {
    @core.Pattern(image, repeat, matrix) =>
      @core.Pattern(self.image(image), repeat, matrix)
    value => value
  }
  let value = self.target.add_paint(paint)
  self.paints[index] = value
  value
}

///|
fn PrefixReplay::font(self : PrefixReplay, index : Int32) -> Int32 raise {
  if self.fonts.get(index) is Some(value) {
    return value
  }
  if index < 0 || index >= self.source.fonts.length() {
    raise InvalidReference("prefix font index out of range")
  }
  let value = self.target.add_font(self.source.fonts[index])
  self.fonts[index] = value
  self.font_refs.push(index)
  value
}

///|
fn PrefixReplay::child(self : PrefixReplay, index : Int32) -> Int32 raise {
  if self.children.get(index) is Some(value) {
    return value
  }
  if index < 0 || index >= self.source.object.objects.length() {
    raise InvalidReference("prefix child index out of range")
  }
  if index >= self.child_boxes.length() {
    raise InvalidReference("prefix child bounds missing")
  }
  let box = self.child_boxes[index]
  let value = self.target.add_object(self.source.object.objects[index], box)
  self.children[index] = value
  self.child_refs.push(index)
  value
}

///|
fn PrefixReplay::source_index(
  self : PrefixReplay,
  span : InstructionSpan,
) -> Int32 raise {
  let reader = @core.Reader::new(
    self.source.object.ops[span.start + 1:span.end].to_owned(),
  )
  reader.varuint()
}
