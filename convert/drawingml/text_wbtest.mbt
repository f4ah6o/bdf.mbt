///|
test "DrawingML text wraps and aligns" {
  let style = TextStyle::new(size=12.0)
  let body : TextBody = {
    paragraphs: [
      TextParagraph::{
        runs: [{ text: "abcdefghij", style }],
        align: 0,
      },
      TextParagraph::{
        runs: [{ text: "center", style }],
        align: 1,
      },
    ],
  }
  let (lines, overflow) = layout(body, { x: 10.0, y: 20.0, width: 30.0, height: 100.0 })
  assert_eq(overflow, false)
  assert_eq(lines.length() >= 3, true)
  assert_eq(lines[0].x, 10.0)
  assert_eq(lines[lines.length() - 1].align, 1)
  assert_eq(lines[lines.length() - 1].x > 10.0, true)
}

///|
test "DrawingML text flows through frames" {
  let style = TextStyle::new(size=10.0)
  let body : TextBody = {
    paragraphs: [
      TextParagraph::{ runs: [{ text: "one two three four five six", style }], align: 0 },
    ],
  }
  let (pages, overflow) = flow(
    body,
    [
      { x: 0.0, y: 0.0, width: 40.0, height: 15.0 },
      { x: 0.0, y: 0.0, width: 40.0, height: 60.0 },
    ],
  )
  assert_eq(overflow, false)
  assert_eq(pages[0].length() > 0, true)
  assert_eq(pages[1].length() > 0, true)
}

///|
test "DrawingML text reports overflow" {
  let style = TextStyle::new(size=20.0)
  let body : TextBody = {
    paragraphs: [{ runs: [{ text: "too much text for the frame", style }], align: 0 }],
  }
  let (lines, overflow) = layout(body, { x: 0.0, y: 0.0, width: 40.0, height: 25.0 })
  assert_eq(overflow, true)
  assert_eq(lines.length(), 1)
}
