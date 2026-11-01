///|
/// An affine transform [a b c d e f] in Canvas order.
pub(all) struct Matrix {
  a : Double
  b : Double
  c : Double
  d : Double
  e : Double
  f : Double
} derive(Eq, Debug)

///|
pub fn Matrix::identity() -> Matrix {
  { a: 1.0, b: 0.0, c: 0.0, d: 1.0, e: 0.0, f: 0.0 }
}

///|
pub fn Matrix::translate(x : Double, y : Double) -> Matrix {
  { a: 1.0, b: 0.0, c: 0.0, d: 1.0, e: x, f: y }
}

///|
pub fn Matrix::scale(x : Double, y : Double) -> Matrix {
  { a: x, b: 0.0, c: 0.0, d: y, e: 0.0, f: 0.0 }
}

///|
/// A rotation by degrees (clockwise in y-down space).
pub fn Matrix::rotate(deg : Double) -> Matrix {
  let radians = deg * 3.141592653589793 / 180.0
  let sine = @math.sin(radians)
  let cosine = @math.cos(radians)
  { a: cosine, b: sine, c: -sine, d: cosine, e: 0.0, f: 0.0 }
}

///|
/// The transform `m * n`: `n` is applied first, then `m`.
pub fn Matrix::mul(self : Matrix, n : Matrix) -> Matrix {
  {
    a: self.a * n.a + self.c * n.b,
    b: self.b * n.a + self.d * n.b,
    c: self.a * n.c + self.c * n.d,
    d: self.b * n.c + self.d * n.d,
    e: self.a * n.e + self.c * n.f + self.e,
    f: self.b * n.e + self.d * n.f + self.f,
  }
}

///|
pub fn Matrix::apply(self : Matrix, x : Double, y : Double) -> (Double, Double) {
  (self.a * x + self.c * y + self.e, self.b * x + self.d * y + self.f)
}

///|
/// The mean scale factor: how lengths change on average.
pub fn Matrix::scale_factor(self : Matrix) -> Double {
  (self.a * self.d - self.b * self.c).abs().sqrt()
}

///|
/// Whether the transform is a translation.
pub fn Matrix::is_translation(self : Matrix) -> Bool {
  self.a == 1.0 && self.b == 0.0 && self.c == 0.0 && self.d == 1.0
}

///|
/// Narrow a double to a BDF float, mapping NaN and infinities to zero.
pub fn f32(value : Double) -> Float {
  if value.is_nan() || value.is_inf() {
    0.0F
  } else {
    Float::from_double(value)
  }
}
