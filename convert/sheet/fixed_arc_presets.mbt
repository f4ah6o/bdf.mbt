///|
// DrawingML arcs retain floating-point state until the complete path is encoded.
priv struct SheetArcPath {
  verbs : Array[Byte]
  coordinates : Array[Double]
  mut x : Double
  mut y : Double
}

///|
fn SheetArcPath::move(self : SheetArcPath, x : Double, y : Double) -> Unit {
  self.verbs.push(b'\x00')
  self.coordinates.push(x)
  self.coordinates.push(y)
  self.x = x
  self.y = y
}

///|
fn SheetArcPath::line(self : SheetArcPath, x : Double, y : Double) -> Unit {
  self.verbs.push(b'\x01')
  self.coordinates.push(x)
  self.coordinates.push(y)
  self.x = x
  self.y = y
}

///|
fn SheetArcPath::arc(
  self : SheetArcPath,
  rx : Double,
  ry : Double,
  start : Double,
  sweep : Double,
) -> Unit {
  if rx <= 0.0 || ry <= 0.0 {
    return
  }
  let unit = 2.9088820866572161809e-7
  let start = start * unit
  let sweep = sweep * unit
  let a0 = @math.atan2(rx * @math.sin(start), ry * @math.cos(start))
  let end = @math.atan2(
    rx * @math.sin(start + sweep),
    ry * @math.cos(start + sweep),
  )
  let d = end - (a0 + sweep)
  let d = @core.fused_multiply_add(
    -2.0 * @math.PI,
    (d / (2.0 * @math.PI)).round(),
    d,
  )
  let a1 = a0 + sweep + d
  let cx = @core.fused_multiply_add(-rx, @math.cos(a0), self.x)
  let cy = @core.fused_multiply_add(-ry, @math.sin(a0), self.y)
  self.verbs.push(b'\x06')
  self.coordinates.push(cx)
  self.coordinates.push(cy)
  self.coordinates.push(rx)
  self.coordinates.push(ry)
  self.coordinates.push(0.0)
  self.coordinates.push(a0)
  self.coordinates.push(a1)
  self.coordinates.push(if sweep < 0.0 { 1.0 } else { 0.0 })
  self.x = @core.fused_multiply_add(rx, @math.cos(a1), cx)
  self.y = @core.fused_multiply_add(ry, @math.sin(a1), cy)
}

///|
fn sheet_fixed_arc_preset_path(
  geometry : String,
  width : Double,
  height : Double,
) -> @core.Path {
  let builder : SheetArcPath = { verbs: [], coordinates: [], x: 0.0, y: 0.0, }
  match geometry {
    "flowChartTerminator" => {
      let sx = width / 21600.0
      let sy = height / 21600.0
      builder.move(3475.0 * sx, 0.0)
      builder.line(18125.0 * sx, 0.0)
      builder.arc(3475.0 * sx, 10800.0 * sy, 16200000.0, 10800000.0)
      builder.line(3475.0 * sx, 21600.0 * sy)
      builder.arc(3475.0 * sx, 10800.0 * sy, 5400000.0, 10800000.0)
    }
    "flowChartDisplay" => {
      let sx = width / 6.0
      let sy = height / 6.0
      builder.move(0.0, 3.0 * sy)
      builder.line(sx, 0.0)
      builder.line(5.0 * sx, 0.0)
      builder.arc(sx, 3.0 * sy, 16200000.0, 10800000.0)
      builder.line(sx, 6.0 * sy)
    }
    "flowChartOnlineStorage" => {
      let sx = width / 6.0
      let sy = height / 6.0
      builder.move(sx, 0.0)
      builder.line(6.0 * sx, 0.0)
      builder.arc(sx, 3.0 * sy, 16200000.0, -10800000.0)
      builder.line(sx, 6.0 * sy)
      builder.arc(sx, 3.0 * sy, 5400000.0, 10800000.0)
    }
    "flowChartPunchedTape" => {
      let sx = width / 20.0
      let sy = height / 20.0
      builder.move(0.0, 2.0 * sy)
      builder.arc(5.0 * sx, 2.0 * sy, 10800000.0, -10800000.0)
      builder.arc(5.0 * sx, 2.0 * sy, 10800000.0, 10800000.0)
      builder.line(20.0 * sx, 18.0 * sy)
      builder.arc(5.0 * sx, 2.0 * sy, 0.0, -10800000.0)
      builder.arc(5.0 * sx, 2.0 * sy, 0.0, 10800000.0)
    }
    _ => abort("unknown fixed arc preset")
  }
  builder.verbs.push(b'\x04')
  { verbs: Bytes::from_array(builder.verbs), coordinates: builder.coordinates, }
}
