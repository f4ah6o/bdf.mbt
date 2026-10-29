///|
fn specimen_f32(value : Double) -> Float {
  if value.is_nan() || value.is_inf() {
    0.0F
  } else {
    Float::from_double(value)
  }
}
