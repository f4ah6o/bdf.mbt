///|
// PDF's current path is separate from the graphics-state stack. Coordinates
// are rounded to float32 when inserted, as in the upstream BDF Path builder.
priv struct PdfDrawPath {
  verbs : Array[Byte]
  coordinates : Array[Double]
  mut current_x : Double
  mut current_y : Double
  mut start_x : Double
  mut start_y : Double
  mut bounds : (Double, Double, Double, Double)?
}

///|
fn PdfDrawPath::new() -> PdfDrawPath {
  {
    verbs: [],
    coordinates: [],
    current_x: 0.0,
    current_y: 0.0,
    start_x: 0.0,
    start_y: 0.0,
    bounds: None,
  }
}

///|
fn PdfDrawPath::add(
  self : PdfDrawPath,
  verb : Byte,
  values : Array[Double],
) -> Unit {
  self.verbs.push(verb)
  for value in values {
    self.coordinates.push(Float::from_double(value).to_double())
  }
}

///|
fn PdfDrawPath::grow(self : PdfDrawPath, x : Double, y : Double) -> Unit {
  self.bounds = Some(
    match self.bounds {
      None => (x, y, x, y)
      Some((x0, y0, x1, y1)) =>
        (
          Double::min(x0, x),
          Double::min(y0, y),
          Double::max(x1, x),
          Double::max(y1, y),
        )
    },
  )
}

///|
fn PdfDrawPath::move(self : PdfDrawPath, x : Double, y : Double) -> Unit {
  self.add(0, [x, y])
  self.current_x = x
  self.current_y = y
  self.start_x = x
  self.start_y = y
  self.grow(x, y)
}

///|
fn PdfDrawPath::line(self : PdfDrawPath, x : Double, y : Double) -> Unit {
  if self.bounds is None {
    self.move(x, y)
    return
  }
  self.add(1, [x, y])
  self.current_x = x
  self.current_y = y
  self.grow(x, y)
}

///|
fn PdfDrawPath::curve(
  self : PdfDrawPath,
  x1 : Double,
  y1 : Double,
  x2 : Double,
  y2 : Double,
  x3 : Double,
  y3 : Double,
) -> Unit {
  if self.bounds is None {
    self.move(x1, y1)
  }
  self.add(3, [x1, y1, x2, y2, x3, y3])
  self.grow(x1, y1)
  self.grow(x2, y2)
  self.grow(x3, y3)
  self.current_x = x3
  self.current_y = y3
}

///|
fn PdfDrawPath::close(self : PdfDrawPath) -> Unit {
  if self.bounds is None {
    return
  }
  self.add(4, [])
  self.current_x = self.start_x
  self.current_y = self.start_y
}

///|
fn PdfDrawPath::rectangle(
  self : PdfDrawPath,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
) -> Unit {
  self.add(5, [x, y, width, height])
  self.grow(x, y)
  self.grow(x + width, y + height)
  self.current_x = x
  self.current_y = y
  self.start_x = x
  self.start_y = y
}
