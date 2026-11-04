///|
test "XLSX data bar f-element formulas set the range" {
  let encoded = "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"
  let data = @base64.decode(encoded[:]) catch { _ => b"" }
  let result = convert_plain_no_fonts(data)
  let doc = @core.open_single(result.bdf)
  let widths : Array[Double] = []
  for part in doc.manifest.parts {
    if part.kind != "obj" {
      continue
    }
    let resources = @core.decode_object_resources(doc.part(part.hash)) catch {
      _ => continue
    }
    for command in @render.compile_object(resources.object) {
      match command {
        FillRect(_, _, width, _) => widths.push(width)
        _ => ()
      }
    }
  }
  assert_eq(widths.length(), 4)
  assert_true(widths[0] > 12.0)
}
