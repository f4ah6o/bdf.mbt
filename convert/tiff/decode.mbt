///|
priv struct TiffLayout {
  width : Int32
  height : Int32
  samples : Int32
  bits : Int32
  photo : Int32
  compression : Int32
  planar : Int32
  predictor : Int32
  fill : Int32
  ncolor : Int32
  alpha : Int32
  tiled : Bool
  block_width : Int32
  block_height : Int32
  across : Int32
  down : Int32
  offsets : Array[Int64]
  counts : Array[Int64]
  two_d : Bool
}

///|
fn tiff_zeroes(count : Int32) -> FixedArray[Byte] {
  FixedArray::make(count, (0).to_byte())
}

///|
fn tiff_zero_bytes(count : Int32) -> Bytes {
  Bytes::from_array(tiff_zeroes(count)[:])
}

///|
fn tiff_clamp_byte(value : Int32) -> Byte {
  if value > 255 {
    (255).to_byte()
  } else if value < 0 {
    0
  } else {
    value.to_byte()
  }
}

///|
fn tiff_layout(ifd : TiffIfd, data : Bytes) -> TiffLayout raise TiffError {
  let (width, height) = ifd.size()
  if width <= 0 || height <= 0 {
    raise TiffInvalid("TIFF: the image has no size")
  }
  let pixels = width.to_int64() * height.to_int64()
  if pixels > TIFF_MAX_PIXELS {
    raise TiffInvalid(
      "TIFF: a \{width}×\{height} image is too large to decode",
    )
  }
  let photo = ifd.photometric()
  let compression = ifd.compression()
  if compression == TIFF_COMPRESSION_JPEG {
    raise TiffInvalid("TIFF: JPEG-compressed pages are not supported")
  }
  let samples = ifd.uint(TIFF_TAG_SAMPLES_PER_PIXEL, 1L).to_int()
  if samples < 1 || samples > 16 {
    raise TiffInvalid("TIFF: \{samples} samples per pixel")
  }
  let bits_values = ifd.uints(TIFF_TAG_BITS_PER_SAMPLE)
  let mut bits = 1
  if !bits_values.is_empty() {
    bits = bits_values[0].to_int()
    for value in bits_values {
      if value.to_int() != bits {
        raise TiffInvalid("TIFF: samples of different sizes")
      }
    }
  }
  match bits {
    1 | 2 | 4 | 8 | 16 => ()
    _ => raise TiffInvalid("TIFF: \{bits} bits per sample")
  }
  if ifd.uint(TIFF_TAG_SAMPLE_FORMAT, 1L) != 1L {
    raise TiffInvalid("TIFF: only unsigned integer samples are supported")
  }
  let mut planar = ifd.uint(TIFF_TAG_PLANAR_CONFIG, 1L).to_int()
  if samples == 1 {
    planar = 1
  }
  if planar != 1 && planar != 2 {
    raise TiffInvalid("TIFF: planar configuration \{planar}")
  }
  let predictor = ifd.uint(TIFF_TAG_PREDICTOR, 1L).to_int()
  if predictor != 1 {
    if predictor != 2 || (bits != 8 && bits != 16) {
      raise TiffInvalid(
        "TIFF: predictor \{predictor} with \{bits} bits per sample",
      )
    }
  }
  let fill = ifd.uint(TIFF_TAG_FILL_ORDER, 1L).to_int()
  let ncolor = match photo {
    TIFF_WHITE_IS_ZERO | TIFF_BLACK_IS_ZERO => 1
    TIFF_RGB => 3
    TIFF_PALETTE => {
      if bits > 8 {
        raise TiffInvalid("TIFF: 16-bit palette")
      }
      if ifd.uints(TIFF_TAG_COLOR_MAP).length() < 3 << bits {
        raise TiffInvalid("TIFF: palette image without a colour map")
      }
      1
    }
    TIFF_SEPARATED => {
      if ifd.uint(TIFF_TAG_INK_SET, 1L) != 1L {
        raise TiffInvalid("TIFF: inks other than CMYK")
      }
      4
    }
    TIFF_YCBCR =>
      raise TiffInvalid("TIFF: YCbCr pixels outside JPEG are not supported")
    _ => raise TiffInvalid("TIFF: photometric interpretation \{photo}")
  }
  if samples < ncolor {
    raise TiffInvalid(
      "TIFF: \{samples} samples per pixel for photometric interpretation \{photo}",
    )
  }
  let mut alpha = 0
  if samples > ncolor && photo != TIFF_PALETTE && photo != TIFF_SEPARATED {
    let extra = ifd.uints(TIFF_TAG_EXTRA_SAMPLES)
    if !extra.is_empty() && (extra[0] == 1L || extra[0] == 2L) {
      alpha = extra[0].to_int()
    }
  }
  let tiled = ifd.has(TIFF_TAG_TILE_WIDTH)
  let mut block_width = width
  let mut block_height = height
  let mut offsets_tag = TIFF_TAG_STRIP_OFFSETS
  let mut counts_tag = TIFF_TAG_STRIP_BYTE_COUNTS
  if tiled {
    block_width = ifd.uint(TIFF_TAG_TILE_WIDTH, 0L).to_int()
    block_height = ifd.uint(TIFF_TAG_TILE_LENGTH, 0L).to_int()
    offsets_tag = TIFF_TAG_TILE_OFFSETS
    counts_tag = TIFF_TAG_TILE_BYTE_COUNTS
    if block_width <= 0 ||
      block_height <= 0 ||
      block_width > 1073741824 ||
      block_height > 1073741824 {
      raise TiffInvalid("TIFF: bad tile size")
    }
  } else {
    block_height = ifd.uint(TIFF_TAG_ROWS_PER_STRIP, height.to_int64()).to_int()
    if block_height <= 0 {
      block_height = height
    }
    if block_height > height {
      block_height = height
    }
  }
  let across = (width + block_width - 1) / block_width
  let down = (height + block_height - 1) / block_height
  let samples_per_block = if planar == 2 { 1 } else { samples }
  let row_bytes = (block_width * samples_per_block * bits + 7) / 8
  if row_bytes.to_int64() * block_height.to_int64() > TIFF_MAX_DECODE_BYTES {
    raise TiffInvalid("TIFF: the tiles are too large to decode")
  }
  let mut blocks = across.to_int64() * down.to_int64()
  if planar == 2 {
    blocks = blocks * samples.to_int64()
  }
  if blocks > 67108864L {
    raise TiffInvalid("TIFF: too many strips or tiles")
  }
  let offsets_values = ifd.uints(offsets_tag)
  let counts_values = ifd.uints(counts_tag)
  if offsets_values.length().to_int64() < blocks {
    raise TiffInvalid(
      "TIFF: \{offsets_values.length()} strips or tiles for \{blocks}",
    )
  }
  let mut counts = counts_values
  if counts.length().to_int64() < blocks {
    if blocks == 1L && compression == TIFF_COMPRESSION_NONE {
      counts = [row_bytes.to_int64() * block_height.to_int64()]
    } else {
      raise TiffInvalid("TIFF: missing strip or tile byte counts")
    }
  }
  let offsets = offsets_values[:blocks.to_int()].to_array()
  let counts = counts[:blocks.to_int()].to_array()
  let file_size = data.length().to_int64()
  let mut stored = 0L
  for i in 0..<offsets.length() {
    let offset = offsets[i]
    let count = counts[i]
    if offset >= 0L && offset < file_size {
      let available = file_size - offset
      stored += if count < available { count } else { available }
    }
  }
  let decoded = row_bytes.to_int64() *
    block_height.to_int64() *
    across.to_int64() *
    down.to_int64() *
    (if planar == 2 { samples.to_int64() } else { 1L })
  if decoded > stored * TIFF_MAX_RATIO + TIFF_DECODE_SLACK {
    raise TiffInvalid(
      "TIFF: \{stored} bytes of pixel data for a \{width}×\{height} image",
    )
  }
  {
    width,
    height,
    samples,
    bits,
    photo,
    compression,
    planar,
    predictor,
    fill,
    ncolor,
    alpha,
    tiled,
    block_width,
    block_height,
    across,
    down,
    offsets,
    counts,
    two_d: (ifd.uint(TIFF_TAG_T4_OPTIONS, 0L) & 1L) != 0L,
  }
}

///|
fn tiff_row_bytes(layout : TiffLayout) -> Int32 {
  let samples = if layout.planar == 2 { 1 } else { layout.samples }
  (layout.block_width * samples * layout.bits + 7) / 8
}

///|
fn tiff_block_rows(layout : TiffLayout, by : Int32) -> Int32 {
  if layout.tiled {
    return layout.block_height
  }
  let left = layout.height - by * layout.block_height
  if left < layout.block_height {
    left
  } else {
    layout.block_height
  }
}

///|
fn tiff_reverse_bits(data : Bytes) -> Bytes {
  let out : FixedArray[Byte] = FixedArray::make(data.length(), 0)
  for i in 0..<data.length() {
    let value = data[i].to_int()
    let mut reversed = 0
    for bit in 0..<8 {
      reversed = (reversed << 1) | ((value >> bit) & 1)
    }
    out[i] = reversed.to_byte()
  }
  Bytes::from_array(out)
}

///|
fn tiff_packbits(src : Bytes, need : Int32) -> Bytes {
  let out = @buffer.Buffer()
  let mut i = 0
  while i < src.length() && out.length() < need {
    let control = src[i].to_int()
    let signed = if control >= 128 { control - 256 } else { control }
    i += 1
    if signed >= 0 {
      let count = signed + 1
      let end = if i + count < src.length() { i + count } else { src.length() }
      out.write_bytes(src[i:end])
      i = end
    } else if signed != -128 && i < src.length() {
      for _ in 0..<(1 - signed) {
        out.write_byte(src[i])
      }
      i += 1
    }
  }
  let bytes = out.to_bytes()
  let result : FixedArray[Byte] = tiff_zeroes(need)
  for i in 0..<bytes.length() {
    if i >= need {
      break
    }
    result[i] = bytes[i]
  }
  Bytes::from_array(result)
}

///|
fn tiff_read_block(
  layout : TiffLayout,
  data : Bytes,
  index : Int32,
  rows : Int32,
) -> (Bytes, Bool) raise TiffError {
  let need = tiff_row_bytes(layout) * rows
  if index < 0 || index >= layout.offsets.length() {
    return (tiff_zero_bytes(need), true)
  }
  let offset = layout.offsets[index]
  let count = layout.counts[index]
  if offset < 0L || offset >= data.length().to_int64() || count <= 0L {
    return (tiff_zero_bytes(need), true)
  }
  let available = data.length().to_int64() - offset
  let length = if count < available { count } else { available }
  if length <= 0L {
    return (tiff_zero_bytes(need), true)
  }
  let src = data[offset.to_int():offset.to_int() + length.to_int()].to_owned()
  let mut damaged = false
  let raw = match layout.compression {
    TIFF_COMPRESSION_CCITT_RLE => {
      let (bytes, bad) = tiff_decode_ccitt(
        src,
        TIFF_COMPRESSION_CCITT_RLE,
        false,
        layout.fill == 2,
        layout.block_width,
        rows,
      )
      damaged = bad
      bytes
    }
    TIFF_COMPRESSION_G3 => {
      let (bytes, bad) = tiff_decode_ccitt(
        src,
        TIFF_COMPRESSION_G3,
        layout.two_d,
        layout.fill == 2,
        layout.block_width,
        rows,
      )
      damaged = bad
      bytes
    }
    TIFF_COMPRESSION_G4 => {
      let (bytes, bad) = tiff_decode_ccitt(
        src,
        TIFF_COMPRESSION_G4,
        false,
        layout.fill == 2,
        layout.block_width,
        rows,
      )
      damaged = bad
      bytes
    }
    _ => {
      let body = if layout.fill == 2 { tiff_reverse_bits(src) } else { src }
      match layout.compression {
        TIFF_COMPRESSION_NONE => {
          let out : FixedArray[Byte] = tiff_zeroes(need)
          let take = if body.length() < need { body.length() } else { need }
          for i in 0..<take {
            out[i] = body[i]
          }
          if take < need {
            damaged = true
          }
          Bytes::from_array(out)
        }
        TIFF_COMPRESSION_PACKBITS => tiff_packbits(body, need)
        TIFF_COMPRESSION_LZW => {
          let decoded = tiff_lzw_decode(body, need)
          if decoded.length() < need {
            damaged = true
          }
          decoded
        }
        TIFF_COMPRESSION_DEFLATE | TIFF_COMPRESSION_DEFLATE_OLD => {
          let decoded = @zlib.decompress(body, max_output=need) catch {
            _ => b""
          }
          let out : FixedArray[Byte] = tiff_zeroes(need)
          for i in 0..<decoded.length() {
            if i >= need {
              break
            }
            out[i] = decoded[i]
          }
          if decoded.length() < need {
            damaged = true
          }
          Bytes::from_array(out)
        }
        _ =>
          raise TiffInvalid(
            "TIFF: compression \{layout.compression} is not supported",
          )
      }
    }
  }
  if raw.length() >= need {
    (raw[:need].to_owned(), damaged)
  } else {
    let out : FixedArray[Byte] = tiff_zeroes(need)
    for i in 0..<raw.length() {
      out[i] = raw[i]
    }
    (Bytes::from_array(out), true)
  }
}

///|
fn tiff_unpredict(
  layout : TiffLayout,
  raw : FixedArray[Byte],
  rows : Int32,
  big : Bool,
) -> Unit {
  if layout.predictor != 2 {
    return
  }
  let samples = if layout.planar == 2 { 1 } else { layout.samples }
  let row_bytes = tiff_row_bytes(layout)
  let count = layout.block_width * samples
  for row in 0..<rows {
    let start = row * row_bytes
    if layout.bits == 8 {
      for i in samples..<count {
        let at = start + i
        let left = start + i - samples
        raw[at] = (raw[at].to_int() + raw[left].to_int()).to_byte()
      }
    } else {
      for i in samples..<count {
        let at = start + i * 2
        let left = start + (i - samples) * 2
        let value = tiff_read_u16(raw, at, big) + tiff_read_u16(raw, left, big)
        tiff_write_u16(raw, at, value, big)
      }
    }
  }
}

///|
fn tiff_read_u16(data : FixedArray[Byte], offset : Int32, big : Bool) -> Int32 {
  if offset < 0 || offset + 2 > data.length() {
    return 0
  }
  if big {
    (data[offset].to_int() << 8) | data[offset + 1].to_int()
  } else {
    data[offset].to_int() | (data[offset + 1].to_int() << 8)
  }
}

///|
fn tiff_write_u16(
  data : FixedArray[Byte],
  offset : Int32,
  value : Int32,
  big : Bool,
) -> Unit {
  if offset < 0 || offset + 2 > data.length() {
    return
  }
  if big {
    data[offset] = ((value >> 8) & 0xff).to_byte()
    data[offset + 1] = (value & 0xff).to_byte()
  } else {
    data[offset] = (value & 0xff).to_byte()
    data[offset + 1] = ((value >> 8) & 0xff).to_byte()
  }
}

///|
fn tiff_unpack_row(
  dst : FixedArray[Byte],
  row : FixedArray[Byte],
  base : Int32,
  bits : Int32,
  count : Int32,
  big : Bool,
) -> Unit {
  match bits {
    8 =>
      for i in 0..<count {
        dst[i] = row[base + i]
      }
    16 => {
      let high = if big { 0 } else { 1 }
      for i in 0..<count {
        dst[i] = row[base + 2 * i + high]
      }
    }
    _ => {
      let mask = (1 << bits) - 1
      for i in 0..<count {
        let bit = i * bits
        let value = (row[base + bit / 8].to_int() >> (8 - bits - bit % 8)) &
          mask
        dst[i] = value.to_byte()
      }
    }
  }
}

///|
fn tiff_gray_scale(bits : Int32, value : Int32) -> Int32 {
  match bits {
    1 => value * 255
    2 => value * 85
    4 => value * 17
    16 => value
    _ => value
  }
}

///|
fn tiff_palette(
  ifd : TiffIfd,
  layout : TiffLayout,
) -> Array[(Int32, Int32, Int32)] {
  let size = 1 << layout.bits
  let map = ifd.uints(TIFF_TAG_COLOR_MAP)
  let out : Array[(Int32, Int32, Int32)] = []
  for i in 0..<size {
    let red = if i < map.length() { (map[i] >> 8).to_int() } else { 0 }
    let green = if size + i < map.length() {
      (map[size + i] >> 8).to_int()
    } else {
      0
    }
    let blue = if 2 * size + i < map.length() {
      (map[2 * size + i] >> 8).to_int()
    } else {
      0
    }
    out.push((red, green, blue))
  }
  out
}

///|
fn tiff_decode(ifd : TiffIfd, data : Bytes) -> (Bytes, Bool) raise TiffError {
  let layout = tiff_layout(ifd, data)
  let pixel_count = layout.width.to_int64() * layout.height.to_int64()
  let values_count = pixel_count * layout.samples.to_int64()
  if values_count > TIFF_MAX_DECODE_BYTES {
    raise TiffInvalid("TIFF: the image is too large to decode")
  }
  let samples : FixedArray[Byte] = FixedArray::make(
    values_count.to_int(),
    (0).to_byte(),
  )
  let mut damaged = false
  let planes = if layout.planar == 2 { layout.samples } else { 1 }
  let block_samples = if layout.planar == 2 { 1 } else { layout.samples }
  let vals : FixedArray[Byte] = FixedArray::make(
    layout.block_width * block_samples,
    0,
  )
  for plane in 0..<planes {
    for by in 0..<layout.down {
      for bx in 0..<layout.across {
        let index = if layout.planar == 2 {
          (plane * layout.down + by) * layout.across + bx
        } else {
          by * layout.across + bx
        }
        let rows = tiff_block_rows(layout, by)
        let (raw_bytes, bad) = tiff_read_block(layout, data, index, rows)
        if bad {
          damaged = true
        }
        let raw : FixedArray[Byte] = raw_bytes.to_fixedarray()
        tiff_unpredict(layout, raw, rows, ifd.big_endian)
        let row_bytes = tiff_row_bytes(layout)
        let x0 = bx * layout.block_width
        let y0 = by * layout.block_height
        let cols = if layout.width - x0 < layout.block_width {
          layout.width - x0
        } else {
          layout.block_width
        }
        let row_count = if layout.height - y0 < rows {
          layout.height - y0
        } else {
          rows
        }
        for row in 0..<row_count {
          let count = cols * block_samples
          tiff_unpack_row(
            vals,
            raw,
            row * row_bytes,
            layout.bits,
            count,
            ifd.big_endian,
          )
          let y = y0 + row
          for x in 0..<cols {
            let pixel = (y.to_int64() * layout.width.to_int64() +
            (x0 + x).to_int64()).to_int()
            if layout.planar == 2 {
              samples[pixel * layout.samples + plane] = vals[x]
            } else {
              for k in 0..<layout.samples {
                samples[pixel * layout.samples + k] = vals[x * block_samples + k]
              }
            }
          }
        }
      }
    }
  }
  (tiff_pixels(ifd, layout, samples), damaged)
}

///|
fn tiff_pixels(
  ifd : TiffIfd,
  layout : TiffLayout,
  samples : FixedArray[Byte],
) -> Bytes {
  let count = layout.width.to_int64() * layout.height.to_int64()
  let out : FixedArray[Byte] = FixedArray::make(
    (count * 4L).to_int(),
    (0).to_byte(),
  )
  let palette = if layout.photo == TIFF_PALETTE {
    tiff_palette(ifd, layout)
  } else {
    []
  }
  let white_is_zero = layout.photo == TIFF_WHITE_IS_ZERO
  for index in 0..<count.to_int() {
    let base = index * layout.samples
    let mut red = 0
    let mut green = 0
    let mut blue = 0
    match layout.photo {
      TIFF_PALETTE => {
        let (r, g, b) = palette[samples[base].to_int()]
        red = r
        green = g
        blue = b
      }
      TIFF_SEPARATED => {
        // Go's color.CMYKToRGB, which the upstream PNG encoder applies.
        let c = samples[base].to_int()
        let m = samples[base + 1].to_int()
        let y = samples[base + 2].to_int()
        let k = samples[base + 3].to_int()
        let weight = 0xffffL - k.to_int64() * 0x101L
        red = (((0xffffL - c.to_int64() * 0x101L) * weight / 0xffffL) >> 8).to_int()
        green = (((0xffffL - m.to_int64() * 0x101L) * weight / 0xffffL) >> 8).to_int()
        blue = (((0xffffL - y.to_int64() * 0x101L) * weight / 0xffffL) >> 8).to_int()
      }
      TIFF_RGB => {
        red = samples[base].to_int()
        green = samples[base + 1].to_int()
        blue = samples[base + 2].to_int()
      }
      _ => {
        let mut gray = tiff_gray_scale(layout.bits, samples[base].to_int())
        if white_is_zero {
          gray = 255 - gray
        }
        red = gray
        green = gray
        blue = gray
      }
    }
    let mut alpha = 255
    if layout.alpha != 0 {
      alpha = tiff_gray_scale(
        layout.bits,
        samples[base + layout.ncolor].to_int(),
      )
      if layout.alpha == 1 {
        if alpha <= 0 {
          red = 0
          green = 0
          blue = 0
        } else {
          red = red * 255 / alpha
          green = green * 255 / alpha
          blue = blue * 255 / alpha
        }
      }
    }
    let at = index * 4
    out[at] = tiff_clamp_byte(red)
    out[at + 1] = tiff_clamp_byte(green)
    out[at + 2] = tiff_clamp_byte(blue)
    out[at + 3] = tiff_clamp_byte(alpha)
  }
  Bytes::from_array(out)
}

///|
fn tiff_bilevel(layout : TiffLayout) -> Bool {
  (layout.photo == TIFF_WHITE_IS_ZERO || layout.photo == TIFF_BLACK_IS_ZERO) &&
  layout.bits == 1 &&
  layout.ncolor == 1 &&
  layout.alpha == 0
}
