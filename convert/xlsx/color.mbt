///|
/// A resolved RGB color, with components in the range 0 to 1.
pub(all) struct XlsxRgb {
  red : Double
  green : Double
  blue : Double
}

///|
fn xlsx_clamp_color(value : Double) -> Double {
  if value.is_nan() || value < 0.0 {
    0.0
  } else if value > 1.0 {
    1.0
  } else {
    value
  }
}

///|
fn xlsx_color_component(hue : Double, p : Double, q : Double) -> Double {
  let mut t = hue
  if t < 0.0 {
    t += 1.0
  }
  if t > 1.0 {
    t -= 1.0
  }
  if t < 1.0 / 6.0 {
    xlsx_fma((q - p) * 6.0, t, p)
  } else if t < 0.5 {
    q
  } else if t < 2.0 / 3.0 {
    xlsx_fma((q - p) * (2.0 / 3.0 - t), 6.0, p)
  } else {
    p
  }
}

///|
/// Apply Excel's HLS-based tint to an RGB color.
pub fn xlsx_tint_color(color : XlsxRgb, tint : Double) -> XlsxRgb {
  let max = Double::max(color.red, Double::max(color.green, color.blue))
  let min = Double::min(color.red, Double::min(color.green, color.blue))
  let mut l = (max + min) / 2.0
  let mut h = 0.0
  let mut s = 0.0
  if max != min {
    let d = max - min
    s = if l > 0.5 { d / (2.0 - max - min) } else { d / (max + min) }
    if max == color.red {
      h = (color.green - color.blue) / d
      if color.green < color.blue {
        h += 6.0
      }
    } else if max == color.green {
      h = (color.blue - color.red) / d + 2.0
    } else {
      h = (color.red - color.green) / d + 4.0
    }
    h /= 6.0
  }
  l = xlsx_clamp_color(
    if tint < 0.0 {
      l * (1.0 + tint)
    } else {
      xlsx_fma(l, 1.0 - tint, tint)
    },
  )
  if s == 0.0 {
    return { red: l, green: l, blue: l, }
  }
  let q = if l < 0.5 { l * (1.0 + s) } else { xlsx_fma(-l, s, l + s) }
  let p = 2.0 * l - q
  {
    red: xlsx_color_component(h + 1.0 / 3.0, p, q),
    green: xlsx_color_component(h, p, q),
    blue: xlsx_color_component(h - 1.0 / 3.0, p, q),
  }
}

///|
fn xlsx_rgb_from_uint(rgb : UInt32) -> XlsxRgb {
  {
    red: ((rgb >> 16) & 255U).to_double() / 255.0,
    green: ((rgb >> 8) & 255U).to_double() / 255.0,
    blue: (rgb & 255U).to_double() / 255.0,
  }
}

///|
/// Resolve a color against the workbook palette and a theme indexed by XLSX theme ID.
pub fn XlsxStyles::resolve_color(
  self : XlsxStyles,
  color : XlsxColor,
  default : XlsxRgb,
  theme : Map[Int32, XlsxRgb],
) -> XlsxRgb {
  let resolved = match color.kind {
    1 => xlsx_rgb_from_uint(color.rgb)
    2 =>
      match theme.get(color.index) {
        Some(v) if color.index >= 0 && color.index < 12 => v
        _ => return default
      }
    3 =>
      if color.index == 64 || color.index == 81 {
        xlsx_rgb_from_uint(0U)
      } else if color.index == 65 || color.index == 80 {
        xlsx_rgb_from_uint(0xffffffU)
      } else if color.index >= 0 && color.index < self.palette.length() {
        xlsx_rgb_from_uint(self.palette[color.index])
      } else {
        return default
      }
    _ => return default
  }
  if color.tint == 0.0 {
    resolved
  } else {
    xlsx_tint_color(resolved, color.tint)
  }
}

///|
/// Quantize RGB to the packed RGBA color used by BDF objects.
pub fn XlsxRgb::rgba(self : XlsxRgb) -> UInt32 {
  let r = (xlsx_clamp_color(self.red) * 255.0).round().to_uint()
  let g = (xlsx_clamp_color(self.green) * 255.0).round().to_uint()
  let b = (xlsx_clamp_color(self.blue) * 255.0).round().to_uint()
  (r << 24) | (g << 16) | (b << 8) | 255U
}
