///|
// PDF's Flate/LZW predictors, adapted from upstream converter/pdf/flate.go.
priv suberror PdfStreamError {
  InvalidStream(String)
}

///|
priv struct PdfPredictor {
  kind : Int32
  colors : Int32
  bits : Int32
  columns : Int32
  bytes_per_pixel : Int32
  row_size : Int32
  row_length : Int32
}

///|
fn pdf_predictor(
  predictor : Int32,
  colors : Int32,
  bits : Int32,
  columns : Int32,
  input_size : Int32,
) -> PdfPredictor raise PdfStreamError {
  if predictor <= 1 {
    return {
      kind: 0,
      colors,
      bits,
      columns,
      bytes_per_pixel: 0,
      row_size: 0,
      row_length: 0,
    }
  }
  if columns < 1 || columns > 16777216 {
    raise InvalidStream("predictor columns")
  }
  if colors < 1 || colors > 32 {
    raise InvalidStream("predictor colors")
  }
  if ![1, 2, 4, 8, 16].contains(bits) {
    raise InvalidStream("predictor bits per component")
  }
  let row_size = (bits.to_int64() * colors.to_int64() * columns.to_int64() + 7L) /
    8L
  if row_size > 1032L * input_size.to_int64() + 64L {
    raise InvalidStream("predictor row too large")
  }
  let kind = if predictor == 2 {
    1
  } else if predictor >= 10 && predictor <= 15 {
    2
  } else {
    raise InvalidStream("invalid predictor")
  }
  let row_size = row_size.to_int()
  {
    kind,
    colors,
    bits,
    columns,
    bytes_per_pixel: (bits * colors + 7) / 8,
    row_size,
    row_length: row_size + (if kind == 2 { 1 } else { 0 }),
  }
}

///|
fn PdfPredictor::undo(
  self : PdfPredictor,
  raw : Bytes,
) -> Bytes raise PdfStreamError {
  if self.kind == 0 {
    return raw
  }
  let rows = raw.length() / self.row_length
  let result : Array[Byte] = []
  for row in 0..<rows {
    let start = row * self.row_length
    let output_start = result.length()
    let filter = if self.kind == 2 { raw[start].to_int() } else { 0 }
    if self.kind == 2 && filter > 4 {
      raise InvalidStream("invalid PNG predictor filter")
    }
    let source_start = start + (if self.kind == 2 { 1 } else { 0 })
    for i in 0..<self.row_size {
      result.push(raw[source_start + i])
    }
    if self.kind == 1 {
      self.undo_tiff(result, output_start)
    } else {
      for i in 0..<self.row_size {
        let left = if i >= self.bytes_per_pixel {
          result[output_start + i - self.bytes_per_pixel].to_int()
        } else {
          0
        }
        let above = if row > 0 {
          result[output_start - self.row_size + i].to_int()
        } else {
          0
        }
        let corner = if row > 0 && i >= self.bytes_per_pixel {
          result[output_start - self.row_size + i - self.bytes_per_pixel].to_int()
        } else {
          0
        }
        let delta = match filter {
          0 => 0
          1 => left
          2 => above
          3 => (left + above) / 2
          4 => pdf_paeth(left, above, corner)
          _ => 0
        }
        result[output_start + i] = ((result[output_start + i].to_int() + delta) &
        255).to_byte()
      }
    }
  }
  Bytes::from_array(result)
}

///|
fn PdfPredictor::undo_tiff(
  self : PdfPredictor,
  row : Array[Byte],
  start : Int32,
) -> Unit {
  if self.bits == 8 {
    for i in self.colors..<self.row_size {
      row[start + i] = ((
        row[start + i].to_int() + row[start + i - self.colors].to_int()
      ) &
      255).to_byte()
    }
  } else if self.bits == 16 {
    let mut i = self.colors * 2
    while i + 1 < self.row_size {
      let v = row[start + i].to_int() * 256 + row[start + i + 1].to_int()
      let p = row[start + i - self.colors * 2].to_int() * 256 +
        row[start + i - self.colors * 2 + 1].to_int()
      let value = (v + p) & 65535
      row[start + i] = (value >> 8).to_byte()
      row[start + i + 1] = (value & 255).to_byte()
      i += 2
    }
  } else {
    let mask = (1 << self.bits) - 1
    for k in self.colors..<(self.colors * self.columns) {
      let bit = k * self.bits
      let previous = (k - self.colors) * self.bits
      let shift = 8 - self.bits - bit % 8
      let previous_shift = 8 - self.bits - previous % 8
      let old = (row[start + bit / 8].to_int() >> shift) & mask
      let before = (row[start + previous / 8].to_int() >> previous_shift) & mask
      let value = (old + before) & mask
      let keep = row[start + bit / 8].to_int() & (255 ^ (mask << shift))
      row[start + bit / 8] = (keep | (value << shift)).to_byte()
    }
  }
}

///|
fn pdf_paeth(left : Int32, above : Int32, corner : Int32) -> Int32 {
  let a = (above - corner).abs()
  let b = (left - corner).abs()
  let c = (left + above - 2 * corner).abs()
  if a <= b && a <= c {
    left
  } else if b <= c {
    above
  } else {
    corner
  }
}
