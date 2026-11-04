///|
// MMR (ITU-T T.6 Group 4 facsimile) decoding, ported from upstream
// converter/internal/jbig2/mmr.go. The run and mode lookup tables are shared
// with the PDF CCITT decoder (ccitt.mbt).
let pdf_jbig2_eofb : Int = 0x001001

///|
// Reads MMR codes; past the end of the data it reads 0 bits.
priv struct PdfJbig2MmrReader {
  data : Bytes
  mut pos : Int // in bits
}

///|
fn PdfJbig2MmrReader::peek(self : PdfJbig2MmrReader, n : Int) -> Int {
  let mut v = 0
  for k in 0..<n {
    let bit = self.pos + k
    let index = bit >> 3
    if index >= 0 && index < self.data.length() {
      v = (v << 1) | ((self.data[index].to_int() >> (7 - (bit & 7))) & 1)
    } else {
      v = v << 1
    }
  }
  v
}

///|
// Decode a run length of the given colour (0 = white).
fn PdfJbig2MmrReader::run(
  self : PdfJbig2MmrReader,
  color : Int,
) -> Int raise PdfStreamError {
  let lut = if color == 0 {
    pdf_ccitt_white_lut
  } else {
    pdf_ccitt_black_lut
  }
  let mut total = 0
  while true {
    let entry = lut[self.peek(13)]
    if entry < 0 {
      raise InvalidStream("invalid MMR run length code")
    }
    self.pos += entry & 0xff
    let value = entry >> 8
    total += value
    if value < 64 {
      return total
    }
    if total > 67108864 {
      raise InvalidStream("invalid MMR run length")
    }
  }
  0
}

///|
// Decode one coding line against the reference line ref, a list of changing
// elements followed by at least three entries equal to the width w. The
// changing elements of the new line are appended to cur.
fn PdfJbig2MmrReader::line(
  self : PdfJbig2MmrReader,
  reference : Array[Int],
  cur : Array[Int],
  w : Int,
) -> Unit raise PdfStreamError {
  let mut a0 = -1
  let mut color = 0
  let mut i = 0
  let mut steps = 0
  while a0 < w {
    if steps > 2 * w + 16 || (self.pos >> 3) > self.data.length() + 8 {
      raise InvalidStream("invalid MMR data")
    }
    // b1 is the first changing element of the reference line after a0 of the
    // colour opposite to a0's; b2 the one after it.
    while i > 0 && reference[i - 1] > a0 {
      i -= 1
    }
    while i < reference.length() && reference[i] <= a0 {
      i += 1
    }
    if (i & 1) != color {
      i += 1
    }
    let b1 = if i < reference.length() { reference[i] } else { w }
    let b2 = if i + 1 < reference.length() { reference[i + 1] } else { w }
    let entry = pdf_ccitt_mode_lut[self.peek(7)]
    if entry < 0 {
      raise InvalidStream("invalid or unsupported MMR code")
    }
    self.pos += entry & 0xff
    let mode = entry >> 8
    let start = if a0 > 0 { a0 } else { 0 }
    match mode {
      0 => a0 = b2 // pass
      1 => {
        // horizontal
        let r1 = self.run(color)
        let r2 = self.run(1 - color)
        let a1 = Int::min(start + r1, w)
        a0 = Int::min(a1 + r2, w)
        cur.push(a1)
        cur.push(a0)
      }
      _ => {
        let delta = match mode {
          2 => 0
          3 => 1
          4 => 2
          5 => 3
          6 => -1
          7 => -2
          8 => -3
          _ => raise InvalidStream("invalid or unsupported MMR code")
        }
        let a1 = b1 + delta
        if a1 < start {
          raise InvalidStream("invalid MMR data")
        }
        let a1 = Int::min(a1, w)
        cur.push(a1)
        a0 = a1
        color = 1 - color
      }
    }
    steps += 1
  }
}

///|
// Decode a w×h MMR coded bitmap. An end-of-facsimile-block code before the
// last row leaves the remaining rows white; one right after the last row is
// consumed. It returns the bitmap and the number of bytes used.
fn PdfJbig2Decoder::decode_mmr(
  self : PdfJbig2Decoder,
  data : Bytes,
  w : Int,
  h : Int,
) -> (PdfJbig2Bitmap, Int) raise PdfStreamError {
  let bm = self.new_bitmap(w, h)
  let reader : PdfJbig2MmrReader = { data, pos: 0 }
  let reference : Array[Int] = [w, w, w]
  let cur : Array[Int] = []
  for y in 0..<h {
    if reader.peek(24) == pdf_jbig2_eofb {
      reader.pos += 24
      return (bm, (reader.pos + 7) >> 3)
    }
    cur.clear()
    reader.line(reference, cur, w)
    let base = y * bm.stride
    let mut k = 0
    while k < cur.length() {
      let end = if k + 1 < cur.length() { cur[k + 1] } else { w }
      pdf_jbig2_fill_span(bm.data, base, cur[k], end)
      k += 2
    }
    // The new line becomes the reference line, without empty runs.
    reference.clear()
    for c in cur {
      if reference.length() > 0 && reference[reference.length() - 1] == c {
        let _ = reference.pop()
      } else {
        reference.push(c)
      }
    }
    reference.push(w)
    reference.push(w)
    reference.push(w)
  }
  if reader.peek(24) == pdf_jbig2_eofb {
    reader.pos += 24
  }
  (bm, Int::min((reader.pos + 7) >> 3, data.length()))
}
