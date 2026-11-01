///|
fn psd_clamp8(value : Double) -> Int32 {
  if value <= 0.0 {
    0
  } else if value >= 255.0 {
    255
  } else {
    value.round().to_int()
  }
}

///|
fn psd_unmatte(value : Int32, matte : Double, alpha : Int32) -> Int32 {
  let a = alpha.to_double() / 255.0
  if a == 0.0 {
    matte.to_int()
  } else if a < 1.0 {
    psd_clamp8((value.to_double() - matte * (1.0 - a)) / a)
  } else {
    value
  }
}

///|
fn psd_lab_to_rgb(l8 : Int32, a8 : Int32, b8 : Int32) -> (Int32, Int32, Int32) {
  let l = l8.to_double() * 100.0 / 255.0
  let a = a8.to_double() - 128.0
  let b = b8.to_double() - 128.0
  let fy = (l + 16.0) / 116.0
  let fx = fy + a / 500.0
  let fz = fy - b / 200.0
  let inv = fn(t : Double) -> Double {
    if t > 6.0 / 29.0 {
      t * t * t
    } else {
      3.0 * (6.0 / 29.0) * (6.0 / 29.0) * (t - 4.0 / 29.0)
    }
  }
  let x = 0.9642 * inv(fx)
  let y = inv(fy)
  let z = 0.8249 * inv(fz)
  let rl = 3.1338561 * x - 1.6168667 * y - 0.4906146 * z
  let gl = -0.9787684 * x + 1.9161415 * y + 0.0334540 * z
  let bl = 0.0719453 * x - 0.2289914 * y + 1.4052427 * z
  (
    psd_float_sample(rl, true),
    psd_float_sample(gl, true),
    psd_float_sample(bl, true),
  )
}

///|
fn psd_to_rgba(file : PsdFile, planes : Array[Bytes]) -> Bytes {
  let header = file.header
  let base = psd_base_channels(header)
  let count = header.width.to_int64() * header.height.to_int64()
  let out : FixedArray[Byte] = FixedArray::make(
    (count * 4L).to_int(),
    (0).to_byte(),
  )
  let alpha = if planes.length() > base && file.global_alpha {
    Some(planes[base])
  } else {
    None
  }
  let mut transparent = -1
  if header.mode == PSD_MODE_INDEXED {
    match file.resources.get(PSD_TRANSPARENCY) {
      Some(data) =>
        if data.length() >= 2 {
          transparent = (data[0].to_int() << 8) | data[1].to_int()
        }
      None => ()
    }
  }
  for index in 0..<count.to_int() {
    let a = match alpha {
      Some(values) => values[index].to_int()
      None => 255
    }
    let mut red = 0
    let mut green = 0
    let mut blue = 0
    let mut out_alpha = a
    match header.mode {
      PSD_MODE_RGB => {
        red = psd_unmatte(planes[0][index].to_int(), 255.0, a)
        green = psd_unmatte(planes[1][index].to_int(), 255.0, a)
        blue = psd_unmatte(planes[2][index].to_int(), 255.0, a)
      }
      PSD_MODE_CMYK => {
        let k = psd_unmatte(planes[3][index].to_int(), 255.0, a)
        red = (psd_unmatte(planes[0][index].to_int(), 255.0, a) * k + 127) / 255
        green = (psd_unmatte(planes[1][index].to_int(), 255.0, a) * k + 127) /
          255
        blue = (psd_unmatte(planes[2][index].to_int(), 255.0, a) * k + 127) /
          255
      }
      PSD_MODE_LAB => {
        let l = psd_unmatte(planes[0][index].to_int(), 255.0, a)
        let aa = psd_unmatte(planes[1][index].to_int(), 128.0, a)
        let bb = psd_unmatte(planes[2][index].to_int(), 128.0, a)
        let (r, g, b) = psd_lab_to_rgb(l, aa, bb)
        red = r
        green = g
        blue = b
      }
      PSD_MODE_INDEXED => {
        let value = planes[0][index].to_int()
        if file.palette.length() >= 768 {
          red = file.palette[value].to_int()
          green = file.palette[256 + value].to_int()
          blue = file.palette[512 + value].to_int()
        }
        if value == transparent {
          out_alpha = 0
        }
      }
      _ => {
        let gray = psd_unmatte(planes[0][index].to_int(), 255.0, a)
        red = gray
        green = gray
        blue = gray
      }
    }
    let at = index * 4
    out[at] = psd_clamp8(red.to_double()).to_byte()
    out[at + 1] = psd_clamp8(green.to_double()).to_byte()
    out[at + 2] = psd_clamp8(blue.to_double()).to_byte()
    out[at + 3] = psd_clamp8(out_alpha.to_double()).to_byte()
  }
  Bytes::from_array(out)
}
