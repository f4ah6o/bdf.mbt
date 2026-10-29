///|
test "dialect detection matches upstream samples" {
  let cases : Array[(String, Byte, Byte, Byte)] = [
    ("a,b,c\n1,2,3\n4,5,6\n", b',', b'"', 0),
    ("a\tb\tc\n1\t2\t3\n", b'\t', b'"', 0),
    ("a;b;c\n1,5;2;3\n4,25;5;6,5\n", b';', b'"', 0),
    ("a|b|c\n1|2|3\n", b'|', b'"', 0),
    ("id,place,n\n1,\"Tokyo, Japan\",3\n2,\"Paris, France\",4\n", b',', b'"', 0),
    ("name\tplace\nAnn\tTokyo, Japan\nBob\tParis, France\n", b'\t', b'"', 0),
    ("'a','b,c'\n'd','e,f'\n'g','h'\n", b',', b'\'', 0),
    ("name,note\nAnn,it's fine\nBob,that's it\nCy,ok\n", b',', b'"', 0),
    ("1,\"say \\\"hi\\\", then go\",x\n2,\"plain\",y\n", b',', b'"', b'\\'),
    ("a\tb\n\"quoted\" start\tx\ny\t\"z\n", b'\t', 0, 0),
    ("a\nb\nc\n", b',', b'"', 0),
  ]
  for (input, delimiter, quote, escape) in cases {
    assert_eq(detect_dialect(input).dialect, { delimiter, quote, escape, })
  }
}

///|
test "dialect sampling excludes a truncated last record and honors options" {
  let sample = detect_dialect("a,b\n1,\"x\nyyyyyyyyyy", cut=true)
  assert_eq(sample.dialect, { delimiter: b',', quote: b'"', escape: 0, })
  assert_eq((sample.records, sample.fields, sample.score), (1, 2, 1.0))
  assert_eq(detect_dialect("a;b,c\n", delimiter=b';', quote=-1).dialect, {
    delimiter: b';',
    quote: 0,
    escape: 0,
  })
}
