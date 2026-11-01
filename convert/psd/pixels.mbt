///|
priv struct PsdPlaneSpec {
  width : Int32
  height : Int32
  depth : Int32
  psb : Bool
  linear : Bool
}

///|
fn psd_row_bytes(width : Int32, depth : Int32) -> Int32 {
  (width * depth + 7) / 8
}

///|
fn psd_float_sample(value : Double, linear : Bool) -> Int32 {
  if !(value > 0.0) {
    return 0
  }
  if value >= 1.0 {
    return 255
  }
  let mut sample = value
  if linear {
    if sample <= 0.0031308 {
      sample = sample * 12.92
    } else {
      sample = 1.055 * @math.pow(sample, 1.0 / 2.4) - 0.055
    }
  }
  let scaled = (sample * 255.0).round().to_int()
  if scaled < 0 {
    0
  } else if scaled > 255 {
    255
  } else {
    scaled
  }
}

///|
fn psd_decode_rows(spec : PsdPlaneSpec, raw : Bytes) -> Bytes {
  let count = spec.width.to_int64() * spec.height.to_int64()
  let out : FixedArray[Byte] = FixedArray::make(count.to_int(), (0).to_byte())
  let row_bytes = psd_row_bytes(spec.width, spec.depth)
  for y in 0..<spec.height {
    let row = y * row_bytes
    for x in 0..<spec.width {
      let value = match spec.depth {
        1 => {
          let byte = raw[row + x / 8].to_int()
          if (byte & (0x80 >> (x % 8))) == 0 {
            255
          } else {
            0
          }
        }
        8 => raw[row + x].to_int()
        16 => {
          let high = raw[row + 2 * x].to_int()
          let low = raw[row + 2 * x + 1].to_int()
          (((high << 8) | low) * 255 + 32767) / 65535
        }
        32 => {
          let at = row + 4 * x
          let bits = (raw[at].to_int64() << 24) |
            (raw[at + 1].to_int64() << 16) |
            (raw[at + 2].to_int64() << 8) |
            raw[at + 3].to_int64()
          psd_float_sample(
            Float::reinterpret_from_uint(bits.to_int().to_uint()).to_double(),
            spec.linear,
          )
        }
        _ => 0
      }
      out[(y.to_int64() * spec.width.to_int64() + x.to_int64()).to_int()] = value.to_byte()
    }
  }
  Bytes::from_array(out)
}

///|
fn psd_pack_bits(
  src : Bytes,
  dst : FixedArray[Byte],
  base : Int32,
  need : Int32,
) -> Bool {
  let mut i = 0
  let mut o = 0
  while o < need {
    if i >= src.length() {
      return false
    }
    let control = src[i].to_int()
    let signed = if control >= 128 { control - 256 } else { control }
    i += 1
    if signed >= 0 {
      let count = signed + 1
      if i + count > src.length() || o + count > need {
        return false
      }
      for k in 0..<count {
        dst[base + o + k] = src[i + k]
      }
      i += count
      o += count
    } else if signed > -128 {
      if i >= src.length() || o + 1 - signed > need {
        return false
      }
      for k in 0..<(1 - signed) {
        dst[base + o + k] = src[i]
      }
      i += 1
      o += 1 - signed
    }
  }
  true
}

///|
fn psd_inflate(data : Bytes, want : Int32) -> Bytes? {
  if want < 0 {
    return None
  }
  let decoded = @zlib.decompress(data, max_output=want) catch { _ => b"" }
  if decoded.length() < want {
    None
  } else {
    Some(decoded[:want].to_owned())
  }
}

///|
fn psd_unpredict(spec : PsdPlaneSpec, raw : FixedArray[Byte]) -> Unit {
  let row_bytes = psd_row_bytes(spec.width, spec.depth)
  for y in 0..<spec.height {
    let row = y * row_bytes
    match spec.depth {
      8 =>
        for x in 1..<row_bytes {
          raw[row + x] = (raw[row + x].to_int() + raw[row + x - 1].to_int()).to_byte()
        }
      16 =>
        for x in 2..<row_bytes {
          if x % 2 == 0 {
            let value = (
                (raw[row + x].to_int() << 8) | raw[row + x + 1].to_int()
              ) +
              ((raw[row + x - 2].to_int() << 8) | raw[row + x - 1].to_int())
            raw[row + x] = ((value >> 8) & 0xff).to_byte()
            raw[row + x + 1] = (value & 0xff).to_byte()
          }
        }
      32 => {
        for x in 1..<row_bytes {
          raw[row + x] = (raw[row + x].to_int() + raw[row + x - 1].to_int()).to_byte()
        }
        let temp : FixedArray[Byte] = FixedArray::make(row_bytes, (0).to_byte())
        for x in 0..<spec.width {
          for b in 0..<4 {
            temp[4 * x + b] = raw[row + b * spec.width + x]
          }
        }
        for x in 0..<row_bytes {
          raw[row + x] = temp[x]
        }
      }
      _ => ()
    }
  }
}

///|
fn psd_read_planes(file : PsdFile) -> Array[Bytes] raise PsdError {
  let header = file.header
  let pixels = header.width.to_int64() * header.height.to_int64()
  if pixels > PSD_MAX_PIXELS {
    raise PsdInvalid("psd: the image is too large to decode")
  }
  let base = psd_base_channels(header)
  let alpha = file.global_alpha &&
    header.channels > base &&
    header.mode != PSD_MODE_MULTICHANNEL
  let count = base + (if alpha { 1 } else { 0 })
  let row_bytes = psd_row_bytes(header.width, header.depth)
  let cursor = {
    data: file.data,
    off: file.image_data,
    end: file.data.length(),
    failed: false,
  }
  let compression = cursor.u16()
  if cursor.failed {
    raise PsdInvalid("psd: image data is missing")
  }
  let spec = fn(index : Int32) -> PsdPlaneSpec {
    {
      width: header.width,
      height: header.height,
      depth: header.depth,
      psb: header.psb,
      linear: index < base && header.mode != PSD_MODE_INDEXED,
    }
  }
  let planes : Array[Bytes] = []
  match compression {
    0 =>
      for index in 0..<count {
        let raw = cursor.bytes(row_bytes * header.height)
        if cursor.failed {
          raise PsdInvalid("psd: image data is too short")
        }
        planes.push(psd_decode_rows(spec(index), raw))
      }
    1 => {
      let count_width = if header.psb { 4 } else { 2 }
      let counts = cursor.bytes(count_width * header.height * header.channels)
      if cursor.failed {
        raise PsdInvalid("psd: RLE row counts are missing")
      }
      for index in 0..<count {
        let mut total = 0L
        for y in 0..<header.height {
          let at = (index * header.height + y) * count_width
          let value = if count_width == 4 {
            psd_be32(counts, at)
          } else {
            (counts[at].to_int64() << 8) | counts[at + 1].to_int64()
          }
          total += value
        }
        if total < 0L || total > cursor.left().to_int64() {
          raise PsdInvalid("psd: RLE data is too short")
        }
        let data = cursor.bytes(total.to_int())
        let raw : FixedArray[Byte] = FixedArray::make(
          row_bytes * header.height,
          (0).to_byte(),
        )
        let mut offset = 0
        for y in 0..<header.height {
          let at = (index * header.height + y) * count_width
          let length = if count_width == 4 {
            psd_be32(counts, at).to_int()
          } else {
            (counts[at].to_int() << 8) | counts[at + 1].to_int()
          }
          if length < 0 || offset + length > data.length() {
            raise PsdInvalid("psd: RLE data is too short")
          }
          let ok = psd_pack_bits(
            data[offset:offset + length].to_owned(),
            raw,
            y * row_bytes,
            row_bytes,
          )
          if !ok {
            raise PsdInvalid("psd: malformed RLE data")
          }
          offset += length
        }
        planes.push(psd_decode_rows(spec(index), Bytes::from_array(raw)))
      }
    }
    2 | 3 => {
      let want = row_bytes.to_int64() *
        header.height.to_int64() *
        count.to_int64()
      if want > 2147483647L {
        raise PsdInvalid("psd: the image is too large to decompress")
      }
      let data = cursor.bytes(cursor.left())
      let raw = psd_inflate(data, want.to_int()) catch { _ => None }
      let raw = match raw {
        Some(value) => value
        None => raise PsdInvalid("psd: malformed ZIP image data")
      }
      let plane_size = row_bytes * header.height
      for index in 0..<count {
        let part = raw[index * plane_size:(index + 1) * plane_size]
        let samples : FixedArray[Byte] = part.to_fixedarray()
        if compression == 3 {
          psd_unpredict(spec(index), samples)
        }
        planes.push(psd_decode_rows(spec(index), Bytes::from_array(samples)))
      }
    }
    _ => raise PsdInvalid("psd: unknown image compression \{compression}")
  }
  planes
}
