///|
test "XLSX color scale interpolates three stops" {
  let red = 0xff0000ffU
  let yellow = 0xffff00ffU
  let green = 0x00ff00ffU
  assert_eq(xlsx_color_scale_rgb([red, yellow, green], 0.0), red)
  assert_eq(xlsx_color_scale_rgb([red, yellow, green], 0.5), yellow)
  assert_eq(xlsx_color_scale_rgb([red, yellow, green], 1.0), green)
  assert_eq(xlsx_color_scale_rgb([red, yellow, green], 0.25), 0xff7f00ffU)
}

test "XLSX color scales paint interpolated fills" {
  let encoded = "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"
  let data = @base64.decode(encoded[:]) catch { _ => b"" }
  let result = convert_plain_no_fonts(data)
  let doc = @core.open_single(result.bdf)
  let fills : Array[UInt32] = []
  for part in doc.manifest.parts {
    if part.kind != "obj" {
      continue
    }
    let resources = @core.decode_object_resources(doc.part(part.hash)) catch {
      _ => continue
    }
    for command in @render.compile_object(resources.object) {
      match command {
        FillColor(color) => fills.push(color.to_uint())
        _ => ()
      }
    }
  }
  assert_eq(fills.contains(0xff0000ffU), true)
  assert_eq(fills.contains(0x00ff00ffU), true)
  assert_eq(fills.length() >= 4, true)
}
