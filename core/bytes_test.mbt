///|
let hex_digits : String = "0123456789abcdef"

///|
/// Independent lowercase-hex oracle: a digit table, not the arithmetic in
/// `Reader::hash`.
fn hex_of(bytes : Bytes) -> String {
  let out = StringBuilder()
  for b in bytes {
    let n = b.to_int()
    out.write_char(hex_digits[n >> 4].unsafe_to_char())
    out.write_char(hex_digits[n & 15].unsafe_to_char())
  }
  out.to_string()
}

///|
test "reader remaining tracks consumed bytes" {
  let r = @core.Reader::new(b"\x01\x02\x03")
  assert_eq(r.remaining(), 3)
  assert_eq(r.u8(), 1)
  assert_eq(r.remaining(), 2)
  assert_eq(r.u16(), 0x0302)
  assert_eq(r.remaining(), 0)
}

///|
test "reader rejects a read past the end" {
  let rejected = try {
    ignore(@core.Reader::new(b"").u8())
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
}

///|
test "u64_size accepts a zero high word" {
  assert_eq(
    @core.Reader::new(b"\x20\x00\x00\x00\x00\x00\x00\x00").u64_size(),
    32,
  )
}

///|
test "u64_size rejects a nonzero high word" {
  let rejected = try {
    ignore(@core.Reader::new(b"\x00\x00\x00\x00\x01\x00\x00\x00").u64_size())
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
}

///|
test "u64_size rejects a negative low word" {
  let rejected = try {
    ignore(@core.Reader::new(b"\x00\x00\x00\x80\x00\x00\x00\x00").u64_size())
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
}

///|
test "varuint decodes multi-byte values" {
  assert_eq(@core.Reader::new(b"\x00").varuint(), 0)
  assert_eq(@core.Reader::new(b"\x7f").varuint(), 127)
  assert_eq(@core.Reader::new(b"\x80\x01").varuint(), 128)
  assert_eq(@core.Reader::new(b"\xff\xff\xff\xff\x07").varuint(), 0x7fffffff)
}

///|
test "varuint rejects a fifth byte with high bits" {
  let rejected = try {
    ignore(@core.Reader::new(b"\xff\xff\xff\xff\x1f").varuint())
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
}

///|
test "varuint rejects a fifth byte whose excess bits would be truncated" {
  let rejected = try {
    ignore(@core.Reader::new(b"\x80\x80\x80\x80\x10").varuint())
    false
  } catch {
    @core.BadFormat(_) => true
    _ => false
  }
  assert_true(rejected)
}

///|
test "skip and take advance the cursor" {
  let r = @core.Reader::new(b"\x01\x02\x03")
  r.skip(1)
  assert_eq(r.remaining(), 2)
  assert_eq(r.take(2), b"\x02\x03")
  assert_eq(r.remaining(), 0)
}

///|
test "skip rejects out-of-range sizes" {
  let too_far = try {
    ignore(@core.Reader::new(b"\x01").skip(2))
    false
  } catch {
    _ => true
  }
  assert_true(too_far)
  let negative = try {
    ignore(@core.Reader::new(b"\x01").skip(-1))
    false
  } catch {
    _ => true
  }
  assert_true(negative)
}

///|
test "take rejects out-of-range sizes" {
  let too_far = try {
    ignore(@core.Reader::new(b"\x01").take(2))
    false
  } catch {
    _ => true
  }
  assert_true(too_far)
  let negative = try {
    ignore(@core.Reader::new(b"\x01").take(-1))
    false
  } catch {
    _ => true
  }
  assert_true(negative)
}

///|
test "hash renders lowercase hex" {
  assert_eq(
    @core.Reader::new(
      b"\x00\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0a\x0b\x0c\x0d\x0e\x0f",
    ).hash(),
    "000102030405060708090a0b0c0d0e0f",
  )
  assert_eq(
    @core.Reader::new(
      b"\xde\xad\xbe\xef\x00\x11\x22\x33\x44\x55\x66\x77\x88\x99\xaa\xbb",
    ).hash(),
    "deadbeef00112233445566778899aabb",
  )
}

///|
test "f32 reinterprets little-endian bits" {
  assert_eq(@core.Reader::new(b"\x00\x00\x80\x3f").f32(), 1.0)
  assert_eq(@core.Reader::new(b"\x00\x00\x00\x00").f32(), 0.0)
}

///|
test "valid_hash accepts only 32 lowercase hex characters" {
  assert_true(@core.valid_hash("000102030405060708090a0b0c0d0e0f"))
  assert_false(@core.valid_hash(""))
  assert_false(@core.valid_hash("000102030405060708090a0b0c0d0e0"))
  assert_false(@core.valid_hash("000102030405060708090a0b0c0d0e0f0"))
  assert_false(@core.valid_hash("000102030405060708090a0b0c0d0e0g"))
  assert_false(@core.valid_hash("000102030405060708090A0B0C0D0E0F"))
  assert_false(@core.valid_hash("000102030405060708090a0b0c0d0e0:"))
}

///|
test "property: take splits the input at a generated point" {
  @quickcheck.check((bs : Bytes) => {
    let len = bs.length()
    let n = if len == 0 { 0 } else { bs[0].to_int().abs() % (len + 1) }
    let r = @core.Reader::new(bs)
    let taken = r.take(n)
    let prefix = Bytes::from_array([ for i in 0..<n => bs[i] ])
    let rest = Bytes::from_array([ for i in n..<len => bs[i] ])
    taken == prefix && r.remaining() == len - n && r.take(len - n) == rest
  })
}

///|
test "property: hash matches an independent hex oracle" {
  @quickcheck.check((bs : Bytes) => {
    let padded = FixedArray::make(16, b'\x00')
    for i in 0..<16 {
      if i < bs.length() {
        padded[i] = bs[i]
      }
    }
    let bytes = Bytes::from_fixedarray(padded)
    @core.Reader::new(bytes).hash() == hex_of(bytes)
  })
}

///|
test "property: hash output is a valid hash format" {
  @quickcheck.check((bs : Bytes) => {
    if bs.length() < 16 {
      true
    } else {
      let h = @core.Reader::new(bs).hash()
      h.length() == 32 && @core.valid_hash(h)
    }
  })
}

///|
test "property: valid_hash rejects every non-32-character string" {
  @quickcheck.check((s : String) => {
    if s.length() == 32 {
      true
    } else {
      !@core.valid_hash(s)
    }
  })
}
