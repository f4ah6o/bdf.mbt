///|
fn code39_test_bits(symbol : Symbol) -> String {
  let bits = StringBuilder()
  for x in 0..<symbol.width() {
    bits.write_string(if symbol.at(x, 0) { "1" } else { "0" })
  }
  bits.to_string()
}

///|
/// Fixed examples from the Code 39 module specification, independent of the
/// encoder's wide/narrow table.
fn code39_test_reference(payload : String) -> String {
  let out = StringBuilder()
  out.write_string("0000000000" + "100010111011101")
  for c in payload {
    out.write_string("0")
    out.write_string(
      match c {
        'A' => "111010100010111"
        '0' => "101000111011101"
        '-' => "100010101110111"
        'Z' => "100011101110101"
        _ => ""
      },
    )
  }
  out.write_string("0" + "100010111011101" + "0000000000")
  out.to_string()
}

///|
test "Code39 module pattern matches upstream vector" {
  let symbol = encode("Code-39", "*A*")
  assert_eq(symbol.text(), "A")
  assert_eq(symbol.width(), 67)
  assert_eq(symbol.height(), 1)
  assert_eq(code39_test_bits(symbol), code39_test_reference("A"))
  assert_false(symbol.at(-1, 0))
  assert_false(symbol.at(symbol.width(), 0))
  assert_false(symbol.at(10, -1))
  assert_false(symbol.at(10, 1))
  assert_eq(kinds(), ["code39"])
  assert_eq(kind("Code_3 9"), "code39")
  assert_eq(kind("ean13"), "")
}

///|
test "Code39 quiet zones and payload limits" {
  let standard = encode("code39", "A")
  let no_quiet = encode("code39", "A", quiet=-1)
  let one = encode("code39", "A", quiet=1)
  let capped = encode("code39", "A", quiet=1000)
  assert_eq(standard.width(), 67)
  assert_eq(no_quiet.width(), 47)
  assert_eq(one.width(), 49)
  assert_eq(capped.width(), 175)
  assert_true(no_quiet.at(0, 0))
  assert_false(one.at(0, 0))
  let long = StringBuilder()
  for _ in 0..<MAX_TEXT {
    long.write_string("A")
  }
  assert_eq(encode("code39", long.to_string()).text().length(), MAX_TEXT)
  long.write_string("A")
  let rejected = try {
    ignore(encode("code39", long.to_string()))
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
}

///|
test "Code39 rejects empty and invalid payloads instead of misencoding" {
  for value in ["", "*", "**", "a", "A*B", "日本", "A\nB", "ABC**"] {
    let rejected = try {
      ignore(encode("code39", value))
      false
    } catch {
      _ => true
    }
    assert_true(rejected, msg=value)
  }
  let unknown = try {
    ignore(encode("ean13", "1"))
    false
  } catch {
    _ => true
  }
  assert_true(unknown)
  assert_eq(encode("code39", "*A").text(), "A")
  assert_eq(encode("code39", "A*").text(), "A")
}

///|
test "Code39 drawing encodes a single path and the full quiet-zone bounds" {
  let symbol = encode("code39", "A")
  let path = symbol.path(0.0F, 0.0F, 67.0F, 20.0F)
  assert_eq(path.verbs.length(), symbol.rects().length())
  assert_eq(path.coordinates.length(), path.verbs.length() * 4)
  for i in 0..<path.verbs.length() {
    assert_eq(path.verbs[i], 5)
    let (x, _, width, _) = symbol.rects()[i]
    assert_eq(path.coordinates[i * 4], x.to_double())
    assert_eq(path.coordinates[i * 4 + 2], width.to_double())
    assert_eq(path.coordinates[i * 4 + 3], 20.0)
  }
  let object = symbol.object(67.0F, 20.0F)
  assert_eq(object.bbox(), (0.0F, 0.0F, 67.0F, 20.0F))
  let decoded = @core.decode_object_resources(object.encode())
  let commands = @render.compile_object(decoded.object)
  let mut fills = 0
  for command in commands {
    match command {
      @render.FillPath(_, _) => fills += 1
      _ => ()
    }
  }
  assert_eq(fills, 1)
}

///|
test "Code39 rejects non-finite and negative drawing dimensions" {
  let symbol = encode("code39", "A")
  for
    box in [
      (0.0F, 0.0F, -1.0F, 1.0F),
      (0.0F, 0.0F, 1.0F, -1.0F),
      (0.0F, 0.0F, @float.infinity, 1.0F),
      (Float::reinterpret_from_int(0x7fc00000), 0.0F, 1.0F, 1.0F),
      (@float.max_value, 0.0F, @float.max_value, 1.0F),
      (0.0F, 0.0F, Float::reinterpret_from_int(1), 1.0F),
    ] {
    let rejected = try {
      ignore(symbol.path(box.0, box.1, box.2, box.3))
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
  }
  assert_eq(symbol.object(0.0F, 0.0F).bbox(), (0.0F, 0.0F, 0.0F, 0.0F))
}

///|
test "property: generated Code39 symbols match independent bit oracle" {
  @quickcheck.check((seed : Byte) => {
    let n = seed.to_int() % 32 + 1
    let alphabet : Array[Char] = ['A', '0', '-', 'Z']
    let text = StringBuilder()
    for i in 0..<n {
      text.write_char(alphabet[(seed.to_int() + i * 3) % 4])
    }
    let payload = text.to_string()
    try {
      let symbol = encode("code39", payload)
      let same = code39_test_bits(symbol) == code39_test_reference(payload)
      let covered = Array::make(symbol.width(), false)
      let mut valid = true
      for rect in symbol.rects() {
        let (x, y, w, h) = rect
        if x < 0 || w <= 0 || x + w > symbol.width() || y != 0 || h != 1 {
          valid = false
        } else {
          for pos in x..<(x + w) {
            if covered[pos] {
              valid = false
            }
            covered[pos] = true
          }
        }
      }
      for pos in 0..<symbol.width() {
        if covered[pos] != symbol.at(pos, 0) {
          valid = false
        }
      }
      same && valid && symbol.text() == payload
    } catch {
      _ => false
    }
  })
}

///|
// Fixed 15-module symbols independently derived from the upstream Code 39
// table (MIT; licenses/Shibukawa-bdf.txt). Each public encode call checks
// the character between the start and stop sentinels.
test "every Code39 data character matches its fixed module oracle" {
  let cases : Array[(Char, String)] = [
    ('0', "101000111011101"),
    ('1', "111010001010111"),
    ('2', "101110001010111"),
    ('3', "111011100010101"),
    ('4', "101000111010111"),
    ('5', "111010001110101"),
    ('6', "101110001110101"),
    ('7', "101000101110111"),
    ('8', "111010001011101"),
    ('9', "101110001011101"),
    ('A', "111010100010111"),
    ('B', "101110100010111"),
    ('C', "111011101000101"),
    ('D', "101011100010111"),
    ('E', "111010111000101"),
    ('F', "101110111000101"),
    ('G', "101010001110111"),
    ('H', "111010100011101"),
    ('I', "101110100011101"),
    ('J', "101011100011101"),
    ('K', "111010101000111"),
    ('L', "101110101000111"),
    ('M', "111011101010001"),
    ('N', "101011101000111"),
    ('O', "111010111010001"),
    ('P', "101110111010001"),
    ('Q', "101010111000111"),
    ('R', "111010101110001"),
    ('S', "101110101110001"),
    ('T', "101011101110001"),
    ('U', "111000101010111"),
    ('V', "100011101010111"),
    ('W', "111000111010101"),
    ('X', "100010111010111"),
    ('Y', "111000101110101"),
    ('Z', "100011101110101"),
    ('-', "100010101110111"),
    ('.', "111000101011101"),
    (' ', "100011101011101"),
    ('$', "100010001000101"),
    ('/', "100010001010001"),
    ('+', "100010100010001"),
    ('%', "101000100010001"),
  ]
  assert_eq(cases.length(), 43)
  for (ch, bits) in cases {
    let text = ch.to_string()
    let actual = code39_test_bits(encode("code39", text))
    let expected = "0000000000" +
      "100010111011101" +
      "0" +
      bits +
      "0" +
      "100010111011101" +
      "0000000000"
    assert_eq(actual, expected, msg=text)
  }
}

///|
fn code39_error(text : String) -> String {
  try {
    ignore(encode("code39", text))
    "accepted"
  } catch {
    BarcodeError(message) => message
    _ => "other error"
  }
}

///|
test "UTF-8 length and kind are bounded before normalization or allocation" {
  let below = StringBuilder()
  for _ in 0..<2730 {
    below.write_string("€")
  }
  assert_eq(
    code39_error(below.to_string()),
    "barcode: character cannot be encoded as Code 39",
  )
  below.write_string("€")
  assert_eq(code39_error(below.to_string()), "barcode: text exceeds 8192 bytes")
  let emoji = StringBuilder()
  for _ in 0..<4096 {
    emoji.write_string("😀")
  }
  assert_eq(code39_error(emoji.to_string()), "barcode: text exceeds 8192 bytes")
  let name = StringBuilder()
  name.write_string("code39")
  for _ in 0..<58 {
    name.write_string("-")
  }
  assert_eq(kind(name.to_string()), "code39")
  name.write_string("-")
  assert_eq(kind(name.to_string()), "code39")
  for _ in 0..<8192 {
    name.write_string("-")
  }
  assert_eq(kind(name.to_string()), "code39")
  name.write_string("x")
  assert_eq(kind(name.to_string()), "")
  assert_eq(kind("ＣＯＤＥ３９"), "")
}
