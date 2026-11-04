///|
test "XLSX negative data bars use an axis, negative colour and border" {
  let encoded = "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"
  let data = @base64.decode(encoded[:]) catch { _ => b"" }
  let result = convert_plain_no_fonts(data)
  let doc = @core.open_single(result.bdf)
  let mut fills = 0
  let mut strokes = 0
  let mut blue = false
  let mut red = false
  for part in doc.manifest.parts {
    if part.kind != "obj" {
      continue
    }
    let resources = @core.decode_object_resources(doc.part(part.hash)) catch {
      _ => continue
    }
    for command in @render.compile_object(resources.object) {
      match command {
        FillColor(color) => {
          if color.to_uint() == 0x00b0f0ffU {
            blue = true
          } else if color.to_uint() == 0xff0000ffU {
            red = true
          }
        }
        FillRect(_, _, _, _) => fills += 1
        StrokePath(_) => strokes += 1
        _ => ()
      }
    }
  }
  assert_eq(fills, 4)
  assert_eq(strokes, 4)
  assert_true(blue)
  assert_true(red)
}
