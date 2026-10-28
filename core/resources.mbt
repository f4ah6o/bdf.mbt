///|
/// One gradient stop. Colors use BDF's 0xRRGGBBAA encoding.
pub(all) struct ColorStop {
  offset : Double
  color : Int32
}

///|
/// A gradient or image pattern from an object's resource table.
pub(all) enum Paint {
  Gradient(Int32, Array[Double], Array[ColorStop])
  Pattern(Int32, Int32, Array[Double])
}

///|
/// A system or embedded font reference from an object.
pub(all) struct Font {
  hash : String?
  family : String
  weight : Int32
  style : Int32
}

///|
fn read_paint(reader : Reader) -> Paint raise {
  let kind = reader.u8()
  if kind == 3 {
    let image = reader.varuint()
    let repeat = reader.u8()
    let matrix = []
    for _ in 0..<6 {
      matrix.push(reader.f32())
    }
    Pattern(image, repeat, matrix)
  } else {
    if kind > 2 {
      raise BadFormat("unknown paint kind")
    }
    let count = if kind == 0 { 4 } else if kind == 1 { 6 } else { 3 }
    let coordinates = []
    for _ in 0..<count {
      coordinates.push(reader.f32())
    }
    let count = reader.varuint()
    if count > reader.remaining() / 8 {
      raise BadFormat("paint stops out of range")
    }
    let stops = []
    for _ in 0..<count {
      stops.push({ offset: reader.f32(), color: reader.u32(), })
    }
    Gradient(kind, coordinates, stops)
  }
}

///|
fn read_font(reader : Reader) -> Font raise {
  let hash = match reader.u8() {
    0 => Some(reader.hash())
    1 => None
    _ => raise BadFormat("unknown font kind")
  }
  { hash, family: reader.string(), weight: reader.u16(), style: reader.u8(), }
}
