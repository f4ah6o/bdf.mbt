///|
test "streaming SHA-256 matches one-shot at block boundaries" {
  for length in [0, 1, 55, 56, 63, 64, 65, 127, 128, 129, 1024] {
    let bytes = Bytes::from_array([ for i in 0..<length => (i * 37).to_byte() ])
    let stream = Sha256Stream::new()
    let mut i = 0
    while i < length {
      let end = Int32::min(length, i + 13)
      stream.write(bytes[i:end])
      assert_eq(stream.digest(), sha256(bytes[:end]))
      i = end
    }
    assert_eq(stream.digest(), sha256(bytes[:]))
    assert_eq(stream.digest(), sha256(bytes[:]))
  }
}
