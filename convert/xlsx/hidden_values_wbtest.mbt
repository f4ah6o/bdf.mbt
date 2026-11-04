///|
test "XLSX icon sets with showValue false hide the cell text" {
  let encoded = "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"
  let data = @base64.decode(encoded[:]) catch { _ => b"" }
  let result = convert_plain_no_fonts(data)
  let doc = @core.open_single(result.bdf)
  let mut icons = 0
  let mut texts = 0
  for part in doc.manifest.parts {
    if part.kind != "obj" {
      continue
    }
    let resources = @core.decode_object_resources(doc.part(part.hash)) catch {
      _ => continue
    }
    for command in @render.compile_object(resources.object) {
      match command {
        FillPath(_, _) => icons += 1
        FillText(_, _, _, _) => texts += 1
        _ => ()
      }
    }
  }
  assert_eq(icons, 3)
  assert_eq(texts, 0)
}
