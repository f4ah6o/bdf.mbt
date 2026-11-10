///|
// Tests for the paragraph marks of DOCX headers and footers: the MARK that
// starts a paragraph, the MARK that starts each following line, and the reset
// between paragraphs. The documents are built as stored ZIP packages, so a
// test shows the WordprocessingML it uses.
//
// Every expectation comes from the model below. The model reads the case
// description (outline levels, text segments and explicit breaks) and never
// calls the marking code it checks, so a change that drops a mark or keeps
// paragraph state across a paragraph boundary fails here.

///|
/// The paragraph marks `docx_mark_line` writes. Language marks share the
/// command stream, so the tests keep only the four kinds they check.
fn docx_story_marks(
  commands : Array[@render.Command],
) -> Array[(Int32, String)] {
  let marks : Array[(Int32, String)] = []
  for command in commands {
    match command {
      @render.Mark(kind, payload) =>
        if kind == @core.MARK_PARAGRAPH.to_int() ||
          kind == @core.MARK_LINE.to_int() ||
          kind == @core.MARK_WRAP.to_int() ||
          kind == @core.MARK_HEADING.to_int() {
          marks.push((kind, payload))
        }
      _ => ()
    }
  }
  marks
}

///|
/// A compact spelling of a mark sequence: `P` starts a paragraph, `H1`..`H6`
/// start a heading, `L` starts a line and `W` starts a wrapped line.
fn docx_story_mark_text(marks : Array[(Int32, String)]) -> String {
  let out = StringBuilder()
  for index, mark in marks {
    if index > 0 {
      out.write_string(" ")
    }
    let (kind, payload) = mark
    if kind == @core.MARK_PARAGRAPH.to_int() {
      out.write_string("P")
    } else if kind == @core.MARK_HEADING.to_int() {
      out.write_string("H" + payload)
    } else if kind == @core.MARK_LINE.to_int() {
      out.write_string("L")
    } else if kind == @core.MARK_WRAP.to_int() {
      out.write_string("W")
    } else {
      out.write_string("?" + kind.to_string())
    }
  }
  out.to_string()
}

///|
/// The paragraph marks of the first page's header or footer layer.
fn docx_story_marks_of(
  role : String,
  root : String,
) -> Array[(Int32, String)] raise {
  let body = "<w:p><w:r><w:t>Body</w:t></w:r></w:p>"
  let result = if role == "header" {
    convert(docx_test_story_document(body, header=root))
  } else {
    convert(docx_test_story_document(body, footer=root))
  }
  docx_story_marks(docx_test_page_commands(result, "pages", 0, role))
}

///|
/// One line of a story paragraph as the model expects it: the text it holds
/// and the characters at its two edges. An empty line has NUL at both edges,
/// which is what `docx_line_edges` reports for a line without text.
struct DocxStoryLine {
  text : String
  first : Char
  last : Char
}

///|
/// One paragraph of a story: its outline level (-1 for a plain paragraph) and
/// the text segments separated by explicit breaks.
struct DocxStoryParagraph {
  outline : Int
  segments : Array[String]
}

///|
/// The width of the header text: a 12240 twip page less 1440 twips on each
/// side, in points.
const DOCX_STORY_WIDTH : Double = 468.0

///|
/// The advance of one character at the default 10pt size: a space is a
/// quarter em, an East Asian character a full em, and anything else 0.55 em.
fn docx_story_advance(c : Char) -> Double {
  if c == ' ' {
    2.5
  } else if docx_story_wide(c) {
    10.0
  } else {
    5.5
  }
}

///|
/// Whether `c` is an East Asian character, which the layout sets a full em
/// wide.
fn docx_story_wide(c : Char) -> Bool {
  c.to_int() >= 0x2e80 || c == '\u{3000}'
}

///|
/// Whether a line ending in `a` and a line starting in `b` join without a
/// space. Word breaks lines between East Asian characters, so a boundary that
/// touches one of them joins; a break space at the end of the first line
/// keeps the two lines apart.
fn docx_story_joins(a : Char, b : Char) -> Bool {
  a.to_int() != 0 &&
  b.to_int() != 0 &&
  a != ' ' &&
  a != '\u{3000}' &&
  a != '\u{2009}' &&
  a != '\u{2002}' &&
  a != '\u{2003}' &&
  (docx_story_wide(a) || docx_story_wide(b))
}

///|
/// The lines a paragraph produces: greedy character wrapping at the header
/// width, with an explicit break ending a line only when the line has
/// content. A paragraph without content still occupies one empty line.
fn docx_story_lines(segments : Array[String]) -> Array[DocxStoryLine] {
  let lines : Array[DocxStoryLine] = []
  let current : Array[Char] = []
  let mut width = 0.0
  fn push_line() -> Unit {
    let text = StringBuilder()
    for c in current {
      text.write_char(c)
    }
    let first = if current.is_empty() {
      '\u{0}'
    } else {
      current[0]
    }
    let last = if current.is_empty() {
      '\u{0}'
    } else {
      current[current.length() - 1]
    }
    lines.push({ text: text.to_string(), first, last })
    current.clear()
    width = 0.0
  }
  for index, segment in segments {
    if index > 0 && !current.is_empty() {
      push_line()
    }
    for c in segment {
      let advance = docx_story_advance(c)
      if width + advance > DOCX_STORY_WIDTH && !current.is_empty() {
        if c == ' ' {
          // A space that does not fit is not drawn.
          continue
        }
        let mut space = -1
        for i in 0..<current.length() {
          if current[i] == ' ' {
            space = i
          }
        }
        if space >= 0 && space < current.length() - 1 {
          // The line breaks at its last space, which stays on the line.
          let moved : Array[Char] = []
          for i in (space + 1)..<current.length() {
            moved.push(current[i])
          }
          while current.length() > space + 1 {
            ignore(current.pop())
          }
          push_line()
          for c in moved {
            current.push(c)
            width += docx_story_advance(c)
          }
        } else {
          push_line()
        }
      }
      current.push(c)
      width += advance
    }
  }
  if !current.is_empty() {
    push_line()
  }
  if lines.is_empty() {
    lines.push({ text: "", first: '\u{0}', last: '\u{0}' })
  }
  lines
}

///|
/// The marks a story should emit for `paragraphs`, computed from the case
/// description alone.
fn docx_story_expected(
  paragraphs : Array[DocxStoryParagraph],
) -> Array[(Int32, String)] {
  let marks : Array[(Int32, String)] = []
  for paragraph in paragraphs {
    let lines = docx_story_lines(paragraph.segments)
    for index, line in lines {
      if index == 0 {
        if paragraph.outline >= 0 &&
          paragraph.outline < 6 &&
          paragraph.outline != 9 {
          marks.push((
            @core.MARK_HEADING.to_int(),
            (paragraph.outline + 1).to_string(),
          ))
        } else {
          marks.push((@core.MARK_PARAGRAPH.to_int(), ""))
        }
      } else {
        let previous = lines[index - 1]
        if docx_story_joins(previous.last, line.first) {
          marks.push((@core.MARK_WRAP.to_int(), ""))
        } else {
          marks.push((@core.MARK_LINE.to_int(), ""))
        }
      }
    }
  }
  marks
}

///|
/// The WordprocessingML of one story paragraph.
fn docx_story_paragraph_xml(paragraph : DocxStoryParagraph) -> String {
  let out = StringBuilder()
  out.write_string("<w:p>")
  if paragraph.outline >= 0 {
    out.write_string(
      "<w:pPr><w:outlineLvl w:val=\"" +
      paragraph.outline.to_string() +
      "\"/></w:pPr>",
    )
  }
  for index, segment in paragraph.segments {
    if index > 0 {
      out.write_string("<w:r><w:br/></w:r>")
    }
    if segment != "" {
      out.write_string(
        "<w:r><w:t xml:space=\"preserve\">" + segment + "</w:t></w:r>",
      )
    }
  }
  out.write_string("</w:p>")
  out.to_string()
}

///|
/// The WordprocessingML of a whole story.
fn docx_story_xml(paragraphs : Array[DocxStoryParagraph]) -> String {
  let out = StringBuilder()
  for paragraph in paragraphs {
    out.write_string(docx_story_paragraph_xml(paragraph))
  }
  out.to_string()
}

///|
/// A readable spelling of a case, so a failure names the document it came
/// from.
fn docx_story_describe(paragraphs : Array[DocxStoryParagraph]) -> String {
  let out = StringBuilder()
  for index, paragraph in paragraphs {
    if index > 0 {
      out.write_string(" | ")
    }
    out.write_string("outline=" + paragraph.outline.to_string() + " [")
    for segment_index, segment in paragraph.segments {
      if segment_index > 0 {
        out.write_string(" / ")
      }
      out.write_string(segment)
    }
    out.write_string("]")
  }
  out.to_string()
}

///|
/// The lines the model expects, so a failure shows where the two sequences
/// part.
fn docx_story_lines_text(paragraphs : Array[DocxStoryParagraph]) -> String {
  let out = StringBuilder()
  let mut first = true
  for paragraph in paragraphs {
    for line in docx_story_lines(paragraph.segments) {
      if !first {
        out.write_string(" / ")
      }
      first = false
      out.write_string("[" + line.text + "]")
    }
  }
  out.to_string()
}

///|
/// A deterministic xorshift32 generator. The seed is part of the test name, so
/// a failure can be replayed with the same cases.
struct DocxStoryRng {
  mut state : Int64
}

///|
fn docx_story_rng(seed : Int64) -> DocxStoryRng {
  { state: if seed == 0L { 0x2545F491L } else { seed } }
}

///|
fn DocxStoryRng::next(self : DocxStoryRng) -> Int64 {
  let mut x = self.state
  x = x ^ ((x << 13) & 0x7FFFFFFFL)
  x = x ^ (x >> 17)
  x = x ^ ((x << 5) & 0x7FFFFFFFL)
  self.state = x
  x
}

///|
fn DocxStoryRng::below(self : DocxStoryRng, bound : Int) -> Int {
  (self.next() % bound.to_int64()).to_int()
}

///|
/// The East Asian characters the generated cases draw from. They are a full em
/// wide, so the model can predict where a line wraps.
let docx_story_wide_chars : Array[Char] = ['あ', '漢', 'ア', '字']

///|
/// The Latin characters the generated cases draw from. They are 0.55 em wide.
let docx_story_narrow_chars : Array[Char] = ['a', 'b', 'c', 'X', 'Y', 'Z']

///|
fn docx_story_text(rng : DocxStoryRng, length : Int) -> String {
  let out = StringBuilder()
  for _ in 0..<length {
    let pick = rng.below(10)
    if pick < 5 {
      out.write_char(docx_story_wide_chars[rng.below(4)])
    } else if pick < 9 {
      out.write_char(docx_story_narrow_chars[rng.below(6)])
    } else {
      out.write_char(' ')
    }
  }
  out.to_string()
}

///|
/// One generated paragraph. Outline levels cover the heading boundaries: 0..5
/// are headings, 6..9 and -1 are plain paragraphs.
fn docx_story_paragraph(rng : DocxStoryRng) -> DocxStoryParagraph {
  let outline = if rng.below(4) == 0 {
    rng.below(11) - 1
  } else {
    -1
  }
  let segments : Array[String] = []
  let count = 1 + rng.below(3)
  for _ in 0..<count {
    let kind = rng.below(10)
    let length = if kind < 3 {
      0
    } else if kind < 7 {
      1 + rng.below(12)
    } else {
      20 + rng.below(120)
    }
    segments.push(docx_story_text(rng, length))
  }
  { outline, segments }
}

///|
/// What the generated cases covered. A generator that stops producing wrapped
/// lines, headings or paragraph boundaries that would join fails on these
/// counts instead of passing vacuously.
struct DocxStoryCoverage {
  mut paragraphs : Int
  mut headings : Int
  mut wraps : Int
  mut lines : Int
  mut joins : Int
}

///|
/// Check `cases` generated stories against the model. A mismatch reports the
/// seed, the case number and the document, so the failure can be replayed.
fn docx_story_check(role : String, seed : Int64, cases : Int) -> Unit raise {
  let rng = docx_story_rng(seed)
  let coverage : DocxStoryCoverage = {
    paragraphs: 0,
    headings: 0,
    wraps: 0,
    lines: 0,
    joins: 0,
  }
  for case_index in 0..<cases {
    let paragraphs : Array[DocxStoryParagraph] = []
    let count = 1 + rng.below(5)
    for _ in 0..<count {
      paragraphs.push(docx_story_paragraph(rng))
    }
    let expected = docx_story_mark_text(docx_story_expected(paragraphs))
    let actual = docx_story_mark_text(
      docx_story_marks_of(role, docx_story_xml(paragraphs)),
    )
    if actual != expected {
      fail(
        role +
        " seed " +
        seed.to_string() +
        " case " +
        case_index.to_string() +
        ": expected [" +
        expected +
        "] got [" +
        actual +
        "] for " +
        docx_story_describe(paragraphs) +
        " lines " +
        docx_story_lines_text(paragraphs),
      )
    }
    coverage.paragraphs += paragraphs.length()
    for index, paragraph in paragraphs {
      let lines = docx_story_lines(paragraph.segments)
      if paragraph.outline >= 0 && paragraph.outline < 6 {
        coverage.headings += 1
      }
      for line_index, line in lines {
        if line_index > 0 {
          if docx_story_joins(lines[line_index - 1].last, line.first) {
            coverage.wraps += 1
          } else {
            coverage.lines += 1
          }
        }
      }
      // A boundary that would join if the paragraph state leaked.
      if index > 0 {
        let previous = docx_story_lines(paragraphs[index - 1].segments)
        if docx_story_joins(
          previous[previous.length() - 1].last,
          lines[0].first,
        ) {
          coverage.joins += 1
        }
      }
    }
  }
  let report = role +
    " seed " +
    seed.to_string() +
    " covered paragraphs=" +
    coverage.paragraphs.to_string() +
    " headings=" +
    coverage.headings.to_string() +
    " wraps=" +
    coverage.wraps.to_string() +
    " lines=" +
    coverage.lines.to_string() +
    " joins=" +
    coverage.joins.to_string()
  assert_true(coverage.paragraphs > 0, msg=report)
  assert_true(coverage.headings > 0, msg=report)
  assert_true(coverage.wraps > 0, msg=report)
  assert_true(coverage.lines > 0, msg=report)
  assert_true(coverage.joins > 0, msg=report)
}

///|
/// Check one story against an expected mark sequence, reporting both
/// sequences when they differ.
fn docx_story_assert(
  role : String,
  root : String,
  expected : String,
  msg : String,
) -> Unit raise {
  let actual = docx_story_mark_text(docx_story_marks_of(role, root))
  if actual != expected {
    fail(msg + ": expected [" + expected + "] got [" + actual + "]")
  }
}

///|
test "DOCX story paragraph marks: header paragraphs in order" {
  docx_story_assert(
    "header",
    "<w:p><w:r><w:t>Header</w:t></w:r></w:p>" +
    "<w:p><w:pPr><w:outlineLvl w:val=\"0\"/></w:pPr>" +
    "<w:r><w:t>Title</w:t></w:r></w:p>" +
    "<w:p><w:r><w:t>One</w:t></w:r><w:r><w:br/></w:r>" +
    "<w:r><w:t>Two</w:t></w:r></w:p>",
    "P H1 P L",
    "header paragraph marks",
  )
}

///|
test "DOCX story paragraph marks: footer paragraphs in order" {
  docx_story_assert(
    "footer",
    "<w:p><w:r><w:t>Footer</w:t></w:r></w:p>" +
    "<w:p><w:pPr><w:outlineLvl w:val=\"1\"/></w:pPr>" +
    "<w:r><w:t>Sub</w:t></w:r></w:p>" +
    "<w:p><w:r><w:t>One</w:t></w:r><w:r><w:br/></w:r>" +
    "<w:r><w:t>Two</w:t></w:r></w:p>",
    "P H2 P L",
    "footer paragraph marks",
  )
}

///|
test "DOCX story paragraph marks: empty paragraph keeps its mark" {
  docx_story_assert(
    "header",
    "<w:p><w:r><w:t>あ</w:t></w:r></w:p>" +
    "<w:p/>" +
    "<w:p><w:r><w:t>い</w:t></w:r></w:p>",
    "P P P",
    "an empty paragraph starts a paragraph and resets the join",
  )
}

///|
test "DOCX story paragraph marks: heading levels" {
  let out = StringBuilder()
  for level in 0..<10 {
    out.write_string(
      "<w:p><w:pPr><w:outlineLvl w:val=\"" +
      level.to_string() +
      "\"/></w:pPr><w:r><w:t>H</w:t></w:r></w:p>",
    )
  }
  out.write_string("<w:p><w:r><w:t>Plain</w:t></w:r></w:p>")
  docx_story_assert(
    "header",
    out.to_string(),
    "H1 H2 H3 H4 H5 H6 P P P P P",
    "outline levels 0..5 are headings, 6..9 and none are paragraphs",
  )
}

///|
test "DOCX story paragraph marks: soft wrap joins East Asian lines" {
  let text = docx_test_repeat("あ", 120)
  // 120 full-width characters at 10pt fill 46 per 468pt line: 46, 46, 28.
  docx_story_assert(
    "header",
    "<w:p><w:r><w:t>" + text + "</w:t></w:r></w:p>",
    "P W W",
    "East Asian soft wraps are WRAP marks",
  )
}

///|
test "DOCX story paragraph marks: soft wrap breaks Latin lines" {
  let text = docx_test_repeat("a", 200)
  // 200 narrow characters at 5.5pt fill 85 per 468pt line: 85, 85, 30.
  docx_story_assert(
    "header",
    "<w:p><w:r><w:t>" + text + "</w:t></w:r></w:p>",
    "P L L",
    "Latin soft wraps are LINE marks",
  )
}

///|
test "DOCX story paragraph marks: explicit break keeps the boundary rule" {
  docx_story_assert(
    "header",
    "<w:p><w:r><w:t>One</w:t></w:r><w:r><w:br/></w:r>" +
    "<w:r><w:t>Two</w:t></w:r></w:p>" +
    "<w:p><w:r><w:t>あ</w:t></w:r><w:r><w:br/></w:r>" +
    "<w:r><w:t>い</w:t></w:r></w:p>",
    "P L P W",
    "the mark follows the characters at the boundary, not the break kind",
  )
}

///|
test "DOCX story paragraph marks: reset between paragraphs" {
  docx_story_assert(
    "header",
    "<w:p><w:r><w:t>あ</w:t></w:r></w:p>" +
    "<w:p><w:r><w:t>い</w:t></w:r></w:p>" +
    "<w:p><w:r><w:t>a</w:t></w:r></w:p>" +
    "<w:p><w:r><w:t>b</w:t></w:r></w:p>",
    "P P P P",
    "a paragraph never continues the previous one",
  )
}

///|
test "DOCX story paragraph marks: a trailing break adds no line" {
  docx_story_assert(
    "header",
    "<w:p><w:r><w:t>One</w:t></w:r><w:r><w:br/></w:r></w:p>" +
    "<w:p><w:r><w:br/></w:r></w:p>" +
    "<w:p><w:r><w:br/></w:r><w:r><w:t>Two</w:t></w:r></w:p>",
    "P P P",
    "a break without content does not start a line",
  )
}

///|
test "DOCX story paragraph marks: a line without text does not join" {
  // The field result is regenerated, so the line holds a field item and no
  // text: `docx_line_edges` reports NUL at both edges and the next line is a
  // LINE, not a WRAP.
  docx_story_assert(
    "header",
    "<w:p><w:r><w:fldChar w:fldCharType=\"begin\"/></w:r>" +
    "<w:r><w:instrText> PAGE </w:instrText></w:r>" +
    "<w:r><w:fldChar w:fldCharType=\"separate\"/></w:r>" +
    "<w:r><w:t>1</w:t></w:r>" +
    "<w:r><w:fldChar w:fldCharType=\"end\"/></w:r>" +
    "<w:r><w:br/></w:r><w:r><w:t>あ</w:t></w:r></w:p>",
    "P L",
    "a line whose only content is a field has no text edge",
  )
}

///|
test "DOCX story paragraph marks: an empty story has no marks" {
  docx_story_assert(
    "header",
    "",
    "",
    "a header without paragraphs emits no layer",
  )
}

///|
test "DOCX story paragraph marks: each mark precedes its line text" {
  let commands = docx_test_page_commands(
    convert(docx_test_story_document(
      "<w:p><w:r><w:t>Body</w:t></w:r></w:p>",
      header="<w:p><w:r><w:t>One</w:t></w:r><w:r><w:br/></w:r>" +
      "<w:r><w:t>Two</w:t></w:r></w:p>",
    )),
    "pages",
    0,
    "header",
  )
  let mut pending = 0
  let mut seen = 0
  for command in commands {
    match command {
      @render.Mark(kind, _) =>
        if kind == @core.MARK_PARAGRAPH.to_int() ||
          kind == @core.MARK_LINE.to_int() ||
          kind == @core.MARK_WRAP.to_int() ||
          kind == @core.MARK_HEADING.to_int() {
          pending += 1
        }
      @render.FillText(_, _, _, _) => {
        assert_true(pending > 0, msg="a line draws text only after its mark")
        pending = 0
        seen += 1
      }
      _ => ()
    }
  }
  assert_eq(seen, 2, msg="two lines of text")
}

///|
test "DOCX story paragraph marks: property seed 1" {
  docx_story_check("header", 1L, 12)
  docx_story_check("footer", 1L, 12)
}

///|
test "DOCX story paragraph marks: property seed 2" {
  docx_story_check("header", 2L, 12)
  docx_story_check("footer", 2L, 12)
}

///|
test "DOCX story paragraph marks: property seed 42" {
  docx_story_check("header", 42L, 12)
  docx_story_check("footer", 42L, 12)
}

///|
test "DOCX story paragraph marks: property seed 20261110" {
  docx_story_check("header", 20261110L, 12)
  docx_story_check("footer", 20261110L, 12)
}

///|
test "DOCX story paragraph marks: property seed 4294967295" {
  docx_story_check("header", 4294967295L, 12)
  docx_story_check("footer", 4294967295L, 12)
}
