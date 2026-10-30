///|
fn xlsx_shape_pack_rgb(color : XlsxRgb, alpha : UInt32) -> UInt32 {
  let red = (xlsx_clamp_color(color.red) * 255.0).round().to_uint()
  let green = (xlsx_clamp_color(color.green) * 255.0).round().to_uint()
  let blue = (xlsx_clamp_color(color.blue) * 255.0).round().to_uint()
  (red << 24) | (green << 16) | (blue << 8) | alpha
}

///|
fn xlsx_shape_apply_lum(
  color : XlsxRgb,
  name : String,
  fraction : Double,
) -> XlsxRgb {
  let mx = Double::max(color.red, Double::max(color.green, color.blue))
  let mn = Double::min(color.red, Double::min(color.green, color.blue))
  let mut lum = (mx + mn) / 2.0
  let mut hue = 0.0
  let mut sat = 0.0
  if mx != mn {
    let delta = mx - mn
    sat = if lum > 0.5 { delta / (2.0 - mx - mn) } else { delta / (mx + mn) }
    if mx == color.red {
      hue = (color.green - color.blue) / delta
      if color.green < color.blue {
        hue += 6.0
      }
    } else if mx == color.green {
      hue = (color.blue - color.red) / delta + 2.0
    } else {
      hue = (color.red - color.green) / delta + 4.0
    }
    hue /= 6.0
  }
  lum = xlsx_clamp_color(
    if name == "lumMod" {
      lum * fraction
    } else {
      lum + fraction
    },
  )
  if sat == 0.0 {
    return { red: lum, green: lum, blue: lum, }
  }
  let q = if lum < 0.5 {
    lum * (1.0 + sat)
  } else {
    xlsx_fma(-lum, sat, lum + sat)
  }
  let p = 2.0 * lum - q
  {
    red: xlsx_clamp_color(xlsx_color_component(hue + 1.0 / 3.0, p, q)),
    green: xlsx_clamp_color(xlsx_color_component(hue, p, q)),
    blue: xlsx_clamp_color(xlsx_color_component(hue - 1.0 / 3.0, p, q)),
  }
}
