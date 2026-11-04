///|
fn markdown_test_fixture(text : String) -> Bytes {
  @gzip.decompress(@base64.decode(text[:], ignore_whitespace=true)[:]) catch {
    _ => b""
  }
}

///|
fn markdown_text_of_view(doc : @core.Document, view : @core.View) -> String raise {
  let mut text = ""
  for run in @core.decode_text_index(doc.part(view.text_index.unwrap())) {
    text += run.text
  }
  text
}

///|
fn markdown_image_parts(doc : @core.Document) -> Array[@core.Part] {
  let parts : Array[@core.Part] = []
  for part in doc.manifest.parts {
    if part.kind == "img" {
      parts.push(part)
    }
  }
  parts
}

///|
test "Markdown reader pages and metadata" {
  let data = markdown_test_fixture(markdown_basic_fixture)
  let result = convert(data)
  assert_eq(result.pages > 0, true)
  let doc = @core.open_single(result.bdf)
  let view = doc.manifest.views[0]
  assert_eq(view.kind, "scroll")
  assert_eq(view.pages.length(), 1)
  assert_eq(result.pages, 1)
  assert_eq(view.text_index.is_empty(), false)
}

///|
test "Markdown headings, code, lists and text" {
  let data = markdown_test_fixture(markdown_basic_fixture)
  let result = convert(data)
  let doc = @core.open_single(result.bdf)
  let index = @core.decode_text_index(doc.part(doc.manifest.views[0].text_index.unwrap()))
  let mut text = ""
  for run in index {
    text += run.text
  }
  for want in ["Markdown のテスト文書", "見出し", "func main()", "完了したタスク", "リンク"] {
    assert_eq(text.contains(want), true)
  }
}

///|
test "Markdown inline SVG blocks, symbols and relative images" {
  let source = "<svg viewBox=\"0 0 400 100\" role=\"img\" aria-label=\"Bars\"><rect width=\"400\" height=\"100\" fill=\"#f6f8fa\"/><rect x=\"30\" y=\"70\" width=\"60\" height=\"30\" fill=\"url(#bar)\"/></svg>\n\n" +
    "![Passing](images/badge.svg) ![Done](images/check.svg) <svg width=\"24\" height=\"24\" viewBox=\"0 0 16 16\" aria-label=\"Dot\"><use href=\"#dot\"/></svg>\n\n" +
    "<svg style=\"display:none\"><symbol id=\"dot\" viewBox=\"0 0 16 16\"><circle cx=\"8\" cy=\"8\" r=\"6\" fill=\"currentColor\"/></symbol><linearGradient id=\"bar\" x1=\"0\" y1=\"0\" x2=\"0\" y2=\"1\"><stop offset=\"0\" stop-color=\"#1a7f37\"/><stop offset=\"1\" stop-color=\"#4ac26b\"/></linearGradient></svg>\n\n" +
    "# SVG images\n\nThe chart comes from its markup.\n"
  let result = convert(@utf8.encode(source))
  let doc = @core.open_single(result.bdf)
  let images = markdown_image_parts(doc)
  assert_eq(images.length(), 2)
  let view = doc.manifest.views[0]
  assert_eq(view.kind, "scroll")
  let text = markdown_text_of_view(doc, view)
  for want in ["Passing", "Done", "SVG images", "chart comes from its markup"] {
    assert_eq(text.contains(want), true)
  }
  let mut warned_badge = false
  let mut warned_check = false
  for warning in result.warnings {
    if warning.contains("images/badge.svg") {
      warned_badge = true
    }
    if warning.contains("images/check.svg") {
      warned_check = true
    }
  }
  assert_eq(warned_badge, true)
  assert_eq(warned_check, true)
}

///|
test "Markdown borrows definitions from a multi-line sprite sheet" {
  let source = "<svg style=\"display:none\">\n" +
    "<symbol id=\"dot\" viewBox=\"0 0 16 16\"><circle cx=\"8\" cy=\"8\" r=\"6\" fill=\"currentColor\"/></symbol>\n" +
    "</svg>\n\n" +
    "<svg width=\"24\" height=\"24\" viewBox=\"0 0 16 16\" aria-label=\"Dot\"><use href=\"#dot\"/></svg>\n"
  let result = convert(@utf8.encode(source))
  let doc = @core.open_single(result.bdf)
  assert_eq(markdown_image_parts(doc).length(), 1)
  assert_eq(result.warnings.length(), 0)
}

test "Markdown data URI SVG image is drawn without its alternative text" {
  let source = "before ![a drawn mark](data:image/svg+xml,%3Csvg%20xmlns='http://www.w3.org/2000/svg'%20width='40'%20height='20'%3E%3Crect%20width='40'%20height='20'%20fill='%230969da'/%3E%3C/svg%3E) after"
  let result = convert(@utf8.encode(source))
  let doc = @core.open_single(result.bdf)
  assert_eq(markdown_image_parts(doc).length(), 1)
  let text = markdown_text_of_view(doc, doc.manifest.views[0])
  assert_eq(text.contains("before"), true)
  assert_eq(text.contains("after"), true)
  assert_eq(text.contains("a drawn mark"), false)
  assert_eq(result.warnings.length(), 0)
}

///|
test "Markdown pages view paginates with page text indexes" {
  let source = StringBuilder::new()
  for i in 0..<8 {
    source.write_string("# Heading \{i}\n\n")
    source.write_string("word ".repeat(120))
    source.write_string("\n\n")
  }
  let data = @utf8.encode(source.to_string())
  let result = convert(data, views="pages")
  let doc = @core.open_single(result.bdf)
  assert_eq(doc.manifest.views.length(), 1)
  let view = doc.manifest.views[0]
  assert_eq(view.id, "pages")
  assert_eq(view.kind, "fixed")
  assert_eq(view.pages.length() > 1, true)
  assert_eq(result.pages, view.pages.length())
  for page in view.pages {
    assert_eq(page.width, 504.0)
    assert_eq(page.height, 769.9)
  }
  let runs = @core.decode_text_index(doc.part(view.text_index.unwrap()))
  let pages_seen : Map[Int32, Bool] = Map([])
  for run in runs {
    assert_eq(run.a >= 0 && run.a < view.pages.length(), true)
    pages_seen[run.a] = true
  }
  for i in 0..<view.pages.length() {
    assert_eq(pages_seen.contains(i), true)
  }
}

///|
test "Markdown both view keeps the scroll view and adds pages" {
  let source = "# A heading\n\n" + "long text ".repeat(200)
  let data = @utf8.encode(source)
  let result = convert(data, views="both")
  let doc = @core.open_single(result.bdf)
  assert_eq(doc.manifest.views.length(), 2)
  assert_eq(doc.manifest.views[0].id, "pages")
  assert_eq(doc.manifest.views[0].kind, "fixed")
  assert_eq(doc.manifest.views[1].id, "scroll")
  assert_eq(doc.manifest.views[1].kind, "scroll")
  assert_eq(doc.manifest.views[1].pages.length(), 1)
  assert_eq(doc.manifest.views[1].pages[0].width, 504.0)
  assert_eq(result.pages, doc.manifest.views[0].pages.length())
  let scroll_only = convert(data)
  assert_eq(result.warnings, scroll_only.warnings)
}

///|
test "Markdown footnote references are numbered by first use and skip code" {
  let source = "First [^b], then [^a], and `[^a]` is code.\n\n" +
    "[^a]: A note\n[^b]: B note\n"
  let result = convert(@utf8.encode(source))
  let doc = @core.open_single(result.bdf)
  let text = markdown_text_of_view(doc, doc.manifest.views[0])
  assert_eq(text.contains("[^a]"), true)
  assert_eq(text.contains("1. B note"), true)
  assert_eq(text.contains("2. A note"), true)
}

///|
test "Markdown fenced code keeps footnote definitions as code" {
  let source = "```\n[^1]: not a definition\n```\n\nText [^1].\n"
  let result = convert(@utf8.encode(source))
  let doc = @core.open_single(result.bdf)
  let text = markdown_text_of_view(doc, doc.manifest.views[0])
  assert_eq(text.contains("[^1]: not a definition"), true)
  assert_eq(text.contains("Text [^1]."), true)
}

///|
test "Markdown definition lists keep every definition" {
  let source = "Term\n: first definition\n: second definition\n"
  let result = convert(@utf8.encode(source))
  let doc = @core.open_single(result.bdf)
  let text = markdown_text_of_view(doc, doc.manifest.views[0])
  assert_eq(text.contains("Term"), true)
  assert_eq(text.contains("first definition"), true)
  assert_eq(text.contains("second definition"), true)
  assert_eq(text.contains(": second definition"), false)
}

///|
test "Markdown raw HTML skips script and style contents and warns about img" {
  let source = "<div>visible<script>hidden()</script><style>p{color:red}</style></div>\n\n" +
    "<p><img src='images/picture.png' alt='single quoted'></p>\n"
  let result = convert(@utf8.encode(source))
  let doc = @core.open_single(result.bdf)
  let text = markdown_text_of_view(doc, doc.manifest.views[0])
  assert_eq(text.contains("visible"), true)
  assert_eq(text.contains("hidden()"), false)
  assert_eq(text.contains("color:red"), false)
  assert_eq(text.contains("single quoted"), true)
  let mut warned = false
  for warning in result.warnings {
    if warning.contains("images/picture.png") {
      warned = true
    }
  }
  assert_eq(warned, true)
}

///|
test "Markdown SVG sizing follows attributes and view box" {
  let (width, height, fill) = md_svg_size("<svg viewBox=\"0 0 400 100\">")
  assert_eq(width, 225.0)
  assert_eq(height, 56.25)
  assert_eq(fill, true)
  let (width, height, fill) = md_svg_size(
    "<svg width=\"24\" height=\"24\" viewBox=\"0 0 16 16\">",
  )
  assert_eq(width, 18.0)
  assert_eq(height, 18.0)
  assert_eq(fill, false)
  let (width, height, _) = md_svg_size("<svg style=\"width: 20pt; height: 10pt\">")
  assert_eq(width, 20.0)
  assert_eq(height, 10.0)
}

///|
test "Markdown default view is the scroll view" {
  let source = "# Heading\n\nA paragraph with **bold** text.\n"
  let data = @utf8.encode(source)
  assert_eq(convert(data).bdf, convert(data, views="scroll").bdf)
}

///|
test "Markdown unknown views are rejected" {
  let failed = try {
    ignore(convert(b"# x", views="tiles"))
    false
  } catch {
    MarkdownInvalid(_) => true
    _ => false
  }
  assert_eq(failed, true)
}

///|
test "Markdown emits heading, paragraph and figure marks" {
  let source = "# Heading\n\nParagraph\n\n![Alt](data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAFgwJ/lv0nWQAAAABJRU5ErkJggg==)\n"
  let result = convert(@utf8.encode(source))
  let doc = @core.open_single(result.bdf)
  let view = doc.manifest.views[0]
  let mut headings = 0
  let mut paragraphs = 0
  let mut figures = 0
  let mut ends = 0
  for page in view.pages {
    for layer in page.layers {
      for command in @render.decode_commands(doc.part(layer.object)) {
        match command {
          Mark(6, _) => headings += 1
          Mark(0, _) => paragraphs += 1
          Mark(10, _) => figures += 1
          Mark(11, _) => ends += 1
          _ => ()
        }
      }
    }
  }
  assert_eq(headings, 1)
  assert_eq(paragraphs >= 1, true)
  assert_eq(figures, 1)
  assert_eq(ends, 1)
}

test "Markdown emits list and table marks" {
  let source = "- one\n- two\n\n| A | B |\n| - | - |\n| 1 | 2 |\n"
  let result = convert(@utf8.encode(source))
  let doc = @core.open_single(result.bdf)
  let view = doc.manifest.views[0]
  let mut lists = 0
  let mut items = 0
  let mut tables = 0
  let mut cells = 0
  let mut ends = 0
  for page in view.pages {
    for layer in page.layers {
      for command in @render.decode_commands(doc.part(layer.object)) {
        match command {
          Mark(7, _) => lists += 1
          Mark(8, _) => items += 1
          Mark(9, _) => tables += 1
          Mark(2, _) => cells += 1
          Mark(11, _) => ends += 1
          _ => ()
        }
      }
    }
  }
  assert_eq(lists, 1)
  assert_eq(items, 2)
  assert_eq(tables, 1)
  assert_eq(cells, 4)
  assert_eq(ends >= 2, true)
}

test "Markdown emits line and wrap marks" {
  let mut source = ""
  for _ in 0..<20 {
    source += "word word word word word word word word "
  }
  let result = convert(@utf8.encode(source))
  let doc = @core.open_single(result.bdf)
  let view = doc.manifest.views[0]
  let mut lines = 0
  let mut wraps = 0
  for page in view.pages {
    for layer in page.layers {
      for command in @render.decode_commands(doc.part(layer.object)) {
        match command {
          Mark(1, _) => lines += 1
          Mark(5, _) => wraps += 1
          _ => ()
        }
      }
    }
  }
  assert_eq(lines >= 2, true)
  assert_eq(wraps >= 1, true)
}

test "Markdown pages split long tables and repeat headers" {
  let mut source = "# Table\n\n| H1 | H2 |\n| --- | --- |\n"
  for i in 0..<80 {
    source += "| row" + i.to_string() + " | value" + i.to_string() + " |\n"
  }
  let result = convert(@utf8.encode(source), views="pages")
  assert_eq(result.pages >= 2, true)
  let doc = @core.open_single(result.bdf)
  let view = doc.manifest.views[0]
  assert_eq(view.kind, "fixed")
  assert_eq(view.pages.length() >= 2, true)
  let page_text = fn(page : @core.Page) -> String raise {
    let mut text = ""
    for layer in page.layers {
      for command in @render.decode_commands(doc.part(layer.object)) {
        match command {
          FillText(value, _, _, _) => {
            text += value
            text += " "
          }
          _ => ()
        }
      }
    }
    text
  }
  let first = page_text(view.pages[0])
  let second = page_text(view.pages[1])
  assert_eq(first.contains("H1"), true)
  assert_eq(first.contains("row0"), true)
  assert_eq(second.contains("H1"), true)
  assert_eq(second.contains("row"), true)
}

test "Markdown repeats quote bars on every page" {
  let mut source = ""
  for i in 0..<30 {
    let mut line = "> "
    for _ in 0..<80 {
      line += "word "
    }
    line += i.to_string()
    line += "\n"
    source += line
  }
  let result = convert(@utf8.encode(source), views="pages")
  assert_eq(result.pages >= 2, true)
  let doc = @core.open_single(result.bdf)
  let view = doc.manifest.views[0]
  for page in view.pages {
    let mut bars = 0
    for layer in page.layers {
      for command in @render.decode_commands(doc.part(layer.object)) {
        match command {
          FillRect(_, _, 2.0, _) => bars += 1
          _ => ()
        }
      }
    }
    assert_eq(bars >= 1, true)
  }
}

test "Markdown front matter maps Dublin Core terms" {
  let (body, meta) = md_front_matter(
    "---\nauthor:\n  - Alice\n  - name: Bob\ndate: 2026-09-26\ntags: [bdf, markdown]\n---\nbody",
  )
  assert_eq(body, "body")
  let creators = meta.get("creator").unwrap()
  assert_eq(creators.length(), 2)
  assert_eq(creators[0], "Alice")
  assert_eq(creators[1], "Bob")
  assert_eq(meta.get("created").unwrap()[0], "2026-09-26")
  let subjects = meta.get("subject").unwrap()
  assert_eq(subjects.length(), 2)
  assert_eq(subjects[0], "bdf")
  assert_eq(subjects[1], "markdown")
}
