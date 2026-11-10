///|
fn template_error(text : String) -> String {
  try {
    ignore(parse_template(@utf8.encode(text)))
    ""
  } catch {
    TextFormError(message) => message
  }
}

///|
test "textform parses lines and sections" {
  let tpl = parse_template(@utf8.encode("---\ncolumns: 20\n---\nhello {{name}}\n"))
  assert_eq(tpl.grid.columns, 20)
  assert_eq(tpl.lines.length(), 1)
  assert_eq(tpl.lines[0].no, 4)
  assert_eq(tpl.lines[0].src, "hello {{name}}")
  assert_eq(tpl.lines[0].toks.length(), 2)
  assert_eq(tpl.lines[0].toks[0].kind, @tag.TagKind::Text)
  assert_eq(tpl.lines[0].toks[1].name, "name")
  let multi = parse_template(
    @utf8.encode("{{#rows}}\n{{name}}\n{{/rows}}\n"),
  )
  assert_eq(multi.lines.length(), 3)
  assert_eq(multi.root.children.length(), 1)
  let section = multi.root.children[0]
  assert_eq(section.name, "rows")
  assert_eq(section.mode, @tag.MODE_SLOTS)
  assert_eq(section.a, 0)
  assert_eq(section.b, 2)
  let rows = parse_template(
    @utf8.encode("{{#rows | rows}}\n{{name}}\n{{/rows}}\n"),
  )
  assert_eq(rows.root.children[0].mode, @tag.MODE_ROWS)
  assert_true(rows.grows, msg="rows grows")
  let same = parse_template(@utf8.encode("{{#items}}{{name}}{{/items}}\n"))
  assert_eq(same.root.children.length(), 0)
  assert_eq(same.lines[0].matches[0], 2)
}

///|
test "textform attributes and conditions" {
  let wide = parse_template(
    @utf8.encode("{{#_wide}}\nabc\n{{/_wide}}\n"),
  )
  assert_eq(wide.lines[0].attrs, ATTR_WIDE)
  assert_eq(wide.lines[1].attrs, ATTR_WIDE)
  assert_eq(wide.root.children.length(), 0)
  let big = parse_template(
    @utf8.encode("{{#_big}}\nabc\n{{/_big}}\n"),
  )
  assert_eq(big.lines[0].attrs, ATTR_WIDE | ATTR_TALL)
  assert_eq(big.lines[1].attrs, ATTR_WIDE | ATTR_TALL)
  let paper = parse_template(
    @utf8.encode("{{#preprinted}}\na\nb\n{{/preprinted}}\n"),
  )
  assert_eq(paper.lines[0].attrs, ATTR_PAPER)
  assert_eq(paper.lines[1].attrs, ATTR_PAPER)
  let inverted = parse_template(
    @utf8.encode("{{^paid}}\nno\n{{/paid}}\n"),
  )
  assert_eq(inverted.root.children[0].mode, @tag.MODE_ROWS)
  assert_true(inverted.root.children[0].inverted, msg="inverted")
  let fields = wide.fields()
  assert_eq(fields.length(), 0)
  let values = parse_template(
    @utf8.encode("{{#items}}{{name}}{{/items}}\n"),
  ).fields()
  assert_eq(values.length(), 2)
  assert_eq(values[0].name, "items")
  assert_eq(values[1].name, "name")
  assert_eq(values[1].in_sections, ["items"])
}

///|
test "textform parse errors" {
  assert_true(
    template_error("{{/x}}").contains("closes no section"),
    msg="a close without a section",
  )
  assert_true(
    template_error("{{#a}}\n{{/b}}").contains("closes {{#a}}"),
    msg="a mismatched close",
  )
  assert_true(
    template_error("{{#a}}\nx").contains("not closed"),
    msg="an unclosed section",
  )
  assert_true(
    template_error("{{%photo}}").contains("no pictures"),
    msg="an image",
  )
  assert_true(
    template_error("{{^_wide}}x{{/_wide}}").contains("not inverted"),
    msg="an inverted attribute",
  )
  assert_true(
    template_error("{{#a | slots}}\n{{#b}}\nx\n{{/b}}\n{{/a}}").contains("slots"),
    msg="sections in slots",
  )
}

///|
test "textform text detection" {
  assert_true(is_text(@utf8.encode("hello")), msg="text")
  assert_false(is_text(@utf8.encode("a\u{0}b")), msg="NUL")
  assert_true(is_template(@utf8.encode("---\na: 1\n---\n")), msg="front matter")
  assert_true(is_template(@utf8.encode("hello {{name}}")), msg="a tag")
  assert_false(is_template(@utf8.encode("hello")), msg="plain text")
}

///|
test "textform detection reads a character that the end of a sample cuts" {
  let a = @utf8.encode("あ")
  assert_eq(a.length(), 3)
  // a character cut by the end of the sample is not a mistake
  assert_true(is_text(@utf8.encode("x") + a[:2].to_owned()), msg="a cut 3-byte character")
  assert_true(is_text(@utf8.encode("x") + a[:1].to_owned()), msg="a cut 3-byte character, one byte")
  assert_true(
    is_template(@utf8.encode("{{name}}") + a[:2].to_owned()),
    msg="a tag and a cut character",
  )
  let emoji = @utf8.encode("😀")
  assert_eq(emoji.length(), 4)
  assert_true(is_text(@utf8.encode("x") + emoji[:3].to_owned()), msg="a cut 4-byte character")
  assert_true(
    is_template(@utf8.encode("{{name}}") + emoji[:1].to_owned()),
    msg="a tag and a cut 4-byte character",
  )
  // a sample that holds nothing but a cut character has no text to read
  assert_false(is_text(a[:2].to_owned()), msg="only a cut character")
  // bytes that are not UTF-8 at all are still a mistake
  assert_false(is_text(b"\xff\xfe"), msg="not UTF-8")
  assert_false(is_text(b"\x80\x80"), msg="continuation bytes alone")
  assert_false(is_text(@utf8.encode("x") + b"\xff"), msg="text and a bad byte")
  assert_false(is_template(b"\xff{{name}}"), msg="not UTF-8 with a tag")
  assert_false(is_template(@utf8.encode("{{name}}") + b"\x80"), msg="a tag and a bad byte")
  // NUL is still a mistake
  assert_false(is_text(@utf8.encode("x") + a[:2].to_owned() + b"\x00"), msg="NUL")
}
