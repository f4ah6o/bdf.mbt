///|
// A JBIG2 bitmap: one bit per pixel, MSB first, each row byte aligned. 1 is
// black, the JBIG2 convention. Padding bits at the end of a row are 0.
// Ported from upstream converter/internal/jbig2/bitmap.go.
priv struct PdfJbig2Bitmap {
  width : Int
  mut height : Int
  stride : Int
  data : Array[Byte]
}

///|
// Combination operators (T.88 7.4.1.5, 7.4.3.1.1).
let pdf_jbig2_op_replace : Int = 4

///|
fn pdf_jbig2_bitmap_new(w : Int, h : Int) -> PdfJbig2Bitmap {
  let stride = (w + 7) >> 3
  { width: w, height: h, stride, data: Array::make(stride * h, 0) }
}

///|
fn PdfJbig2Bitmap::pixel(self : PdfJbig2Bitmap, x : Int, y : Int) -> Int {
  if x < 0 || y < 0 || x >= self.width || y >= self.height {
    return 0
  }
  (self.data[y * self.stride + (x >> 3)].to_int() >> (7 - (x & 7))) & 1
}

///|
fn PdfJbig2Bitmap::set(self : PdfJbig2Bitmap, x : Int, y : Int) -> Unit {
  let index = y * self.stride + (x >> 3)
  self.data[index] = (self.data[index].to_int() | (0x80 >> (x & 7))).to_byte()
}

///|
fn PdfJbig2Bitmap::fill(self : PdfJbig2Bitmap, v : Int) -> Unit {
  let c : Byte = if v != 0 { 0xff } else { 0 }
  for i in 0..<self.data.length() {
    self.data[i] = c
  }
  self.clear_padding()
}

///|
// Clear the bits past the width at the end of each row.
fn PdfJbig2Bitmap::clear_padding(self : PdfJbig2Bitmap) -> Unit {
  if (self.width & 7) == 0 {
    return
  }
  let mask = (0xff << (8 - (self.width & 7))) & 0xff
  let mut i = self.stride - 1
  while i < self.data.length() {
    self.data[i] = (self.data[i].to_int() & mask).to_byte()
    i += self.stride
  }
}

///|
// The index of row y in the data, or -1 for a row outside the bitmap.
fn PdfJbig2Bitmap::row_base(self : PdfJbig2Bitmap, y : Int) -> Int {
  if y < 0 || y >= self.height {
    -1
  } else {
    y * self.stride
  }
}

///|
// Pixel x of the row starting at base, or 0 outside it or for a missing row.
fn pdf_jbig2_bit(data : Array[Byte], base : Int, w : Int, x : Int) -> Int {
  if base < 0 || x < 0 || x >= w {
    0
  } else {
    (data[base + (x >> 3)].to_int() >> (7 - (x & 7))) & 1
  }
}

///|
// Combine the w bits of src starting at bit sx into dst starting at bit dx.
fn pdf_jbig2_compose_row(
  dst : Array[Byte],
  dst_base : Int,
  dx0 : Int,
  src : Array[Byte],
  src_base : Int,
  src_stride : Int,
  sx0 : Int,
  w0 : Int,
  op : Int,
) -> Unit {
  let mut dx = dx0
  let mut sx = sx0
  let mut w = w0
  while w > 0 {
    let off = dx & 7
    let mut n = 8 - off
    if n > w {
      n = w
    }
    // The next eight source bits, aligned to the destination bit position.
    let i = src_base + (sx >> 3)
    let sh = sx & 7
    let mut v = (src[i].to_int() << sh) & 0xff
    if sh != 0 && i + 1 < src_base + src_stride {
      v = (v | (src[i + 1].to_int() >> (8 - sh))) & 0xff
    }
    v = v >> off
    let mask = ((0xff >> off) & (0xff ^ (0xff >> (off + n)))) & 0xff
    let p = dst_base + (dx >> 3)
    let current = dst[p].to_int()
    let r = match op {
      0 => current | v
      1 => current & v
      2 => current ^ v
      3 => (current ^ v) ^ 0xff
      _ => v
    }
    dst[p] = ((current & (mask ^ 0xff)) | (r & mask)).to_byte()
    dx += n
    sx += n
    w -= n
  }
}

///|
// Combine src into self with its top left corner at (x, y), clipped to self.
fn PdfJbig2Bitmap::compose(
  self : PdfJbig2Bitmap,
  src : PdfJbig2Bitmap,
  x0 : Int,
  y0 : Int,
  op : Int,
) -> Unit {
  let mut sx = 0
  let mut sy = 0
  let mut x = x0
  let mut y = y0
  if x < 0 {
    sx = -x
    x = 0
  }
  if y < 0 {
    sy = -y
    y = 0
  }
  let w = Int::min(src.width - sx, self.width - x)
  let h = Int::min(src.height - sy, self.height - y)
  if w <= 0 || h <= 0 {
    return
  }
  for r in 0..<h {
    pdf_jbig2_compose_row(
      self.data,
      (y + r) * self.stride,
      x,
      src.data,
      (sy + r) * src.stride,
      src.stride,
      sx,
      w,
      op,
    )
  }
}

///|
// Copy the w×h rectangle at (x, y), which must lie in the bitmap.
fn PdfJbig2Bitmap::sub(
  self : PdfJbig2Bitmap,
  x : Int,
  y : Int,
  w : Int,
  h : Int,
) -> PdfJbig2Bitmap {
  let out = pdf_jbig2_bitmap_new(w, h)
  for r in 0..<h {
    pdf_jbig2_compose_row(
      out.data,
      r * out.stride,
      0,
      self.data,
      (y + r) * self.stride,
      self.stride,
      x,
      w,
      pdf_jbig2_op_replace,
    )
  }
  out
}

///|
fn PdfJbig2Bitmap::copy_row_from(
  self : PdfJbig2Bitmap,
  y : Int,
  from_y : Int,
) -> Unit {
  let dst = y * self.stride
  let src = from_y * self.stride
  for k in 0..<self.stride {
    self.data[dst + k] = self.data[src + k]
  }
}

///|
// Set pixels x0 to x1−1 of a row.
fn pdf_jbig2_fill_span(
  data : Array[Byte],
  base : Int,
  x0 : Int,
  x1 : Int,
) -> Unit {
  let mut x = x0
  while x < x1 && (x & 7) != 0 {
    data[base + (x >> 3)] = (data[base + (x >> 3)].to_int() | (0x80 >> (x & 7))).to_byte()
    x += 1
  }
  while x + 8 <= x1 {
    data[base + (x >> 3)] = 0xff
    x += 8
  }
  while x < x1 {
    data[base + (x >> 3)] = (data[base + (x >> 3)].to_int() | (0x80 >> (x & 7))).to_byte()
    x += 1
  }
}
