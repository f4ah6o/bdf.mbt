///|
// Go's matrix multiplication fuses the first product and the second product's
// rounded result. Preserve IEEE signed zero for zero products.
fn pdf_matrix_fma(a : Double, b : Double, c : Double) -> Double {
  if a == 0.0 || b == 0.0 {
    return a * b + c
  }
  @core.fused_multiply_add(a, b, c)
}

///|
// Go evaluates the first product separately and fuses the subtraction.
fn pdf_matrix_scale(
  matrix : (Double, Double, Double, Double, Double, Double),
) -> Double {
  let (a, b, c, d, _, _) = matrix
  pdf_matrix_fma(-b, c, a * d).abs().sqrt()
}

///|
fn pdf_matrix_mul(
  m : (Double, Double, Double, Double, Double, Double),
  n : (Double, Double, Double, Double, Double, Double),
) -> (Double, Double, Double, Double, Double, Double) {
  let (a, b, c, d, e, f) = m
  let (g, h, i, j, k, l) = n
  (
    pdf_matrix_fma(a, g, b * i),
    pdf_matrix_fma(a, h, b * j),
    pdf_matrix_fma(c, g, d * i),
    pdf_matrix_fma(c, h, d * j),
    pdf_matrix_fma(e, g, f * i) + k,
    pdf_matrix_fma(e, h, f * j) + l,
  )
}

///|
priv struct PdfPageGeometry {
  width : Double
  height : Double
  matrix : (Double, Double, Double, Double, Double, Double)
} derive(Debug, Eq)

///|
fn pdf_rect_intersection(
  a : (Double, Double, Double, Double),
  b : (Double, Double, Double, Double),
) -> (Double, Double, Double, Double) {
  let (ax, ay, bx, by) = a
  let (cx, cy, dx, dy) = b
  (
    Double::max(ax, cx),
    Double::max(ay, cy),
    Double::min(bx, dx),
    Double::min(by, dy),
  )
}

///|
fn pdf_rect_empty(box : (Double, Double, Double, Double)) -> Bool {
  let (x0, y0, x1, y1) = box
  x1 <= x0 || y1 <= y0
}

///|
// Optional bleed, trim and art boxes are normalized, then clipped to the
// chosen crop/media box. Unlike these boxes, inherited boxes are not normalized.
fn PdfFile::page_boundary(
  self : PdfFile,
  page : PdfObject,
  key : Bytes,
) -> (Double, Double, Double, Double) {
  match self.page_deref(pdf_dict_get(page, key)) {
    PdfArray(values) if values.length() == 4 => {
      let nums = values.map(fn(value) {
        match self.page_num(Some(value)) {
          Some(v) => v
          None => 0.0
        }
      })
      (
        Double::min(nums[0], nums[2]),
        Double::min(nums[1], nums[3]),
        Double::max(nums[0], nums[2]),
        Double::max(nums[1], nums[3]),
      )
    }
    _ => (0.0, 0.0, 0.0, 0.0)
  }
}

///|
fn PdfFile::page_geometry(
  self : PdfFile,
  page : PdfPageLeaf,
  which : String,
) -> PdfPageGeometry {
  let mut box = match page.attrs.media {
    Some(value) => value
    None => (0.0, 0.0, 612.0, 792.0)
  }
  match page.attrs.crop {
    Some(crop) if which != "media" => {
      let clipped = pdf_rect_intersection(crop, box)
      if !pdf_rect_empty(clipped) {
        box = clipped
      }
    }
    _ => ()
  }
  let key = match which {
    "bleed" => b"BleedBox"
    "trim" => b"TrimBox"
    "art" => b"ArtBox"
    _ => b""
  }
  if key != b"" {
    let clipped = pdf_rect_intersection(self.page_boundary(page.dict, key), box)
    if !pdf_rect_empty(clipped) {
      box = clipped
    }
  }
  let (x0, y0, x1, y1) = box
  if pdf_rect_empty(box) || x1 - x0 > 20000.0 || y1 - y0 > 20000.0 {
    box = (0.0, 0.0, 612.0, 792.0)
  }
  let (x0, y0, x1, y1) = box
  let w = x1 - x0
  let h = y1 - y0
  let rotate = (page.attrs.rotate % 360 + 360) % 360
  let base = (1.0, 0.0, 0.0, -1.0, -x0, y1)
  match rotate {
    90 =>
      {
        width: h,
        height: w,
        matrix: pdf_matrix_mul(base, (0.0, 1.0, -1.0, 0.0, h, 0.0)),
      }
    180 =>
      {
        width: w,
        height: h,
        matrix: pdf_matrix_mul(base, (-1.0, 0.0, 0.0, -1.0, w, h)),
      }
    270 =>
      {
        width: h,
        height: w,
        matrix: pdf_matrix_mul(base, (0.0, -1.0, 1.0, 0.0, 0.0, w)),
      }
    _ => { width: w, height: h, matrix: base, }
  }
}
