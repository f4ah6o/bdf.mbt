///|
fn flat(tokens : Array[TagToken]) -> Array[(TagKind, String, String, String)] {
  let out : Array[(TagKind, String, String, String)] = []
  for token in tokens {
    let text = if token.kind == TagKind::Text {
      token.text
    } else {
      token.name
    }
    out.push((token.kind, text, token.format, token.mode + token.fit))
  }
  out
}

///|
fn tag_error(value : String, text : Bool) -> String {
  try {
    if text {
      ignore(parse_text(value))
    } else {
      ignore(parse(value))
    }
    ""
  } catch {
    TagError(message, _) => message
  }
}

///|
test "form tags split text and values" {
  assert_eq(flat(parse("")), [])
  assert_eq(flat(parse("plain")), [(TagKind::Text, "plain", "", "")])
  assert_eq(flat(parse("{{name}}")), [(TagKind::Value, "name", "", "")])
  assert_eq(
    flat(parse("a {{ b . c }} d")),
    [
      (TagKind::Text, "a ", "", ""),
      (TagKind::Value, "b.c", "", ""),
      (TagKind::Text, " d", "", ""),
    ],
  )
  assert_eq(flat(parse("{{.}}")), [(TagKind::Value, ".", "", "")])
  assert_eq(
    flat(parse("{{#items}}x{{/items}}")),
    [
      (TagKind::Open, "items", "", ""),
      (TagKind::Text, "x", "", ""),
      (TagKind::Close, "items", "", ""),
    ],
  )
  assert_eq(
    flat(parse("{{^paid}}{{/}}")),
    [(TagKind::Inverted, "paid", "", ""), (TagKind::Close, "", "", "")],
  )
  assert_eq(
    flat(parse("{{%photo}}{{% logo | fit:cover}}")),
    [
      (TagKind::Image, "photo", "", ""),
      (TagKind::Image, "logo", "", "cover"),
    ],
  )
}

///|
test "form tags read formats, modes and full-width braces" {
  assert_eq(
    flat(parse("{{total | fmt:\"#,##0\"}}")),
    [(TagKind::Value, "total", "#,##0", "")],
  )
  assert_eq(
    flat(parse("{{d|fmt:'yyyy\"年\"m\"月\"d\"日\"'}}")),
    [(TagKind::Value, "d", "yyyy\"年\"m\"月\"d\"日\"", "")],
  )
  assert_eq(
    flat(parse("{{total | fmt:“#,##0”}}")),
    [(TagKind::Value, "total", "#,##0", "")],
  )
  assert_eq(
    flat(parse("{{x | fmt:\"}}\"}}")),
    [(TagKind::Value, "x", "}}", "")],
  )
  assert_eq(
    flat(parse("{{x | fmt:\"a|b\"}}")),
    [(TagKind::Value, "x", "a|b", "")],
  )
  assert_eq(
    flat(parse("{{#rows | slots}}{{#p|pages}}")),
    [
      (TagKind::Open, "rows", "", "slots"),
      (TagKind::Open, "p", "", "pages"),
    ],
  )
  assert_eq(
    flat(parse("{{#g | block}}{{#r|ROWS}}")),
    [(TagKind::Open, "g", "", "rows"), (TagKind::Open, "r", "", "rows")],
  )
  assert_eq(
    flat(parse("｛｛顧客名｝｝様")),
    [(TagKind::Value, "顧客名", "", ""), (TagKind::Text, "様", "", "")],
  )
  assert_eq(
    flat(parse("｛｛＃明細｜slots｝｝{{／明細}}")),
    [
      (TagKind::Open, "明細", "", "slots"),
      (TagKind::Close, "明細", "", ""),
    ],
  )
  assert_eq(
    flat(parse("{{金額 ｜ fmt：「#,##0」}}")),
    [(TagKind::Value, "金額", "#,##0", "")],
  )
  assert_eq(
    flat(parse("{{　name　}}")),
    [(TagKind::Value, "name", "", "")],
  )
  assert_eq(
    flat(parse("\\{{not a tag}} {{a}}")),
    [(TagKind::Text, "{{not a tag}} ", "", ""), (TagKind::Value, "a", "", "")],
  )
  assert_eq(
    flat(parse("a } b { c }} d")),
    [(TagKind::Text, "a } b { c }} d", "", "")],
  )
  assert_eq(
    flat(parse("{{unit price}}")),
    [(TagKind::Value, "unit price", "", "")],
  )
  let empty = parse("{{x | fmt:\"\"}}")
  assert_true(empty[0].has_format, msg="an empty format is kept")
}

///|
test "form tag errors point at the tag" {
  let cases : Array[(String, String)] = [
    ("a {{name", "not closed"),
    ("{{a {{b}}", "not closed"),
    ("{{}}", "without a name"),
    ("{{#}}", "without a name"),
    ("{{a..b}}", "empty part"),
    ("{{a | upper}}", "option"),
    ("{{a | fmt}}", "option"),
    ("{{#a | fmt:\"0\"}}", "option"),
    ("{{%a | fit:tile}}", "option"),
    ("{{a | pages}}", "option"),
    ("{{a#b}}", "character"),
    ("{{" + "a".repeat(MAX_TAG_LEN + 1) + "}}", "longer"),
  ]
  for entry in cases {
    assert_true(
      tag_error(entry.0, false).contains(entry.1),
      msg="error for " + entry.0,
    )
  }
  assert_true(has("x {{a}}"), msg="ascii tag")
  assert_true(has("｛｛a｝｝"), msg="full-width tag")
  assert_false(has("{ {a} }"), msg="no tag")
}

///|
test "form tags read codes and picture inputs" {
  let qr = parse("{{%url | qr}}")[0]
  assert_eq(qr.code, "qr")
  let level = parse("{{%url | qr:h | fit:contain}}")[0]
  assert_eq(level.code, "qr")
  assert_eq(level.level, "H")
  assert_eq(level.fit, FIT_CONTAIN)
  let jan = parse("{{%jan | barcode:JAN-13}}")[0]
  assert_eq(jan.code, "ean13")
  let gs1 = parse("{{%lot | barcode:\"gs1-128\"}}")[0]
  assert_eq(gs1.code, "gs1-128")
  let quiet = parse("{{%url | qr | quiet:0}}")[0]
  assert_true(quiet.has_quiet, msg="quiet is set")
  let nw = parse("{{%code | barcode:nw7 | quiet:5}}")[0]
  assert_eq(nw.code, "nw7")
  assert_eq(nw.quiet, 5)
  let signature = parse("{{%sign | signature}}")[0]
  assert_eq(signature.input, INPUT_SIGNATURE)
  let seal = parse("{{%seal | seal | fit:contain}}")[0]
  assert_eq(seal.input, INPUT_SEAL)
  assert_eq(seal.fit, FIT_CONTAIN)
  for value in [
    "{{url | qr}}",
    "{{%url | qr:Z}}",
    "{{%x | barcode}}",
    "{{%x | barcode:pdf417}}",
    "{{%x | quiet:65}}",
    "{{%x | quiet:-1}}",
    "{{#x | qr}}",
    "{{sign | signature}}",
    "{{%sign | signature | seal}}",
    "{{%sign | signature:x}}",
    "{{%url | qr | signature}}",
  ] {
    assert_true(
      tag_error(value, false).contains("option") ||
      tag_error(value, false).contains("is a code"),
      msg="code option for " + value,
    )
  }
}

///|
fn tag_columns(value : String) -> (Int, String, String) raise {
  let token = parse_text(value)[0]
  (token.width, token.align, token.overflow)
}

///|
test "form text tags read columns" {
  assert_eq(tag_columns("{{a | width:20}}"), (20, ALIGN_LEFT, ""))
  assert_eq(tag_columns("{{a | right:8}}"), (8, ALIGN_RIGHT, ""))
  assert_eq(
    tag_columns("{{a|center：4|wrap}}"),
    (4, ALIGN_CENTER, OVERFLOW_WRAP),
  )
  assert_eq(
    tag_columns("{{a | fmt:\"#,##0\" | right:10 | cut}}"),
    (10, ALIGN_RIGHT, OVERFLOW_CUT),
  )
  assert_eq(tag_columns("{{a}}"), (0, "", ""))
  for value in [
    "{{a | width:0}}",
    "{{a | width:x}}",
    "{{a | right:5000}}",
    "{{a | cut}}",
    "{{a | width:3 | right:4}}",
    "{{a | width:3 | cut | cut}}",
    "{{#a | width:3}}",
    "{{%a | right:3}}",
  ] {
    assert_true(tag_error(value, true) != "", msg="text tag error " + value)
  }
  assert_true(
    tag_error("{{a | width:20}}", false) != "",
    msg="office tags have no columns",
  )
}
