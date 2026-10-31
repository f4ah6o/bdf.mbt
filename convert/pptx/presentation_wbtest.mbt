///|
fn check_pptx_manifest(
  name : String,
  chunks : Array[String],
  part : String,
  width : Double,
  height : Double,
  first_slide : Int64,
  slides : Array[(String, Bool)],
  contexts : Array[(String, String, Bool, Bool)],
) -> Unit raise {
  let joined = StringBuilder()
  for chunk in chunks {
    joined.write_string(chunk)
  }
  let compressed = @base64.decode(joined.to_string()[:])
  let data = @gzip.decompress(compressed[:])
  let actual = pptx_presentation(data)
  let package = @ooxml.open_ooxml(data)
  assert_eq(actual.part, part, msg=name)
  assert_eq(actual.width, width, msg=name)
  assert_eq(actual.height, height, msg=name)
  assert_eq(actual.first_slide, first_slide, msg=name)
  assert_eq(actual.slides.length(), slides.length(), msg=name)
  for i in 0..<slides.length() {
    let (slide_part, hidden) = slides[i]
    let context = pptx_slide_context(package, slide_part)
    assert_eq(
      (
        context.layout_part,
        context.master_part,
        context.draw_layout,
        context.draw_master,
      ),
      contexts[i],
      msg="\{name} slide context \{i}",
    )
    assert_eq(
      actual.slides[i],
      { part: slide_part, hidden, },
      msg="\{name} slide \{i}",
    )
  }
}

///|
test "PPTX sizes support standard and strict units" {
  assert_eq(pptx_measure("9144000", 0.0), 720.0)
  assert_eq(pptx_measure(" 10in ", 0.0), 720.0)
  assert_eq(pptx_measure("2.54cm", 0.0), 72.0)
  assert_eq(pptx_measure("garbage", 5.0), 5.0)
}
