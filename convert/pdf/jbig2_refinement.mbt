///|
// Generic refinement region decoding (T.88 6.3.5), ported from upstream
// converter/internal/jbig2/refinement.go.
// Context bits of the generic refinement templates (6.3.5.3). Both take bit 0
// from pixel x−1 of the current row and further bits from the row above and
// from the 3×3 neighbourhood of the corresponding reference pixel.
let pdf_jbig2_refinement_bits : Array[Int] = [13, 10]

///|
// The parameters of the generic refinement region decoding procedure.
priv struct PdfJbig2RefinementParams {
  template : Int
  at : Array[PdfJbig2Point] // two AT pixels for template 0
  reference : PdfJbig2Bitmap
  dx : Int
  dy : Int
  tpgron : Bool
}

///|
fn pdf_jbig2_new_refinement_stats(template : Int) -> Array[Int] {
  Array::make(1 << pdf_jbig2_refinement_bits[template], 0)
}

///|
// Decode a w×h bitmap with the generic refinement region decoding procedure
// (6.3.5). If the coded data runs out, the rows not yet decoded stay white.
fn pdf_jbig2_decode_refinement(
  ad : PdfJbig2Arith,
  stats : Array[Int],
  w : Int,
  h : Int,
  p : PdfJbig2RefinementParams,
) -> PdfJbig2Bitmap {
  let bm = pdf_jbig2_bitmap_new(w, h)
  let reference = p.reference
  let dx = pdf_jbig2_clamp_coord(p.dx.to_int64())
  let dy = pdf_jbig2_clamp_coord(p.dy.to_int64())
  let mut at0 : PdfJbig2Point = { x: 0, y: 0 }
  let mut at1 : PdfJbig2Point = { x: 0, y: 0 }
  let mut nominal = true
  if p.template == 0 {
    at0 = p.at[0]
    at1 = p.at[1]
    nominal = at0.x == -1 && at0.y == -1 && at1.x == -1 && at1.y == -1
  }
  // Typical prediction decodes this context, whose only 1 is the reference
  // pixel corresponding to the current one (6.3.5.6).
  let sltp = if p.template == 1 { 0x080 } else { 0x100 }
  let mut ltp = 0
  let up_window : PdfJbig2Window = { hi: 1, lo: -1, shift: 0 }
  let ref_window : PdfJbig2Window = { hi: 1 - dx, lo: -1 - dx, shift: 0 }
  for y in 0..<h {
    if ad.exhausted() {
      break
    }
    if p.tpgron {
      ltp = ltp ^ pdf_jbig2_arith_decode(ad, stats, sltp)
    }
    let up = bm.row_base(y - 1)
    let ry = y - dy
    let rp = reference.row_base(ry + 1)
    let r0 = reference.row_base(ry)
    let rm = reference.row_base(ry - 1)
    // Three-pixel windows with bit 0 at the right: the row above at x+1, x,
    // x−1, and the reference rows around x−dx.
    let mut u = up_window.start(bm.data, up, w)
    let mut vp = ref_window.start(reference.data, rp, reference.width)
    let mut v0 = ref_window.start(reference.data, r0, reference.width)
    let mut vm = ref_window.start(reference.data, rm, reference.width)
    let mut c = 0
    for x in 0..<w {
      let mut b = -1
      if ltp != 0 {
        if (vp | v0 | vm) == 0 {
          b = 0
        } else if (vp & v0 & vm) == 7 {
          b = 1
        }
      }
      if b < 0 {
        let cx = if p.template == 0 {
          let mut cx = c |
            ((u & 3) << 1) |
            ((vp & 7) << 4) |
            ((v0 & 7) << 7) |
            ((vm & 3) << 10)
          if nominal {
            cx = cx | (((u >> 2) & 1) << 3) | (((vm >> 2) & 1) << 12)
          } else {
            cx = cx |
              (bm.pixel(x + at0.x, y + at0.y) << 3) |
              (reference.pixel(x - dx + at1.x, ry + at1.y) << 12)
          }
          cx
        } else {
          c |
          ((u & 7) << 1) |
          ((vp & 3) << 4) |
          ((v0 & 7) << 6) |
          (((vm >> 1) & 1) << 9)
        }
        b = pdf_jbig2_arith_decode(ad, stats, cx)
      }
      if b != 0 {
        bm.set(x, y)
      }
      c = b
      u = ((u << 1) | pdf_jbig2_bit(bm.data, up, w, x + 2)) & 7
      let rx = x - dx + 2
      vp = ((vp << 1) | pdf_jbig2_bit(reference.data, rp, reference.width, rx)) & 7
      v0 = ((v0 << 1) | pdf_jbig2_bit(reference.data, r0, reference.width, rx)) & 7
      vm = ((vm << 1) | pdf_jbig2_bit(reference.data, rm, reference.width, rx)) & 7
    }
  }
  bm
}

///|
// Decode a generic refinement region segment (7.4.7). It refines the
// intermediate region it refers to, or else the part of the page it covers.
fn PdfJbig2Decoder::refinement_region_segment(
  self : PdfJbig2Decoder,
  s : PdfJbig2Segment,
  data : Bytes,
) -> Unit raise PdfStreamError {
  let r = pdf_jbig2_reader_new(data)
  let ri = pdf_jbig2_read_region_info(r)
  let flags = r.u8()
  let template = flags & 1
  let tpgron = (flags & 2) != 0
  let mut at : Array[PdfJbig2Point] = []
  if template == 0 {
    at = r.at(2)
  }
  let body = r.rest()
  if r.err {
    raise InvalidStream("truncated JBIG2 refinement region segment")
  }
  let (w, h) = ri.size()
  let mut reference : PdfJbig2Bitmap? = None
  for value in self.referred(s) {
    match value {
      PdfJbig2ResultBitmap(bm) => reference = Some(bm)
      _ => ()
    }
  }
  let reference = match reference {
    Some(bm) => bm
    None => {
      let page = match self.page {
        Some(page) => page
        None =>
          raise InvalidStream(
            "JBIG2 refinement region segment \{s.header.number} before the page information",
          )
      }
      let bm = self.new_bitmap(w, h)
      bm.compose(
        page.bm,
        -pdf_jbig2_clamp_coord(ri.x.to_int64()),
        -pdf_jbig2_clamp_coord(ri.y.to_int64()),
        pdf_jbig2_op_replace,
      )
      bm
    }
  }
  let bm = pdf_jbig2_decode_refinement(
    pdf_jbig2_arith_new(body),
    pdf_jbig2_new_refinement_stats(template),
    w,
    h,
    { template, at, reference, dx: 0, dy: 0, tpgron },
  )
  self.place_region(s, bm, ri)
}
