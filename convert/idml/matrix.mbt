///|
priv struct IdmlMatrix {
  a : Double
  b : Double
  c : Double
  d : Double
  e : Double
  f : Double
}

///|
fn idml_matrix_identity() -> IdmlMatrix {
  { a: 1.0, b: 0.0, c: 0.0, d: 1.0, e: 0.0, f: 0.0 }
}

///|
fn idml_matrix(text : String) -> IdmlMatrix {
  let values = idml_numbers(text)
  if values.length() < 6 {
    idml_matrix_identity()
  } else {
    {
      a: values[0],
      b: values[1],
      c: values[2],
      d: values[3],
      e: values[4],
      f: values[5],
    }
  }
}

///|
fn IdmlMatrix::apply(self : IdmlMatrix, x : Double, y : Double) -> (Double, Double) {
  (self.a * x + self.c * y + self.e, self.b * x + self.d * y + self.f)
}

///|
fn idml_matrix_mul(a : IdmlMatrix, b : IdmlMatrix) -> IdmlMatrix {
  {
    a: a.a * b.a + a.c * b.b,
    b: a.b * b.a + a.d * b.b,
    c: a.a * b.c + a.c * b.d,
    d: a.b * b.c + a.d * b.d,
    e: a.a * b.e + a.c * b.f + a.e,
    f: a.b * b.e + a.d * b.f + a.f,
  }
}
