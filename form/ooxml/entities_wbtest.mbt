///|
// Regression tests of the entities of an OOXML part: a tag of a document is
// written with the quotes of its arguments escaped (`fmt:&quot;¥#,##0&quot;`),
// and the fill reads it as the tag it is. The values that the fill writes are
// escaped once, and a text that spells an entity stays as it is written.

///|
test "ooxml reads the entities of a tag" {
  assert_eq(xml_unescape("&amp;"), "&")
  assert_eq(xml_unescape("&lt;"), "<")
  assert_eq(xml_unescape("&gt;"), ">")
  assert_eq(xml_unescape("&quot;"), "\"")
  assert_eq(xml_unescape("&apos;"), "'")
  assert_eq(xml_unescape("&#x3042;"), "あ")
  assert_eq(xml_unescape("&#12354;"), "あ")
  // one pass: a text that spells an entity stays as it is written
  assert_eq(xml_unescape("&amp;quot;"), "&quot;")
  assert_eq(xml_unescape("&amp;amp;"), "&amp;")
  // what is not an entity stays
  assert_eq(xml_unescape("A & B"), "A & B")
  assert_eq(xml_unescape("&foo;"), "&foo;")
  assert_eq(xml_unescape("&;"), "&;")
  assert_eq(xml_unescape("&"), "&")
  assert_eq(xml_unescape(""), "")
  assert_eq(xml_unescape("&#xZZ;"), "&#xZZ;")
}

///|
test "ooxml reads the numeric entities that XML allows" {
  assert_eq(xml_unescape("&#x9;"), "\t")
  assert_eq(xml_unescape("&#xA;"), "\n")
  assert_eq(xml_unescape("&#xD;"), "\r")
  assert_eq(xml_unescape("&#x20;"), " ")
  assert_eq(xml_unescape("&#x7E;"), "~")
  assert_eq(xml_unescape("&#xD7FF;"), "\u{D7FF}")
  assert_eq(xml_unescape("&#xE000;"), "\u{E000}")
  assert_eq(xml_unescape("&#xFFFD;"), "\u{FFFD}")
  assert_eq(xml_unescape("&#x10000;"), "\u{10000}")
  assert_eq(xml_unescape("&#x10FFFF;"), "\u{10FFFF}")
}

///|
test "ooxml keeps a numeric entity that has a sign or a space" {
  // XML writes the digits only, so these are not character references.
  assert_eq(xml_unescape("&#+65;"), "&#+65;")
  assert_eq(xml_unescape("&#x+41;"), "&#x+41;")
  assert_eq(xml_unescape("&#-65;"), "&#-65;")
  assert_eq(xml_unescape("&# 65;"), "&# 65;")
  assert_eq(xml_unescape("&#65 ;"), "&#65 ;")
  assert_eq(xml_unescape("&#;"), "&#;")
  assert_eq(xml_unescape("&#x;"), "&#x;")
  // the digits alone still decode, in both bases and both cases
  assert_eq(xml_unescape("&#65;"), "A")
  assert_eq(xml_unescape("&#x41;"), "A")
  assert_eq(xml_unescape("&#X41;"), "A")
  assert_eq(xml_unescape("&#x1F600;"), "\u{1F600}")
}

///|
test "ooxml keeps the numeric entities that XML forbids" {
  // a control that XML does not allow in a document
  assert_eq(xml_unescape("&#0;"), "&#0;")
  assert_eq(xml_unescape("&#x1F;"), "&#x1F;")
  assert_eq(xml_unescape("&#xB;"), "&#xB;")
  // a surrogate is not a character
  assert_eq(xml_unescape("&#xD800;"), "&#xD800;")
  assert_eq(xml_unescape("&#xDFFF;"), "&#xDFFF;")
  // the last two code points of the basic plane are not characters
  assert_eq(xml_unescape("&#xFFFE;"), "&#xFFFE;")
  assert_eq(xml_unescape("&#xFFFF;"), "&#xFFFF;")
  // beyond the last code point
  assert_eq(xml_unescape("&#x110000;"), "&#x110000;")
  assert_eq(xml_unescape("&#99999999999;"), "&#99999999999;")
}

///|
test "ooxml reads the format of a tag for the schema" {
  let fields = inspect_tags("<t>{{amount | fmt:&quot;¥#,##0&quot;}}</t>")
  assert_eq(fields.length(), 1)
  assert_eq(fields[0].name, "amount")
  assert_eq(fields[0].format, "¥#,##0")
}

///|
test "ooxml fills a tag that markup splits and entities escape" {
  let values = Json::object({ "amount": Json::number(12000.0) })
  let (filled, warnings) = fill_part(
    "<t>{{amount | fmt:<w:r><w:t>&quot;¥#,##0&quot;</w:t></w:r>}}</t>",
    values,
    false,
    0,
    true,
  )
  assert_eq(warnings.length(), 0, msg=warnings.join("; "))
  assert_eq(filled, "<t>¥12,000</t>")
}

///|
test "ooxml writes a negative, a million and a decimal with the format" {
  let cases : Array[(Double, String)] = [
    (-12000.0, "¥-12,000"),
    (1234567.0, "¥1,234,567"),
    (1000000.0, "¥1,000,000"),
    (1234.5, "¥1,235"),
    (0.5, "¥1"),
    (-0.5, "¥-1"),
  ]
  for pair in cases {
    let (value, expected) = pair
    let values = Json::object({ "amount": Json::number(value) })
    let (filled, warnings) = fill_part(
      "<t>{{amount | fmt:&quot;¥#,##0&quot;}}</t>",
      values,
      false,
      0,
      true,
    )
    assert_eq(warnings.length(), 0, msg=warnings.join("; "))
    assert_eq(filled, "<t>" + expected + "</t>", msg=value.to_string())
  }
}

///|
test "ooxml fills a tag whose format is written with entities" {
  let values = Json::object({ "amount": Json::number(12000.0) })
  let (filled, warnings) = fill_part(
    "<t>{{amount | fmt:&quot;¥#,##0&quot;}}</t>",
    values,
    false,
    0,
    true,
  )
  assert_eq(warnings.length(), 0, msg=warnings.join("; "))
  assert_eq(filled, "<t>¥12,000</t>")
}

///|
test "ooxml fills a tag whose format is written with quotes" {
  let values = Json::object({ "amount": Json::number(12000.0) })
  let (filled, warnings) = fill_part(
    "<t>{{amount | fmt:\"¥#,##0\"}}</t>",
    values,
    false,
    0,
    true,
  )
  assert_eq(warnings.length(), 0, msg=warnings.join("; "))
  assert_eq(filled, "<t>¥12,000</t>")
}

///|
test "ooxml escapes the values of a tag once" {
  let values = Json::object({ "name": Json::string("A & B <c> \"d\"") })
  let (filled, warnings) = fill_part(
    "<t>{{name}}</t>",
    values,
    false,
    0,
    true,
  )
  assert_eq(warnings.length(), 0, msg=warnings.join("; "))
  assert_eq(filled, "<t>A &amp; B &lt;c&gt; &quot;d&quot;</t>")
}

///|
test "ooxml does not read the entities of the data" {
  let values = Json::object({ "name": Json::string("&quot;") })
  let (filled, warnings) = fill_part(
    "<t>{{name}}</t>",
    values,
    false,
    0,
    true,
  )
  assert_eq(warnings.length(), 0, msg=warnings.join("; "))
  assert_eq(filled, "<t>&amp;quot;</t>")
}

///|
/// A deterministic generator, so that a failing case can be made again.
struct OoxmlEntityGen {
  mut state : Int
}

///|
fn ooxml_entity_gen(seed : Int) -> OoxmlEntityGen {
  { state: seed }
}

///|
fn OoxmlEntityGen::next(gen : OoxmlEntityGen, bound : Int) -> Int {
  gen.state = (gen.state * 75 + 74) % 65537
  gen.state % bound
}

///|
let ooxml_entity_chars : Array[String] = [
  "&", "<", ">", "\"", "'", "a", "Z", "0", "7", " ", "#", ";", "x", "日", "本",
  "あ", "ア", "①", "→",
]

///|
fn OoxmlEntityGen::text(gen : OoxmlEntityGen) -> String {
  let len = gen.next(13)
  let mut out = ""
  for _ in 0..<len {
    out = out + ooxml_entity_chars[gen.next(ooxml_entity_chars.length())]
  }
  out
}

///|
/// The digits of a number with a comma every three, as `#,##0` writes them.
fn ooxml_entity_grouped(value : Int) -> String {
  let digits = value.to_string()
  let out = StringBuilder()
  for i, c in digits {
    if i > 0 && (digits.length() - i) % 3 == 0 {
      out.write_char(',')
    }
    out.write_char(c)
  }
  out.to_string()
}

///|
test "ooxml property: escaping and reading back a text gives the text" {
  let gen = ooxml_entity_gen(2026)
  for i in 0..<200 {
    let text = gen.text()
    let escaped = xml_escape(text)
    assert_eq(
      xml_unescape(escaped),
      text,
      msg="case " + i.to_string() + ": " + escaped,
    )
    // the escaped text has no raw markup
    assert_true(
      !escaped.contains("<") && !escaped.contains(">"),
      msg="case " + i.to_string() + ": " + escaped,
    )
  }
}

///|
test "ooxml property: a tag with an escaped format fills like a plain one" {
  let gen = ooxml_entity_gen(7)
  for i in 0..<100 {
    let amount = gen.next(10000000)
    let values = Json::object({ "amount": Json::number(amount.to_double()) })
    let (escaped, warnings) = fill_part(
      "<t>{{amount | fmt:&quot;¥#,##0&quot;}}</t>",
      values,
      false,
      0,
      true,
    )
    assert_eq(warnings.length(), 0, msg=warnings.join("; "))
    let (plain, _) = fill_part(
      "<t>{{amount | fmt:\"¥#,##0\"}}</t>",
      values,
      false,
      0,
      true,
    )
    assert_eq(escaped, plain, msg="case " + i.to_string())
    assert_eq(
      escaped,
      "<t>¥" + ooxml_entity_grouped(amount) + "</t>",
      msg="case " + i.to_string(),
    )
    assert_true(
      !escaped.contains("&"),
      msg="case " + i.to_string() + ": " + escaped,
    )
  }
}
