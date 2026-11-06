///|
/// A row source: straight-alpha RGBA pixels, top row first.
pub(all) struct RasterImage {
  width : Int
  height : Int
  rgba : Bytes
}

///|
pub fn RasterImage::new(width : Int, height : Int, rgba : Bytes) -> RasterImage raise RasterError {
  if width <= 0 || height <= 0 || rgba.length() != width * height * 4 {
    raise RasterError("raster: the image does not hold RGBA pixels")
  }
  { width, height, rgba }
}

///|
fn raster_over_white(image : RasterImage, x : Int, y : Int) -> (Int, Int, Int) {
  let i = (y * image.width + x) * 4
  let alpha = image.rgba[i + 3].to_int()
  let over = fn(value : Byte) -> Int {
    (value.to_int() * alpha + 255 * (255 - alpha) + 127) / 255
  }
  (over(image.rgba[i]), over(image.rgba[i + 1]), over(image.rgba[i + 2]))
}

///|
fn raster_luma(r : Int, g : Int, b : Int) -> Int {
  (19595 * r + 38470 * g + 7471 * b + 32768) >> 16
}

///|
/// The bytes of row y in a page type: gray, RGB or packed one-bit pixels.
pub fn row_bytes(
  image : RasterImage,
  y : Int,
  typ : String,
) -> Bytes raise RasterError {
  if y < 0 || y >= image.height {
    raise RasterError("raster: the row is outside the image")
  }
  let layout = raster_layout(typ)
  let (_, _, bits, _) = match layout {
    Some(value) => value
    None => raise RasterError("raster: no PWG Raster type \"" + typ + "\"")
  }
  if bits == 8 && typ == SGRAY_8 {
    let out = Array::make(image.width, b'\x00')
    for x in 0..<image.width {
      let (r, g, b) = raster_over_white(image, x, y)
      out[x] = raster_luma(r, g, b).to_byte()
    }
    Bytes::from_array(out)
  } else if bits == 24 && typ == SRGB_8 {
    let out = Array::make(image.width * 3, b'\x00')
    for x in 0..<image.width {
      let (r, g, b) = raster_over_white(image, x, y)
      out[x * 3] = r.to_byte()
      out[x * 3 + 1] = g.to_byte()
      out[x * 3 + 2] = b.to_byte()
    }
    Bytes::from_array(out)
  } else if bits == 1 && (typ == BLACK_1 || typ == SGRAY_1) {
    let line_size = (image.width + 7) / 8
    let out = Array::make(line_size, if typ == SGRAY_1 { b'\xff' } else { b'\x00' })
    let ink_is_one = typ == BLACK_1
    for x in 0..<image.width {
      let (r, g, b) = raster_over_white(image, x, y)
      let dark = raster_luma(r, g, b) < 128
      let bit = b'\x80'.to_int() >> (x & 7)
      if dark == ink_is_one {
        out[x >> 3] = (out[x >> 3].to_int() | bit).to_byte()
      } else {
        out[x >> 3] = (out[x >> 3].to_int() & (bit ^ 0xff)).to_byte()
      }
    }
    Bytes::from_array(out)
  } else {
    raise RasterError("raster: no row conversion for \"" + typ + "\"")
  }
}

///|
/// Convert and add row y of an image to the current page.
pub fn Writer::write_image_row(self : Writer, image : RasterImage, y : Int) -> Unit raise RasterError {
  let page = match self.page {
    Some(value) => value
    None => raise RasterError("raster: a row before a page")
  }
  if image.width != page.width {
    raise RasterError("raster: rows of another width")
  }
  self.write_row(row_bytes(image, y, page.typ))
}
