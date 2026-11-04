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
