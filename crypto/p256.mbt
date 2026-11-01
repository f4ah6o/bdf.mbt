///|
let p256_p : @bigint.BigInt = @bigint.BigInt::from_string(
  "ffffffff00000001000000000000000000000000ffffffffffffffffffffffff",
  radix=16,
)

///|
let p256_b : @bigint.BigInt = @bigint.BigInt::from_string(
  "5ac635d8aa3a93e7b3ebbd55769886bc651d06b0cc53b0f63bce3c3e27d2604b",
  radix=16,
)

///|
let p256_gx : @bigint.BigInt = @bigint.BigInt::from_string(
  "6b17d1f2e12c4247f8bce6e563a440f277037d812deb33a0f4a13945d898c296",
  radix=16,
)

///|
let p256_gy : @bigint.BigInt = @bigint.BigInt::from_string(
  "4fe342e2fe1a7f9b8ee7eb4a7c0f9e162bce33576b315ececbb6406837bf51f5",
  radix=16,
)

///|
let p256_n : @bigint.BigInt = @bigint.BigInt::from_string(
  "ffffffff00000000ffffffffffffffffbce6faada7179e84f3b9cac2fc632551",
  radix=16,
)

///|
fn p256_mod(value : @bigint.BigInt) -> @bigint.BigInt {
  let result = value % p256_p
  if result.compare_int(0) < 0 {
    result + p256_p
  } else {
    result
  }
}

///|
priv struct P256Point {
  x : @bigint.BigInt
  y : @bigint.BigInt
  z : @bigint.BigInt
}

///|
fn p256_infinity() -> P256Point {
  {
    x: @bigint.BigInt::from_int(0),
    y: @bigint.BigInt::from_int(1),
    z: @bigint.BigInt::from_int(0),
  }
}

///|
fn p256_double(point : P256Point) -> P256Point {
  if point.z.is_zero() || point.y.is_zero() {
    return p256_infinity()
  }
  let delta = p256_mod(point.z * point.z)
  let gamma = p256_mod(point.y * point.y)
  let beta = p256_mod(point.x * gamma)
  let alpha = p256_mod(
    (point.x - delta) * (point.x + delta) * @bigint.BigInt::from_int(3),
  )
  let x3 = p256_mod(alpha * alpha - beta * @bigint.BigInt::from_int(8))
  let z3 = p256_mod((point.y + point.z) * (point.y + point.z) - gamma - delta)
  let y3 = p256_mod(
    alpha * (beta * @bigint.BigInt::from_int(4) - x3) -
    gamma * gamma * @bigint.BigInt::from_int(8),
  )
  { x: x3, y: y3, z: z3, }
}

///|
fn p256_add(left : P256Point, right : P256Point) -> P256Point {
  if left.z.is_zero() {
    return right
  }
  if right.z.is_zero() {
    return left
  }
  let z1z1 = p256_mod(left.z * left.z)
  let z2z2 = p256_mod(right.z * right.z)
  let u1 = p256_mod(left.x * z2z2)
  let u2 = p256_mod(right.x * z1z1)
  let s1 = p256_mod(left.y * right.z * z2z2)
  let s2 = p256_mod(right.y * left.z * z1z1)
  let h = p256_mod(u2 - u1)
  if h.is_zero() {
    if s2 == s1 {
      return p256_double(left)
    }
    return p256_infinity()
  }
  let i = p256_mod((h + h) * (h + h))
  let j = p256_mod(h * i)
  let v = p256_mod(u1 * i)
  let r = p256_mod((s2 - s1) * @bigint.BigInt::from_int(2))
  let x3 = p256_mod(r * r - j - v - v)
  let y3 = p256_mod(r * (v - x3) - s1 * j * @bigint.BigInt::from_int(2))
  let z3 = p256_mod((left.z + right.z) * (left.z + right.z) - z1z1 - z2z2)
  let z3 = p256_mod(z3 * h)
  { x: x3, y: y3, z: z3, }
}

///|
fn p256_multiply(scalar : @bigint.BigInt, point : P256Point) -> P256Point {
  let mut result = p256_infinity()
  let mut addend = point
  let mut value = scalar
  while !value.is_zero() {
    if (value % @bigint.BigInt::from_int(2)).compare_int(1) == 0 {
      result = p256_add(result, addend)
    }
    addend = p256_double(addend)
    value = value / @bigint.BigInt::from_int(2)
  }
  result
}

///|
fn p256_affine(point : P256Point) -> (@bigint.BigInt, @bigint.BigInt)? {
  if point.z.is_zero() {
    return None
  }
  let inverse = point.z.pow(
    p256_p - @bigint.BigInt::from_int(2),
    modulus=p256_p,
  )
  let x = p256_mod(point.x * inverse * inverse)
  let y = p256_mod(point.y * inverse * inverse * inverse)
  Some((x, y))
}

///|
fn p256_on_curve(x : @bigint.BigInt, y : @bigint.BigInt) -> Bool {
  p256_mod(y * y) ==
  p256_mod(x * x * x - x * @bigint.BigInt::from_int(3) + p256_b)
}

///|
fn p256_public_point(public_key : Bytes) -> P256Point raise {
  if public_key.length() != 65 || public_key[0] != b'\x04' {
    raise InvalidKeyWrap
  }
  let x = @bigint.BigInt::from_octets(public_key[1:33])
  let y = @bigint.BigInt::from_octets(public_key[33:65])
  if x.compare(p256_p) >= 0 || y.compare(p256_p) >= 0 || !p256_on_curve(x, y) {
    raise InvalidKeyWrap
  }
  { x, y, z: @bigint.BigInt::from_int(1), }
}

///|
/// Return the uncompressed P-256 public key for a 32-byte private scalar.
pub fn p256_public_key(private_key : Bytes) -> Bytes raise {
  if private_key.length() != 32 {
    raise InvalidKeyWrap
  }
  let scalar = @bigint.BigInt::from_octets(private_key)
  if scalar.is_zero() || scalar.compare(p256_n) >= 0 {
    raise InvalidKeyWrap
  }
  let point = p256_multiply(scalar, {
    x: p256_gx,
    y: p256_gy,
    z: @bigint.BigInt::from_int(1),
  })
  match p256_affine(point) {
    Some((x, y)) => {
      let output : Array[Byte] = [b'\x04']
      for byte in x.to_octets(length=32) {
        output.push(byte)
      }
      for byte in y.to_octets(length=32) {
        output.push(byte)
      }
      Bytes::from_array(output)
    }
    None => raise InvalidKeyWrap
  }
}

///|
/// P-256 ECDH shared secret (the x-coordinate of d * Q).
pub fn p256_ecdh(private_key : Bytes, public_key : Bytes) -> Bytes raise {
  if private_key.length() != 32 {
    raise InvalidKeyWrap
  }
  let scalar = @bigint.BigInt::from_octets(private_key)
  if scalar.is_zero() || scalar.compare(p256_n) >= 0 {
    raise InvalidKeyWrap
  }
  let point = p256_multiply(scalar, p256_public_point(public_key))
  match p256_affine(point) {
    Some((x, _)) => x.to_octets(length=32)
    None => raise InvalidKeyWrap
  }
}
