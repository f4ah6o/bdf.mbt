///|
test "content tokens match the upstream lexer" {
  let lexer : ContentLexer = {
    data: b"/Name#20x 1 -2.5 (a\\(b\\)\\n\\101) <48656c6c6f> [1 /B (c)] << /K 1 >> Tj BI /W 2 /H 1 /BPC 8 /CS /G ID ab EI Q",
    pos: 0,
  }
  assert_eq(lexer.next(0), Operand(Name(b"Name x")))
  assert_eq(lexer.next(0), Operand(Integer(1L)))
  assert_eq(lexer.next(0), Operand(Real(-2.5)))
  assert_eq(lexer.next(0), Operand(Literal(b"a(b)\nA")))
  assert_eq(lexer.next(0), Operand(Hex(b"48656c6c6f")))
  assert_eq(
    lexer.next(0),
    Operand(ArrayValue([Integer(1L), Name(b"B"), Literal(b"c")])),
  )
  assert_eq(lexer.next(0), Operand(Dictionary([(b"K", Integer(1L))])))
  assert_eq(lexer.next(0), Operator(b"Tj"))
  assert_eq(lexer.next(0), Operator(b"BI"))
  while lexer.next(0) != Operator(b"ID") {

  }
  assert_eq(lexer.read_inline_image(2), b"ab")
  assert_eq(lexer.next(0), Operator(b"Q"))
  assert_eq(lexer.next(0), End)
}

///|
test "content strings and malformed numbers" {
  let lexer : ContentLexer = {
    data: b"% comment\r\n/Bad#xF /Bytes#00#FF (a(b)c\\777\\\r\nd) < 1 2 z > 3.4.5 --5 true false null [1 nope 2] << /K 1 /K 2 >>",
    pos: 0,
  }
  assert_eq(lexer.next(0), Operand(Name(b"Bad#xF")))
  assert_eq(lexer.next(0), Operand(Name(b"Bytes\x00\xff")))
  assert_eq(lexer.next(0), Operand(Literal(b"a(b)c\xffd")))
  assert_eq(lexer.next(0), Operand(Hex(b"12z")))
  assert_eq(lexer.next(0), Operand(Real(3.4)))
  assert_eq(lexer.next(0), Operand(Real(0.0)))
  assert_eq(lexer.next(0), Operand(Boolean(true)))
  assert_eq(lexer.next(0), Operand(Boolean(false)))
  assert_eq(lexer.next(0), Operand(Null))
  assert_eq(lexer.next(0), Operand(ArrayValue([Integer(1L), Integer(2L)])))
  assert_eq(lexer.next(0), Operand(Dictionary([(b"K", Integer(2L))])))
}

///|
test "inline image termination" {
  let exact : ContentLexer = { data: b" x EI y EI Q", pos: 0, }
  assert_eq(exact.read_inline_image(6), b"x EI y")
  assert_eq(exact.next(0), Operator(b"Q"))
  let search : ContentLexer = { data: b" abc EIx def EI Q", pos: 0, }
  assert_eq(search.read_inline_image(-1), b"abc EIx def")
  assert_eq(search.next(0), Operator(b"Q"))
  let missing : ContentLexer = { data: b" abc", pos: 0, }
  assert_eq(missing.read_inline_image(-1), b"abc")
  assert_eq(missing.next(0), End)
}

///|
test "string operand decoding" {
  assert_eq(content_literal_bytes(Literal(b"\x00\xff")), Some(b"\x00\xff"))
  assert_eq(content_literal_bytes(Hex(b"0041ff")), Some(b"\x00A\xff"))
  assert_eq(content_literal_bytes(Hex(b"ABC")), None)
  assert_eq(content_literal_bytes(Hex(b"0z")), None)
  assert_eq(content_literal_bytes(Integer(1L)), None)
}

///|
test "content nesting is limited to 32 levels" {
  let input : Array[Byte] = []
  for _ in 0..<40 {
    input.push(b'[')
  }
  input.push(b'7')
  for _ in 0..<40 {
    input.push(b']')
  }
  input.push(b' ')
  input.push(b'8')
  let lexer : ContentLexer = { data: Bytes::from_array(input), pos: 0, }
  let mut value = match lexer.next(0) {
    Operand(v) => v
    _ => abort("missing operand")
  }
  let mut depth = 0
  while value is ArrayValue(items) {
    depth += 1
    assert_eq(items.length(), 1)
    value = items[0]
  }
  assert_eq(depth, 32)
  assert_eq(value, Integer(7L))
  assert_eq(lexer.next(0), Operand(Integer(8L)))
}
