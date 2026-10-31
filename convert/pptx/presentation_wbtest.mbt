///|
fn check_pptx_manifest(
  name : String,
  chunks : Array[String],
  part : String,
  width : Double,
  height : Double,
  first_slide : Int64,
  slides : Array[(String, Bool)],
  contexts : Array[(String, String, Bool, Bool, Array[(String, String)])],
  placeholders : Array[
    (
      Array[(String, String?)],
      Array[(String, String?)],
      Array[(String, String?)],
    ),
  ],
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
    let (slide_ph, layout_ph, master_ph) = placeholders[i]
    let load_ph = fn(part : String) -> Array[(String, String?)] raise {
      if part == "" {
        return []
      }
      pptx_placeholders(package, part).map(fn(ph) { (ph.kind, ph.index) })
    }
    let context = pptx_slide_context(package, slide_part)
    let (layout_part, master_part, draw_layout, draw_master, colors) = contexts[i]
    assert_eq(
      load_ph(slide_part),
      slide_ph,
      msg="\{name} slide placeholders \{i}",
    )
    assert_eq(
      load_ph(layout_part),
      layout_ph,
      msg="\{name} layout placeholders \{i}",
    )
    assert_eq(
      load_ph(master_part),
      master_ph,
      msg="\{name} master placeholders \{i}",
    )
    assert_eq(context.color_map.length(), colors.length())
    for (key, value) in colors {
      let mut found = false
      for (actual_key, actual_value) in context.color_map {
        if key == actual_key && value == actual_value {
          found = true
        }
      }
      assert_true(found)
    }
    assert_eq(
      (
        context.layout_part,
        context.master_part,
        context.draw_layout,
        context.draw_master,
      ),
      (layout_part, master_part, draw_layout, draw_master),
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
