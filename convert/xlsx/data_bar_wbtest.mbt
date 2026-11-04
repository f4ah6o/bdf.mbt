///|
test "XLSX data bars draw proportional rects" {
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
  for index in 1..<widths.length() {
    assert_true(widths[index] > widths[index - 1])
  }
}
