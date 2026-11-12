///|
fn docx_alternate_content_walker() -> DocxTextWalker raise {
  {
    styles: docx_styles_from_xml("<styles/>"),
    blocks: [],
    paragraphs: [],
    section_index: 0,
    fields: [],
    bookmarks: Map([]),
    open_bookmarks: [],
    current_link: "",
    has_math: false,
  }
}

///|
// Runs the walker over a body whose first paragraph holds the given inline
// markup and returns the paragraph items as (kind, text) pairs.
fn docx_alternate_content_items(inline : String) -> Array[(String, String)] raise {
  let body = docx_text_xml(
    "<body><p><AlternateContent>" + inline + "</AlternateContent></p></body>",
  )
  let walker = docx_alternate_content_walker()
  walker.blocks(body, false)
  let items : Array[(String, String)] = []
  for paragraph in walker.paragraphs {
    for item in paragraph.items {
      items.push((item.kind, item.text))
    }
  }
  items
}

///|
fn docx_alternate_content_chosen(source : String) -> String raise {
  let root = docx_text_xml(source)
  let chosen = docx_alternate_content(root).unwrap()
  let mut name = ""
  for child in chosen.children {
    name = child.name()
  }
  name
}

///|
test "DOCX alternate content picks the first Choice with supported Requires" {
  assert_eq(
    docx_alternate_content_chosen(
      "<AlternateContent><Choice Requires=\"wps\"><c1/></Choice><Choice Requires=\"w14\"><c2/></Choice><Fallback><f/></Fallback></AlternateContent>",
    ),
    "c1",
  )
}

///|
test "DOCX alternate content skips a Choice whose Requires is unsupported" {
  assert_eq(
    docx_alternate_content_chosen(
      "<AlternateContent><Choice Requires=\"c14\"><c1/></Choice><Choice Requires=\"wps\"><c2/></Choice><Fallback><f/></Fallback></AlternateContent>",
    ),
    "c2",
  )
}

///|
test "DOCX alternate content rejects partial Requires support" {
  assert_eq(
    docx_alternate_content_chosen(
      "<AlternateContent><Choice Requires=\"wps c14\"><c1/></Choice><Choice Requires=\"a14\"><c2/></Choice><Fallback><f/></Fallback></AlternateContent>",
    ),
    "c2",
  )
}

///|
test "DOCX alternate content accepts every supported prefix" {
  for
    prefix in [
      "wps", "wpg", "wpc", "wp14", "w14", "w15", "a14", "pic14",
    ] {
    let source = "<AlternateContent><Choice Requires=\"" + prefix +
      "\"><c1/></Choice><Fallback><f/></Fallback></AlternateContent>"
    assert_eq(docx_alternate_content_chosen(source), "c1", msg=prefix)
  }
}

///|
test "DOCX alternate content ignores Requires whitespace runs" {
  assert_eq(
    docx_alternate_content_chosen(
      "<AlternateContent><Choice Requires=\"  wps\t w14 \"><c1/></Choice><Fallback><f/></Fallback></AlternateContent>",
    ),
    "c1",
  )
}

///|
test "DOCX alternate content falls back on empty Requires" {
  for requires in ["\"\"", "\"   \""] {
    let source = "<AlternateContent><Choice Requires=" + requires +
      "><c1/></Choice><Fallback><f/></Fallback></AlternateContent>"
    assert_eq(docx_alternate_content_chosen(source), "f", msg=requires)
  }
}

///|
test "DOCX alternate content falls back on missing Requires" {
  assert_eq(
    docx_alternate_content_chosen(
      "<AlternateContent><Choice><c1/></Choice><Fallback><f/></Fallback></AlternateContent>",
    ),
    "f",
  )
}

///|
test "DOCX alternate content without Fallback keeps the first Choice" {
  // Without a supported Choice or a Fallback, the first Choice stays.
  assert_eq(
    docx_alternate_content_chosen(
      "<AlternateContent><Choice Requires=\"c14\"><c1/></Choice><Choice Requires=\"v\"><c2/></Choice></AlternateContent>",
    ),
    "c1",
  )
  // A supported later Choice still wins over an unsupported first one.
  assert_eq(
    docx_alternate_content_chosen(
      "<AlternateContent><Choice Requires=\"c14\"><c1/></Choice><Choice Requires=\"pic14\"><c2/></Choice></AlternateContent>",
    ),
    "c2",
  )
}

///|
test "DOCX alternate content without Choice takes the Fallback" {
  assert_eq(
    docx_alternate_content_chosen("<AlternateContent><Fallback><f/></Fallback></AlternateContent>"),
    "f",
  )
}

///|
test "DOCX alternate content without Choice or Fallback is dropped" {
  let root = docx_text_xml("<AlternateContent><other/></AlternateContent>")
  assert_true(docx_alternate_content(root) is None)
}

///|
test "DOCX alternate content extracts the supported Choice picture" {
  let items = docx_alternate_content_items(
    "<Choice Requires=\"wps\"><r><drawing><inline><extent cx=\"9525\" cy=\"9525\"/><blip embed=\"rId4\"/></inline></drawing></r></Choice>" +
    "<Fallback><r><t>FALLBACK</t></r></Fallback>",
  )
  assert_eq(items.length(), 1)
  assert_eq(items[0], ("image", "rId4"))
}

///|
test "DOCX alternate content extracts Fallback text for unsupported Requires" {
  let items = docx_alternate_content_items(
    "<Choice Requires=\"c14\"><drawing/></Choice>" + "<Fallback><r><t>FALLBACK</t></r></Fallback>",
  )
  let text = StringBuilder()
  let mut pictures = 0
  for item in items {
    if item.0 == "char" {
      text.write_string(item.1)
    }
    if item.0 == "image" {
      pictures += 1
    }
  }
  assert_eq(text.to_string(), "FALLBACK")
  assert_eq(pictures, 0)
}

///|
test "DOCX alternate content picks the Fallback over a fatal Choice" {
  // The Choice drawing would raise for the walker, but it is never visited
  // once the Fallback is picked, so the paragraph converts.
  let rejected = try {
    ignore(
      docx_alternate_content_items(
        "<Choice Requires=\"c14\"><drawing/></Choice>" +
        "<Fallback><r><t>FALLBACK</t></r></Fallback>",
      ),
    )
    false
  } catch {
    _ => true
  }
  assert_false(rejected)
}

///|
test "DOCX alternate content resolves a nested Choice in a Fallback" {
  let items = docx_alternate_content_items(
    "<Choice Requires=\"c14\"><r><t>OUTER</t></r></Choice>" +
    "<Fallback><AlternateContent><Choice Requires=\"w15\"><r><t>INNER</t></r></Choice><Fallback><r><t>LAST</t></r></Fallback></AlternateContent></Fallback>",
  )
  let text = StringBuilder()
  for item in items {
    if item.0 == "char" {
      text.write_string(item.1)
    }
  }
  assert_eq(text.to_string(), "INNER")
}

///|
test "DOCX alternate content resolves a nested Choice in a Choice" {
  let items = docx_alternate_content_items(
    "<Choice Requires=\"wps\"><AlternateContent><Choice Requires=\"c14\"><drawing/></Choice><Fallback><r><t>NESTED</t></r></Fallback></AlternateContent></Choice>" +
    "<Fallback><r><t>OUTER</t></r></Fallback>",
  )
  let text = StringBuilder()
  for item in items {
    if item.0 == "char" {
      text.write_string(item.1)
    }
  }
  assert_eq(text.to_string(), "NESTED")
}

///|
test "DOCX alternate content without Fallback yields Choice text" {
  let items = docx_alternate_content_items(
    "<Choice Requires=\"c14\"><r><t>NEVER</t></r></Choice>" +
    "<Choice Requires=\"w15\"><r><t>PICKED</t></r></Choice>",
  )
  let text = StringBuilder()
  for item in items {
    if item.0 == "char" {
      text.write_string(item.1)
    }
  }
  assert_eq(text.to_string(), "PICKED")
}
