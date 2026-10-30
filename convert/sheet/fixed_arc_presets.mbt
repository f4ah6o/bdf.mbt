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
  go_angles~ : Bool = false,
) -> Unit {
  if rx <= 0.0 || ry <= 0.0 {
    return
  }
  let unit = 2.9088820866572161809e-7
  let start = start * unit
  let sweep = sweep * unit
  let y0 = rx * @math.sin(start)
  let x0 = ry * @math.cos(start)
  let y1 = rx * @math.sin(start + sweep)
  let x1 = ry * @math.cos(start + sweep)
  let a0 = if go_angles {
    sheet_arc_go_atan2(y0, x0)
  } else {
    @math.atan2(y0, x0)
  }
  let end = if go_angles {
    sheet_arc_go_atan2(y1, x1)
  } else {
    @math.atan2(y1, x1)
  }
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
// Copyright 2009 The Go Authors. Adapted from Go math/atan.go and atan2.go
// (BSD license: ../../licenses/Go-x-text.txt). The atan approximation is based
// on the Cephes Math Library by Stephen L. Moshier; see
// ../../licenses/Cephes.txt for its copyright and permission notice.
// Go computes atan2 through atan(y / x) followed by a quadrant correction.
// Browser and Wasm atan2 may round differently near pi, which changes BDF
// coordinates even when the resulting angles have the same float32 value.
fn sheet_arc_go_atan2(y : Double, x : Double) -> Double {
  if y == 0.0 {
    if x < 0.0 {
      return if y.reinterpret_as_uint64() >> 63 == 0UL {
        @math.PI
      } else {
        -@math.PI
      }
    }
    return y
  }
  if x == 0.0 {
    return if y > 0.0 { @math.PI / 2.0 } else { -@math.PI / 2.0 }
  }
  let q = sheet_arc_go_atan(y / x)
  if x < 0.0 {
    if q <= 0.0 {
      q + @math.PI
    } else {
      q - @math.PI
    }
  } else {
    q
  }
}

///|
// Go's atan range reduction is required here: near a quadrant the small
// difference between atan and the platform math library survives as a path
// coordinate after the arc center is computed.
fn sheet_arc_go_atan(value : Double) -> Double {
  if value == 0.0 {
    return value
  }
  let x = value.abs()
  let more = 6.123233995736765886130e-17
  let result = if x <= 0.66 {
    sheet_arc_go_xatan(x)
  } else if x > 2.41421356237309504880 {
    @math.PI / 2.0 - sheet_arc_go_xatan(1.0 / x) + more
  } else {
    @math.PI / 4.0 + sheet_arc_go_xatan((x - 1.0) / (x + 1.0)) + 0.5 * more
  }
  if value > 0.0 {
    result
  } else {
    -result
  }
}

///|
fn sheet_arc_go_xatan(x : Double) -> Double {
  let z = x * x
  let p = @core.fused_multiply_add(
    @core.fused_multiply_add(
      @core.fused_multiply_add(
        @core.fused_multiply_add(
          -8.750608600031904122785e-1, z, -1.615753718733365076637e1,
        ),
        z,
        -7.500855792314704667340e1,
      ),
      z,
      -1.228866684490136173410e2,
    ),
    z,
    -6.485021904942025371773e1,
  )
  let q = @core.fused_multiply_add(
    @core.fused_multiply_add(
      @core.fused_multiply_add(
        @core.fused_multiply_add(
          z + 2.485846490142306297962e1,
          z,
          1.650270098316988542046e2,
        ),
        z,
        4.328810604912902668951e2,
      ),
      z,
      4.853903996359136964868e2,
    ),
    z,
    1.945506571482613964425e2,
  )
  let r = z * p / q
  @core.fused_multiply_add(x, r, x)
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
