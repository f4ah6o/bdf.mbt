///|
test "XLSX icon sets draw coloured traffic lights" {
  let encoded = "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"
  let data = @base64.decode(encoded[:]) catch { _ => b"" }
  let result = convert_plain_no_fonts(data)
  let doc = @core.open_single(result.bdf)
  let mut paths = 0
  let mut red = false
  let mut yellow = false
  let mut green = false
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
          let value = color.to_uint()
          if value == 0xe0301effU {
            red = true
          } else if value == 0xffb628ffU {
            yellow = true
          } else if value == 0x1d9e48ffU {
            green = true
          }
        }
        FillPath(_, _) => paths += 1
        _ => ()
      }
    }
  }
  assert_eq(paths, 3)
  assert_true(red)
  assert_true(yellow)
  assert_true(green)
}
