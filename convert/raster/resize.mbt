///|
/// One source pixel and how much of a target pixel it covers, in units of
/// 1/target-size of a source pixel.
priv struct RasterWeight {
  index : Int32
  weight : Int64
}

///|
/// For each of `m` target pixels along an axis of `n` source pixels, the
/// source pixels it covers and their overlaps. The overlaps of one target
/// pixel add up to `n`.
fn raster_box_weights(n : Int32, m : Int32) -> Array[Array[RasterWeight]] {
  let out : Array[Array[RasterWeight]] = []
  let n64 = n.to_int64()
  let m64 = m.to_int64()
  for target in 0..<m {
    let lo = target.to_int64() * n64
    let hi = (target.to_int64() + 1L) * n64
    let row : Array[RasterWeight] = []
    let mut source = lo / m64
    while source * m64 < hi {
      let start = if lo > source * m64 { lo } else { source * m64 }
      let end = if hi < (source + 1L) * m64 { hi } else { (source + 1L) * m64 }
      if end > start {
        row.push({ index: source.to_int(), weight: end - start, })
      }
      source += 1L
    }
    out.push(row)
  }
  out
}

///|
fn raster_distinct_colors(src : Bytes) -> (Int64, Int64, Int64, Int64)? {
  let count = src.length() / 4
  if count <= 0 {
    return None
  }
  let mut first = -1L
  let mut second = -1L
  let mut first_count = 0L
  let mut second_count = 0L
  for i in 0..<count {
    let offset = i * 4
    let color = (src[offset].to_int64() << 24) |
      (src[offset + 1].to_int64() << 16) |
      (src[offset + 2].to_int64() << 8) |
      src[offset + 3].to_int64()
    if first < 0L {
      first = color
      first_count = 1L
    } else if color == first {
      first_count += 1L
    } else if second < 0L {
      second = color
      second_count = 1L
    } else if color == second {
      second_count += 1L
    } else {
      return None
    }
  }
  if second < 0L {
    return None
  }
  Some((first, second, first_count, second_count))
}

///|
fn raster_resize_bilevel(
  src : Bytes,
  sw : Int32,
  sh : Int32,
  dw : Int32,
  dh : Int32,
  first : Int64,
  second : Int64,
  first_count : Int64,
  second_count : Int64,
) -> Bytes {
  let ink = if first_count <= second_count { first } else { second }
  let paper = if first_count <= second_count { second } else { first }
  let xs = raster_box_weights(sw, dw)
  let ys = raster_box_weights(sh, dh)
  let den = sw.to_int64() * sh.to_int64()
  let result : FixedArray[Byte] = FixedArray::make(
    (dw.to_int64() * dh.to_int64() * 4L).to_int(),
    0,
  )
  for y in 0..<dh {
    for x in 0..<dw {
      let mut covered = 0L
      for yw in ys[y] {
        let row = yw.index.to_int64() * sw.to_int64() * 4L
        for xw in xs[x] {
          let offset = (row + xw.index.to_int64() * 4L).to_int()
          let color = (src[offset].to_int64() << 24) |
            (src[offset + 1].to_int64() << 16) |
            (src[offset + 2].to_int64() << 8) |
            src[offset + 3].to_int64()
          if color == ink {
            covered += yw.weight * xw.weight
          }
        }
      }
      let average = (covered * 255L + den / 2L) / den
      let color = if average >= 102L { ink } else { paper }
      let offset = (y.to_int64() * dw.to_int64() + x.to_int64()) * 4L
      let at = offset.to_int()
      result[at] = ((color >> 24) & 0xffL).to_byte()
      result[at + 1] = ((color >> 16) & 0xffL).to_byte()
      result[at + 2] = ((color >> 8) & 0xffL).to_byte()
      result[at + 3] = (color & 0xffL).to_byte()
    }
  }
  Bytes::from_array(result)
}

///|
/// Scale 8-bit RGBA pixels down by averaging the source pixels each target
/// pixel covers (the box filter upstream uses for scanned pages).
///
/// A two-colour image keeps its two colours: a target pixel takes the ink
/// when it covers at least two fifths of the pixel, so thin strokes survive.
pub fn resize_box(
  src : Bytes,
  sw : Int32,
  sh : Int32,
  dw : Int32,
  dh : Int32,
  bilevel~ : Bool = false,
) -> Bytes raise RasterError {
  if sw <= 0 || sh <= 0 || dw <= 0 || dh <= 0 {
    raise InvalidRaster("raster: the image has no size")
  }
  if src.length().to_int64() != sw.to_int64() * sh.to_int64() * 4L {
    raise InvalidRaster("raster: the RGBA buffer does not match the image size")
  }
  if dw >= sw && dh >= sh {
    return src
  }
  let width = if dw < sw { dw } else { sw }
  let height = if dh < sh { dh } else { sh }
  if bilevel {
    match raster_distinct_colors(src) {
      Some((first, second, first_count, second_count)) =>
        return raster_resize_bilevel(
          src, sw, sh, width, height, first, second, first_count, second_count,
        )
      None => ()
    }
  }
  let xs = raster_box_weights(sw, width)
  let ys = raster_box_weights(sh, height)
  let den = sw.to_int64() * sh.to_int64()
  let result : FixedArray[Byte] = FixedArray::make(width * height * 4, 0)
  for y in 0..<height {
    for x in 0..<width {
      let mut red = 0L
      let mut green = 0L
      let mut blue = 0L
      let mut alpha = 0L
      for yw in ys[y] {
        let row = yw.index.to_int64() * sw.to_int64() * 4L
        for xw in xs[x] {
          let offset = (row + xw.index.to_int64() * 4L).to_int()
          let a = src[offset + 3].to_int64()
          let weight = yw.weight * xw.weight
          red += src[offset].to_int64() * a * weight
          green += src[offset + 1].to_int64() * a * weight
          blue += src[offset + 2].to_int64() * a * weight
          alpha += a * weight
        }
      }
      let a = (alpha + den / 2L) / den
      let r = if alpha > 0L { (red + alpha / 2L) / alpha } else { 0L }
      let g = if alpha > 0L { (green + alpha / 2L) / alpha } else { 0L }
      let b = if alpha > 0L { (blue + alpha / 2L) / alpha } else { 0L }
      let at = (y * width + x) * 4
      result[at] = r.to_byte()
      result[at + 1] = g.to_byte()
      result[at + 2] = b.to_byte()
      result[at + 3] = a.to_byte()
    }
  }
  Bytes::from_array(result)
}

///|
fn raster_axis_size(n : Int32, pt : Double, max_dpi : Double) -> Int32 {
  if n <= 0 || pt <= 0.0 || max_dpi <= 0.0 {
    return n
  }
  let scale = max_dpi * pt / 72.0 / n.to_double()
  if scale >= 1.0 - 1.0e-9 {
    return n
  }
  let scaled = (n.to_double() * scale).to_int()
  if scaled < 1 {
    1
  } else {
    scaled
  }
}

///|
/// The size in pixels at which a raster input of `w`×`h` pixels, shown
/// `w_pt`×`h_pt` points large, is stored: each axis is capped at
/// `max_dpi` pixels per inch, then both shrink by the same factor to at
/// most `max_pixels` pixels. It never scales up.
pub fn fit_size(
  w : Int32,
  h : Int32,
  w_pt : Double,
  h_pt : Double,
  max_dpi~ : Double = 192.0,
  max_pixels~ : Int64 = 14745600L,
) -> (Int32, Int32) {
  if w <= 0 || h <= 0 {
    return (w, h)
  }
  let mut width = raster_axis_size(w, w_pt, max_dpi)
  let mut height = raster_axis_size(h, h_pt, max_dpi)
  if max_pixels > 0L {
    let mut pixels = width.to_int64() * height.to_int64()
    if pixels > max_pixels {
      let scale = (max_pixels.to_double() / pixels.to_double()).sqrt()
      width = (width.to_double() * scale).to_int()
      height = (height.to_double() * scale).to_int()
      if width < 1 {
        width = 1
      }
      if height < 1 {
        height = 1
      }
      pixels = width.to_int64() * height.to_int64()
      while pixels > max_pixels {
        if width >= height {
          width -= 1
        } else {
          height -= 1
        }
        pixels = width.to_int64() * height.to_int64()
      }
    }
  }
  (width, height)
}
